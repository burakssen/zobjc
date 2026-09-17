//! Scoped autorelease pool token management.
//!
//! Autorelease pools are thread-local and must be created and popped in strict
//! LIFO (stack) order.

const std = @import("std");
const testing = std.testing;
const objc = @import("zobjc");
const raw = @import("raw");

/// A scoped autorelease pool that pops its boundary on `deinit()`.
///
/// AutoreleasePool is an owning value and MUST NOT be copied.
pub const AutoreleasePool = struct {
    token: ?*anyopaque,

    /// Pushes a new autorelease pool context.
    pub fn init() AutoreleasePool {
        return .{
            .token = raw.compiler_runtime.objc_autoreleasePoolPush(),
        };
    }

    /// Drains and pops the autorelease pool (alias for deinit).
    pub inline fn drain(self: *AutoreleasePool) void {
        self.deinit();
    }

    /// Pops the autorelease pool token via `objc_autoreleasePoolPop`.
    /// Idempotent: safe to call multiple times.
    pub fn deinit(self: *AutoreleasePool) void {
        if (self.token) |tok| {
            raw.compiler_runtime.objc_autoreleasePoolPop(tok);
            self.token = null;
        }
    }
};

var g_pool_dealloc_count: usize = 0;
var g_pool_super_dealloc_fn: ?*const fn (objc.raw.id, objc.raw.SEL) callconv(.c) void = null;

fn customPoolDealloc(self_id: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) void {
    g_pool_dealloc_count += 1;
    if (g_pool_super_dealloc_fn) |super_fn| super_fn(self_id, sel_val);
}

fn getOrCreatePoolTestClass() objc.Class {
    const class_name = "AutoreleasePoolLifecycleTestClass";
    if (objc.getClass(class_name)) |existing| return existing;

    const NSObject = objc.requireClass("NSObject");
    const cls = objc.allocateClassPair(NSObject, class_name).?;
    g_pool_super_dealloc_fn = @ptrCast(NSObject.instanceMethod(objc.sel("dealloc")).?.implementation().toRaw());
    _ = cls.addMethod(objc.sel("dealloc"), objc.Imp.fromRawNonNull(@ptrCast(&customPoolDealloc)), "v@:");
    objc.registerClassPair(cls);
    return cls;
}

test "AutoreleasePool: basic creation and idempotent drain" {
    var pool = AutoreleasePool.init();
    try testing.expect(pool.token != null);
    pool.drain();
    try testing.expect(pool.token == null);
    pool.drain();
    pool.deinit();
    try testing.expect(pool.token == null);
}

test "AutoreleasePool: drains autoreleased object" {
    const cls = getOrCreatePoolTestClass();
    const initial_count = g_pool_dealloc_count;
    var pool = AutoreleasePool.init();
    const obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    _ = obj.send(objc.Object, "autorelease", .{});
    try testing.expectEqual(initial_count, g_pool_dealloc_count);
    pool.drain();
    try testing.expectEqual(initial_count + 1, g_pool_dealloc_count);
}

test "AutoreleasePool: nested pools follow LIFO drain ordering" {
    const cls = getOrCreatePoolTestClass();
    const initial_count = g_pool_dealloc_count;
    var outer_pool = AutoreleasePool.init();
    defer outer_pool.deinit();
    const outer_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    _ = outer_obj.send(objc.Object, "autorelease", .{});

    {
        var inner_pool = AutoreleasePool.init();
        const inner_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
        _ = inner_obj.send(objc.Object, "autorelease", .{});
        try testing.expectEqual(initial_count, g_pool_dealloc_count);
        inner_pool.drain();
        try testing.expectEqual(initial_count + 1, g_pool_dealloc_count);
    }
    outer_pool.drain();
    try testing.expectEqual(initial_count + 2, g_pool_dealloc_count);
}
