//! Optional runtime method signature validation and debug checked messaging.

const std = @import("std");
const raw = @import("raw");
const encoding = @import("encoding");
const receiver_mod = @import("receiver.zig");
const selector_mod = @import("selector.zig");
const arguments_mod = @import("arguments.zig");
const returns_mod = @import("returns.zig");
const send_mod = @import("send.zig");

// Optional diagnostic layer that compiles away in fast release modes.

/// Checks whether `receiver` has an implementation for `selector`.
pub fn respondsToSelector(receiver: anytype, selector: anytype) bool {
    const raw_rec = receiver_mod.toRaw(receiver) orelse return false;
    const raw_sel = selector_mod.toRaw(selector);

    const cls = raw.runtime.object_getClass(raw_rec) orelse return false;
    return raw.runtime.class_respondsToSelector(cls, raw_sel) == raw.YES;
}

/// Dispatches an Objective-C message after validating that `receiver` responds to `selector`.
///
/// In Debug/ReleaseSafe this additionally compares `method_getTypeEncoding()`
/// against the Zig-requested `Return` + `args` signature (layout offsets and
/// frame size ignored) and panics on mismatch. Ordinary `send()` remains the
/// zero-overhead expert API with no runtime lookup.
///
/// Best-effort only: unknown runtime types compare compatible, and parse/OOM
/// failures or non-standard method structures skip the check instead of
/// panicking. No strict mode is provided.
///
/// Panics in Debug/ReleaseSafe if `receiver` is non-nil and does not respond
/// to `selector`, if no method implementation can be found, or if the runtime
/// signature is incompatible with the requested Zig signature.
pub inline fn sendChecked(
    comptime Return: type,
    receiver: anytype,
    selector: anytype,
    args: anytype,
) Return {
    if (std.debug.runtime_safety) {
        // Built at comptime (this function is inline); the runtime check below
        // only parses and compares strings.
        const expected = comptime expectedMethodEncoding(Return, @TypeOf(args));
        checkSignature(receiver, selector, &expected);
    }
    return send_mod.send(Return, receiver, selector, args);
}

fn expectedMethodEncodingLength(comptime Return: type, comptime Args: type) usize {
    comptime {
        const AbiReturn = returns_mod.AbiReturnType(Return);
        var total: usize = encoding.encoder.encodedLength(AbiReturn);
        total += 1; // self ('@')
        total += 1; // _cmd (':')
        const fields = @typeInfo(Args).@"struct".fields;
        for (fields) |f| {
            total += encoding.encoder.encodedLength(arguments_mod.AbiArgumentType(f.type));
        }
        return total;
    }
}

fn expectedMethodEncoding(
    comptime Return: type,
    comptime Args: type,
) [expectedMethodEncodingLength(Return, Args):0]u8 {
    comptime {
        const len = expectedMethodEncodingLength(Return, Args);
        var buf: [len:0]u8 = undefined;
        var idx: usize = 0;

        const AbiReturn = returns_mod.AbiReturnType(Return);
        const ret_enc = encoding.comptimeEncode(AbiReturn);
        @memcpy(buf[idx .. idx + ret_enc.len], &ret_enc);
        idx += ret_enc.len;

        // Canonical method encoding: implicit self is always '@', even for
        // class methods (the receiver's class-ness is not re-encoded here).
        buf[idx] = '@';
        idx += 1;
        buf[idx] = ':';
        idx += 1;

        const fields = @typeInfo(Args).@"struct".fields;
        for (fields) |f| {
            const arg_enc = encoding.comptimeEncode(arguments_mod.AbiArgumentType(f.type));
            @memcpy(buf[idx .. idx + arg_enc.len], &arg_enc);
            idx += arg_enc.len;
        }

        buf[len] = 0;
        return buf;
    }
}

