//! Objective-C protocol representation and introspection.

const std = @import("std");
const raw = @import("../raw/root.zig");
const Property = @import("property.zig").Property;

/// Represents an Objective-C protocol handle.
pub const Protocol = extern struct {
    value: *raw.objc_object,

    pub fn conformsToProtocol(self: Protocol, other: Protocol) bool {
        return raw.boolResult(raw.runtime.protocol_conformsToProtocol(self.value, other.value));
    }

    pub fn isEqual(self: Protocol, other: Protocol) bool {
        return raw.boolResult(raw.runtime.protocol_isEqual(self.value, other.value));
    }

    pub fn getName(self: Protocol) [:0]const u8 {
        return std.mem.span(raw.runtime.protocol_getName(self.value));
    }

    pub fn getProperty(
        self: Protocol,
        name: [:0]const u8,
        is_required: bool,
        is_instance: bool,
    ) ?Property {
        return .{ .value = raw.runtime.protocol_getProperty(
            self.value,
            name,
            raw.boolParam(is_required),
            raw.boolParam(is_instance),
        ) orelse return null };
    }

    comptime {
        std.debug.assert(@sizeOf(@This()) == @sizeOf(?*raw.objc_object));
        std.debug.assert(@alignOf(@This()) == @alignOf(?*raw.objc_object));
    }
};

/// Looks up an Objective-C protocol by name.
pub fn getProtocol(name: [:0]const u8) ?Protocol {
    const proto = raw.runtime.objc_getProtocol(name) orelse return null;
    return .{ .value = proto };
}
