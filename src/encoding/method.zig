//! Objective-C method signature representation and parsing.
//!
//! Handles:
//! - `MethodSignature`: Return type, optional frame size, and arguments with optional offsets.
//! - `parseMethod`: Parses compact (`v@:i`) and annotated (`v24@0:8i16`) method signatures.
//! - `methodEncoding`: Comptime generator from Zig C-ABI callback function types.
//! - `encodeMethod`: Serializes a `MethodSignature` AST into an encoding string.

const std = @import("std");
const types = @import("type.zig");
const QualifiedType = types.QualifiedType;
const parser_mod = @import("parser.zig");
const Parser = parser_mod.Parser;
const encoder = @import("encoder.zig");
const zig_type = @import("zig_type.zig");
const raw = @import("raw");
const wrapper = @import("internal").wrapper;

/// A Zig type usable as an Objective-C method receiver: a raw `id`/`Class`
/// handle or any wrapper whose kind is object or class.
fn isMethodReceiver(comptime T: type) bool {
    if (T == raw.id or T == raw.Class) return true;
    if (!wrapper.isObjCWrapper(T)) return false;
    return switch (wrapper.wrapperKind(T)) {
        .object, .class => true,
        else => false,
    };
}

/// A Zig type usable as an Objective-C method selector: a raw `SEL` handle
/// or any wrapper whose kind is selector.
fn isMethodSelector(comptime T: type) bool {
    if (T == raw.SEL) return true;
    if (!wrapper.isObjCWrapper(T)) return false;
    return wrapper.wrapperKind(T) == .selector;
}

/// An argument in an Objective-C method signature.
pub const MethodArgument = struct {
    type: QualifiedType,
    offset: ?isize = null,

    pub fn deinit(self: *MethodArgument, allocator: std.mem.Allocator) void {
        self.type.deinit(allocator);
    }

    pub fn eql(self: MethodArgument, other: MethodArgument) bool {
        return self.type.eql(other.type);
    }
};

/// Options controlling `encodeMethod` output formatting.
pub const MethodEncodeOptions = struct {
    include_frame_size: bool = false,
    include_offsets: bool = false,
};

/// A complete Objective-C method signature.
pub const MethodSignature = struct {
    return_type: QualifiedType,
    frame_size: ?usize = null,
    arguments: []MethodArgument,

    pub fn deinit(self: *MethodSignature, allocator: std.mem.Allocator) void {
        self.return_type.deinit(allocator);
        for (self.arguments) |*arg| arg.deinit(allocator);
        allocator.free(self.arguments);
    }

    /// Validates that this signature adheres to standard Objective-C method dispatch requirements:
    /// - At least 2 arguments.
    /// - Argument 0 is receiver (Object or Class).
    /// - Argument 1 is selector.
    pub fn validateObjectiveCMethod(self: MethodSignature) !void {
        if (self.arguments.len < 2) return error.MissingReceiverOrSelector;
        switch (self.arguments[0].type.type) {
            .object, .class => {},
            else => return error.InvalidReceiverArgument,
        }
        if (self.arguments[1].type.type != .selector) {
            return error.InvalidSelectorArgument;
        }
    }

    pub fn eql(self: MethodSignature, other: MethodSignature) bool {
        if (!self.return_type.eql(other.return_type)) return false;
        if (self.arguments.len != other.arguments.len) return false;
        for (self.arguments, other.arguments) |a1, a2| {
            if (!a1.eql(a2)) return false;
        }
        return true;
    }
};

/// Parses an Objective-C method encoding string into a `MethodSignature`.
///
/// Supports compact encodings (`v@:i`) and annotated encodings (`v24@0:8i16`).
pub fn parseMethod(allocator: std.mem.Allocator, input: []const u8) !MethodSignature {
    if (input.len == 0) return error.UnexpectedEnd;
    var parser = Parser.init(allocator, input);

    var ret_type: QualifiedType = undefined;
    var frame_size: ?usize = null;

    if (parser.peek()) |first_ch| {
        if (first_ch >= '0' and first_ch <= '9') {
            // Clang extension / edge case: vector or incomplete type emitted 0 characters,
            // so string begins immediately with frame size digits (e.g. "48@0:8@1624^B40")
            ret_type = .{
                .type = .unknown,
                .qualifiers = .{},
            };
            frame_size = try parser.parseNumber();
        } else {
            ret_type = try parser.parseQualifiedType();
            if (parser.peek()) |ch| {
                if (ch >= '0' and ch <= '9') {
                    frame_size = try parser.parseNumber();
                }
            }
        }
    } else {
        return error.UnexpectedEnd;
    }
    errdefer ret_type.deinit(allocator);

    var args: std.ArrayList(MethodArgument) = .empty;
    errdefer {
        for (args.items) |*arg| arg.deinit(allocator);
        args.deinit(allocator);
    }

    while (parser.peek() != null) {
        if (parser.peek()) |ch| {
            if (ch >= '0' and ch <= '9') {
                // Vector / incomplete argument type where Clang emitted 0 characters,
                // leaving only the stack offset digits!
                const offset = try parser.parseSignedNumber();
                try args.append(allocator, .{
                    .type = .{ .type = .unknown, .qualifiers = .{} },
                    .offset = offset,
                });
                continue;
            }
        }

        var arg_type = try parser.parseQualifiedType();
        errdefer arg_type.deinit(allocator);

        var offset: ?isize = null;
        if (parser.peek()) |ch| {
            if (ch == '+' or ch == '-' or (ch >= '0' and ch <= '9')) {
                offset = try parser.parseSignedNumber();
            }
        }

        try args.append(allocator, .{
            .type = arg_type,
            .offset = offset,
        });
    }

    return .{
        .return_type = ret_type,
        .frame_size = frame_size,
        .arguments = try args.toOwnedSlice(allocator),
    };
}

