//! Weak reference storage tests (Weak).

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

var g_weak_dealloc_count: usize = 0;
var g_super_dealloc_fn: ?*const fn (objc.raw.id, objc.raw.SEL) callconv(.c) void = null;

fn customWeakDealloc(self_id: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) void {
    g_weak_dealloc_count += 1;
    if (g_super_dealloc_fn) |super_fn| {
        super_fn(self_id, sel_val);
    }
}

fn getOrCreateWeakTestClass() objc.Class {
    const class_name = "WeakLifecycleTestClass";
    if (objc.getClass(class_name)) |existing| {
        return existing;
    }

    const NSObject = objc.requireClass("NSObject");
    const cls = objc.allocateClassPair(NSObject, class_name).?;

    const nsobject_dealloc = NSObject.instanceMethod(objc.sel("dealloc")).?.getImplementation();
    g_super_dealloc_fn = @ptrCast(nsobject_dealloc.toRaw());

    const dealloc_sel = objc.sel("dealloc");
    _ = cls.addMethod(dealloc_sel, objc.Imp.fromRawNonNull(@ptrCast(&customWeakDealloc)), "v@:");

    objc.registerClassPair(cls);
    return cls;
}

test "Weak: in-place initialization and loadRetained while alive" {
    const cls = getOrCreateWeakTestClass();

    const raw_obj = cls.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    var strong = objc.Retained(objc.Object).adopt(raw_obj);
    defer strong.deinit();

    var weak: objc.Weak(objc.Object) = .{};
    weak.init(strong.borrow());
    defer weak.deinit();

    // While strong is alive, loadRetained returns a valid Retained(Object)
    if (weak.loadRetained()) |*loaded| {
        var mutable_loaded = loaded.*;
        defer mutable_loaded.deinit();
        try testing.expectEqual(strong.borrow().toRaw(), mutable_loaded.borrow().toRaw());
    } else {
        return error.ExpectedNonNullWeak;
    }
}

test "Weak: automatic zeroing when strong owner deallocates" {
    const cls = getOrCreateWeakTestClass();
    const initial_dealloc = g_weak_dealloc_count;

    var weak: objc.Weak(objc.Object) = .{};
    defer weak.deinit();

    {
        const raw_obj = cls.msgSend(objc.Object, "alloc", .{})
            .msgSend(objc.Object, "init", .{});
        var strong = objc.Retained(objc.Object).adopt(raw_obj);

        weak.init(strong.borrow());

        // Object is still alive
        if (weak.loadRetained()) |*loaded| {
            var m = loaded.*;
            m.deinit();
        } else return error.ExpectedNonNullWeak;
        try testing.expectEqual(initial_dealloc, g_weak_dealloc_count);

        strong.deinit();
        // Object has deallocated!
        try testing.expectEqual(initial_dealloc + 1, g_weak_dealloc_count);
    }

    // Weak slot must have been zeroed by the Objective-C runtime
    try testing.expect(weak.loadRetained() == null);
}

test "Weak: store and clear" {
    const cls = getOrCreateWeakTestClass();

    const raw_obj1 = cls.msgSend(objc.Object, "alloc", .{}).msgSend(objc.Object, "init", .{});
    var strong1 = objc.Retained(objc.Object).adopt(raw_obj1);
    defer strong1.deinit();

    const raw_obj2 = cls.msgSend(objc.Object, "alloc", .{}).msgSend(objc.Object, "init", .{});
    var strong2 = objc.Retained(objc.Object).adopt(raw_obj2);
    defer strong2.deinit();

    var weak: objc.Weak(objc.Object) = .{};
    weak.init(strong1.borrow());
    defer weak.deinit();

    if (weak.loadRetained()) |*loaded| {
        var m = loaded.*;
        defer m.deinit();
        try testing.expectEqual(strong1.borrow().toRaw(), m.borrow().toRaw());
    } else return error.ExpectedNonNull;

    // Store strong2 into weak
    weak.store(strong2.borrow());
    if (weak.loadRetained()) |*loaded| {
        var m = loaded.*;
        defer m.deinit();
        try testing.expectEqual(strong2.borrow().toRaw(), m.borrow().toRaw());
    } else return error.ExpectedNonNull;

    // Clear weak
    weak.clear();
    try testing.expect(weak.loadRetained() == null);
}

test "Weak: copyFrom and moveFrom" {
    const cls = getOrCreateWeakTestClass();

    const raw_obj = cls.msgSend(objc.Object, "alloc", .{}).msgSend(objc.Object, "init", .{});
    var strong = objc.Retained(objc.Object).adopt(raw_obj);
    defer strong.deinit();

    var weak1: objc.Weak(objc.Object) = .{};
    weak1.init(strong.borrow());
    defer weak1.deinit();

    var weak2: objc.Weak(objc.Object) = .{};
    defer weak2.deinit();

    // copyFrom: both point to strong
    weak2.copyFrom(&weak1);

    if (weak1.loadRetained()) |*l1| {
        var m1 = l1.*;
        defer m1.deinit();
        try testing.expectEqual(strong.borrow().toRaw(), m1.borrow().toRaw());
    } else return error.ExpectedNonNull;

    if (weak2.loadRetained()) |*l2| {
        var m2 = l2.*;
        defer m2.deinit();
        try testing.expectEqual(strong.borrow().toRaw(), m2.borrow().toRaw());
    } else return error.ExpectedNonNull;

    // moveFrom: weak3 takes weak2's reference, weak2 is cleared
    var weak3: objc.Weak(objc.Object) = .{};
    defer weak3.deinit();

    weak3.moveFrom(&weak2);

    try testing.expect(weak2.loadRetained() == null);
    if (weak3.loadRetained()) |*l3| {
        var m3 = l3.*;
        defer m3.deinit();
        try testing.expectEqual(strong.borrow().toRaw(), m3.borrow().toRaw());
    } else return error.ExpectedNonNull;
}

test "Weak: loadBorrowed with autorelease pool" {
    const cls = getOrCreateWeakTestClass();

    const raw_obj = cls.msgSend(objc.Object, "alloc", .{}).msgSend(objc.Object, "init", .{});
    var strong = objc.Retained(objc.Object).adopt(raw_obj);
    defer strong.deinit();

    var weak: objc.Weak(objc.Object) = .{};
    weak.init(strong.borrow());
    defer weak.deinit();

    var pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    if (weak.loadBorrowed()) |borrowed| {
        try testing.expectEqual(strong.borrow().toRaw(), borrowed.toRaw());
    } else return error.ExpectedNonNull;
}
