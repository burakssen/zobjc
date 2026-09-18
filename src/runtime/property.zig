//! Objective-C property introspection.
//!
//! A non-owning, non-null handle to an Objective-C declared property (`objc_property_t`).

const std = @import("std");
const testing = std.testing;
const raw = @import("raw");
const conversion = @import("conversion.zig");
const memory = @import("memory");
const encoding = @import("encoding");

pub const Property = struct {
    ptr: *raw.objc_property,

    /// Converts a raw nullable `raw.objc_property_t` into an optional `Property`.
    pub inline fn fromRaw(val: raw.objc_property_t) ?Property {
        const p = val orelse return null;
        return .{ .ptr = p };
    }

    /// Converts this `Property` into its raw `raw.objc_property_t` pointer.
    pub inline fn toRaw(self: Property) raw.objc_property_t {
        return self.ptr;
    }

    /// Creates a `Property` from a known non-null raw property pointer.
    pub inline fn fromRawNonNull(p: *raw.objc_property) Property {
        return .{ .ptr = p };
    }

    /// Returns the name of the property.
    pub inline fn name(self: Property) [:0]const u8 {
        return conversion.spanCString(raw.runtime.property_getName(self.ptr));
    }

    /// Returns the attribute string of the property.
    pub inline fn attributes(self: Property) ?[:0]const u8 {
        return conversion.spanNullableCString(raw.runtime.property_getAttributes(self.ptr));
    }

    /// Returns a caller-freed C string containing the value of a property attribute.
    pub inline fn copyAttributeValue(self: Property, attr: [:0]const u8) ?memory.OwnedCString {
        const raw_val = raw.runtime.property_copyAttributeValue(self.ptr, attr.ptr);
        return memory.OwnedCString.fromRaw(raw_val);
    }

    /// Returns a caller-freed list of attributes declared by this property.
    pub fn attributesList(self: Property) memory.OwnedPropertyAttributes {
        var count_val: c_uint = 0;
        const list = raw.runtime.property_copyAttributeList(self.ptr, &count_val);
        return memory.OwnedPropertyAttributes.fromRaw(list, count_val);
    }

    /// Tests property equality by comparing pointer addresses.
    pub inline fn eql(self: Property, other: Property) bool {
        return self.ptr == other.ptr;
    }

    /// Parses the declared property's attributes into a structured `PropertyEncoding`.
    pub fn parse(self: Property, allocator: std.mem.Allocator) !encoding.PropertyEncoding {
        const attrs = self.attributes() orelse "";
        return encoding.parseProperty(allocator, attrs);
    }

    comptime {
        std.debug.assert(@sizeOf(@This()) == @sizeOf(raw.objc_property_t));
        std.debug.assert(@alignOf(@This()) == @alignOf(raw.objc_property_t));
    }
};

test "handle: Property is pointer-sized and pointer-aligned" {
    try testing.expectEqual(@sizeOf(usize), @sizeOf(Property));
    try testing.expectEqual(@alignOf(usize), @alignOf(Property));
}
