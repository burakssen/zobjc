//! BlockFlags and BLOCK_USE_STRET tests.

const std = @import("std");
const objc = @import("objc");
const raw = objc.raw;
const testing = std.testing;

test "flags: BlockFlags builder" {
    const f1 = objc.block.BlockFlags{
        .global = true,
        .signature = true,
    };
    try testing.expectEqual(@as(c_int, raw.blocks.BLOCK_IS_GLOBAL | raw.blocks.BLOCK_HAS_SIGNATURE), f1.bits());

    const f2 = objc.block.BlockFlags{
        .copy_dispose = true,
        .signature = true,
        .stret = true,
    };
    try testing.expectEqual(@as(c_int, raw.blocks.BLOCK_HAS_COPY_DISPOSE | raw.blocks.BLOCK_HAS_SIGNATURE | raw.blocks.BLOCK_USE_STRET), f2.bits());
}

test "flags: BLOCK_USE_STRET derivation" {
    // Basic types never use stret
    try testing.expect(!objc.block.abi.usesStret(void));
    try testing.expect(!objc.block.abi.usesStret(c_int));
    try testing.expect(!objc.block.abi.usesStret(f64));
    try testing.expect(!objc.block.abi.usesStret(c_longdouble));

    // Small struct (<= 16 bytes)
    const Small = extern struct { x: f64, y: f64 };
    try testing.expect(!objc.block.abi.usesStret(Small));

    // On ARM64 macOS, aggregates never use stret messenger convention
    const Large = extern struct { a: u64, b: u64, c: u64 };
    if (@import("builtin").target.cpu.arch == .aarch64) {
        try testing.expect(!objc.block.abi.usesStret(Large));
    }
}
