//! Caller-freed property attribute list wrapper.
//!
//! Wraps the array returned by `property_copyAttributeList`.
//! Frees the array buffer with `free()` upon `deinit()`.

const std = @import("std");
const testing = std.testing;
const raw = @import("raw");
const PropertyAttribute = @import("internal").metadata.PropertyAttribute;
const c_free = @import("c_free.zig");

/// An owning wrapper for an array of `raw.objc_property_attribute_t` records.
///
/// MUST NOT be copied by value.
pub const OwnedPropertyAttributes = struct {
    ptr: ?[*]raw.objc_property_attribute_t,
    len: usize,

    pub fn fromRaw(p: ?[*]raw.objc_property_attribute_t, count_val: usize) OwnedPropertyAttributes {
        if (p == null or count_val == 0) {
            if (p) |non_null| c_free.free(non_null);
            return empty();
        }
        return .{
            .ptr = p,
            .len = count_val,
        };
    }

    pub fn empty() OwnedPropertyAttributes {
        return .{
            .ptr = null,
            .len = 0,
        };
    }

    pub fn count(self: *const OwnedPropertyAttributes) usize {
        return self.len;
    }

    pub fn isEmpty(self: *const OwnedPropertyAttributes) bool {
        return self.len == 0;
    }

    pub fn get(self: *const OwnedPropertyAttributes, index: usize) ?PropertyAttribute {
        if (index >= self.len or self.ptr == null) {
            return null;
        }
        const attr = self.ptr.?[index];
        return .{
            .name = attr.name,
            .value = attr.value,
        };
    }

    pub fn iterator(self: *const OwnedPropertyAttributes) Iterator {
        return .{ .list = self, .index = 0 };
    }

    pub const Iterator = struct {
        list: *const OwnedPropertyAttributes,
        index: usize = 0,

        pub fn next(self: *Iterator) ?PropertyAttribute {
            if (self.index >= self.list.len) return null;
            const item = self.list.get(self.index);
            self.index += 1;
            return item;
        }
    };

    pub fn deinit(self: *OwnedPropertyAttributes) void {
        if (self.ptr) |p| {
            c_free.free(p);
            self.ptr = null;
            self.len = 0;
        }
    }
};

test "OwnedPropertyAttributes: empty representation" {
    var empty_attrs = OwnedPropertyAttributes.empty();
    try testing.expect(empty_attrs.isEmpty());
    try testing.expectEqual(@as(usize, 0), empty_attrs.count());
    try testing.expect(empty_attrs.get(0) == null);
    empty_attrs.deinit();
}
