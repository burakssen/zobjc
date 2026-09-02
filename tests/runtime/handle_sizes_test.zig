//! Handle size, alignment, and zero-cost pointer invariant tests.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");
const raw = objc.raw;

test "handle: all 8 runtime handles are pointer-sized and pointer-aligned" {
    // 1. Object
    try testing.expectEqual(@sizeOf(usize), @sizeOf(objc.Object));
    try testing.expectEqual(@alignOf(usize), @alignOf(objc.Object));

    // 2. Class
    try testing.expectEqual(@sizeOf(usize), @sizeOf(objc.Class));
    try testing.expectEqual(@alignOf(usize), @alignOf(objc.Class));

    // 3. Selector
    try testing.expectEqual(@sizeOf(usize), @sizeOf(objc.Selector));
    try testing.expectEqual(@alignOf(usize), @alignOf(objc.Selector));

    // 4. Method
    try testing.expectEqual(@sizeOf(usize), @sizeOf(objc.Method));
    try testing.expectEqual(@alignOf(usize), @alignOf(objc.Method));

    // 5. Ivar
    try testing.expectEqual(@sizeOf(usize), @sizeOf(objc.Ivar));
    try testing.expectEqual(@alignOf(usize), @alignOf(objc.Ivar));

    // 6. Property
    try testing.expectEqual(@sizeOf(usize), @sizeOf(objc.Property));
    try testing.expectEqual(@alignOf(usize), @alignOf(objc.Property));

    // 7. Protocol
    try testing.expectEqual(@sizeOf(usize), @sizeOf(objc.Protocol));
    try testing.expectEqual(@alignOf(usize), @alignOf(objc.Protocol));

    // 8. Imp
    try testing.expectEqual(@sizeOf(usize), @sizeOf(objc.Imp));
    try testing.expectEqual(@alignOf(usize), @alignOf(objc.Imp));
}

test "handle: PropertyAttribute matches raw C layout exactly" {
    try testing.expectEqual(
        @sizeOf(raw.objc_property_attribute_t),
        @sizeOf(objc.PropertyAttribute),
    );
    try testing.expectEqual(
        @alignOf(raw.objc_property_attribute_t),
        @alignOf(objc.PropertyAttribute),
    );
}
