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

// ponytail: Always .normal for messenger selection on arm64 Darwin.
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
        .objc_object,
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