/// Calculates the exact character count needed for the compact method encoding of `F`.
pub fn methodEncodingLength(comptime F: type) usize {
    comptime {
        const info = @typeInfo(F);
        if (info != .@"fn") {
            @compileError("methodEncoding requires a function type, found: " ++ @typeName(F));
        }
        const fn_info = info.@"fn";
        if (fn_info.params.len < 2) {
            @compileError("Objective-C method implementation must take at least 2 arguments (self, _cmd)");
        }

        const p0 = fn_info.params[0].type orelse @compileError("parameter 0 must have a type");
        if (!isMethodReceiver(p0)) {
            @compileError("First parameter of an Objective-C method must be Object or Class (or raw id/Class)");
        }

        const p1 = fn_info.params[1].type orelse @compileError("parameter 1 must have a type");
        if (!isMethodSelector(p1)) {
            @compileError("Second parameter of an Objective-C method must be a Selector (or raw SEL)");
        }

        const RetType = fn_info.return_type orelse void;
        zig_type.assertObjCEncodable(RetType);

        var total_len: usize = encoder.encodedLength(RetType);
        // Implicit self/_cmd are always '@' + ':' in canonical method
        // metadata, regardless of the Zig receiver type (Object vs Class).
        total_len += 2;
        for (fn_info.params[2..]) |param| {
            const PT = param.type orelse @compileError("method parameter must have a type");
            zig_type.assertObjCEncodable(PT);
            total_len += encoder.encodedLength(PT);
        }
        return total_len;
    }
}

/// Generates a compact Objective-C method type encoding (e.g. `v@:i`) from a Zig C-ABI callback function type.
pub fn methodEncoding(comptime F: type) [methodEncodingLength(F):0]u8 {
    const S = struct {
        const value = blk: {
            const total_len = methodEncodingLength(F);
            var buf: [total_len:0]u8 = undefined;
            var idx: usize = 0;

            const fn_info = @typeInfo(F).@"fn";
            const RetType = fn_info.return_type orelse void;
            const ret_enc = encoder.comptimeEncode(RetType);
            @memcpy(buf[idx .. idx + ret_enc.len], &ret_enc);
            idx += ret_enc.len;

            // Canonical method metadata: implicit self is always '@', even for
            // class receivers; _cmd is always ':'. (A `Class` in any other
            // position still encodes as '#' via the generic encoder.)
            buf[idx] = '@';
            idx += 1;
            buf[idx] = ':';
            idx += 1;

            for (fn_info.params[2..]) |param| {
                const p_enc = encoder.comptimeEncode(param.type.?);
                @memcpy(buf[idx .. idx + p_enc.len], &p_enc);
                idx += p_enc.len;
            }

            buf[total_len] = 0;
            break :blk buf;
        };
    };
    return S.value;
}

/// Serializes a `MethodSignature` AST into an allocated null-terminated string.
pub fn encodeMethod(
    allocator: std.mem.Allocator,
    signature: MethodSignature,
    options: MethodEncodeOptions,
) ![:0]u8 {
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(allocator);

    const ret_str = try encoder.encode(allocator, signature.return_type);
    defer allocator.free(ret_str);
    try list.appendSlice(allocator, ret_str);

    if (options.include_frame_size) {
        if (signature.frame_size) |fs| {
            try list.print(allocator, "{d}", .{fs});
        }
    }

    for (signature.arguments) |arg| {
        const arg_str = try encoder.encode(allocator, arg.type);
        defer allocator.free(arg_str);
        try list.appendSlice(allocator, arg_str);

        if (options.include_offsets) {
            if (arg.offset) |off| {
                try list.print(allocator, "{d}", .{off});
            }
        }
    }

    return list.toOwnedSliceSentinel(allocator, 0);
}

