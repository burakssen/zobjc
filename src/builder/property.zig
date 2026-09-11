//! Declared property registration for dynamic classes and protocols.

const std = @import("std");
const raw = @import("../raw/root.zig");
const runtime = @import("../runtime/root.zig");
const encoding = @import("../encoding/root.zig");
const errors = @import("errors.zig");
const attributes_internal = @import("internal/attributes.zig");
const Class = runtime.Class;
const Protocol = runtime.Protocol;
const ProtocolPropertyOptions = runtime.ProtocolPropertyOptions;
const ClassBuilderError = errors.ClassBuilderError;
const ProtocolBuilderError = errors.ProtocolBuilderError;

pub const PropertyOptions = attributes_internal.PropertyOptions;

/// Adds a declared property with typed options to an un-registered class.
pub fn addPropertyToClass(
    cls: Class,
    comptime T: type,
    name: [:0]const u8,
    options: PropertyOptions,
) ClassBuilderError!void {
    encoding.assertObjCEncodable(T);
    const type_enc = comptime encoding.comptimeEncode(T);

    var buffer: [attributes_internal.MaxAttributes]raw.objc_property_attribute_t = undefined;
    const count = attributes_internal.buildAttributes(&type_enc, options, &buffer) catch {
        return error.InvalidPropertyAttributes;
    };

    const ok = raw.boolResult(raw.runtime.class_addProperty(
        cls.ptr,
        name.ptr,
        &buffer,
        @intCast(count),
    ));

    if (!ok) {
        return error.CannotAddProperty;
    }
}

/// Adds a declared property to an un-registered protocol.
pub fn addPropertyToProtocol(
    proto: Protocol,
    comptime T: type,
    name: [:0]const u8,
    property_options: PropertyOptions,
    protocol_options: ProtocolPropertyOptions,
) ProtocolBuilderError!void {
    encoding.assertObjCEncodable(T);
    const type_enc = comptime encoding.comptimeEncode(T);

    var buffer: [attributes_internal.MaxAttributes]raw.objc_property_attribute_t = undefined;
    const count = attributes_internal.buildAttributes(&type_enc, property_options, &buffer) catch {
        return error.InvalidPropertyAttributes;
    };

    raw.runtime.protocol_addProperty(
        proto.ptr,
        name.ptr,
        &buffer,
        @intCast(count),
        raw.boolParam(protocol_options.required),
        raw.boolParam(protocol_options.instance),
    );
}