/// Structural compatibility between a runtime type and the Zig-requested type.
///
/// Lenient where the Zig side cannot know static details: object class names,
/// qualifiers, offsets, and aggregate tag names are ignored. Anything unknown
/// on the runtime side (e.g. Clang vector edge cases) fails open.
fn typesCompatible(runtime_type: encoding.Type, expected: encoding.Type) bool {
    const Tag = std.meta.Tag(encoding.Type);
    if (@as(Tag, runtime_type) != @as(Tag, expected)) {
        // `unknown` on the runtime side means the parser hit a Clang edge case;
        // fail open rather than panic on encodings we cannot model.
        if (@as(Tag, runtime_type) == .unknown) return true;
        return false;
    }
    return switch (runtime_type) {
        .scalar => |s| s == expected.scalar,
        // Class names and protocols are runtime details; any object matches.
        .object, .class, .selector, .block, .function_pointer, .unknown => true,
        .pointer => |ptr| typesCompatible(ptr.child.*.type, expected.pointer.child.*.type),
        .array => |arr| arr.len == expected.array.len and
            typesCompatible(arr.child.*.type, expected.array.child.*.type),
        // Aggregate tag names are ignored; layout (field count + types) decides.
        .structure => |s| aggregatesCompatible(s, expected.structure),
        .union_ => |u| aggregatesCompatible(u, expected.union_),
        .bitfield => |b| b.bits == expected.bitfield.bits,
        .atomic => |a| typesCompatible(a.child.*.type, expected.atomic.child.*.type),
    };
}

fn aggregatesCompatible(runtime_agg: encoding.AggregateType, expected_agg: encoding.AggregateType) bool {
    if (runtime_agg.fields.len != expected_agg.fields.len) return false;
    for (runtime_agg.fields, expected_agg.fields) |rf, ef| {
        if (!typesCompatible(rf.type.type, ef.type.type)) return false;
    }
    return true;
}

/// Outcome of comparing parsed runtime vs expected method signatures.
/// `skip` is the documented fail-open path: malformed or non-standard runtime
/// encodings never panic.
const SignatureVerdict = union(enum) {
    match,
    skip,
    return_mismatch,
    count_mismatch,
    argument_mismatch: usize,
};

/// Pure comparison behind `checkSignature`: return type, exact arity, then the
/// explicit arguments at [2..]. Unknown runtime types stay compatible.
fn checkSignatures(
    runtime_sig: encoding.method.MethodSignature,
    expected_sig: encoding.method.MethodSignature,
) SignatureVerdict {
    runtime_sig.validateObjectiveCMethod() catch return .skip;
    if (!typesCompatible(runtime_sig.return_type.type, expected_sig.return_type.type))
        return .return_mismatch;
    if (runtime_sig.arguments.len != expected_sig.arguments.len)
        return .count_mismatch;
    for (runtime_sig.arguments[2..], expected_sig.arguments[2..], 0..) |ra, ea, i| {
        if (!typesCompatible(ra.type.type, ea.type.type))
            return .{ .argument_mismatch = i };
    }
    return .match;
}

fn checkSignature(
    receiver: anytype,
    selector: anytype,
    expected_enc: []const u8,
) void {
    const raw_rec = receiver_mod.toRaw(receiver);
    if (raw_rec == null) return; // nil messaging: no method, nothing to check.
    const raw_sel = selector_mod.toRaw(selector);

    if (!respondsToSelector(receiver, selector)) {
        std.debug.panic("Objective-C message target does not respond to selector", .{});
    }

    // `object_getClass` yields the dispatch class directly: the class for an
    // instance, the metaclass for a class object (whose instance methods are
    // the class methods). One lookup covers both receivers.
    const cls = raw.runtime.object_getClass(raw_rec.?) orelse return;
    const m = raw.runtime.class_getInstanceMethod(cls, raw_sel) orelse std.debug.panic(
        "Objective-C message target responds to selector but no Method was found",
        .{},
    );

    const runtime_enc_c = raw.runtime.method_getTypeEncoding(m) orelse return;
    const runtime_enc = std.mem.span(runtime_enc_c);

    // Stack-backed allocator: method encodings are small; OOM fails open.
    var backing: [2048]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&backing);
    const allocator = fba.allocator();

    var runtime_sig = encoding.parseMethod(allocator, runtime_enc) catch return;
    defer runtime_sig.deinit(allocator);
    var expected_sig = encoding.parseMethod(allocator, expected_enc) catch return;
    defer expected_sig.deinit(allocator);

    switch (checkSignatures(runtime_sig, expected_sig)) {
        .match, .skip => {},
        .return_mismatch => std.debug.panic(
            "Objective-C return signature mismatch: runtime '{s}' vs requested '{s}'",
            .{ runtime_enc, expected_enc },
        ),
        .count_mismatch => std.debug.panic(
            "Objective-C argument count mismatch: runtime '{s}' vs requested '{s}'",
            .{ runtime_enc, expected_enc },
        ),
        .argument_mismatch => |i| std.debug.panic(
            "Objective-C argument #{d} signature mismatch: runtime '{s}' vs requested '{s}'",
            .{ i, runtime_enc, expected_enc },
        ),
    }
}

