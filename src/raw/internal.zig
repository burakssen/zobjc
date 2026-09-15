//! Private and unstable Apple Objective-C runtime SPI.
//!
//! WARNING: Symbols in this module are not part of Apple's public runtime API contract.
//! They may change, break, or disappear without notice between OS releases.
//!
//! POLICIES:
//! - No SemVer guarantees are provided for anything in `raw.internal`.
//! - Stable high-level zobjc facilities NEVER depend on this module.
//! - Symbols are resolved dynamically via `dlsym` to prevent binary linkage failures.

const std = @import("std");

/// Signature of the historical Apple private forwarding handler hook.
pub const SetForwardHandlerFn = *const fn (
    fwd: ?*const anyopaque,
    fwd_stret: ?*const anyopaque,
) callconv(.c) void;

// Darwin dlfcn.h: #define RTLD_DEFAULT ((void *) -2)
const RTLD_DEFAULT: ?*anyopaque = @ptrFromInt(@as(usize, @bitCast(@as(isize, -2))));

/// Dynamically resolves the private `objc_setForwardHandler` symbol if exported by the host runtime.
pub fn getSetForwardHandler() ?SetForwardHandlerFn {
    const sym = std.c.dlsym(RTLD_DEFAULT, "objc_setForwardHandler");
    if (sym) |s| return @ptrCast(@alignCast(s));
    return null;
}

test {
    std.testing.refAllDecls(@This());
}
