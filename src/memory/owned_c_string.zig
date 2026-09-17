//! Caller-freed C string wrapper for Objective-C runtime copy results.
//!
//! Owns a malloc-allocated null-terminated C string returned by functions such as
//! `method_copyReturnType` or `property_copyAttributeValue`.
//! Frees the string with `free()` upon `deinit()`.

const std = @import("std");
const testing = std.testing;
const objc = @import("zobjc");
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

test "OwnedCString: method.copyReturnType" {
    const method = objc.requireClass("NSObject").instanceMethod(objc.sel("description")).?;
    var ret_type = method.copyReturnType().?;
    defer ret_type.deinit();
    try testing.expectEqualStrings("@", ret_type.slice());
    try testing.expectEqual(@as(usize, 1), ret_type.len());
    ret_type.deinit();
    try testing.expectEqual(@as(usize, 0), ret_type.len());
}

test "OwnedCString: method.copyArgumentType" {
    const method = objc.requireClass("NSObject").instanceMethod(objc.sel("isEqual:")).?;
    var arg0 = method.copyArgumentType(0).?;
    defer arg0.deinit();
    try testing.expectEqualStrings("@", arg0.slice());
    var arg1 = method.copyArgumentType(1).?;
    defer arg1.deinit();
    try testing.expectEqualStrings(":", arg1.slice());
    var arg2 = method.copyArgumentType(2).?;
    defer arg2.deinit();
    try testing.expectEqualStrings("@", arg2.slice());
    try testing.expect(method.copyArgumentType(99) == null);
}

test "OwnedCString: property.copyAttributeValue" {
    const NSObject = objc.requireClass("NSObject");
    if (NSObject.property("className")) |prop| {
        if (prop.copyAttributeValue("T")) |val| {
            var owned = val;
            defer owned.deinit();
            try testing.expect(owned.len() > 0);
        }
    }
}

test "OwnedCString: intoRaw relinquishes ownership" {
    const method = objc.requireClass("NSObject").instanceMethod(objc.sel("description")).?;
    var ret_type = method.copyReturnType().?;
    const raw_ptr = ret_type.intoRaw();
    try testing.expectEqual(@as(usize, 0), ret_type.len());
    ret_type.deinit();
    try testing.expectEqualStrings("@", std.mem.span(raw_ptr));
    std.c.free(@ptrCast(raw_ptr));
}

test "OwnedCString: empty fromRaw(null)" {
    try testing.expect(OwnedCString.fromRaw(null) == null);
}
