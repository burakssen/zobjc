//! Objective-C runtime image discovery and class inspection.
//!
//! Provides caller-freed lists of loaded dynamic libraries and class names per image.

const std = @import("std");
const raw = @import("../raw/root.zig");
const memory = @import("../memory/root.zig");

/// Returns a caller-freed list of all loaded dynamic library image names.
///
/// NOTE: The returned pointer array is caller-owned and freed via `deinit()`,
/// while the image name strings inside refer to runtime-owned image metadata.
pub fn images() memory.OwnedCStringList {
    var count_val: c_uint = 0;
    const list = raw.runtime.objc_copyImageNames(&count_val);
    return memory.OwnedCStringList.fromRaw(list, count_val);
}

/// Returns a caller-freed list of class names declared in the given image.
///
/// If the image is unknown or contains no classes, returns a valid empty list.
pub fn classNamesForImage(image: [:0]const u8) memory.OwnedCStringList {
    var count_val: c_uint = 0;
    const list = raw.runtime.objc_copyClassNamesForImage(image.ptr, &count_val);
    return memory.OwnedCStringList.fromRaw(list, count_val);
}
