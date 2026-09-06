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
const raw = @import("../raw/root.zig");
const Object = @import("../runtime/object.zig").Object;
const Class = @import("../runtime/class.zig").Class;
const Selector = @import("../runtime/selector.zig").Selector;

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
        if (!fn_info.calling_convention.eql(std.builtin.CallingConvention.c)) {
            @compileError("Objective-C method implementation function must use callconv(.c)");
        }
        if (fn_info.params.len < 2) {
            @compileError("Objective-C method implementation must take at least 2 arguments (self, _cmd)");
        }

        const p0 = fn_info.params[0].type orelse @compileError("parameter 0 must have a type");
        if (p0 != Object and p0 != ?Object and p0 != Class and p0 != ?Class and
            p0 != raw.id and p0 != raw.Class)
        {
            @compileError("First parameter of an Objective-C method must be Object or Class (or raw id/Class)");
        }

        const p1 = fn_info.params[1].type orelse @compileError("parameter 1 must have a type");
        if (p1 != Selector and p1 != ?Selector and p1 != raw.SEL) {
            @compileError("Second parameter of an Objective-C method must be a Selector (or raw SEL)");
        }

        const RetType = fn_info.return_type orelse void;
        zig_type.assertObjCEncodable(RetType);

        var total_len: usize = encoder.encodedLength(RetType);
        total_len += encoder.encodedLength(p0);
        total_len += encoder.encodedLength(p1);
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

            const p0 = fn_info.params[0].type.?;
            const p0_enc = encoder.comptimeEncode(p0);
            @memcpy(buf[idx .. idx + p0_enc.len], &p0_enc);
            idx += p0_enc.len;

            const p1 = fn_info.params[1].type.?;
            const p1_enc = encoder.comptimeEncode(p1);
            @memcpy(buf[idx .. idx + p1_enc.len], &p1_enc);
            idx += p1_enc.len;

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
    comptime _ = methodEncoding(F);
}
