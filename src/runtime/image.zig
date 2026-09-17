//! Objective-C runtime image discovery and class inspection.
//!
//! Provides caller-freed lists of loaded dynamic libraries and class names per image.

const std = @import("std");
const testing = std.testing;
const objc = @import("zobjc");
const raw = @import("raw");
const memory = @import("memory");

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

test "image introspection: loaded images enumeration" {
    var image_list = objc.runtime.images();
    defer image_list.deinit();

    try testing.expect(image_list.len > 0);
    var found_libobjc = false;
    var iter = image_list.iterator();
    while (iter.next()) |name| {
        if (std.mem.indexOf(u8, name, "libobjc") != null) {
            found_libobjc = true;
            break;
        }
    }
    try testing.expect(found_libobjc);
}

test "image introspection: class names for image" {
    const NSObject = objc.requireClass("NSObject");
    const nsobject_image = NSObject.imageName() orelse return;

    var class_names = objc.runtime.classNamesForImage(nsobject_image);
    defer class_names.deinit();
    try testing.expect(class_names.len > 0);

    var found_nsobject = false;
    var name_iter = class_names.iterator();
    while (name_iter.next()) |cls_name| {
        if (std.mem.eql(u8, cls_name, "NSObject")) {
            found_nsobject = true;
            break;
        }
    }
    try testing.expect(found_nsobject);
}

test "image introspection: unknown image returns empty list" {
    var class_names = objc.runtime.classNamesForImage("/nonexistent/image/path.dylib");
    defer class_names.deinit();

    try testing.expectEqual(@as(usize, 0), class_names.len);
    try testing.expect(class_names.isEmpty());
}

test "image introspection: class.imageName" {
    const NSObject = objc.requireClass("NSObject");
    const image_name = NSObject.imageName();
    try testing.expect(image_name != null);
    try testing.expect(image_name.?.len > 0);
    try testing.expect(std.mem.indexOf(u8, image_name.?, "libobjc") != null or
        std.mem.indexOf(u8, image_name.?, "Foundation") != null);
}
