//! Tests for low-level Objective-C runtime type layouts, sizes, and alignments.

const std = @import("std");
const testing = std.testing;
const raw = @import("objc").raw;

test "opaque handle sizes and alignments" {
    // All opaque handle pointer aliases must match standard pointer dimensions
    try testing.expectEqual(@sizeOf(usize), @sizeOf(raw.id));
    try testing.expectEqual(@alignOf(usize), @alignOf(raw.id));

    try testing.expectEqual(@sizeOf(usize), @sizeOf(raw.Class));
    try testing.expectEqual(@alignOf(usize), @alignOf(raw.Class));

    try testing.expectEqual(@sizeOf(usize), @sizeOf(raw.SEL));
    try testing.expectEqual(@alignOf(usize), @alignOf(raw.SEL));

    try testing.expectEqual(@sizeOf(usize), @sizeOf(raw.IMP));
    try testing.expectEqual(@alignOf(usize), @alignOf(raw.IMP));

    try testing.expectEqual(@sizeOf(usize), @sizeOf(raw.Method));
    try testing.expectEqual(@alignOf(usize), @alignOf(raw.Method));

    try testing.expectEqual(@sizeOf(usize), @sizeOf(raw.Ivar));
    try testing.expectEqual(@alignOf(usize), @alignOf(raw.Ivar));

    try testing.expectEqual(@sizeOf(usize), @sizeOf(raw.objc_property_t));
    try testing.expectEqual(@alignOf(usize), @alignOf(raw.objc_property_t));

    try testing.expectEqual(@sizeOf(usize), @sizeOf(raw.Protocol));
    try testing.expectEqual(@alignOf(usize), @alignOf(raw.Protocol));

    try testing.expectEqual(@sizeOf(usize), @sizeOf(raw.Category));
    try testing.expectEqual(@alignOf(usize), @alignOf(raw.Category));
}

test "BOOL representation and boolean conversion helpers" {
    // BOOL is 1 byte on all modern Darwin 64-bit targets (signed char on macOS, bool on iOS64)
    try testing.expectEqual(1, @sizeOf(raw.BOOL));
    try testing.expectEqual(1, @alignOf(raw.BOOL));

    try testing.expect(raw.boolResult(raw.YES));
    try testing.expect(!raw.boolResult(raw.NO));

    try testing.expectEqual(raw.YES, raw.boolParam(true));
    try testing.expectEqual(raw.NO, raw.boolParam(false));
}

test "ABI struct memory layouts" {
    // objc_super: receiver (id) + super_class (Class)
    try testing.expectEqual(2 * @sizeOf(usize), @sizeOf(raw.objc_super));
    try testing.expectEqual(@alignOf(usize), @alignOf(raw.objc_super));

    const s: raw.objc_super = .{
        .receiver = null,
        .super_class = null,
    };
    try testing.expectEqual(@as(raw.id, null), s.receiver);
    try testing.expectEqual(@as(raw.Class, null), s.super_class);

    // objc_method_description: name (SEL) + types ([*:0]const u8)
    try testing.expectEqual(2 * @sizeOf(usize), @sizeOf(raw.objc_method_description));
    try testing.expectEqual(@alignOf(usize), @alignOf(raw.objc_method_description));

    // objc_property_attribute_t: name ([*:0]const u8) + value ([*:0]const u8)
    try testing.expectEqual(2 * @sizeOf(usize), @sizeOf(raw.objc_property_attribute_t));
    try testing.expectEqual(@alignOf(usize), @alignOf(raw.objc_property_attribute_t));
}

test "Blocks runtime structures and flags" {
    // BlockFieldFlags constants
    try testing.expectEqual(3, @intFromEnum(raw.blocks.BlockFieldFlags.object));
    try testing.expectEqual(7, @intFromEnum(raw.blocks.BlockFieldFlags.block));
    try testing.expectEqual(8, @intFromEnum(raw.blocks.BlockFieldFlags.byref));
    try testing.expectEqual(16, @intFromEnum(raw.blocks.BlockFieldFlags.weak));
    try testing.expectEqual(128, @intFromEnum(raw.blocks.BlockFieldFlags.byref_caller));

    // BlockFlags bitfield size
    try testing.expectEqual(@sizeOf(c_int), @sizeOf(raw.blocks.BlockFlags));

    // BlockDescriptor size and fields
    const expected_desc_size = 2 * @sizeOf(c_ulong) + 3 * @sizeOf(usize);
    try testing.expectEqual(expected_desc_size, @sizeOf(raw.blocks.BlockDescriptor));

    // BlockLiteral layout
    const expected_literal_size = @sizeOf(usize) + 2 * @sizeOf(c_int) + 2 * @sizeOf(usize);
    try testing.expectEqual(expected_literal_size, @sizeOf(raw.blocks.BlockLiteral));
}
