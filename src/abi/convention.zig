//! Objective-C return convention and low-level ABI classification types.

const std = @import("std");

/// Objective-C runtime messenger dispatch convention for return values.
pub const ReturnConvention = enum {
    /// Ordinary Objective-C entry point (`objc_msgSend` / `objc_msgSendSuper`).
    ///
    /// Used for:
    /// - All returns on ARM64 Darwin.
    /// - Integer, pointer, object, float (`f32`), and double (`f64`) on x86_64 Darwin.
    /// - Aggregates returned in integer/SSE registers on x86_64 Darwin.
    normal,

    /// Structure-return entry point (`objc_msgSend_stret` / `objc_msgSendSuper_stret`).
    ///
    /// Used for memory-returned aggregates on x86_64 Darwin.
    /// Unavailable on ARM64 Darwin.
    stret,

    /// Floating-point return entry point (`objc_msgSend_fpret`).
    ///
    /// Specifically used on x86_64 Darwin for `long double` (80-bit x87).
    /// Does NOT apply to `float` or `double` on x86_64 Darwin.
    fpret,

    /// Complex long double return entry point (`objc_msgSend_fp2ret`).
    ///
    /// Used on x86_64 Darwin for complex `long double`.
    fp2ret,
};

/// Low-level platform ABI return mechanism.
pub const ABIResult = union(enum) {
    /// Returned directly in CPU registers (GPR or SIMD/SSE).
    direct,

    /// Returned indirectly in memory via a hidden return-slot pointer.
    indirect,

    /// Returned on the x87 floating-point register stack (long double).
    x87,

    /// Returned as complex on the x87 floating-point register stack.
    complex_x87,
};

/// Detailed metadata describing how a return type is handled by the ABI.
pub const ReturnInfo = struct {
    convention: ReturnConvention,
    indirect: bool,
    size: usize,
    alignment: usize,
    arch: std.Target.Cpu.Arch,
};
