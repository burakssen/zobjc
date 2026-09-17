//! Parity tests verifying raw types, handles, and scalars against Apple SDK translate-c headers.

const std = @import("std");
const testing = std.testing;
const raw = @import("objc").raw;
const c = @import("objc-c");

test "ABI parity: handles and scalar types match Apple SDK" {
    // id
    try testing.expectEqual(@sizeOf(c.id), @sizeOf(raw.id));
    try testing.expectEqual(@alignOf(c.id), @alignOf(raw.id));

    // Class
    try testing.expectEqual(@sizeOf(c.Class), @sizeOf(raw.Class));
    try testing.expectEqual(@alignOf(c.Class), @alignOf(raw.Class));

    // SEL
    try testing.expectEqual(@sizeOf(c.SEL), @sizeOf(raw.SEL));
    try testing.expectEqual(@alignOf(c.SEL), @alignOf(raw.SEL));

    // IMP
    try testing.expectEqual(@sizeOf(c.IMP), @sizeOf(raw.IMP));
    try testing.expectEqual(@alignOf(c.IMP), @alignOf(raw.IMP));

    // Method
    try testing.expectEqual(@sizeOf(c.Method), @sizeOf(raw.Method));
    try testing.expectEqual(@alignOf(c.Method), @alignOf(raw.Method));

    // Ivar
    try testing.expectEqual(@sizeOf(c.Ivar), @sizeOf(raw.Ivar));
    try testing.expectEqual(@alignOf(c.Ivar), @alignOf(raw.Ivar));

    // objc_property_t
    try testing.expectEqual(@sizeOf(c.objc_property_t), @sizeOf(raw.objc_property_t));
    try testing.expectEqual(@alignOf(c.objc_property_t), @alignOf(raw.objc_property_t));

    // Category
    try testing.expectEqual(@sizeOf(c.Category), @sizeOf(raw.Category));
    try testing.expectEqual(@alignOf(c.Category), @alignOf(raw.Category));

    // BOOL
    try testing.expectEqual(@sizeOf(c.BOOL), @sizeOf(raw.BOOL));
    try testing.expectEqual(@alignOf(c.BOOL), @alignOf(raw.BOOL));
}
