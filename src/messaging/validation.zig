//! Compile-time argument, return type, and selector validation for Objective-C messaging.

const std = @import("std");
const raw = @import("raw");
const wrapper = @import("internal").wrapper;
const receiver_mod = @import("receiver.zig");
const selector_mod = @import("selector.zig");
const arguments_mod = @import("arguments.zig");
const returns_mod = @import("returns.zig");
const encoding = @import("encoding");

// Strict compile-time validation with actionable diagnostics.

/// Asserts that `Args` is a tuple.
pub fn assertArgumentTuple(comptime Args: type) void {
    if (@typeInfo(Args) != .@"struct" or !@typeInfo(Args).@"struct".is_tuple) {
        @compileError("Objective-C message arguments must be supplied as a tuple. " ++
            "Example: objc.send(void, object, \"foo:bar:\", .{ foo, bar }); Found: " ++ @typeName(Args));
    }
}

/// Validates an individual message argument type at compile time.
pub fn assertValidArgument(comptime T: type, comptime index: usize) void {
    const idx_str = std.fmt.comptimePrint("#{d}", .{index});

    if (T == comptime_int) {
        @compileError("Objective-C message argument " ++ idx_str ++ " has type 'comptime_int'. " ++
            "Explicitly annotate the integer type (e.g. @as(c_int, 42) or @as(usize, 42)).");
    }

    if (T == comptime_float) {
        @compileError("Objective-C message argument " ++ idx_str ++ " has type 'comptime_float'. " ++
            "Explicitly annotate the float type (e.g. @as(f32, 1.5) or @as(f64, 1.5)).");
    }

    if (T == @TypeOf(null)) {
        @compileError("Objective-C message argument " ++ idx_str ++ " is untyped 'null'. " ++
            "Explicitly annotate the pointer or object type, e.g. @as(?objc.Object, null).");
    }

    if (T == []const u8 or T == []u8) {
        @compileError("Objective-C message argument " ++ idx_str ++ " has type '" ++ @typeName(T) ++ "'. " ++
            "A Zig slice is not a C string. Pass a sentinel-terminated string literal or [:0]const u8.");
    }

    // Explicit wrapper handles (runtime or custom) via the shared trait.
    // NOTE: explicit `comptime` is load-bearing (see NOTE in abi/type.zig).
    if (comptime wrapper.isObjCWrapper(T)) return;

    // Raw handles
    if (T == raw.id or T == raw.Class or T == raw.SEL or T == raw.IMP) return;

    // Sentinel strings
    if (arguments_mod.isSentinelString(T)) return;

    // Primitives
    if (T == bool or T == raw.BOOL) return;
    if (T == i8 or T == u8 or T == i16 or T == u16 or
        T == i32 or T == u32 or T == i64 or T == u64 or
        T == isize or T == usize or T == f32 or T == f64 or
        T == c_longdouble or T == c_char or T == c_short or
        T == c_ushort or T == c_int or T == c_uint or
        T == c_long or T == c_ulong or T == c_longlong or T == c_ulonglong)
    {
        return;
    }

    // Enums
    if (@typeInfo(T) == .@"enum") return;

    // Structural checks
    switch (@typeInfo(T)) {
        .pointer => |p| {
            if (p.size == .slice) {
                @compileError("Objective-C message argument " ++ idx_str ++ " is a slice ('" ++ @typeName(T) ++ "'). " ++
                    "Slices are fat pointers not compatible with the C ABI; pass a single pointer or array.");
            }
            return;
        },
        .optional => |opt| {
            if (@typeInfo(opt.child) == .pointer) return;
            @compileError("Objective-C message argument " ++ idx_str ++ " is optional '" ++ @typeName(T) ++ "'. " ++
                "Only optional pointers or object handles are supported across the C ABI.");
        },
        .@"struct" => |s| {
            if (s.layout != .@"extern") {
                @compileError("Objective-C message argument " ++ idx_str ++ " has type '" ++ @typeName(T) ++ "' which is a Zig-layout struct. " ++
                    "Only 'extern struct' types are C ABI compatible.");
            }
            return;
        },
        .@"union" => |u| {
            if (u.layout != .@"extern") {
                @compileError("Objective-C message argument " ++ idx_str ++ " has type '" ++ @typeName(T) ++ "' which is a tagged/Zig union. " ++
                    "Only 'extern union' types are C ABI compatible.");
            }
            return;
        },
        .error_union, .error_set => {
            @compileError("Objective-C message argument " ++ idx_str ++ " is an error type ('" ++ @typeName(T) ++ "'). " ++
                "Error unions cannot cross the Objective-C C ABI.");
        },
        else => @compileError("Objective-C message argument " ++ idx_str ++ " has unsupported type '" ++ @typeName(T) ++ "'."),
    }
}

/// Validates all arguments in a tuple.
pub fn assertValidArguments(comptime Args: type) void {
    assertArgumentTuple(Args);
    const fields = @typeInfo(Args).@"struct".fields;
    inline for (fields, 0..) |f, i| {
        assertValidArgument(f.type, i);
    }
}

/// Asserts that `Return` is a valid return type for Objective-C messaging.
pub fn assertValidReturn(comptime Return: type) void {
    if (Return == void) return;

    // Check for Retained(T) explicitly
    if (@typeInfo(Return) == .@"struct") {
        if (@hasDecl(Return, "adopt") and @hasDecl(Return, "retain") and @hasField(Return, "value")) {
            @compileError("Direct Retained(T) return is not supported in objc.send(). " ++
                "Receive as Object and use Retained(Object).adopt(...) or .retain(...) to explicitly manage ownership.");
        }
    }

    // Explicit wrapper handles (runtime or custom) via the shared trait.
    // NOTE: explicit `comptime` is load-bearing (see NOTE in abi/type.zig).
    if (comptime wrapper.isObjCWrapper(Return)) return;

    // Raw handles
    if (Return == raw.id or Return == raw.Class or Return == raw.SEL or Return == raw.IMP) return;

    // Normalized ABI type check
    const AbiReturn = returns_mod.AbiReturnType(Return);
    encoding.assertObjCEncodable(AbiReturn);
}
