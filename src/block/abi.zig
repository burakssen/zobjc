//! Objective-C Block ABI coordination.
//!
//! Bridges Darwin ABI return classification (Phase 5) and type encoding (Phase 4)
//! to generate authoritative Block flags, descriptors, and layouts.

const std = @import("std");
const abi = @import("../abi/root.zig");
const messaging = @import("../messaging/root.zig");
const raw = @import("../raw/root.zig");
const flags_mod = @import("flags.zig");
const descriptor_mod = @import("descriptor.zig");
const layout_mod = @import("layout.zig");
const signature_mod = @import("signature.zig");

pub const BlockFlags = flags_mod.BlockFlags;
pub const Descriptor = descriptor_mod.Descriptor;
pub const LayoutResult = layout_mod.LayoutResult;
pub const blockSignature = signature_mod.blockSignature;

/// Determines whether a Block with the given return type requires `BLOCK_USE_STRET`.
///
/// Under Apple's libclosure / Clang ABI, `BLOCK_USE_STRET` is undefined unless `BLOCK_HAS_SIGNATURE`
/// is set. On ARM64, `BLOCK_USE_STRET` is always false because ARM64 does not use the separate
/// stret convention entry points. On x86_64, it is true only for aggregates that cannot fit in RAX/RDX.
pub fn usesStret(comptime Return: type) bool {
    const AbiReturn = messaging.AbiReturnType(Return);
    const convention = abi.returnConvention(AbiReturn);
    // // ponytail: strictly derived from Phase 5 ABI return classification; never checks @typeInfo(Return) == .@"struct"
    return convention == .stret;
}

test "abi: usesStret classification" {
    // Basic scalars and void never use stret
    try std.testing.expect(!usesStret(void));
    try std.testing.expect(!usesStret(c_int));
    try std.testing.expect(!usesStret(f64));

    // Long double never uses stret (it uses fpret on x86_64)
    try std.testing.expect(!usesStret(c_longdouble));

    // Small struct (<= 16 bytes)
    const Small = extern struct { a: u64, b: u64 };
    try std.testing.expect(!usesStret(Small));

    // On arm64 native test runner, large struct does NOT use stret
    const Large = extern struct { a: u64, b: u64, c: u64 };
    if (@import("builtin").target.cpu.arch == .aarch64) {
        try std.testing.expect(!usesStret(Large));
    }
}
