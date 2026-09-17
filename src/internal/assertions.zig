//! Internal assertions and compile-time validation helpers.

const std = @import("std");

/// Verifies that a type is safe to pass across the C ABI.
// Leverage Zig's builtin @typeInfo to check ABI compatibility.
pub fn assertCAbiCompatible(comptime T: type) void {
    switch (@typeInfo(T)) {
        .int, .float, .bool, .void => {},
        .@"enum" => {},
        .pointer => {},
        .optional => |opt| {
            if (@typeInfo(opt.child) != .pointer)
                @compileError("assertCAbiCompatible: " ++ @typeName(T) ++ " — optional must wrap a pointer");
        },
        .@"struct" => |s| {
            if (s.layout != .@"extern" and s.layout != .@"packed")
                @compileError("assertCAbiCompatible: " ++ @typeName(T) ++ " — struct must be extern or packed");
        },
        .@"union" => |u| {
            if (u.layout != .@"extern")
                @compileError("assertCAbiCompatible: " ++ @typeName(T) ++ " — union must be extern");
        },
        else => @compileError("assertCAbiCompatible: " ++ @typeName(T) ++ " — not C-ABI compatible"),
    }
}
