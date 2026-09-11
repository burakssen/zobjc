//! Objective-C instance variable layout and addition.

const std = @import("std");
const raw = @import("../raw/root.zig");
const runtime = @import("../runtime/root.zig");
const encoding = @import("../encoding/root.zig");
const errors = @import("errors.zig");
const Class = runtime.Class;
const ClassBuilderError = errors.ClassBuilderError;

/// Low-level escape hatch to add an instance variable with an explicit size, log2 alignment, and encoding.
pub fn addIvarEncoded(
    cls: Class,
    name: [:0]const u8,
    size: usize,
    alignment_log2: u8,
    encoding_str: [:0]const u8,
) ClassBuilderError!void {
    // Check if an instance variable with this name already exists.
    if (cls.instanceIvar(name) != null) {
        return error.IvarAlreadyExists;
    }

    const ok = raw.boolResult(raw.runtime.class_addIvar(
        cls.ptr,
        name.ptr,
        size,
        alignment_log2,
        encoding_str.ptr,
    ));

    if (!ok) {
        return error.CannotAddIvar;
    }
}

/// Adds a strongly typed instance variable to an un-registered class.
///
/// Computes physical storage size and log2 alignment via `encoding.StorageType(T)`,
/// and derives the Objective-C metadata encoding via `encoding.comptimeEncode(T)`.
pub fn addIvar(
    cls: Class,
    comptime T: type,
    name: [:0]const u8,
) ClassBuilderError!void {
    encoding.assertObjCEncodable(T);

    const Storage = encoding.StorageType(T);
    const size = @sizeOf(Storage);
    const alignment_log2: u8 = @intCast(std.math.log2_int(usize, @alignOf(Storage)));
    const type_enc = comptime encoding.comptimeEncode(T);

    return addIvarEncoded(cls, name, size, alignment_log2, &type_enc);
}
