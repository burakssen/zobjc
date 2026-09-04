//! Autorelease pool tests (AutoreleasePool).

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

var g_pool_dealloc_count: usize = 0;
var g_super_dealloc_fn: ?*const fn (objc.raw.id, objc.raw.SEL) callconv(.c) void = null;

fn customPoolDealloc(self_id: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) void {
    g_pool_dealloc_count += 1;
    if (g_super_dealloc_fn) |super_fn| {
        super_fn(self_id, sel_val);
    }
}

fn getOrCreatePoolTestClass() objc.Class {
    const class_name = "AutoreleasePoolLifecycleTestClass";
    if (objc.getClass(class_name)) |existing| {
        return existing;
    }

    const NSObject = objc.requireClass("NSObject");
    const cls = objc.allocateClassPair(NSObject, class_name).?;

    const nsobject_dealloc = NSObject.instanceMethod(objc.sel("dealloc")).?.getImplementation();
    g_super_dealloc_fn = @ptrCast(nsobject_dealloc.toRaw());

    const dealloc_sel = objc.sel("dealloc");
    _ = cls.addMethod(dealloc_sel, objc.Imp.fromRawNonNull(@ptrCast(&customPoolDealloc)), "v@:");

    objc.registerClassPair(cls);
    return cls;
}

test "AutoreleasePool: basic creation and idempotent drain" {
    var pool = objc.AutoreleasePool.init();
    try testing.expect(pool.token != null);

    pool.drain();
    try testing.expect(pool.token == null);

    // Multiple drain is safe no-op
    pool.drain();
    try testing.expect(pool.token == null);

    // deinit is safe no-op after drain
    pool.deinit();
    try testing.expect(pool.token == null);
}

test "AutoreleasePool: drains autoreleased object" {
    const cls = getOrCreatePoolTestClass();
    const initial_count = g_pool_dealloc_count;

    var pool = objc.AutoreleasePool.init();

    const obj = cls.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    _ = obj.msgSend(objc.Object, "autorelease", .{});

    // Object must not have deallocated yet
    try testing.expectEqual(initial_count, g_pool_dealloc_count);

    // Drain the pool
    pool.drain();

    // Pool pop should have caused the object to deallocate
    try testing.expectEqual(initial_count + 1, g_pool_dealloc_count);
}

test "AutoreleasePool: nested pools follow LIFO drain ordering" {
    const cls = getOrCreatePoolTestClass();
    const initial_count = g_pool_dealloc_count;

    var outer_pool = objc.AutoreleasePool.init();
    defer outer_pool.deinit();

    const outer_obj = cls.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    _ = outer_obj.msgSend(objc.Object, "autorelease", .{});

    {
        var inner_pool = objc.AutoreleasePool.init();

        const inner_obj = cls.msgSend(objc.Object, "alloc", .{})
            .msgSend(objc.Object, "init", .{});
        _ = inner_obj.msgSend(objc.Object, "autorelease", .{});

        try testing.expectEqual(initial_count, g_pool_dealloc_count);

        inner_pool.drain();
        // Inner object deallocated, outer object still alive
        try testing.expectEqual(initial_count + 1, g_pool_dealloc_count);
    }

    outer_pool.drain();
    // Now outer object deallocated as well
    try testing.expectEqual(initial_count + 2, g_pool_dealloc_count);
}
