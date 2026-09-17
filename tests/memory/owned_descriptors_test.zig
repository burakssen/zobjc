//! Owned runtime descriptors and string lists tests.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

test "OwnedMethodDescriptions: protocol.methodDescriptions" {
    const proto = objc.getProtocol("NSObject").?;

    var req_methods = proto.methodDescriptions(.{
        .required = true,
        .instance = true,
    });
    defer req_methods.deinit();

    try testing.expect(!req_methods.isEmpty());
    try testing.expect(req_methods.count() > 0);

    const first = req_methods.get(0).?;
    try testing.expect(first.selector.?.getName().len > 0);

    var count: usize = 0;
    var iter = req_methods.iterator();
    while (iter.next()) |_| {
        count += 1;
    }
    try testing.expectEqual(req_methods.count(), count);
}

test "OwnedPropertyAttributes: property.attributesList" {
    const NSObject = objc.requireClass("NSObject");
    const prop = NSObject.getProperty("className") orelse NSObject.getProperty("description").?;

    var attrs = prop.attributesList();
    defer attrs.deinit();

    try testing.expect(!attrs.isEmpty());
    try testing.expect(attrs.count() > 0);

    const first = attrs.get(0).?;
    try testing.expect(std.mem.span(first.name).len > 0);

    var count: usize = 0;
    var iter = attrs.iterator();
    while (iter.next()) |_| {
        count += 1;
    }
    try testing.expectEqual(attrs.count(), count);
}

test "OwnedCStringList: runtime.imageNames and classNamesForImage" {
    var images = objc.runtime.imageNames();
    defer images.deinit();

    try testing.expect(!images.isEmpty());
    try testing.expect(images.count() > 0);

    const first_image = images.get(0).?;
    try testing.expect(first_image.len > 0);

    var count: usize = 0;
    var iter = images.iterator();
    while (iter.next()) |_| {
        count += 1;
    }
    try testing.expectEqual(images.count(), count);

    // Look for libobjc or Foundation image to test classNamesForImage
    var libobjc_image: ?[:0]const u8 = null;
    var img_iter = images.iterator();
    while (img_iter.next()) |img| {
        if (std.mem.indexOf(u8, img, "libobjc") != null) {
            libobjc_image = img;
            break;
        }
    }

    if (libobjc_image) |target_image| {
        var class_names = objc.runtime.classNamesForImage(target_image);
        defer class_names.deinit();

        try testing.expect(class_names.count() > 0);
        const first_cls_name = class_names.get(0).?;
        try testing.expect(first_cls_name.len > 0);
    }
}

test "Owned descriptors: empty representations" {
    var empty_methods = objc.memory.OwnedMethodDescriptions.empty();
    try testing.expect(empty_methods.isEmpty());
    try testing.expectEqual(@as(usize, 0), empty_methods.count());
    try testing.expect(empty_methods.get(0) == null);
    empty_methods.deinit();

    var empty_attrs = objc.memory.OwnedPropertyAttributes.empty();
    try testing.expect(empty_attrs.isEmpty());
    try testing.expectEqual(@as(usize, 0), empty_attrs.count());
    try testing.expect(empty_attrs.get(0) == null);
    empty_attrs.deinit();

    var empty_strings = objc.memory.OwnedCStringList.empty();
    try testing.expect(empty_strings.isEmpty());
    try testing.expectEqual(@as(usize, 0), empty_strings.count());
    try testing.expect(empty_strings.get(0) == null);
    empty_strings.deinit();
}
