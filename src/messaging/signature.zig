//! Optional runtime method signature validation and debug checked messaging.

const std = @import("std");
const raw = @import("raw");
const runtime = @import("runtime");
const wrapper = @import("internal").wrapper;
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
        const expected = comptime expectedMethodEncoding(Return, @TypeOf(receiver), @TypeOf(args));
        checkSignature(receiver, selector, &expected);
    }
    return send_mod.send(Return, receiver, selector, args);
}

fn receiverIsClass(comptime R: type) bool {
    if (R == runtime.Class or R == ?runtime.Class) return true;
    if (R == raw.Class or R == *raw.objc_class) return true;
    if (@typeInfo(R) == .optional) return receiverIsClass(@typeInfo(R).optional.child);
    if (wrapper.isObjCWrapper(R)) return wrapper.wrapperKind(R) == .class;
    return false;
}

fn receiverEncodingChar(comptime R: type) u8 {
    if (receiverIsClass(R)) return '#';
    if (@typeInfo(R) == .optional) return receiverEncodingChar(@typeInfo(R).optional.child);
    if (wrapper.isObjCWrapper(R)) {
        return if (wrapper.wrapperKind(R) == .class) '#' else '@';
    }
    return '@';
}

fn expectedMethodEncodingLength(comptime Return: type, comptime Receiver: type, comptime Args: type) usize {
    comptime {
        _ = Receiver; // self is always exactly one encoding char ('@' or '#').
        const AbiReturn = returns_mod.AbiReturnType(Return);
        var total: usize = encoding.encoder.encodedLength(AbiReturn);
        total += 1; // self ('@' or '#')
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
    comptime Receiver: type,
    comptime Args: type,
) [expectedMethodEncodingLength(Return, Receiver, Args):0]u8 {
    comptime {
        const len = expectedMethodEncodingLength(Return, Receiver, Args);
        var buf: [len:0]u8 = undefined;
        var idx: usize = 0;

        const AbiReturn = returns_mod.AbiReturnType(Return);
        const ret_enc = encoding.comptimeEncode(AbiReturn);
        @memcpy(buf[idx .. idx + ret_enc.len], &ret_enc);
        idx += ret_enc.len;

        buf[idx] = receiverEncodingChar(Receiver);
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

    const cls = raw.runtime.object_getClass(raw_rec.?) orelse return;
    const method = if (receiverIsClass(@TypeOf(receiver)))
        raw.runtime.class_getClassMethod(cls, raw_sel)
    else
        raw.runtime.class_getInstanceMethod(cls, raw_sel);
    // Fall back to the other lookup before giving up (e.g. root-class edge cases).
    const resolved = method orelse if (receiverIsClass(@TypeOf(receiver)))
        raw.runtime.class_getInstanceMethod(cls, raw_sel)
    else
        raw.runtime.class_getClassMethod(cls, raw_sel);
    const m = resolved orelse std.debug.panic(
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

    if (!typesCompatible(runtime_sig.return_type.type, expected_sig.return_type.type)) {
        std.debug.panic(
            "Objective-C return signature mismatch: runtime '{s}' vs requested '{s}'",
            .{ runtime_enc, expected_enc },
        );
    }
    // Standard method encodings always lead with `self` (`@` for instances,
    // `#` for classes) and `_cmd` (`:`): e.g. `+alloc` is `@16@0:8`, where
    // `@0` is self and `:8` is _cmd. Gate on that structure first and fail
    // open for anything non-standard. Selector colon validation in `send()`
    // already guarantees the caller-side explicit argument count, so a
    // standard runtime encoding must then match exactly: same arity, with the
    // explicit arguments compared at [2..] instead of tail-aligned.
    runtime_sig.validateObjectiveCMethod() catch return;
    if (runtime_sig.arguments.len != expected_sig.arguments.len) {
        std.debug.panic(
            "Objective-C argument count mismatch: runtime '{s}' vs requested '{s}'",
            .{ runtime_enc, expected_enc },
        );
    }
    const runtime_explicit = runtime_sig.arguments[2..];
    const requested_explicit = expected_sig.arguments[2..];
    for (runtime_explicit, requested_explicit, 0..) |ra, ea, i| {
        if (!typesCompatible(ra.type.type, ea.type.type)) {
            std.debug.panic(
                "Objective-C argument #{d} signature mismatch: runtime '{s}' vs requested '{s}'",
                .{ i, runtime_enc, expected_enc },
            );
        }
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

test "sendChecked: nil receiver short-circuits without lookup" {
    const objc = @import("zobjc");
    const nil_obj: ?objc.Object = null;
    const result = sendChecked(?objc.Object, nil_obj, "description", .{});
    try std.testing.expectEqual(@as(?objc.Object, null), result);
}
