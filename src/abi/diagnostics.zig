//! Compile-time diagnostics and validations for Objective-C ABI classification.

const Target = @import("target.zig").Target;

/// Asserts that `target` is a supported Darwin Objective-C ABI target.
pub fn assertValidTarget(comptime target: Target) void {
    target.assertSupported();
}