test "sendChecked: valid NSObject messages pass signature validation" {
    const objc = @import("zobjc");
    const NSObject = objc.requireClass("NSObject");

    const obj = sendChecked(objc.Object, NSObject, "alloc", .{});
    const init = sendChecked(objc.Object, obj, "init", .{});
    defer init.send(void, "dealloc", .{});

    // description -> @ ; hash -> NSUInteger ; isEqual: takes @, returns BOOL.
    const desc = sendChecked(?objc.Object, init, "description", .{});
    _ = desc;
    const hash = sendChecked(usize, init, "hash", .{});
    _ = hash;
    const eq = sendChecked(raw.BOOL, init, "isEqual:", .{init});
    try std.testing.expect(raw.boolResult(eq));
}

test "checkSignatures: table of encoding pairs" {
    const allocator = std.testing.allocator;
    const Case = struct {
        runtime: []const u8,
        expected: []const u8,
        verdict: SignatureVerdict,
    };
    const cases = [_]Case{
        // Exact matches, with and without offsets/frame size.
        .{ .runtime = "@@:", .expected = "@@:", .verdict = .match },
        .{ .runtime = "v@:i", .expected = "v@:i", .verdict = .match },
        .{ .runtime = "@16@0:8", .expected = "@@:", .verdict = .match },
        .{ .runtime = "v24@0:8i16", .expected = "v@:i", .verdict = .match },
        // Wrong explicit argument type / count.
        .{ .runtime = "v@:i", .expected = "v@:f", .verdict = .{ .argument_mismatch = 0 } },
        .{ .runtime = "v@:if", .expected = "v@:fi", .verdict = .{ .argument_mismatch = 0 } },
        .{ .runtime = "v@:i", .expected = "v@:", .verdict = .count_mismatch },
        .{ .runtime = "v@:", .expected = "v@:i", .verdict = .count_mismatch },
        // Wrong return type.
        .{ .runtime = "i@:", .expected = "v@:", .verdict = .return_mismatch },
        // Missing _cmd: non-standard structure fails open.
        .{ .runtime = "v@", .expected = "v@:", .verdict = .skip },
        // Unknown (Clang edge-case) return type fails open.
        .{ .runtime = "16@0:8", .expected = "@@:", .verdict = .match },
    };
    for (cases) |c| {
        var runtime_sig = try encoding.parseMethod(allocator, c.runtime);
        defer runtime_sig.deinit(allocator);
        var expected_sig = try encoding.parseMethod(allocator, c.expected);
        defer expected_sig.deinit(allocator);
        try std.testing.expectEqualDeep(c.verdict, checkSignatures(runtime_sig, expected_sig));
    }
}

test "sendChecked: nil receiver short-circuits without lookup" {
    const objc = @import("zobjc");
    const nil_obj: ?objc.Object = null;
    const result = sendChecked(?objc.Object, nil_obj, "description", .{});
    try std.testing.expectEqual(@as(?objc.Object, null), result);
}
