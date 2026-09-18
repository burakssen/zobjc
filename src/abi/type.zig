//! Normalized ABI type categorization.
//!
//! Categorizes Zig types into high-level ABI categories before passing
//! to architecture-specific classification engines.

const std = @import("std");
const traits = @import("internal/traits.zig");
const diagnostics = @import("diagnostics.zig");

pub const TypeCategory = enum {
    void,
    integer,
    pointer,
    objc_object,
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
    diagnostics.assertValidReturn(T);

    if (T == void) return .void;
    if (traits.isObjCObjectHandle(T)) return .objc_object;
    if (traits.isComplexLongDouble(T)) return .complex_long_double;

    return switch (@typeInfo(T)) {
        .void => .void,
        .int, .bool, .@"enum" => .integer,
        .pointer => .pointer,
        .optional => |opt| if (comptime traits.isObjCObjectHandle(opt.child))
            .objc_object
        else if (comptime @typeInfo(opt.child) == .pointer)
            .pointer
        else
            @compileError("unsupported type for ABI classification: " ++ @typeName(T)),
        .float => if (traits.isLongDouble(T)) .long_double else .floating,
        .vector => .vector,
        .@"struct", .@"union", .array => .aggregate,
        else => @compileError("unsupported type for ABI classification: " ++ @typeName(T)),
    };
}
