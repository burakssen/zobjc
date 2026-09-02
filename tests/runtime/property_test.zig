//! Property handle tests.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

test "property: dynamic class property introspection" {
    const NSObject = objc.requireClass("NSObject");
    const Subclass = objc.allocateClassPair(NSObject, "PropertyTestClass").?;

    const attrs = [_]objc.PropertyAttribute{
        .{ .name = "T", .value = "@\"NSString\"" },
        .{ .name = "C", .value = "" },
        .{ .name = "N", .value = "" },
        .{ .name = "V", .value = "_title" },
    };
    try testing.expect(Subclass.addProperty("title", &attrs));

    objc.registerClassPair(Subclass);
    defer objc.disposeClassPair(Subclass);

    const prop = Subclass.property("title").?;

    // Name
    try testing.expectEqualStrings("title", prop.name());

    // Attributes string
    const attr_str = prop.attributes();
    try testing.expect(attr_str != null);
    try testing.expect(attr_str.?.len > 0);

    // Copy single attribute value
    if (prop.copyAttributeValue("V")) |val| {
        defer std.heap.c_allocator.free(val);
        try testing.expectEqualStrings("_title", val);
    } else {
        return error.AttributeValueNotFound;
    }

    // Equality
    try testing.expect(prop.eql(prop));
}
