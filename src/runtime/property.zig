//! Objective-C property introspection.
//!
//! A non-owning, non-null handle to an Objective-C declared property (`objc_property_t`).

const std = @import("std");
const raw = @import("../raw/root.zig");
const conversion = @import("conversion.zig");

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

    /// Returns the value of a property attribute given the attribute name. Must be freed with free() if non-null.
    pub inline fn copyAttributeValue(self: Property, attr: [:0]const u8) ?[:0]u8 {
        return conversion.spanNullableMutableCString(raw.runtime.property_copyAttributeValue(self.ptr, attr.ptr));
    }

    /// Tests property equality by comparing pointer addresses.
    pub inline fn eql(self: Property, other: Property) bool {
        return self.ptr == other.ptr;
    }

    // --- Backward Compatibility Aliases ---

    /// Legacy alias for name.
    pub inline fn getName(self: Property) [:0]const u8 {
        return self.name();
    }

    comptime {
        std.debug.assert(@sizeOf(@This()) == @sizeOf(raw.objc_property_t));
        std.debug.assert(@alignOf(@This()) == @alignOf(raw.objc_property_t));
    }
};
