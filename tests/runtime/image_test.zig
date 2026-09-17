//! Tests for image and Mach-O header introspection.
// ponytail: minimalist, zero overhead, verify image enumeration and class name extraction.

const std = @import("std");
const objc = @import("objc");
const testing = std.testing;

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
    // NSObject is typically in libobjc.A.dylib
    try testing.expect(std.mem.indexOf(u8, image_name.?, "libobjc") != null or std.mem.indexOf(u8, image_name.?, "Foundation") != null);
}
