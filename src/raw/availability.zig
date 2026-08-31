//! Compile-time symbol availability queries.
//!
//! Encodes Apple platform and architecture symbol availability facts as documented
//! in <objc/message.h> and <objc/runtime.h>.

const builtin = @import("builtin");

// ponytail: Use pure comptime boolean predicates instead of runtime checks.

/// Apple <objc/message.h>: Struct-returning entry points (objc_msgSend_stret,
/// objc_msgSendSuper_stret, method_invoke_stret, _objc_msgForward_stret) are unavailable on ARM64.
pub const has_msgSendStret = builtin.cpu.arch != .aarch64;

/// Apple <objc/message.h>: Floating-point return entry point (objc_msgSend_fpret)
/// is used on x86_64 (for long double) and i386 (for float, double, long double).
pub const has_msgSendFpret = switch (builtin.cpu.arch) {
    .x86_64, .x86 => true,
    else => false,
};

/// Apple <objc/message.h>: Complex long double floating-point return (objc_msgSend_fp2ret)
/// is used on x86_64 only.
pub const has_msgSendFp2ret = builtin.cpu.arch == .x86_64;
