//! Memory layout queries for compile-time ABI inspection.

const std = @import("std");

/// Returns the size in bytes of type `T`.
pub inline fn sizeOf(comptime T: type) usize {
    return @sizeOf(T);
}

/// Returns the byte alignment of type `T`.
pub inline fn alignOf(comptime T: type) usize {
    return @alignOf(T);
}

/// Returns the byte offset of `field_name` within struct or union `T`.
pub inline fn fieldOffset(comptime T: type, comptime field_name: []const u8) usize {
    return @offsetOf(T, field_name);
}

/// Structure representing the size and alignment of a type.
pub const Layout = struct {
    size: usize,
    alignment: usize,
};

/// Returns the `Layout` for type `T`.
pub inline fn layoutOf(comptime T: type) Layout {
    return .{
        .size = sizeOf(T),
        .alignment = alignOf(T),
    };
}
