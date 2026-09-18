//! Typed Objective-C property attribute representation.

const std = @import("std");
const testing = std.testing;
const raw = @import("raw");

/// Describes an Objective-C property attribute (e.g. "T", "R", "C", "N", "V_ivar").
/// Exactly matches the ABI layout of `raw.objc_property_attribute_t`.
pub const PropertyAttribute = extern struct {
    name: [*:0]const u8,
    value: [*:0]const u8,

    pub inline fn init(n: [:0]const u8, v: [:0]const u8) PropertyAttribute {
        return .{
            .name = n.ptr,
            .value = v.ptr,
        };
    }

    /// Converts this typed property attribute into the raw ABI representation.
    pub inline fn toRaw(self: PropertyAttribute) raw.objc_property_attribute_t {
        return .{
            .name = self.name,
            .value = self.value,
        };
    }

    comptime {
        std.debug.assert(@sizeOf(@This()) == @sizeOf(raw.objc_property_attribute_t));
        std.debug.assert(@alignOf(@This()) == @alignOf(raw.objc_property_attribute_t));
    }
};

test "handle: PropertyAttribute matches raw C layout exactly" {
    try testing.expectEqual(@sizeOf(raw.objc_property_attribute_t), @sizeOf(PropertyAttribute));
    try testing.expectEqual(@alignOf(raw.objc_property_attribute_t), @alignOf(PropertyAttribute));
}
