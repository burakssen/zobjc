//! Tests for raw message dispatch functions in <objc/message.h>.

const std = @import("std");
const testing = std.testing;
const raw = @import("objc").raw;

test "raw.message: direct invocation of objc_msgSend" {
    const cls = raw.runtime.objc_getClass("NSObject");
    try testing.expect(cls != null);

    // [NSObject alloc]
    const sel_alloc = raw.objc.sel_registerName("alloc");
    const AllocFn = *const fn (raw.Class, raw.SEL) callconv(.c) raw.id;
    const alloc_fn: AllocFn = @ptrCast(&raw.message.objc_msgSend);
    const uninit_obj = alloc_fn(cls, sel_alloc);
    try testing.expect(uninit_obj != null);

    // [obj init]
    const sel_init = raw.objc.sel_registerName("init");
    const InitFn = *const fn (raw.id, raw.SEL) callconv(.c) raw.id;
    const init_fn: InitFn = @ptrCast(&raw.message.objc_msgSend);
    const obj = init_fn(uninit_obj, sel_init);
    try testing.expect(obj != null);

    // [obj class]
    const sel_class = raw.objc.sel_registerName("class");
    const ClassFn = *const fn (raw.id, raw.SEL) callconv(.c) raw.Class;
    const class_fn: ClassFn = @ptrCast(&raw.message.objc_msgSend);
    const result_cls = class_fn(obj, sel_class);
    try testing.expectEqual(cls, result_cls);

    // [obj release]
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
