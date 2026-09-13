//! Layout and ABI differential tests comparing Zig Block layout with Clang.

const std = @import("std");
const objc = @import("objc");
const raw = objc.raw;
const testing = std.testing;

extern "c" fn get_clang_block_flags(block: *anyopaque) i32;
extern "c" fn get_clang_block_descriptor_size(block: *anyopaque) usize;
extern "c" fn get_clang_block_signature(block: *anyopaque) ?[*:0]const u8;
extern "c" fn make_int_multiplier_block(multiplier: c_int) *anyopaque;

test "block layout: header size and offsets" {
    try testing.expectEqual(@as(usize, 32), @sizeOf(raw.blocks.Block_layout));
    try testing.expectEqual(@as(usize, 0), @offsetOf(raw.blocks.Block_layout, "isa"));
    try testing.expectEqual(@as(usize, 8), @offsetOf(raw.blocks.Block_layout, "flags"));
    try testing.expectEqual(@as(usize, 12), @offsetOf(raw.blocks.Block_layout, "reserved"));
    try testing.expectEqual(@as(usize, 16), @offsetOf(raw.blocks.Block_layout, "invoke"));
    try testing.expectEqual(@as(usize, 24), @offsetOf(raw.blocks.Block_layout, "descriptor"));
}

test "block layout: Clang block comparison" {
    const clang_blk = make_int_multiplier_block(3);
    defer raw.blocks._Block_release(clang_blk);

    const flags = get_clang_block_flags(clang_blk);
    try testing.expect((flags & raw.blocks.BLOCK_HAS_SIGNATURE) != 0);

    const desc_size = get_clang_block_descriptor_size(clang_blk);
    // 32 header + 4 byte int (aligned to 36 or 40)
    try testing.expect(desc_size >= 36);

    const sig = get_clang_block_signature(clang_blk);
    try testing.expect(sig != null);
}

test "block layout: Zig block descriptor size covers captures" {
    const Captures = struct {
        a: c_int,
        b: f64,
    };
    var blk = try objc.OwnedBlock(fn () void).capture(
        Captures,
        .{ .a = 1, .b = 2.0 },
        struct {
            fn run(_: *const Captures) void {}
        }.run,
    );
    defer blk.deinit();

    const raw_ptr = blk.borrow().toRaw();
    const Lit = objc.block.internal.Literal(Captures);
    try testing.expectEqual(@sizeOf(Lit), raw_ptr.descriptor.size);
    try testing.expect(raw_ptr.descriptor.size >= 48);
}
