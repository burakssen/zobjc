//! Objective-C protocol representation and introspection.
//!
//! A non-owning, non-null handle to an Objective-C protocol (`Protocol *`).

const std = @import("std");
const raw = @import("../raw/root.zig");
const conversion = @import("conversion.zig");
const Selector = @import("selector.zig").Selector;
const Property = @import("property.zig").Property;
const MethodDescription = @import("method_description.zig").MethodDescription;

pub const ProtocolMethodOptions = struct {
    required: bool = true,
    instance: bool = true,
};

pub const ProtocolPropertyOptions = struct {
    required: bool = true,
    instance: bool = true,
};

pub const Protocol = struct {
    ptr: *raw.objc_object,

    /// Converts a raw nullable `raw.Protocol` into an optional `Protocol`.
    pub inline fn fromRaw(val: raw.Protocol) ?Protocol {
        const p = val orelse return null;
        return .{ .ptr = p };
    }

    /// Converts this `Protocol` into its raw `raw.Protocol` pointer.
    pub inline fn toRaw(self: Protocol) raw.Protocol {
        return self.ptr;
    }

    /// Creates a `Protocol` from a known non-null raw protocol pointer.
    pub inline fn fromRawNonNull(p: *raw.objc_object) Protocol {
        return .{ .ptr = p };
    }

    /// Returns the name of the protocol.
    pub inline fn name(self: Protocol) [:0]const u8 {
        return conversion.spanCString(raw.runtime.protocol_getName(self.ptr));
    }

    /// Tests protocol equality using Objective-C runtime protocol equality semantics.
    pub inline fn eql(self: Protocol, other: Protocol) bool {
        return raw.boolResult(raw.runtime.protocol_isEqual(self.ptr, other.ptr));
    }

    /// Returns whether this protocol conforms to another protocol.
    pub inline fn conformsTo(self: Protocol, other: Protocol) bool {
        return raw.boolResult(raw.runtime.protocol_conformsToProtocol(self.ptr, other.ptr));
    }

    /// Retrieves the method description for a specified selector in this protocol.
    pub fn methodDescription(
        self: Protocol,
        sel_val: Selector,
        options: ProtocolMethodOptions,
    ) ?MethodDescription {
        const desc = raw.runtime.protocol_getMethodDescription(
            self.ptr,
            sel_val.toRaw(),
            raw.boolParam(options.required),
            raw.boolParam(options.instance),
        );
        if (desc.name == null) return null;
        return MethodDescription.fromRaw(desc);
    }

    /// Retrieves a declared property of this protocol by name and options.
    pub fn property(
        self: Protocol,
        prop_name: [:0]const u8,
        options: ProtocolPropertyOptions,
    ) ?Property {
        const raw_prop = raw.runtime.protocol_getProperty(
            self.ptr,
            prop_name.ptr,
            raw.boolParam(options.required),
            raw.boolParam(options.instance),
        );
        return Property.fromRaw(raw_prop);
    }

    // --- Backward Compatibility Aliases ---

    /// Legacy alias for name.
    pub inline fn getName(self: Protocol) [:0]const u8 {
        return self.name();
    }

    /// Legacy alias for conformsTo.
    pub inline fn conformsToProtocol(self: Protocol, other: Protocol) bool {
        return self.conformsTo(other);
    }

    /// Legacy alias for property.
    pub inline fn getProperty(
        self: Protocol,
        prop_name: [:0]const u8,
        is_required: bool,
        is_instance: bool,
    ) ?Property {
        return self.property(prop_name, .{
            .required = is_required,
            .instance = is_instance,
        });
    }

    comptime {
        std.debug.assert(@sizeOf(@This()) == @sizeOf(raw.Protocol));
        std.debug.assert(@alignOf(@This()) == @alignOf(raw.Protocol));
    }
};
