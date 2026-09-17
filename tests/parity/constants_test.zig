//! Parity tests verifying runtime constants against Apple SDK and compiler-rt definitions.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");
const raw = objc.raw;
const c = @import("objc-c");

test "ABI parity: runtime sentinels" {
    const yes_val: i32 = if (raw.YES) 1 else 0;
    try testing.expectEqual(@as(i32, c.YES), yes_val);
    const no_val: i32 = if (raw.NO) 1 else 0;
    try testing.expectEqual(@as(i32, c.NO), no_val);
    const null_id: raw.id = null;
    const null_class: raw.Class = null;
    try testing.expect(null_id == null);
    try testing.expect(null_class == null);
}

test "ABI parity: association policy constants" {
    try testing.expectEqual(@as(c_uint, c.OBJC_ASSOCIATION_ASSIGN), @intFromEnum(objc.runtime.AssociationPolicy.assign));
    try testing.expectEqual(@as(c_uint, c.OBJC_ASSOCIATION_RETAIN_NONATOMIC), @intFromEnum(objc.runtime.AssociationPolicy.retain_nonatomic));
    try testing.expectEqual(@as(c_uint, c.OBJC_ASSOCIATION_COPY_NONATOMIC), @intFromEnum(objc.runtime.AssociationPolicy.copy_nonatomic));
    try testing.expectEqual(@as(c_uint, c.OBJC_ASSOCIATION_RETAIN), @intFromEnum(objc.runtime.AssociationPolicy.retain));
    try testing.expectEqual(@as(c_uint, c.OBJC_ASSOCIATION_COPY), @intFromEnum(objc.runtime.AssociationPolicy.copy));
}

test "ABI parity: Block literal flag constants" {
    try testing.expectEqual(@as(c_int, 1 << 25), raw.blocks.BLOCK_HAS_COPY_DISPOSE);
    try testing.expectEqual(@as(c_int, 1 << 28), raw.blocks.BLOCK_IS_GLOBAL);
    try testing.expectEqual(@as(c_int, 1 << 29), raw.blocks.BLOCK_USE_STRET);
    try testing.expectEqual(@as(c_int, 1 << 30), raw.blocks.BLOCK_HAS_SIGNATURE);
}

test "ABI parity: Block field flag constants" {
    try testing.expectEqual(@as(c_int, 3), raw.blocks.BLOCK_FIELD_IS_OBJECT);
    try testing.expectEqual(@as(c_int, 7), raw.blocks.BLOCK_FIELD_IS_BLOCK);
    try testing.expectEqual(@as(c_int, 8), raw.blocks.BLOCK_FIELD_IS_BYREF);
    try testing.expectEqual(@as(c_int, 16), raw.blocks.BLOCK_FIELD_IS_WEAK);
    try testing.expectEqual(@as(c_int, 128), raw.blocks.BLOCK_BYREF_CALLER);
}
