//! Apple Block capture layout metadata generator.
//!
//! Synthesizes compact (0xXYZ) and extended (0xPN byte string) layouts matching libclosure SPI.

const std = @import("std");

pub const BLOCK_LAYOUT_ESCAPE: u8 = 0;
pub const BLOCK_LAYOUT_NON_OBJECT_BYTES: u8 = 1;
pub const BLOCK_LAYOUT_NON_OBJECT_WORDS: u8 = 2;
pub const BLOCK_LAYOUT_STRONG: u8 = 3;
pub const BLOCK_LAYOUT_BYREF: u8 = 4;
pub const BLOCK_LAYOUT_WEAK: u8 = 5;
pub const BLOCK_LAYOUT_UNRETAINED: u8 = 6;

/// Layout representation for a Block's capture payload.
pub const LayoutResult = struct {
    has_layout: bool = false,
    is_compact: bool = false,
    compact_value: u16 = 0,
    extended_bytes: []const u8 = &.{},

    /// Returns the raw pointer value to store in `Descriptor.layout`.
    pub fn rawPointer(self: LayoutResult) ?*const anyopaque {
        if (!self.has_layout) return null;
        if (self.is_compact) {
            // // compact values < 0x1000 are cast directly to pointer per libclosure SPI
            return @ptrFromInt(@as(usize, self.compact_value));
        }
        return @ptrCast(self.extended_bytes.ptr);
    }
};

/// Encodes a compact layout value from word counts.
pub fn encodeCompactLayout(strong_words: u8, byref_words: u8, weak_words: u8) ?u16 {
    if (strong_words > 15 or byref_words > 15 or weak_words > 15) return null;
    const val = (@as(u16, strong_words) << 8) | (@as(u16, byref_words) << 4) | @as(u16, weak_words);
    return val;
}

test "encodeCompactLayout" {
    // 1 strong pointer, 0 byref, 0 weak -> 0x100 (matches Clang output)
    try std.testing.expectEqual(@as(?u16, 0x100), encodeCompactLayout(1, 0, 0));
    // 2 strong, 1 byref, 0 weak -> 0x210
    try std.testing.expectEqual(@as(?u16, 0x210), encodeCompactLayout(2, 1, 0));
    // overflow
    try std.testing.expectEqual(@as(?u16, null), encodeCompactLayout(16, 0, 0));
}
