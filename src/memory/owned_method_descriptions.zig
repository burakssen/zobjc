//! Caller-freed method description list wrapper.
//!
//! Wraps the array returned by `protocol_copyMethodDescriptionList`.
//! Frees the array buffer with `free()` upon `deinit()`.

const std = @import("std");
const testing = std.testing;
const raw = @import("raw");
const MethodDescription = @import("internal").metadata.MethodDescription;
const c_free = @import("c_free.zig");

/// An owning wrapper for an array of `raw.objc_method_description` records.
///
/// MUST NOT be copied by value.
pub const OwnedMethodDescriptions = struct {
    ptr: ?[*]raw.objc_method_description,
    len: usize,

    pub fn fromRaw(p: ?[*]raw.objc_method_description, count_val: usize) OwnedMethodDescriptions {
        if (p == null or count_val == 0) {
            if (p) |non_null| c_free.free(non_null);
            return empty();
        }
        return .{
            .ptr = p,
            .len = count_val,
        };
    }

    pub fn empty() OwnedMethodDescriptions {
        return .{
            .ptr = null,
            .len = 0,
        };
    }

    pub fn count(self: *const OwnedMethodDescriptions) usize {
        return self.len;
    }

    pub fn isEmpty(self: *const OwnedMethodDescriptions) bool {
        return self.len == 0;
    }

    pub fn get(self: *const OwnedMethodDescriptions, index: usize) ?MethodDescription {
        if (index >= self.len or self.ptr == null) {
            return null;
        }
        return MethodDescription.fromRaw(self.ptr.?[index]);
    }

    pub fn iterator(self: *const OwnedMethodDescriptions) Iterator {
        return .{ .list = self, .index = 0 };
    }

    pub const Iterator = struct {
        list: *const OwnedMethodDescriptions,
        index: usize = 0,

        pub fn next(self: *Iterator) ?MethodDescription {
            if (self.index >= self.list.len) return null;
            const item = self.list.get(self.index);
            self.index += 1;
            return item;
        }
    };

    pub fn deinit(self: *OwnedMethodDescriptions) void {
        if (self.ptr) |p| {
            c_free.free(p);
            self.ptr = null;
            self.len = 0;
        }
    }
};

test "OwnedMethodDescriptions: empty representation" {
    var empty_methods = OwnedMethodDescriptions.empty();
    try testing.expect(empty_methods.isEmpty());
    try testing.expectEqual(@as(usize, 0), empty_methods.count());
    try testing.expect(empty_methods.get(0) == null);
    empty_methods.deinit();
}