/// Validates that callback type `F` is suitable for an Objective-C method implementation.
pub fn validateMethodImplementation(comptime F: type) void {
    const info = @typeInfo(F);
    const cc_tag: std.builtin.CallingConvention.Tag = info.@"fn".calling_convention;
    const c_tag: std.builtin.CallingConvention.Tag = std.builtin.CallingConvention.c;
    if (cc_tag != c_tag) {
        @compileError("Objective-C method implementation function must use callconv(.c)");
    }
    comptime _ = methodEncoding(F);
}

const testing = std.testing;

test "method: parse compact and annotated signatures" {
    const allocator = testing.allocator;
    var sig = try parseMethod(allocator, "v@:i");
    defer sig.deinit(allocator);
    try testing.expect(sig.return_type.type == .scalar);
    try testing.expectEqual(.void, sig.return_type.type.scalar);
    try testing.expectEqual(@as(?usize, null), sig.frame_size);
    try testing.expectEqual(@as(usize, 3), sig.arguments.len);
    try testing.expect(sig.arguments[0].type.type == .object);
    try testing.expect(sig.arguments[1].type.type == .selector);
    try testing.expect(sig.arguments[2].type.type == .scalar);
    try testing.expectEqual(.int, sig.arguments[2].type.type.scalar);

    var annotated = try parseMethod(allocator, "v24@0:8i16");
    defer annotated.deinit(allocator);
    try testing.expectEqual(@as(?usize, 24), annotated.frame_size);
    try testing.expectEqual(@as(?isize, 0), annotated.arguments[0].offset);
    try testing.expectEqual(@as(?isize, 8), annotated.arguments[1].offset);
    try testing.expectEqual(@as(?isize, 16), annotated.arguments[2].offset);
}

test "method: parse aggregates and encode round trip" {
    const allocator = testing.allocator;
    var sig = try parseMethod(allocator, "{CGPoint=dd}32@0:8{CGPoint=dd}16");
    defer sig.deinit(allocator);
    try testing.expect(sig.return_type.type == .structure);
    try testing.expectEqualStrings("CGPoint", sig.return_type.type.structure.name);
    try testing.expectEqual(@as(?usize, 32), sig.frame_size);
    try testing.expect(sig.arguments[2].type.type == .structure);
    try testing.expectEqual(@as(?isize, 16), sig.arguments[2].offset);

    var compact = try parseMethod(allocator, "v@:i");
    defer compact.deinit(allocator);
    const encoded = try encodeMethod(allocator, compact, .{});
    defer allocator.free(encoded);
    try testing.expectEqualStrings("v@:i", encoded);
}

const MethodFixtureObject = struct {
    ptr: *raw.objc_object,
    pub const objc_wrapper = true;
};

const MethodFixtureClass = struct {
    ptr: *raw.objc_class,
    pub const objc_wrapper = true;
};

const MethodFixtureSelector = struct {
    ptr: *raw.objc_selector,
    pub const objc_wrapper = true;
};

test "method: comptime methodEncoding from Zig callbacks" {
    const Point = extern struct { x: f64, y: f64 };
    const InstanceCallback = fn (MethodFixtureObject, MethodFixtureSelector, i32) callconv(.c) void;
    const ClassCallback = fn (MethodFixtureClass, MethodFixtureSelector, [4]f32) callconv(.c) i32;
    const StructReturnCallback = fn (MethodFixtureObject, MethodFixtureSelector) callconv(.c) Point;
    const RawHandleCallback = fn (raw.id, raw.SEL, ?*anyopaque) callconv(.c) raw.id;

    const enc1 = comptime methodEncoding(InstanceCallback);
    const enc2 = comptime methodEncoding(ClassCallback);
    const enc3 = comptime methodEncoding(StructReturnCallback);
    const enc4 = comptime methodEncoding(RawHandleCallback);
    try testing.expectEqualStrings("v@:i", &enc1);
    try testing.expectEqualStrings("i@:[4f]", &enc2);
    try testing.expectEqualStrings("{Point=dd}@:", &enc3);
    try testing.expectEqualStrings("@@:^v", &enc4);
}

test "method: implicit self is always @, even for class-kind receivers" {
    const InstanceCallback = fn (MethodFixtureObject, MethodFixtureSelector, i32) callconv(.c) void;
    const ClassCallback = fn (MethodFixtureClass, MethodFixtureSelector, i32) callconv(.c) void;
    try testing.expectEqualStrings("v@:i", &methodEncoding(InstanceCallback));
    try testing.expectEqualStrings("v@:i", &methodEncoding(ClassCallback));
    // Generic encoding of a class-kind wrapper itself is unchanged.
    const class_enc = comptime encoder.comptimeEncode(MethodFixtureClass);
    try testing.expectEqualStrings("#", &class_enc);
}

test "method: validate method implementation" {
    const ValidFn = fn (MethodFixtureObject, MethodFixtureSelector, f64) callconv(.c) bool;
    validateMethodImplementation(ValidFn);
    const ValidClassFn = fn (MethodFixtureClass, MethodFixtureSelector) callconv(.c) void;
    validateMethodImplementation(ValidClassFn);
}
