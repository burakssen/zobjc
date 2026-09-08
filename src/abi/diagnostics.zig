//! Compile-time diagnostics and validations for Objective-C ABI classification.

const std = @import("std");
const Target = @import("target.zig").Target;
const encoding = @import("../encoding/root.zig");

// ponytail: Lean compile-time assertions reusing Phase 4 type encodability checks.

/// Asserts that `T` is a valid return type for Objective-C ABI classification.
pub fn assertValidReturn(comptime T: type) void {
    if (T == void) return;
    encoding.assertObjCEncodable(T);
}

/// Asserts that `target` is a supported Darwin Objective-C ABI target.
pub fn assertValidTarget(comptime target: Target) void {
    target.assertSupported();
}
