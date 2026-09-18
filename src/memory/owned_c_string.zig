//! Caller-freed C string wrapper for Objective-C runtime copy results.
//!
//! Owns a malloc-allocated null-terminated C string returned by functions such as
//! `method_copyReturnType` or `property_copyAttributeValue`.
//! Frees the string with `free()` upon `deinit()`.

const std = @import("std");
const testing = std.testing;
const c_free = @import("c_free.zig");

/// A wrapper owning a null-terminated C string allocated by the Objective-C runtime.
///
/// MUST NOT be copied by value.
pub const OwnedCString = struct {
    ptr: ?[*:0]u8,

    /// Wraps a nullable raw C string. Returns null if pointer is null.
    pub fn fromRaw(p: ?[*:0]u8) ?OwnedCString {
        const non_null = p orelse return null;
        return .{ .ptr = non_null };
    }

    /// Returns a Zig slice view of the owned string, or empty slice if deinitialized.
    pub fn slice(self: *const OwnedCString) [:0]const u8 {
        const p = self.ptr orelse return "";
        return std.mem.span(p);
    }

    /// Returns the character length of the owned string.
    pub fn len(self: *const OwnedCString) usize {
        return self.slice().len;
    }

    /// Frees the allocated string via `free()`.
    /// Idempotent: safe to call multiple times.
    pub fn deinit(self: *OwnedCString) void {
        if (self.ptr) |p| {
            c_free.free(p);
            self.ptr = null;
        }
    }

    /// Relinquishes ownership responsibility to the caller without freeing.
    pub fn intoRaw(self: *OwnedCString) [*:0]u8 {
        const p = self.ptr orelse @panic("attempted to call intoRaw on deinitialized OwnedCString");
        self.ptr = null;
        return p;
    }
};

test "OwnedCString: empty fromRaw(null)" {
    try testing.expect(OwnedCString.fromRaw(null) == null);
}
