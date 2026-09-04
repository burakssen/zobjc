//! Strong reference ownership tests (Retained).

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

var g_dealloc_count: usize = 0;
var g_super_dealloc_fn: ?*const fn (objc.raw.id, objc.raw.SEL) callconv(.c) void = null;

fn customDealloc(self_id: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) void {
    g_dealloc_count += 1;
    if (g_super_dealloc_fn) |super_fn| {
        super_fn(self_id, sel_val);
    }
}

fn getOrCreateTestClass() objc.Class {
    const class_name = "RetainedLifecycleTestClass";
    if (objc.getClass(class_name)) |existing| {
        return existing;
    }

    const NSObject = objc.requireClass("NSObject");
    const cls = objc.allocateClassPair(NSObject, class_name).?;

    // Cache super dealloc IMP
    const nsobject_dealloc = NSObject.instanceMethod(objc.sel("dealloc")).?.getImplementation();
    g_super_dealloc_fn = @ptrCast(nsobject_dealloc.toRaw());

    const dealloc_sel = objc.sel("dealloc");
    _ = cls.addMethod(dealloc_sel, objc.Imp.fromRawNonNull(@ptrCast(&customDealloc)), "v@:");

    objc.registerClassPair(cls);
    return cls;
}

test "Retained: compile-time retainable traits" {
    const traits = objc.memory.traits;
    try testing.expect(traits.isRetainable(objc.Object));
    try testing.expect(!traits.isRetainable(objc.Class));
    try testing.expect(!traits.isRetainable(objc.Method));
    try testing.expect(!traits.isRetainable(objc.Ivar));
    try testing.expect(!traits.isRetainable(objc.Property));
    try testing.expect(!traits.isRetainable(objc.Protocol));
    try testing.expect(!traits.isRetainable(objc.Selector));
    try testing.expect(!traits.isRetainable(i32));
    try testing.expect(!traits.isRetainable(*anyopaque));
}

test "Retained: adopt takes ownership and deinit releases" {
    const cls = getOrCreateTestClass();
    const initial_count = g_dealloc_count;

    {
        const raw_obj = cls.msgSend(objc.Object, "alloc", .{})
            .msgSend(objc.Object, "init", .{});

        var retained = objc.Retained(objc.Object).adopt(raw_obj);
        try testing.expectEqual(initial_count, g_dealloc_count);

        // Borrow produces valid Object handle
        const borrowed = retained.borrow();
        try testing.expectEqual(raw_obj.toRaw(), borrowed.toRaw());

        retained.deinit();
        try testing.expectEqual(initial_count + 1, g_dealloc_count);

        // Subsequent deinit is idempotent
        retained.deinit();
        try testing.expectEqual(initial_count + 1, g_dealloc_count);
    }
}

test "Retained: retain increments retain count" {
    const cls = getOrCreateTestClass();
    const initial_count = g_dealloc_count;

    {
        const raw_obj = cls.msgSend(objc.Object, "alloc", .{})
            .msgSend(objc.Object, "init", .{});

        var r1 = objc.Retained(objc.Object).adopt(raw_obj);
        var r2 = objc.Retained(objc.Object).retain(r1.borrow());

        try testing.expectEqual(initial_count, g_dealloc_count);

        // Deinit r1, object should still be alive because r2 holds a reference
        r1.deinit();
        try testing.expectEqual(initial_count, g_dealloc_count);

        // Deinit r2, now object should be deallocated
        r2.deinit();
        try testing.expectEqual(initial_count + 1, g_dealloc_count);
    }
}

test "Retained: clone increments retain count" {
    const cls = getOrCreateTestClass();
    const initial_count = g_dealloc_count;

    {
        const raw_obj = cls.msgSend(objc.Object, "alloc", .{})
            .msgSend(objc.Object, "init", .{});

        var r1 = objc.Retained(objc.Object).adopt(raw_obj);
        var r2 = r1.clone();

        try testing.expectEqual(initial_count, g_dealloc_count);

        // Deinit r1: object still alive
        r1.deinit();
        try testing.expectEqual(initial_count, g_dealloc_count);

        // Deinit r2: object deallocated
        r2.deinit();
        try testing.expectEqual(initial_count + 1, g_dealloc_count);
    }
}

test "Retained: intoUnmanaged relinquishes ownership without releasing" {
    const cls = getOrCreateTestClass();
    const initial_count = g_dealloc_count;

    const raw_obj = cls.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});

    var retained = objc.Retained(objc.Object).adopt(raw_obj);
    const unmanaged = retained.intoUnmanaged();

    // Calling deinit on consumed retained must not release
    retained.deinit();
    try testing.expectEqual(initial_count, g_dealloc_count);

    // Manually release the unmanaged object
    _ = objc.raw.compiler_runtime.objc_release(unmanaged.toRaw());
    try testing.expectEqual(initial_count + 1, g_dealloc_count);
}

test "Retained: retainOptional and adoptOptional" {
    const cls = getOrCreateTestClass();
    const initial_count = g_dealloc_count;

    // With null
    const null_opt = objc.Retained(objc.Object).adoptOptional(null);
    try testing.expect(null_opt == null);

    const null_retained_opt = objc.Retained(objc.Object).retainOptional(null);
    try testing.expect(null_retained_opt == null);

    // With non-null
    const raw_obj = cls.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});

    if (objc.Retained(objc.Object).adoptOptional(raw_obj)) |*r| {
        var mutable_r = r.*;
        defer mutable_r.deinit();
        try testing.expectEqual(raw_obj.toRaw(), mutable_r.borrow().toRaw());
    } else {
        return error.UnexpectedNull;
    }

    try testing.expectEqual(initial_count + 1, g_dealloc_count);
}

test "Retained: createInstanceRetained on Class" {
    const cls = getOrCreateTestClass();
    const initial_count = g_dealloc_count;

    {
        var retained = cls.createInstanceRetained(0).?;
        _ = retained.borrow().msgSend(objc.Object, "init", .{});
        try testing.expectEqual(initial_count, g_dealloc_count);
        retained.deinit();
        try testing.expectEqual(initial_count + 1, g_dealloc_count);
    }
}
