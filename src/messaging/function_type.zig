//! Pure compile-time C function type synthesis for Objective-C dispatch.
//!
//! Isolates Zig compiler function-type reflection (@Fn) in a single module.

const std = @import("std");
const testing = std.testing;
const raw = @import("raw");

// Isolate compiler-specific @Fn reflection in this module only.

/// Generates the exact non-variadic C function type for an ordinary message dispatch.
///
/// Shape: `fn (raw.id, raw.SEL, AbiArgs...) callconv(.c) AbiReturn`
pub fn MessageFunctionType(comptime AbiReturn: type, comptime AbiArgsTuple: type) type {
    const fields = @typeInfo(AbiArgsTuple).@"struct".fields;
    // fast-path common 0-arg call without @Fn reflection overhead
    if (fields.len == 0) {
        return fn (raw.id, raw.SEL) callconv(.c) AbiReturn;
    }

    const total_params = fields.len + 2;

    var param_types: [total_params]type = undefined;
    param_types[0] = raw.id;
    param_types[1] = raw.SEL;
    inline for (fields, 0..) |f, i| {
        param_types[i + 2] = f.type;
    }

    return @Fn(&param_types, &@splat(.{}), AbiReturn, .{ .@"callconv" = .c });
}

/// Generates the exact C function type for a superclass message dispatch.
///
/// Shape: `fn (*raw.message.objc_super, raw.SEL, AbiArgs...) callconv(.c) AbiReturn`
pub fn SuperFunctionType(comptime AbiReturn: type, comptime AbiArgsTuple: type) type {
    const fields = @typeInfo(AbiArgsTuple).@"struct".fields;
    if (fields.len == 0) {
        return fn (*raw.objc_super, raw.SEL) callconv(.c) AbiReturn;
    }

    const total_params = fields.len + 2;

    var param_types: [total_params]type = undefined;
    param_types[0] = *raw.objc_super;
    param_types[1] = raw.SEL;
    inline for (fields, 0..) |f, i| {
        param_types[i + 2] = f.type;
    }

    return @Fn(&param_types, &@splat(.{}), AbiReturn, .{ .@"callconv" = .c });
}

/// Generates the exact C function type for a direct method invocation (`method_invoke`).
///
/// Shape: `fn (raw.id, raw.Method, AbiArgs...) callconv(.c) AbiReturn`
pub fn MethodInvokeFunctionType(comptime AbiReturn: type, comptime AbiArgsTuple: type) type {
    const fields = @typeInfo(AbiArgsTuple).@"struct".fields;
    if (fields.len == 0) {
        return fn (raw.id, raw.Method) callconv(.c) AbiReturn;
    }

    const total_params = fields.len + 2;

    var param_types: [total_params]type = undefined;
    param_types[0] = raw.id;
    param_types[1] = raw.Method;
    inline for (fields, 0..) |f, i| {
        param_types[i + 2] = f.type;
    }

    return @Fn(&param_types, &@splat(.{}), AbiReturn, .{ .@"callconv" = .c });
}

/// Generates the exact C function type for a direct IMP call.
///
/// Shape: `fn (raw.id, raw.SEL, AbiArgs...) callconv(.c) AbiReturn`
pub fn ImpFunctionType(comptime AbiReturn: type, comptime AbiArgsTuple: type) type {
    return MessageFunctionType(AbiReturn, AbiArgsTuple);
}

test "function_type: message signature structure" {
    const AbiArgsTuple = struct { c_int, f64, [*:0]const u8 };
    const Fn = MessageFunctionType(raw.id, AbiArgsTuple);
    const info = @typeInfo(Fn).@"fn";

    try testing.expectEqual(std.builtin.CallingConvention.c, info.calling_convention);
    try testing.expectEqual(raw.id, info.return_type.?);
    try testing.expectEqual(@as(usize, 5), info.params.len);

    try testing.expectEqual(raw.id, info.params[0].type.?);
    try testing.expectEqual(raw.SEL, info.params[1].type.?);
    try testing.expectEqual(c_int, info.params[2].type.?);
    try testing.expectEqual(f64, info.params[3].type.?);
    try testing.expectEqual([*:0]const u8, info.params[4].type.?);
}

test "function_type: super signature structure" {
    const AbiArgsTuple = struct { usize };
    const Fn = SuperFunctionType(void, AbiArgsTuple);
    const info = @typeInfo(Fn).@"fn";

    try testing.expectEqual(std.builtin.CallingConvention.c, info.calling_convention);
    try testing.expectEqual(void, info.return_type.?);
    try testing.expectEqual(@as(usize, 3), info.params.len);

    try testing.expectEqual(*raw.objc_super, info.params[0].type.?);
    try testing.expectEqual(raw.SEL, info.params[1].type.?);
    try testing.expectEqual(usize, info.params[2].type.?);
}

test "function_type: method_invoke signature structure" {
    const AbiArgsTuple = struct { c_int };
    const Fn = MethodInvokeFunctionType(c_int, AbiArgsTuple);
    const info = @typeInfo(Fn).@"fn";

    try testing.expectEqual(std.builtin.CallingConvention.c, info.calling_convention);
    try testing.expectEqual(c_int, info.return_type.?);
    try testing.expectEqual(@as(usize, 3), info.params.len);

    try testing.expectEqual(raw.id, info.params[0].type.?);
    try testing.expectEqual(raw.Method, info.params[1].type.?);
    try testing.expectEqual(c_int, info.params[2].type.?);
}
