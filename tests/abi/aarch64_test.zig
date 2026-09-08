//! Tests for ARM64 Darwin return convention and ABI classification.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");
const Target = objc.abi.Target;
const returnConventionFor = objc.abi.returnConventionFor;
const classifyReturn = objc.abi.classifyReturn;

const macos_arm64 = Target.macos_arm64;

test "aarch64: all supported returns use normal messenger" {
    // Scalars
    try testing.expectEqual(.normal, returnConventionFor(macos_arm64, void));
    try testing.expectEqual(.normal, returnConventionFor(macos_arm64, bool));
    try testing.expectEqual(.normal, returnConventionFor(macos_arm64, i32));
    try testing.expectEqual(.normal, returnConventionFor(macos_arm64, i64));
    try testing.expectEqual(.normal, returnConventionFor(macos_arm64, f32));
    try testing.expectEqual(.normal, returnConventionFor(macos_arm64, f64));
    try testing.expectEqual(.normal, returnConventionFor(macos_arm64, c_longdouble));
    try testing.expectEqual(.normal, returnConventionFor(macos_arm64, *anyopaque));
    try testing.expectEqual(.normal, returnConventionFor(macos_arm64, objc.Object));

    // Small aggregates (<= 16 bytes)
    const Small = extern struct { a: u64, b: u64 };
    try testing.expectEqual(.normal, returnConventionFor(macos_arm64, Small));

    // Large aggregates (> 16 bytes) - MUST STILL BE NORMAL because stret is unavailable on ARM64!
    const Large = extern struct { a: u64, b: u64, c: u64 };
    const Rect = extern struct {
        origin: extern struct { x: f64, y: f64 },
        size: extern struct { w: f64, h: f64 },
    };
    try testing.expectEqual(.normal, returnConventionFor(macos_arm64, Large));
    try testing.expectEqual(.normal, returnConventionFor(macos_arm64, Rect));
}

test "aarch64: internal ABI classification distinguishes direct vs indirect" {
    // Scalars are direct
    try testing.expectEqual(.direct, classifyReturn(macos_arm64, i32));
    try testing.expectEqual(.direct, classifyReturn(macos_arm64, f64));

    // Small aggregate (<= 16 bytes) is direct in x0, x1
    const Small = extern struct { a: u64, b: u64 };
    try testing.expectEqual(.direct, classifyReturn(macos_arm64, Small));

    // Homogeneous Floating-point Aggregate (HFA) up to 4 elements is direct in SIMD registers
    const HFA3 = extern struct { a: f64, b: f64, c: f64 }; // 24 bytes
    const HFA4 = extern struct { a: f32, b: f32, c: f32, d: f32 }; // 16 bytes
    try testing.expectEqual(.direct, classifyReturn(macos_arm64, HFA3));
    try testing.expectEqual(.direct, classifyReturn(macos_arm64, HFA4));

    // Large non-HFA (> 16 bytes) is indirect via x8
    const LargeNonHFA = extern struct { a: u64, b: u64, c: u64 };
    try testing.expectEqual(.indirect, classifyReturn(macos_arm64, LargeNonHFA));
}
