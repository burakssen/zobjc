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
    // ponytail: kept for API stability; currently unreachable because Zig cannot
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
            .one, .c => .pointer,
            // Sentinel-terminated many-pointers (C strings) are pointers;
            // bare `[*]T` has no C return representation.
            .many => if (comptime ptr.sentinel() != null)
                .pointer
            else
                @compileError("unsupported type for ABI classification: " ++ @typeName(T)),
            else => @compileError("unsupported type for ABI classification: " ++ @typeName(T)),
        },
        // Raw handles, single-pointer wrappers, and their optionals behave
        // as pointers at the machine level.
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
