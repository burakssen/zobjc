//! Objective-C compiler-runtime and ARC primitives.
//!
//! These entry points are used by Clang/ARC code generation and provide low-level
//! reference counting, weak-reference management, and autorelease pool operations.

const types = @import("types.zig");
const std = @import("std");
const testing = std.testing;
const raw = @import("zobjc").raw;
const id = types.id;
const Class = types.Class;

// --- Reference Counting ---

/// Increments the retain count for an object.
pub extern "c" fn objc_retain(obj: id) id;

/// Decrements the retain count for an object.
pub extern "c" fn objc_release(obj: id) void;

/// Adds an object to the current autorelease pool.
pub extern "c" fn objc_autorelease(obj: id) id;

/// Retains an object and adds it to the current autorelease pool.
pub extern "c" fn objc_retainAutorelease(obj: id) id;

/// Sets a strong pointer to a new value, releasing the previous value.
pub extern "c" fn objc_storeStrong(location: *id, obj: id) void;

// --- Autorelease Pools ---

/// Pushes a new autorelease pool context. Returns an opaque token.
pub extern "c" fn objc_autoreleasePoolPush() ?*anyopaque;

/// Pops and drains an autorelease pool given its token.
pub extern "c" fn objc_autoreleasePoolPop(token: ?*anyopaque) void;

// --- Weak References ---

/// Initializes a weak pointer variable to a specified object.
pub extern "c" fn objc_initWeak(location: *id, obj: id) id;

/// Destroys a weak pointer variable.
pub extern "c" fn objc_destroyWeak(location: *id) void;

/// Loads and returns the object referenced by a weak pointer, or nil if deallocated.
pub extern "c" fn objc_loadWeak(location: *id) id;

/// Loads and retains the object referenced by a weak pointer.
pub extern "c" fn objc_loadWeakRetained(location: *id) id;

/// Stores an object into a weak pointer variable.
pub extern "c" fn objc_storeWeak(location: *id, obj: id) id;

/// Copies a weak pointer from src to dst.
pub extern "c" fn objc_copyWeak(dst: *id, src: *id) void;

/// Moves a weak pointer from src to dst.
pub extern "c" fn objc_moveWeak(dst: *id, src: *id) void;

// --- Exception Handling (<objc/objc-exception.h>) ---

pub const objc_uncaught_exception_handler = ?*const fn (id) callconv(.c) void;
pub const objc_exception_preprocessor = ?*const fn (id) callconv(.c) id;
pub const objc_exception_matcher = ?*const fn (Class, id) callconv(.c) c_int;

/// Throws an Objective-C exception.
pub extern "c" fn objc_exception_throw(exception: id) noreturn;

/// Rethrows the currently caught exception.
pub extern "c" fn objc_exception_rethrow() noreturn;

/// Begins an Objective-C catch block.
pub extern "c" fn objc_begin_catch(exception_object: ?*anyopaque) id;

/// Ends an Objective-C catch block.
pub extern "c" fn objc_end_catch() void;

/// Terminates the process following an unhandled exception.
pub extern "c" fn objc_terminate() noreturn;

/// Sets the uncaught exception handler.
pub extern "c" fn objc_setUncaughtExceptionHandler(fn_ptr: objc_uncaught_exception_handler) objc_uncaught_exception_handler;

/// Sets the exception preprocessor.
pub extern "c" fn objc_setExceptionPreprocessor(fn_ptr: objc_exception_preprocessor) objc_exception_preprocessor;

/// Sets the exception matcher.
pub extern "c" fn objc_setExceptionMatcher(fn_ptr: objc_exception_matcher) objc_exception_matcher;

pub const objc_exception_handler = ?*const fn (id, ?*anyopaque) callconv(.c) void;

/// Adds an exception handler to the thread exception list (macOS only).
pub extern "c" fn objc_addExceptionHandler(fn_ptr: objc_exception_handler, context: ?*anyopaque) usize;

/// Removes an exception handler from the thread exception list (macOS only).
pub extern "c" fn objc_removeExceptionHandler(token: usize) void;

test "raw.compiler_runtime: retain and release lifecycle" {
    const cls = raw.runtime.objc_getClass("NSObject");
    try testing.expect(cls != null);

    const sel_alloc = raw.objc.sel_registerName("alloc");
    const sel_init = raw.objc.sel_registerName("init");

    const AllocFn = *const fn (raw.Class, raw.SEL) callconv(.c) raw.id;
    const InitFn = *const fn (raw.id, raw.SEL) callconv(.c) raw.id;

    const alloc_fn: AllocFn = @ptrCast(&raw.message.objc_msgSend);
    const init_fn: InitFn = @ptrCast(&raw.message.objc_msgSend);

    const obj = init_fn(alloc_fn(cls, sel_alloc), sel_init);
    try testing.expect(obj != null);

    const retained = raw.compiler_runtime.objc_retain(obj);
    try testing.expectEqual(obj, retained);

    raw.compiler_runtime.objc_release(retained);
    raw.compiler_runtime.objc_release(obj);
}

test "raw.compiler_runtime: autorelease pool lifecycle" {
    const pool = raw.compiler_runtime.objc_autoreleasePoolPush();
    try testing.expect(pool != null);

    const cls = raw.runtime.objc_getClass("NSObject");
    const sel_alloc = raw.objc.sel_registerName("alloc");
    const sel_init = raw.objc.sel_registerName("init");

    const AllocFn = *const fn (raw.Class, raw.SEL) callconv(.c) raw.id;
    const InitFn = *const fn (raw.id, raw.SEL) callconv(.c) raw.id;

    const alloc_fn: AllocFn = @ptrCast(&raw.message.objc_msgSend);
    const init_fn: InitFn = @ptrCast(&raw.message.objc_msgSend);

    const obj = init_fn(alloc_fn(cls, sel_alloc), sel_init);
    try testing.expect(obj != null);

    _ = raw.compiler_runtime.objc_autorelease(obj);
    raw.compiler_runtime.objc_autoreleasePoolPop(pool);
}

test "raw.compiler_runtime: weak pointer operations" {
    const cls = raw.runtime.objc_getClass("NSObject");
    const sel_alloc = raw.objc.sel_registerName("alloc");
    const sel_init = raw.objc.sel_registerName("init");

    const AllocFn = *const fn (raw.Class, raw.SEL) callconv(.c) raw.id;
    const InitFn = *const fn (raw.id, raw.SEL) callconv(.c) raw.id;

    const alloc_fn: AllocFn = @ptrCast(&raw.message.objc_msgSend);
    const init_fn: InitFn = @ptrCast(&raw.message.objc_msgSend);

    const obj = init_fn(alloc_fn(cls, sel_alloc), sel_init);
    try testing.expect(obj != null);
    defer raw.compiler_runtime.objc_release(obj);

    var weak_location: raw.id = null;
    const init_result = raw.compiler_runtime.objc_initWeak(&weak_location, obj);
    try testing.expectEqual(obj, init_result);

    const loaded = raw.compiler_runtime.objc_loadWeak(&weak_location);
    try testing.expectEqual(obj, loaded);

    _ = raw.compiler_runtime.objc_storeWeak(&weak_location, null);
    try testing.expect(weak_location == null);

    raw.compiler_runtime.objc_destroyWeak(&weak_location);
}
