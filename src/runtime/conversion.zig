//! Internal conversion helpers between typed runtime handles and raw C pointers.
//!
//! Centralized minimal conversion helpers to avoid repeating std.mem.span
//! and pointer unwrapping across runtime wrappers.

const std = @import("std");
const raw = @import("raw");

/// Converts a non-null sentinel-terminated C string into a Zig sentinel-terminated slice.
pub inline fn spanCString(ptr: [*:0]const u8) [:0]const u8 {
    return std.mem.span(ptr);
}

/// Converts a nullable sentinel-terminated C string into a nullable Zig slice.
pub inline fn spanNullableCString(ptr: ?[*:0]const u8) ?[:0]const u8 {
    const p = ptr orelse return null;
    return std.mem.span(p);
}

/// Converts a non-null mutable sentinel-terminated C string into a Zig slice.
pub inline fn spanMutableCString(ptr: [*:0]u8) [:0]u8 {
    return std.mem.span(ptr);
}

/// Converts a nullable mutable sentinel-terminated C string into a nullable Zig slice.
pub inline fn spanNullableMutableCString(ptr: ?[*:0]u8) ?[:0]u8 {
    const p = ptr orelse return null;
    return std.mem.span(p);
}
