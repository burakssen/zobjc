//! Caller-freed array of C string pointers.
//!
//! Wraps arrays returned by `objc_copyImageNames` and `objc_copyClassNamesForImage`.
//! The array itself is freed via `free()`, while the strings inside refer to image metadata.

const std = @import("std");
const testing = std.testing;
const objc = @import("zobjc");
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

test "OwnedCStringList: runtime.imageNames and classNamesForImage" {
    var images = objc.runtime.imageNames();
    defer images.deinit();
    try testing.expect(!images.isEmpty());
    try testing.expect(images.count() > 0);
    try testing.expect(images.get(0).?.len > 0);

    var count: usize = 0;
    var iter = images.iterator();
    while (iter.next()) |_| count += 1;
    try testing.expectEqual(images.count(), count);

    var libobjc_image: ?[:0]const u8 = null;
    var img_iter = images.iterator();
    while (img_iter.next()) |img| {
        if (std.mem.indexOf(u8, img, "libobjc") != null) {
            libobjc_image = img;
            break;
        }
    }
    if (libobjc_image) |target_image| {
        var class_names = objc.runtime.classNamesForImage(target_image);
        defer class_names.deinit();
        try testing.expect(class_names.count() > 0);
        try testing.expect(class_names.get(0).?.len > 0);
    }
}

test "OwnedCStringList: empty representation" {
    var empty_strings = OwnedCStringList.empty();
    try testing.expect(empty_strings.isEmpty());
    try testing.expectEqual(@as(usize, 0), empty_strings.count());
    try testing.expect(empty_strings.get(0) == null);
    empty_strings.deinit();
}
