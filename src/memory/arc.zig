//! First-class Objective-C ARC retain and release facade primitives.
//!
//! Provides ergonomic, type-preserving retain, release, and autorelease helpers
//! for Objective-C handles, domain wrapper structs, and raw pointers.

const std = @import("std");
const testing = std.testing;
const raw = @import("raw");
const wrapper = @import("internal").wrapper;

/// Converts any Objective-C handle (struct, pointer, optional) to raw `raw.id`.
pub inline fn toRawId(target: anytype) raw.id {
    const T = @TypeOf(target);
    if (comptime T == raw.id or T == *raw.objc_object) {
        return target;
    } else if (comptime T == raw.Class or T == *raw.objc_class) {
        return @ptrCast(target);
    } else if (comptime @typeInfo(T) == .optional) {
        if (target) |val| {
            return toRawId(val);
        }
        return null;
    } else if (comptime wrapper.isObjCWrapper(T)) {
        return @ptrCast(target.ptr);
    } else {
        @compileError("Cannot retain/release type '" ++ @typeName(T) ++ "': expected an Objective-C object handle or pointer.");
    }
}

/// Increments the reference count of an Objective-C object or wrapper handle.
///
/// Preserves the exact non-null or optional input type:
/// - Passing a non-null `*raw.objc_object` returns `*raw.objc_object` (no optional unwrapping).
/// - Passing a wrapper struct (e.g. `Device`, `Object`) returns the wrapper struct.
/// - Passing an optional handle `?T` returns `?T`.
pub inline fn retain(target: anytype) @TypeOf(target) {
    if (toRawId(target)) |raw_id| {
        _ = raw.compiler_runtime.objc_retain(raw_id);
    }
    return target;
}

/// Decrements the reference count of an Objective-C object or wrapper handle.
pub inline fn release(target: anytype) void {
    if (toRawId(target)) |raw_id| {
        raw.compiler_runtime.objc_release(raw_id);
    }
}

/// Adds an Objective-C object or wrapper handle to the current autorelease pool.
pub inline fn autorelease(target: anytype) @TypeOf(target) {
    if (toRawId(target)) |raw_id| {
        _ = raw.compiler_runtime.objc_autorelease(raw_id);
    }
    return target;
}

test "arc: retain and release raw non-null pointer preserves non-null type" {
    const cls = raw.runtime.objc_getClass("NSObject");
    try testing.expect(cls != null);
    const sel_alloc = raw.objc.sel_registerName("alloc");
    const sel_init = raw.objc.sel_registerName("init");

    const AllocFn = *const fn (raw.Class, raw.SEL) callconv(.c) raw.id;
    const InitFn = *const fn (raw.id, raw.SEL) callconv(.c) raw.id;
    const alloc_fn: AllocFn = @ptrCast(&raw.message.objc_msgSend);
    const init_fn: InitFn = @ptrCast(&raw.message.objc_msgSend);

    const raw_obj: *raw.objc_object = init_fn(alloc_fn(cls, sel_alloc), sel_init).?;
    defer release(raw_obj);

    // Retaining raw_obj must return exact non-null *raw.objc_object
    const retained = retain(raw_obj);
    try testing.expectEqual(@TypeOf(raw_obj), @TypeOf(retained));
    try testing.expectEqual(raw_obj, retained);
    release(retained);
}

test "arc: retain and release domain wrapper struct" {
    const cls = raw.runtime.objc_getClass("NSObject");
    const sel_alloc = raw.objc.sel_registerName("alloc");
    const sel_init = raw.objc.sel_registerName("init");

    const AllocFn = *const fn (raw.Class, raw.SEL) callconv(.c) raw.id;
    const InitFn = *const fn (raw.id, raw.SEL) callconv(.c) raw.id;
    const alloc_fn: AllocFn = @ptrCast(&raw.message.objc_msgSend);
    const init_fn: InitFn = @ptrCast(&raw.message.objc_msgSend);

    const raw_obj: *raw.objc_object = init_fn(alloc_fn(cls, sel_alloc), sel_init).?;

    const Device = struct {
        ptr: *raw.objc_object,
    };

    const dev = Device{ .ptr = raw_obj };
    defer release(dev);

    const retained_dev = retain(dev);
    try testing.expectEqual(dev.ptr, retained_dev.ptr);
    release(retained_dev);
}

test "arc: retain and release optional null is safe no-op" {
    const opt_raw: ?*raw.objc_object = null;
    const ret_opt = retain(opt_raw);
    try testing.expect(ret_opt == null);
    release(opt_raw);
}
