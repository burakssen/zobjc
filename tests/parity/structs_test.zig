//! Parity tests verifying runtime structure layouts and offsets against Apple SDK translate-c headers.

const std = @import("std");
const testing = std.testing;
const raw = @import("objc").raw;
const c = @import("objc-c");

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

test "ABI parity: BlockLiteral layout matching Apple Blocks ABI" {
    // BlockLiteral layout: isa (ptr), flags (int), reserved (int), invoke (fn ptr), descriptor (ptr)
    try testing.expectEqual(@sizeOf(usize) * 4, @sizeOf(raw.blocks.BlockLiteral));
    try testing.expectEqual(@alignOf(usize), @alignOf(raw.blocks.BlockLiteral));

    try testing.expectEqual(0, @offsetOf(raw.blocks.BlockLiteral, "isa"));
    try testing.expectEqual(@sizeOf(usize), @offsetOf(raw.blocks.BlockLiteral, "flags"));
    try testing.expectEqual(@sizeOf(usize) + 4, @offsetOf(raw.blocks.BlockLiteral, "reserved"));
    try testing.expectEqual(@sizeOf(usize) * 2, @offsetOf(raw.blocks.BlockLiteral, "invoke"));
    try testing.expectEqual(@sizeOf(usize) * 3, @offsetOf(raw.blocks.BlockLiteral, "descriptor"));
}

test "ABI parity: Block_byref layout matching Apple Blocks ABI" {
    // Block_byref layout: isa (ptr), forwarding (ptr), flags (int), size (int)
    try testing.expectEqual(24, @sizeOf(raw.blocks.Block_byref));
    try testing.expectEqual(@alignOf(usize), @alignOf(raw.blocks.Block_byref));

    try testing.expectEqual(0, @offsetOf(raw.blocks.Block_byref, "isa"));
    try testing.expectEqual(8, @offsetOf(raw.blocks.Block_byref, "forwarding"));
    try testing.expectEqual(16, @offsetOf(raw.blocks.Block_byref, "flags"));
    try testing.expectEqual(20, @offsetOf(raw.blocks.Block_byref, "size"));
}

test "ABI parity: BlockDescriptor layout matching Apple Blocks ABI" {
    try testing.expectEqual(0, @offsetOf(raw.blocks.BlockDescriptor, "reserved"));
    try testing.expectEqual(@sizeOf(c_ulong), @offsetOf(raw.blocks.BlockDescriptor, "size"));
    try testing.expectEqual(@sizeOf(c_ulong) * 2, @offsetOf(raw.blocks.BlockDescriptor, "copy_helper"));
    try testing.expectEqual(@sizeOf(c_ulong) * 2 + @sizeOf(usize), @offsetOf(raw.blocks.BlockDescriptor, "dispose_helper"));
    try testing.expectEqual(@sizeOf(c_ulong) * 2 + @sizeOf(usize) * 2, @offsetOf(raw.blocks.BlockDescriptor, "signature"));
}
