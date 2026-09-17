//! Low-level Objective-C message dispatch primitives.
//!
//! Mirrors <objc/message.h>.
//! These functions represent generic dispatch entry points that must be cast to an
//! appropriate function pointer type before being called.

const availability = @import("availability.zig");
const std = @import("std");
const testing = std.testing;
const raw = @import("zobjc").raw;

// --- Universal Messaging Primitives ---

/// Sends a message with a simple return value to an instance of a class.
///
/// Mirrors `objc_msgSend` from <objc/message.h>. Must be cast to the target signature before calling.
pub extern "c" fn objc_msgSend() void;

/// Sends a message with a simple return value to the superclass of an instance of a class.
///
/// Mirrors `objc_msgSendSuper` from <objc/message.h>. Must be cast to the target signature before calling.
pub extern "c" fn objc_msgSendSuper() void;

/// Sends a message to the superclass using Super2 semantics (starts lookup at current_class->superclass).
///
/// Exported by Apple's libobjc. Must be cast to the target signature before calling.
pub extern "c" fn objc_msgSendSuper2() void;

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

/// Structure-returning message send to a superclass using Super2 semantics.
///
/// Unavailable on ARM64. Exported by Apple's libobjc on x86_64.
pub const objc_msgSendSuper2_stret = if (availability.has_msgSendStret)
    struct {
        pub extern "c" fn objc_msgSendSuper2_stret() void;
    }.objc_msgSendSuper2_stret
else
    @compileError("objc_msgSendSuper2_stret is unavailable on this architecture (ARM64)");

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

test "raw.message: direct invocation of objc_msgSend" {
    const cls = raw.runtime.objc_getClass("NSObject");
    try testing.expect(cls != null);

    const sel_alloc = raw.objc.sel_registerName("alloc");
    const AllocFn = *const fn (raw.Class, raw.SEL) callconv(.c) raw.id;
    const alloc_fn: AllocFn = @ptrCast(&raw.message.objc_msgSend);
    const uninit_obj = alloc_fn(cls, sel_alloc);
    try testing.expect(uninit_obj != null);

    const sel_init = raw.objc.sel_registerName("init");
    const InitFn = *const fn (raw.id, raw.SEL) callconv(.c) raw.id;
    const init_fn: InitFn = @ptrCast(&raw.message.objc_msgSend);
    const obj = init_fn(uninit_obj, sel_init);
    try testing.expect(obj != null);

    const sel_class = raw.objc.sel_registerName("class");
    const ClassFn = *const fn (raw.id, raw.SEL) callconv(.c) raw.Class;
    const class_fn: ClassFn = @ptrCast(&raw.message.objc_msgSend);
    const result_cls = class_fn(obj, sel_class);
    try testing.expectEqual(cls, result_cls);

    const sel_release = raw.objc.sel_registerName("release");
    const ReleaseFn = *const fn (raw.id, raw.SEL) callconv(.c) void;
    const release_fn: ReleaseFn = @ptrCast(&raw.message.objc_msgSend);
    release_fn(obj, sel_release);
}

test "raw.message: direct invocation of objc_msgSendSuper" {
    const cls = raw.runtime.objc_getClass("NSObject");
    try testing.expect(cls != null);

    const sel_alloc = raw.objc.sel_registerName("alloc");
    const sel_init = raw.objc.sel_registerName("init");
    const sel_release = raw.objc.sel_registerName("release");

    const AllocFn = *const fn (raw.Class, raw.SEL) callconv(.c) raw.id;
    const InitFn = *const fn (raw.id, raw.SEL) callconv(.c) raw.id;
    const ReleaseFn = *const fn (raw.id, raw.SEL) callconv(.c) void;

    const alloc_fn: AllocFn = @ptrCast(&raw.message.objc_msgSend);
    const init_fn: InitFn = @ptrCast(&raw.message.objc_msgSend);
    const release_fn: ReleaseFn = @ptrCast(&raw.message.objc_msgSend);

    const obj = init_fn(alloc_fn(cls, sel_alloc), sel_init);
    try testing.expect(obj != null);
    defer release_fn(obj, sel_release);

    var super: raw.objc_super = .{
        .receiver = obj,
        .super_class = cls,
    };

    const SuperClassFn = *const fn (*raw.objc_super, raw.SEL) callconv(.c) raw.Class;
    const super_class_fn: SuperClassFn = @ptrCast(&raw.message.objc_msgSendSuper);
    const sel_class = raw.objc.sel_registerName("class");
    const result_cls = super_class_fn(&super, sel_class);
    try testing.expectEqual(cls, result_cls);
}

test "raw.message: dispatch symbol references" {
    _ = &raw.message.objc_msgSend;
    _ = &raw.message.objc_msgSendSuper;
    _ = &raw.message.method_invoke;
    _ = &raw.message._objc_msgForward;

    if (comptime raw.availability.has_msgSendStret) {
        _ = &raw.message.objc_msgSend_stret;
        _ = &raw.message.objc_msgSendSuper_stret;
        _ = &raw.message.method_invoke_stret;
        _ = &raw.message._objc_msgForward_stret;
    }
}
