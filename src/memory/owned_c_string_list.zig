//! Caller-freed array of C string pointers.
//!
//! Wraps arrays returned by `objc_copyImageNames` and `objc_copyClassNamesForImage`.
//! The array itself is freed via `free()`, while the strings inside refer to image metadata.

const std = @import("std");
const c_free = @import("c_free.zig");

/// An owning wrapper for an array of C strings returned by runtime image introspection.
///
/// MUST NOT be copied by value.
pub const OwnedCStringList = struct {
    ptr: ?[*][*:0]const u8,
    len: usize,

    pub fn fromRaw(p: ?[*][*:0]const u8, count_val: usize) OwnedCStringList {
        if (p == null or count_val == 0) {
            if (p) |non_null| c_free.free(@ptrCast(non_null));
            return empty();
        }
        return .{
            .ptr = p,
            .len = count_val,
        };
    }

    pub fn empty() OwnedCStringList {
        return .{
            .ptr = null,
            .len = 0,
        };
    }

    pub fn count(self: *const OwnedCStringList) usize {
        return self.len;
    }

    pub fn isEmpty(self: *const OwnedCStringList) bool {
        return self.len == 0;
    }

    pub fn get(self: *const OwnedCStringList, index: usize) ?[:0]const u8 {
        if (index >= self.len or self.ptr == null) {
            return null;
        }
        const s = self.ptr.?[index];
        return std.mem.span(s);
    }

    pub fn iterator(self: *const OwnedCStringList) Iterator {
        return .{ .list = self, .index = 0 };
    }

    pub const Iterator = struct {
        list: *const OwnedCStringList,
        index: usize = 0,

        pub fn next(self: *Iterator) ?[:0]const u8 {
            if (self.index >= self.list.len) return null;
            const item = self.list.get(self.index);
            self.index += 1;
            return item;
        }
    };

    pub fn deinit(self: *OwnedCStringList) void {
        if (self.ptr) |p| {
            c_free.free(@ptrCast(p));
            self.ptr = null;
            self.len = 0;
        }
    }
};
