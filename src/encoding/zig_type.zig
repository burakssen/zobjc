//! Zig type validation, categorization, and Objective-C encoding traits.
//!
//! Enforces C ABI compatibility:
//! - Accepts extern structs and extern unions.
//! - Rejects Zig-layout structs, packed structs, tagged unions, slices, and error unions.
//! - Supports explicit `objc_type_encoding` and `objc_encoding_name` overrides.

const std = @import("std");
const raw = @import("../raw/root.zig");
const Object = @import("../runtime/object.zig").Object;
const Class = @import("../runtime/class.zig").Class;
const Selector = @import("../runtime/selector.zig").Selector;

/// Determines whether `T` is valid for Objective-C type encoding.
pub fn isObjCEncodable(comptime T: type) bool {
    // 1. Explicit type encoding override
    switch (@typeInfo(T)) {
        .@"struct", .@"union", .@"enum", .@"opaque" => {
            if (@hasDecl(T, "objc_type_encoding")) return true;
        },
        else => {},
    }

    // 2. High-level runtime handles
    if (T == Object or T == ?Object or T == Class or T == ?Class or T == Selector or T == ?Selector) return true;

    // 3. Raw handles
    if (T == raw.id or T == raw.Class or T == raw.SEL) return true;

    // 4. Primitives
    if (T == void or T == bool or T == raw.BOOL) return true;
    if (T == c_char or T == c_short or T == c_ushort or
        T == c_int or T == c_uint or T == c_long or T == c_ulong or
        T == c_longlong or T == c_ulonglong or T == f32 or T == f64 or
        T == c_longdouble or T == i8 or T == u8 or T == i16 or T == u16 or
        T == i32 or T == u32 or T == i64 or T == u64 or T == isize or T == usize or
        T == i128 or T == u128)
    {
        return true;
    }

    // 5. C strings
    if (T == [*c]const u8 or T == [*c]u8 or T == [*:0]const u8 or T == [*:0]u8 or
        T == ?[*:0]const u8 or T == ?[*:0]u8)
    {
        return true;
    }

    // 6. Structural inspection
    return switch (@typeInfo(T)) {
        .@"opaque" => true,
        .@"enum" => |e| isObjCEncodable(e.tag_type),
        .array => |arr| isObjCEncodable(arr.child),
        .pointer => |ptr| switch (ptr.size) {
            .one, .c => ptr.child == anyopaque or isObjCEncodable(ptr.child),
            else => false,
        },
        .optional => |opt| switch (@typeInfo(opt.child)) {
            .pointer => |ptr| ptr.size != .slice and (ptr.child == anyopaque or isObjCEncodable(ptr.child)),
            else => false,
        },
        .@"struct" => |s| switch (s.layout) {
            .@"extern" => {
                inline for (s.fields) |field| {
                    if (!isObjCEncodable(field.type)) return false;
                }
                return true;
            },
            else => false,
        },
        .@"union" => |u| switch (u.layout) {
            .@"extern" => {
                inline for (u.fields) |field| {
                    if (!isObjCEncodable(field.type)) return false;
                }
                return true;
            },
            else => false,
        },
        .@"fn" => |f| blk: {
            if (!f.calling_convention.eql(std.builtin.CallingConvention.c)) break :blk false;
            const rt = f.return_type orelse break :blk false;
            if (!isObjCEncodable(rt)) break :blk false;
            inline for (f.params) |p| {
                const pt = p.type orelse break :blk false;
                if (!isObjCEncodable(pt)) break :blk false;
            }
            break :blk true;
        },
        else => false,
    };
}

/// Asserts at compile-time that `T` is valid for Objective-C type encoding.
/// Emits specific, actionable compiler errors when invalid.
pub fn assertObjCEncodable(comptime T: type) void {
    if (comptime !isObjCEncodable(T)) {
        switch (@typeInfo(T)) {
            .@"struct" => |s| switch (s.layout) {
                .auto => @compileError("Objective-C encoding requires a C ABI-compatible aggregate. Type '" ++ @typeName(T) ++ "' is a Zig-layout struct. Use 'extern struct' for Objective-C/C interop."),
                .@"packed" => @compileError("packed struct '" ++ @typeName(T) ++ "' is not supported for Objective-C encoding."),
                .@"extern" => {
                    inline for (s.fields) |f| {
                        assertObjCEncodable(f.type);
                    }
                },
            },
            .@"union" => |u| switch (u.layout) {
                .@"extern" => {
                    inline for (u.fields) |f| {
                        assertObjCEncodable(f.type);
                    }
                },
                else => @compileError("tagged union '" ++ @typeName(T) ++ "' is not supported for Objective-C encoding. Use 'extern union'."),
            },
            .pointer => |p| switch (p.size) {
                .slice => @compileError("slice '" ++ @typeName(T) ++ "' is a fat pointer and not C ABI compatible; use a pointer or array."),
                else => assertObjCEncodable(p.child),
            },
            .@"fn" => |f| {
                if (!f.calling_convention.eql(std.builtin.CallingConvention.c)) {
                    @compileError("function type '" ++ @typeName(T) ++ "' must use callconv(.c) for Objective-C encoding.");
                }
                if (f.return_type) |rt| {
                    assertObjCEncodable(rt);
                }
                inline for (f.params) |p| {
                    if (p.type) |pt| {
                        assertObjCEncodable(pt);
                    }
                }
            },
            else => @compileError("type '" ++ @typeName(T) ++ "' is not supported for Objective-C type encoding."),
        }
    }
}

/// Returns the aggregate tag name for an extern struct or union.
/// Uses `objc_encoding_name` if declared, otherwise strips leading namespaces from `@typeName(T)`.
pub fn getAggregateName(comptime T: type) []const u8 {
    if (@hasDecl(T, "objc_encoding_name")) {
        return @field(T, "objc_encoding_name");
    }
    const full_name = @typeName(T);
    var it = std.mem.splitBackwardsScalar(u8, full_name, '.');
    return it.first();
}
