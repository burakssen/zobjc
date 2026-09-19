//! Normalized ABI type categorization.
//!
//! Categorizes Zig types into high-level ABI categories before passing
//! to architecture-specific classification engines.

const std = @import("std");
const traits = @import("internal/traits.zig");

pub const TypeCategory = enum {
    void,
    integer,
    pointer,
    floating,
    long_double,
    // Kept for API stability; currently unreachable because Zig cannot
    // spell C `_Complex long double`. Ordinary 2x-long-double structs fall
    // through to `.aggregate` below (stret on x86_64 when >16 bytes).
    complex_long_double,
    aggregate,
    vector,
};

pub inline fn categorize(comptime T: type) TypeCategory {
    if (T == void) return .void;
    if (traits.isComplexLongDouble(T)) return .complex_long_double;

    // NOTE: the explicit `comptime` on the prong conditions below is
    // load-bearing. Without it, cross-module predicate calls in a prong
    // `if` can mis-evaluate (taking the `else` branch unconditionally).
    return switch (@typeInfo(T)) {
        .void => .void,
        .int, .bool, .@"enum" => .integer,
        .pointer => |ptr| switch (ptr.size) {
            .one, .c, .many => .pointer,
            else => @compileError("unsupported type for ABI classification: " ++ @typeName(T)),
        },
        // Optional pointers and optional single-pointer wrappers use pointer
        // classification. Non-optional wrapper structs stay aggregates below
        // and classify by their single pointer field.
        .optional => |opt| if (comptime @typeInfo(opt.child) == .pointer or traits.isSinglePointerStruct(opt.child))
            .pointer
        else
            @compileError("unsupported type for ABI classification: " ++ @typeName(T)),
        .float => if (comptime traits.isLongDouble(T)) .long_double else .floating,
        .vector => .vector,
        .@"struct" => |st| if (comptime st.layout == .@"extern" or traits.isSinglePointerStruct(T))
            .aggregate
        else
            @compileError("unsupported type for ABI classification: " ++ @typeName(T)),
        .@"union" => |un| if (comptime un.layout == .@"extern")
            .aggregate
        else
            @compileError("unsupported type for ABI classification: " ++ @typeName(T)),
        .array => .aggregate,
        else => @compileError("unsupported type for ABI classification: " ++ @typeName(T)),
    };
}

test "categorize: admission table for machine representations" {
    const testing = @import("std").testing;
    const Case = struct { T: type, category: TypeCategory };
    const PtrWrapper = struct { ptr: *anyopaque };
    const cases = [_]Case{
        .{ .T = void, .category = .void },
        .{ .T = c_int, .category = .integer },
        .{ .T = bool, .category = .integer },
        .{ .T = f32, .category = .floating },
        .{ .T = c_longdouble, .category = .long_double },
        .{ .T = *u8, .category = .pointer },
        .{ .T = ?*u8, .category = .pointer },
        .{ .T = [*:0]u8, .category = .pointer },
        .{ .T = [*]f32, .category = .pointer },
        .{ .T = ?[*]f32, .category = .pointer },
        .{ .T = extern struct { a: i32 }, .category = .aggregate },
        .{ .T = extern union { a: i32, b: f32 }, .category = .aggregate },
        .{ .T = [4]u8, .category = .aggregate },
        .{ .T = PtrWrapper, .category = .aggregate },
        .{ .T = ?PtrWrapper, .category = .pointer },
    };
    inline for (cases) |c| {
        try testing.expectEqual(c.category, categorize(c.T));
    }
}
