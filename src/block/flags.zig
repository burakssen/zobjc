//! Semantic Apple Blocks ABI flags builder.
//!
//! Generates bitfield flags according to Apple libclosure / Clang Blocks ABI rules.

const std = @import("std");
const raw = @import("../raw/root.zig");

/// Semantic description of a Block's compiler-generated capabilities.
pub const BlockFlags = struct {
    global: bool = false,
    noescape: bool = false,
    copy_dispose: bool = false,
    stret: bool = false,
    signature: bool = true,
    extended_layout: bool = false,

    /// Computes the bitmask integer for `Block_layout.flags`.
    pub fn bits(self: BlockFlags) c_int {
        var result: c_int = 0;

        if (self.global) result |= raw.blocks.BLOCK_IS_GLOBAL;
        if (self.noescape) result |= raw.blocks.BLOCK_IS_NOESCAPE;
        if (self.copy_dispose) result |= raw.blocks.BLOCK_HAS_COPY_DISPOSE;
        if (self.stret) result |= raw.blocks.BLOCK_USE_STRET;
        if (self.signature) result |= raw.blocks.BLOCK_HAS_SIGNATURE;
        if (self.extended_layout) result |= raw.blocks.BLOCK_HAS_EXTENDED_LAYOUT;

        return result;
    }
};

test "BlockFlags: bitfield serialization" {
    const flags_basic = BlockFlags{
        .global = true,
        .signature = true,
    };
    try std.testing.expectEqual(@as(c_int, 0x50000000), flags_basic.bits());

    const flags_helpers = BlockFlags{
        .copy_dispose = true,
        .signature = true,
        .extended_layout = true,
    };
    try std.testing.expectEqual(@as(c_int, @bitCast(@as(u32, 0xc2000000))), flags_helpers.bits());
}
