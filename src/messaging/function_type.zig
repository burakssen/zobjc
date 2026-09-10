//! Pure compile-time C function type synthesis for Objective-C dispatch.
//!
//! Isolates Zig compiler function-type reflection (@Fn) in a single module.

const std = @import("std");
const raw = @import("../raw/root.zig");

// ponytail: Isolate compiler-specific @Fn reflection in this module only.

/// Generates the exact non-variadic C function type for an ordinary message dispatch.
///
/// Shape: `fn (raw.id, raw.SEL, AbiArgs...) callconv(.c) AbiReturn`
pub fn MessageFunctionType(comptime AbiReturn: type, comptime AbiArgsTuple: type) type {
    const fields = @typeInfo(AbiArgsTuple).@"struct".fields;
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
