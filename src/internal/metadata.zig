//! Shared Objective-C runtime metadata value types.
//!
//! Lives below `runtime`/`memory` so both can name these types without an
//! upward dependency. `runtime.MethodDescription` and
//! `runtime.PropertyAttribute` are aliases of these structs.

const std = @import("std");
const testing = std.testing;
const raw = @import("raw");
const Selector = @import("selector.zig").Selector;

/// Defines an Objective-C method description holding a selector and its type encoding.
pub const MethodDescription = struct {
    selector: ?Selector,
    types: ?[:0]const u8,

    /// Converts a raw `objc_method_description` ABI struct into a typed `MethodDescription`.
    pub fn fromRaw(raw_desc: raw.objc_method_description) MethodDescription {
        return .{
            .selector = Selector.fromRaw(raw_desc.name),
            .types = if (raw_desc.types) |t| std.mem.span(t) else null,
        };
    }

    /// Converts this typed `MethodDescription` into the raw ABI representation.
    pub fn toRaw(self: MethodDescription) raw.objc_method_description {
        return .{
            .name = if (self.selector) |s| s.toRaw() else null,
            .types = if (self.types) |t| t.ptr else null,
        };
    }
};

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
