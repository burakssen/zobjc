//! Central architecture dispatch for Objective-C return ABI classification.

const std = @import("std");
const Target = @import("target.zig").Target;
const convention = @import("convention.zig");
const ReturnConvention = convention.ReturnConvention;
const ReturnInfo = convention.ReturnInfo;
const ABIResult = convention.ABIResult;
const aarch64 = @import("aarch64.zig");
const x86_64 = @import("x86_64.zig");
const layout = @import("layout.zig");
const diagnostics = @import("diagnostics.zig");

// ponytail: Pure compile-time architecture dispatch.

/// Returns the Objective-C runtime return convention for type `T` on `target`.
pub fn returnConventionFor(comptime target: Target, comptime T: type) ReturnConvention {
    diagnostics.assertValidTarget(target);
    diagnostics.assertValidReturn(T);

    return switch (target.arch) {
        .aarch64 => aarch64.returnConvention(target, T),
        .x86_64 => x86_64.returnConvention(target, T),
        else => @compileError("Objective-C ABI classifier currently supports Darwin arm64 and x86_64."),
    };
}

/// Returns the Objective-C runtime return convention for type `T` on the native host target.
pub fn returnConvention(comptime T: type) ReturnConvention {
    return returnConventionFor(Target.native(), T);
}

/// Returns the low-level ABI return mechanism (direct vs indirect vs x87) for type `T` on `target`.
pub fn classifyReturn(comptime target: Target, comptime T: type) ABIResult {
    diagnostics.assertValidTarget(target);
    diagnostics.assertValidReturn(T);

    return switch (target.arch) {
        .aarch64 => aarch64.classifyReturn(target, T),
        .x86_64 => x86_64.classifyReturn(target, T),
        else => @compileError("Objective-C ABI classifier currently supports Darwin arm64 and x86_64."),
    };
}

/// Returns rich return metadata describing size, alignment, indirectness, and runtime convention.
pub fn returnInfo(comptime target: Target, comptime T: type) ReturnInfo {
    const conv = returnConventionFor(target, T);
    const result = classifyReturn(target, T);

    return .{
        .convention = conv,
        .indirect = (result == .indirect),
        .size = layout.sizeOf(T),
        .alignment = layout.alignOf(T),
        .arch = target.arch,
    };
}
