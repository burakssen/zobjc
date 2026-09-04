//! Objective-C protocol representation and introspection.
//!
//! A non-owning, non-null handle to an Objective-C protocol (`Protocol *`).

const std = @import("std");
const raw = @import("../raw/root.zig");
const conversion = @import("conversion.zig");
const Selector = @import("selector.zig").Selector;
const Property = @import("property.zig").Property;
const MethodDescription = @import("method_description.zig").MethodDescription;
const memory = @import("../memory/root.zig");

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

    /// Returns a caller-freed list of method descriptions matching the specified options.
    pub fn methodDescriptions(self: Protocol, options: ProtocolMethodOptions) memory.OwnedMethodDescriptions {
        var count_val: c_uint = 0;
        const list = raw.runtime.protocol_copyMethodDescriptionList(
            self.ptr,
            raw.boolParam(options.required),
            raw.boolParam(options.instance),
            &count_val,
        );
        return memory.OwnedMethodDescriptions.fromRaw(list, count_val);
    }

    /// Returns a caller-freed list of properties declared by this protocol matching options.
    pub fn properties(self: Protocol, options: ProtocolPropertyOptions) memory.OwnedRuntimeList(Property) {
        var count_val: c_uint = 0;
        const list = raw.runtime.protocol_copyPropertyList2(
            self.ptr,
            &count_val,
            raw.boolParam(options.required),
            raw.boolParam(options.instance),
        );
        return memory.OwnedRuntimeList(Property).fromRaw(@ptrCast(list), count_val);
    }

    /// Returns a caller-freed list of other protocols adopted by this protocol.
    pub fn protocols(self: Protocol) memory.OwnedRuntimeList(Protocol) {
        var count_val: c_uint = 0;
        const list = raw.runtime.protocol_copyProtocolList(self.ptr, &count_val);
        return memory.OwnedRuntimeList(Protocol).fromRaw(@ptrCast(list), count_val);
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
