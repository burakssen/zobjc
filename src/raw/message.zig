//! Low-level Objective-C message dispatch primitives.
//!
//! Mirrors <objc/message.h>.
//! These functions represent generic dispatch entry points that must be cast to an
//! appropriate function pointer type before being called.

const availability = @import("availability.zig");

// --- Universal Messaging Primitives ---

/// Sends a message with a simple return value to an instance of a class.
///
/// Mirrors `objc_msgSend` from <objc/message.h>. Must be cast to the target signature before calling.
pub extern "c" fn objc_msgSend() void;

/// Sends a message with a simple return value to the superclass of an instance of a class.
///
/// Mirrors `objc_msgSendSuper` from <objc/message.h>. Must be cast to the target signature before calling.
pub extern "c" fn objc_msgSendSuper() void;

/// Directly invokes the implementation of a method.
///
/// Mirrors `method_invoke` from <objc/message.h>. Must be cast before calling.
pub extern "c" fn method_invoke() void;

/// Forwards a message as if the receiver did not respond to it.
///
/// Mirrors `_objc_msgForward` from <objc/message.h>.
pub extern "c" fn _objc_msgForward() void;

// --- Architecture-Guarded Messaging Primitives ---

/// Structure-returning message send to an instance.
///
/// Unavailable on ARM64. Mirrors `objc_msgSend_stret` from <objc/message.h>.
pub const objc_msgSend_stret = if (availability.has_msgSendStret)
    struct {
        pub extern "c" fn objc_msgSend_stret() void;
    }.objc_msgSend_stret
else
    @compileError("objc_msgSend_stret is unavailable on this architecture (ARM64)");

/// Structure-returning message send to a superclass.
///
/// Unavailable on ARM64. Mirrors `objc_msgSendSuper_stret` from <objc/message.h>.
pub const objc_msgSendSuper_stret = if (availability.has_msgSendStret)
    struct {
        pub extern "c" fn objc_msgSendSuper_stret() void;
    }.objc_msgSendSuper_stret
else
    @compileError("objc_msgSendSuper_stret is unavailable on this architecture (ARM64)");

/// Structure-returning direct method invocation.
///
/// Unavailable on ARM64. Mirrors `method_invoke_stret` from <objc/message.h>.
pub const method_invoke_stret = if (availability.has_msgSendStret)
    struct {
        pub extern "c" fn method_invoke_stret() void;
    }.method_invoke_stret
else
    @compileError("method_invoke_stret is unavailable on this architecture (ARM64)");

/// Structure-returning message forwarding primitive.
///
/// Unavailable on ARM64. Mirrors `_objc_msgForward_stret` from <objc/message.h>.
pub const _objc_msgForward_stret = if (availability.has_msgSendStret)
    struct {
        pub extern "c" fn _objc_msgForward_stret() void;
    }._objc_msgForward_stret
else
    @compileError("_objc_msgForward_stret is unavailable on this architecture (ARM64)");

/// Floating-point-returning message dispatch (x86_64 / i386).
///
/// Mirrors `objc_msgSend_fpret` from <objc/message.h>.
pub const objc_msgSend_fpret = if (availability.has_msgSendFpret)
    struct {
        pub extern "c" fn objc_msgSend_fpret() void;
    }.objc_msgSend_fpret
else
    @compileError("objc_msgSend_fpret is unavailable on this architecture");

/// Complex long double floating-point-returning message dispatch (x86_64).
///
/// Mirrors `objc_msgSend_fp2ret` from <objc/message.h>.
pub const objc_msgSend_fp2ret = if (availability.has_msgSendFp2ret)
    struct {
        pub extern "c" fn objc_msgSend_fp2ret() void;
    }.objc_msgSend_fp2ret
else
    @compileError("objc_msgSend_fp2ret is unavailable on this architecture");
