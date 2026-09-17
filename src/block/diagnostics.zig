//! Block introspection and diagnostics utilities.

const std = @import("std");
const raw = @import("raw");

/// Checks if a Block is a statically allocated global Block.
pub fn isGlobal(block_ptr: *const raw.blocks.Block_layout) bool {
    return (block_ptr.flags & raw.blocks.BLOCK_IS_GLOBAL) != 0;
}

/// Checks if a Block literal has copy/dispose helper functions.
pub fn hasCopyDispose(block_ptr: *const raw.blocks.Block_layout) bool {
    return (block_ptr.flags & raw.blocks.BLOCK_HAS_COPY_DISPOSE) != 0;
}

/// Checks if a Block literal has type signature metadata.
pub fn hasSignature(block_ptr: *const raw.blocks.Block_layout) bool {
    return (block_ptr.flags & raw.blocks.BLOCK_HAS_SIGNATURE) != 0;
}

/// Checks if a Block literal has the BLOCK_USE_STRET flag set.
pub fn usesStret(block_ptr: *const raw.blocks.Block_layout) bool {
    return (block_ptr.flags & raw.blocks.BLOCK_USE_STRET) != 0;
}

/// Checks if a Block literal has extended layout metadata.
pub fn hasExtendedLayout(block_ptr: *const raw.blocks.Block_layout) bool {
    return (block_ptr.flags & raw.blocks.BLOCK_HAS_EXTENDED_LAYOUT) != 0;
}

/// Reads the descriptor's size field (covering the full literal including captures).
pub fn descriptorSize(block_ptr: *const raw.blocks.Block_layout) usize {
    return @intCast(block_ptr.descriptor.size);
}
