//! Tests for raw compiler-runtime and ARC entry points.

const std = @import("std");
const testing = std.testing;
const raw = @import("objc").raw;

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

    // Retain increases refcount
    const retained = raw.compiler_runtime.objc_retain(obj);
    try testing.expectEqual(obj, retained);

    // Release once
    raw.compiler_runtime.objc_release(retained);

    // Release final
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

    // Pop the pool, which releases all autoreleased objects in this scope
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

fn dummyInvoke(_: *anyopaque) callconv(.c) void {}
fn dummyCopy(_: *anyopaque, _: *anyopaque) callconv(.c) void {}
fn dummyDispose(_: *anyopaque) callconv(.c) void {}

test "raw.blocks: block copy and release" {
    const desc = raw.blocks.BlockDescriptor{
        .reserved = 0,
        .size = @sizeOf(raw.blocks.BlockLiteral),
        .copy_helper = &dummyCopy,
        .dispose_helper = &dummyDispose,
        .signature = "v8@?0",
    };

    var flags: raw.blocks.BlockFlags = .{
        .copy_dispose = true,
        .signature = true,
    };

    var literal = raw.blocks.BlockLiteral{
        .isa = raw.blocks._NSConcreteStackBlock,
        .flags = @as(*const c_int, @ptrCast(&flags)).*,
        .reserved = 0,
        .invoke = &dummyInvoke,
        .descriptor = &desc,
    };

    const copied = raw.blocks._Block_copy(@ptrCast(&literal));
    try testing.expect(copied != null);
    raw.blocks._Block_release(copied.?);
}
