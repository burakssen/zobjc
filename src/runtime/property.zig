//! Objective-C property introspection.

const std = @import("std");
const raw = @import("../raw/root.zig");
const c = raw.c;

/// Represents an Objective-C property (`objc_property_t`).
pub const Property = extern struct {
    value: c.objc_property_t,

    /// Returns the name of a property.
    pub fn getName(self: Property) [:0]const u8 {
        return std.mem.span(c.property_getName(self.value));
    }

    /// Returns the value of a property attribute given the attribute name.
    pub fn copyAttributeValue(self: Property, attr: [:0]const u8) ?[:0]u8 {
        const ptr = c.property_copyAttributeValue(self.value, attr.ptr) orelse return null;
        return std.mem.span(ptr);
    }

    comptime {
        std.debug.assert(@sizeOf(@This()) == @sizeOf(c.objc_property_t));
        std.debug.assert(@alignOf(@This()) == @alignOf(c.objc_property_t));
    }
};
