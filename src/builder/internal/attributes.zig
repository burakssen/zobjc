//! Stack-allocated property attribute array synthesis.

const std = @import("std");
const raw = @import("../../raw/root.zig");

/// Configuration options for declared Objective-C properties.
pub const PropertyOptions = struct {
    readonly: bool = false,
    copy: bool = false,
    retain: bool = false,
    nonatomic: bool = false,
    weak: bool = false,
    dynamic: bool = false,

    getter: ?[:0]const u8 = null,
    setter: ?[:0]const u8 = null,
    ivar: ?[:0]const u8 = null,
};

/// Maximum number of property attributes possible from PropertyOptions.
pub const MaxAttributes = 12;

/// Populates a caller-provided stack buffer with `objc_property_attribute_t` descriptors.
///
/// Returns the number of attributes written. Rejects conflicting ownership attributes.
pub fn buildAttributes(
    type_encoding: [:0]const u8,
    options: PropertyOptions,
    buffer: *[MaxAttributes]raw.objc_property_attribute_t,
) error{InvalidPropertyAttributes}!usize {
    // Validate contradictory ownership combinations
    if ((options.copy and options.retain) or
        (options.copy and options.weak) or
        (options.retain and options.weak))
    {
        return error.InvalidPropertyAttributes;
    }

    var count: usize = 0;

    // 'T' attribute: type encoding (always first)
    buffer[count] = .{ .name = "T", .value = type_encoding.ptr };
    count += 1;

    if (options.readonly) {
        buffer[count] = .{ .name = "R", .value = "" };
        count += 1;
    }
    if (options.copy) {
        buffer[count] = .{ .name = "C", .value = "" };
        count += 1;
    }
    if (options.retain) {
        buffer[count] = .{ .name = "&", .value = "" };
        count += 1;
    }
    if (options.weak) {
        buffer[count] = .{ .name = "W", .value = "" };
        count += 1;
    }
    if (options.nonatomic) {
        buffer[count] = .{ .name = "N", .value = "" };
        count += 1;
    }
    if (options.dynamic) {
        buffer[count] = .{ .name = "D", .value = "" };
        count += 1;
    }
    if (options.getter) |g| {
        buffer[count] = .{ .name = "G", .value = g.ptr };
        count += 1;
    }
    if (options.setter) |s| {
        buffer[count] = .{ .name = "S", .value = s.ptr };
        count += 1;
    }
    if (options.ivar) |v| {
        buffer[count] = .{ .name = "V", .value = v.ptr };
        count += 1;
    }

    return count;
}
