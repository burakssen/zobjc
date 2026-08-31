//! Tests for <objc/runtime.h> functions exposed through raw.runtime.

const std = @import("std");
const testing = std.testing;
const raw = @import("objc").raw;

test "raw.runtime: class lookup and inspection" {
    const cls = raw.runtime.objc_getClass("NSObject");
    try testing.expect(cls != null);

    const name = raw.runtime.class_getName(cls);
    try testing.expectEqualStrings("NSObject", std.mem.span(name));

    // NSObject has no superclass
    const super_cls = raw.runtime.class_getSuperclass(cls);
    try testing.expect(super_cls == null);

    // NSObject is not a metaclass
    try testing.expect(!raw.boolResult(raw.runtime.class_isMetaClass(cls)));

    // MetaClass lookup
    const meta_cls = raw.runtime.objc_getMetaClass("NSObject");
    try testing.expect(meta_cls != null);
    try testing.expect(raw.boolResult(raw.runtime.class_isMetaClass(meta_cls)));

    // Instance size
    const size = raw.runtime.class_getInstanceSize(cls);
    try testing.expect(size >= @sizeOf(usize));

    // Selector response
    const sel_init = raw.objc.sel_registerName("init");
    try testing.expect(raw.boolResult(raw.runtime.class_respondsToSelector(cls, sel_init)));
}

test "raw.runtime: dynamic class creation, method/ivar addition, and disposal" {
    const super_cls = raw.runtime.objc_getClass("NSObject");
    try testing.expect(super_cls != null);

    const unique_name = "RawTestClass_DynamicPair";
    const new_cls = raw.runtime.objc_allocateClassPair(super_cls, unique_name, 0);
    try testing.expect(new_cls != null);

    // Add an ivar of pointer size
    const ivar_added = raw.runtime.class_addIvar(
        new_cls,
        "_testIvar",
        @sizeOf(usize),
        @alignOf(usize),
        "^v",
    );
    try testing.expect(raw.boolResult(ivar_added));

    // Add a method
    const dummy_imp: raw.IMP = @ptrCast(&struct {
        fn dummy(self: raw.id, op: raw.SEL) callconv(.c) usize {
            _ = self;
            _ = op;
            return 42;
        }
    }.dummy);

    const sel_test = raw.objc.sel_registerName("rawTestMethod");
    const method_added = raw.runtime.class_addMethod(
        new_cls,
        sel_test,
        dummy_imp,
        "Q@:",
    );
    try testing.expect(raw.boolResult(method_added));

    // Register class pair
    raw.runtime.objc_registerClassPair(new_cls);

    // Verify lookup succeeds
    const registered = raw.runtime.objc_getClass(unique_name);
    try testing.expectEqual(new_cls, registered);

    // Inspect the added ivar
    const ivar = raw.runtime.class_getInstanceVariable(new_cls, "_testIvar");
    try testing.expect(ivar != null);
    const ivar_name = raw.runtime.ivar_getName(ivar);
    try testing.expect(ivar_name != null);
    try testing.expectEqualStrings("_testIvar", std.mem.span(ivar_name.?));

    // Inspect the added method
    const method = raw.runtime.class_getInstanceMethod(new_cls, sel_test);
    try testing.expect(method != null);
    try testing.expectEqual(sel_test, raw.runtime.method_getName(method));

    // Dispose class pair
    raw.runtime.objc_disposeClassPair(new_cls);
}

test "raw.runtime: protocol inspection" {
    const proto = raw.runtime.objc_getProtocol("NSObject");
    try testing.expect(proto != null);

    const name = raw.runtime.protocol_getName(proto);
    try testing.expectEqualStrings("NSObject", std.mem.span(name));

    const cls = raw.runtime.objc_getClass("NSObject");
    try testing.expect(cls != null);
    try testing.expect(raw.boolResult(raw.runtime.class_conformsToProtocol(cls, proto)));
}

test "raw.runtime: associated objects" {
    const cls = raw.runtime.objc_getClass("NSObject");
    try testing.expect(cls != null);

    // Allocate an instance using msgSend
    const sel_alloc = raw.objc.sel_registerName("alloc");
    const sel_init = raw.objc.sel_registerName("init");

    const AllocFn = *const fn (raw.Class, raw.SEL) callconv(.c) raw.id;
    const InitFn = *const fn (raw.id, raw.SEL) callconv(.c) raw.id;

    const alloc_fn: AllocFn = @ptrCast(&raw.message.objc_msgSend);
    const init_fn: InitFn = @ptrCast(&raw.message.objc_msgSend);

    const obj = init_fn(alloc_fn(cls, sel_alloc), sel_init);
    try testing.expect(obj != null);
    defer {
        const sel_release = raw.objc.sel_registerName("release");
        const ReleaseFn = *const fn (raw.id, raw.SEL) callconv(.c) void;
        const release_fn: ReleaseFn = @ptrCast(&raw.message.objc_msgSend);
        release_fn(obj, sel_release);
    }

    var assoc_key: u8 = 0;
    const assoc_val: usize = 0x12345678;

    raw.runtime.objc_setAssociatedObject(
        obj,
        &assoc_key,
        @ptrFromInt(assoc_val),
        raw.runtime.OBJC_ASSOCIATION_ASSIGN,
    );

    const retrieved = raw.runtime.objc_getAssociatedObject(obj, &assoc_key);
    try testing.expectEqual(assoc_val, @intFromPtr(retrieved));

    // Remove association
    raw.runtime.objc_setAssociatedObject(obj, &assoc_key, null, raw.runtime.OBJC_ASSOCIATION_ASSIGN);
    try testing.expect(raw.runtime.objc_getAssociatedObject(obj, &assoc_key) == null);
}
