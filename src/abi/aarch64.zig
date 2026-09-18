//! AArch64 (Apple Silicon / ARM64) Darwin Objective-C ABI classification.
//!
//! On ARM64 Darwin, Apple's Objective-C runtime does NOT provide or support
//! `objc_msgSend_stret`, `objc_msgSend_fpret`, or `objc_msgSend_fp2ret`.
//! All message dispatch strictly targets `objc_msgSend` (`.normal`).

const std = @import("std");
const Target = @import("target.zig").Target;
const convention = @import("convention.zig");
const ReturnConvention = convention.ReturnConvention;
const ABIResult = convention.ABIResult;
const type_mod = @import("type.zig");
const layout = @import("layout.zig");
const testing = std.testing;

// Always .normal for messenger selection on arm64 Darwin.
pub fn returnConvention(comptime target: Target, comptime T: type) ReturnConvention {
    _ = target;
    _ = type_mod.categorize(T);
    return .normal;
}

/// Low-level AArch64 AAPCS64 return classification (direct vs indirect).
///
/// While all Objective-C calls on ARM64 use `objc_msgSend` (.normal),
/// the low-level ABI classification distinguishes whether the return value
/// is returned directly in registers or indirectly via hidden buffer pointer x8.
pub fn classifyReturn(comptime target: Target, comptime T: type) ABIResult {
    _ = target;
    const cat = type_mod.categorize(T);

    switch (cat) {
        .void,
        .integer,
        .pointer,
        .floating,
        .long_double,
        .complex_long_double,
        .vector,
        => return .direct,

        .aggregate => {
            const size = layout.sizeOf(T);
            if (size == 0) return .direct;

            // Check Homogeneous Floating-point Aggregate (HFA) of 1 to 4 floats/doubles
            if (isHFA(T)) return .direct;

            // Standard AArch64 rule: aggregates <= 16 bytes are returned in registers (x0, x1)
            if (size <= 16) return .direct;

            // Aggregates > 16 bytes (non-HFA) are returned indirectly via x8
            return .indirect;
        },
    }
}

/// Returns true if T is a Homogeneous Floating-point Aggregate (HFA) of 1 to 4 elements.
fn isHFA(comptime T: type) bool {
    const info = @typeInfo(T);
    switch (info) {
        .@"struct" => |s| {
            if (s.fields.len == 0 or s.fields.len > 4) return false;
            const Base = getBaseFloatType(s.fields[0].type) orelse return false;
            inline for (s.fields) |f| {
                if (getBaseFloatType(f.type) != Base) return false;
            }
            return true;
        },
        .array => |a| {
            if (a.len == 0 or a.len > 4) return false;
            return getBaseFloatType(a.child) != null;
        },
        else => return false,
    }
}

fn getBaseFloatType(comptime T: type) ?type {
    if (T == f32 or T == f64) return T;
    return null;
}

test "aarch64: all supported returns use normal messenger" {
    const target = Target.macos_arm64;
    try testing.expectEqual(.normal, returnConvention(target, void));
    try testing.expectEqual(.normal, returnConvention(target, bool));
    try testing.expectEqual(.normal, returnConvention(target, i32));
    try testing.expectEqual(.normal, returnConvention(target, i64));
    try testing.expectEqual(.normal, returnConvention(target, f32));
    try testing.expectEqual(.normal, returnConvention(target, f64));
    try testing.expectEqual(.normal, returnConvention(target, c_longdouble));
    try testing.expectEqual(.normal, returnConvention(target, *anyopaque));
    const PtrWrapper = struct { ptr: *anyopaque };
    try testing.expectEqual(.normal, returnConvention(target, PtrWrapper));
    try testing.expectEqual(.normal, returnConvention(target, ?PtrWrapper));

    const Small = extern struct { a: u64, b: u64 };
    try testing.expectEqual(.normal, returnConvention(target, Small));

    const Large = extern struct { a: u64, b: u64, c: u64 };
    const Rect = extern struct {
        origin: extern struct { x: f64, y: f64 },
        size: extern struct { w: f64, h: f64 },
    };
    try testing.expectEqual(.normal, returnConvention(target, Large));
    try testing.expectEqual(.normal, returnConvention(target, Rect));
}

test "aarch64: internal ABI classification distinguishes direct vs indirect" {
    const target = Target.macos_arm64;
    try testing.expectEqual(.direct, classifyReturn(target, i32));
    try testing.expectEqual(.direct, classifyReturn(target, f64));

    const Small = extern struct { a: u64, b: u64 };
    try testing.expectEqual(.direct, classifyReturn(target, Small));

    const HFA3 = extern struct { a: f64, b: f64, c: f64 };
    const HFA4 = extern struct { a: f32, b: f32, c: f32, d: f32 };
    try testing.expectEqual(.direct, classifyReturn(target, HFA3));
    try testing.expectEqual(.direct, classifyReturn(target, HFA4));

    const LargeNonHFA = extern struct { a: u64, b: u64, c: u64 };
    try testing.expectEqual(.indirect, classifyReturn(target, LargeNonHFA));
}
