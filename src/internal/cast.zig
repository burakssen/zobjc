//! Low-level casting and pointer coercion helpers.

const std = @import("std");

/// Casts an untyped id pointer to a typed pointer or handles tagged pointers.
// Keep casting minimal, avoid extra wrapper types.
pub inline fn toIdPtr(comptime Dest: type, id: anytype) Dest {
    @setRuntimeSafety(false);
    return @ptrCast(@alignCast(id));
}
