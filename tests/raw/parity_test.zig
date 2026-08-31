//! Header parity tests comparing handwritten raw definitions against Apple SDK translate-c headers.

const std = @import("std");
const testing = std.testing;
const raw = @import("objc").raw;
const c = @import("objc-c");

test "ABI parity: handles and scalar types" {
    try testing.expectEqual(@sizeOf(c.id), @sizeOf(raw.id));
    try testing.expectEqual(@alignOf(c.id), @alignOf(raw.id));

    try testing.expectEqual(@sizeOf(c.Class), @sizeOf(raw.Class));
    try testing.expectEqual(@alignOf(c.Class), @alignOf(raw.Class));

    try testing.expectEqual(@sizeOf(c.SEL), @sizeOf(raw.SEL));
    try testing.expectEqual(@alignOf(c.SEL), @alignOf(raw.SEL));

    try testing.expectEqual(@sizeOf(c.IMP), @sizeOf(raw.IMP));
    try testing.expectEqual(@alignOf(c.IMP), @alignOf(raw.IMP));

    try testing.expectEqual(@sizeOf(c.Method), @sizeOf(raw.Method));
    try testing.expectEqual(@alignOf(c.Method), @alignOf(raw.Method));

    try testing.expectEqual(@sizeOf(c.Ivar), @sizeOf(raw.Ivar));
    try testing.expectEqual(@alignOf(c.Ivar), @alignOf(raw.Ivar));

    try testing.expectEqual(@sizeOf(c.objc_property_t), @sizeOf(raw.objc_property_t));
    try testing.expectEqual(@alignOf(c.objc_property_t), @alignOf(raw.objc_property_t));

    try testing.expectEqual(@sizeOf(c.BOOL), @sizeOf(raw.BOOL));
    try testing.expectEqual(@alignOf(c.BOOL), @alignOf(raw.BOOL));
}

test "ABI parity: objc_super struct layout" {
    try testing.expectEqual(@sizeOf(c.objc_super), @sizeOf(raw.objc_super));
    try testing.expectEqual(@alignOf(c.objc_super), @alignOf(raw.objc_super));

    try testing.expectEqual(@offsetOf(c.objc_super, "receiver"), @offsetOf(raw.objc_super, "receiver"));
    try testing.expectEqual(@offsetOf(c.objc_super, "super_class"), @offsetOf(raw.objc_super, "super_class"));
}

test "ABI parity: objc_method_description struct layout" {
    try testing.expectEqual(@sizeOf(c.objc_method_description), @sizeOf(raw.objc_method_description));
    try testing.expectEqual(@alignOf(c.objc_method_description), @alignOf(raw.objc_method_description));

    try testing.expectEqual(@offsetOf(c.objc_method_description, "name"), @offsetOf(raw.objc_method_description, "name"));
    try testing.expectEqual(@offsetOf(c.objc_method_description, "types"), @offsetOf(raw.objc_method_description, "types"));
}

test "ABI parity: objc_property_attribute_t struct layout" {
    try testing.expectEqual(@sizeOf(c.objc_property_attribute_t), @sizeOf(raw.objc_property_attribute_t));
    try testing.expectEqual(@alignOf(c.objc_property_attribute_t), @alignOf(raw.objc_property_attribute_t));

    try testing.expectEqual(@offsetOf(c.objc_property_attribute_t, "name"), @offsetOf(raw.objc_property_attribute_t, "name"));
    try testing.expectEqual(@offsetOf(c.objc_property_attribute_t, "value"), @offsetOf(raw.objc_property_attribute_t, "value"));
}
