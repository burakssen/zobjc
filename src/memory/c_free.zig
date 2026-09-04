//! Centralized C allocator free wrapper for Objective-C runtime copy buffers.

const std = @import("std");

/// Frees memory allocated by the C runtime allocator (used by libobjc copy APIs).
pub inline fn free(ptr: ?*anyopaque) void {
    if (ptr) |p| {
        std.c.free(p);
    }
}
