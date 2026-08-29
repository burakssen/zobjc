//! Objective-C protocol representation and introspection.

const std = @import("std");
const raw = @import("../raw/root.zig");
const c = raw.c;
const Property = @import("property.zig").Property;

/// Represents an Objective-C protocol handle.
pub const Protocol = extern struct {
    value: *c.Protocol,

    pub fn conformsToProtocol(self: Protocol, other: Protocol) bool {
        return raw.boolResult(c.protocol_conformsToProtocol(self.value, other.value));
    }

    pub fn isEqual(self: Protocol, other: Protocol) bool {
        return raw.boolResult(c.protocol_isEqual(self.value, other.value));
    }

    pub fn getName(self: Protocol) [:0]const u8 {
        return std.mem.span(c.protocol_getName(self.value));
    }

    pub fn getProperty(
        self: Protocol,
        name: [:0]const u8,
        is_required: bool,
        is_instance: bool,
    ) ?Property {
        return .{ .value = c.protocol_getProperty(
            self.value,
            name,
            raw.boolParam(is_required),
            raw.boolParam(is_instance),
        ) orelse return null };
    }

    comptime {
        std.debug.assert(@sizeOf(@This()) == @sizeOf([*c]c.Protocol));
        std.debug.assert(@alignOf(@This()) == @alignOf([*c]c.Protocol));
    }
};

/// Looks up an Objective-C protocol by name.
pub fn getProtocol(name: [:0]const u8) ?Protocol {
    return .{ .value = c.objc_getProtocol(name) orelse return null };
}
