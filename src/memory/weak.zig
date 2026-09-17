//! Zeroing weak reference wrapper for Objective-C objects.
//!
//! Apple's Objective-C runtime tracks the exact memory address of weak storage slots.
//! Therefore, Weak(T) must be initialized in-place:
//!
//! ```zig
//! var weak: objc.Weak(objc.Object) = .{};
//! weak.init(object);
//! defer weak.deinit();
//! ```

const std = @import("std");
const testing = std.testing;
const objc = @import("zobjc");
const assert = std.debug.assert;
const raw = @import("raw");
const traits = @import("traits.zig");
const Retained = @import("retained.zig").Retained;

/// An address-sensitive zeroing weak reference to an Objective-C object of type `T`.
///
/// MUST NOT be copied by value with ordinary assignment after initialization.
/// Use `.copyFrom()` or `.moveFrom()` to copy or relocate weak storage.
pub fn Weak(comptime T: type) type {
    comptime {
        if (!traits.isRetainable(T)) {
            @compileError(@typeName(T) ++ " is not an Objective-C retainable object type. " ++
                "Only Object and types implementing .asObject()/.fromObject() can be weakly referenced.");
        }
    }

    return struct {
        slot: raw.id = null,
        initialized: bool = false,

        const Self = @This();

        /// Initializes the weak pointer variable in-place.
        ///
        /// Registers the address of `self.slot` with the Objective-C runtime weak table.
        pub fn init(self: *Self, value: ?T) void {
            assert(!self.initialized);
            const raw_id = if (value) |v| traits.toRawId(v) else null;
            _ = raw.compiler_runtime.objc_initWeak(&self.slot, raw_id);
            self.initialized = true;
        }

        /// Updates the referenced object, or sets it to nil without destroying the slot.
        pub fn store(self: *Self, value: ?T) void {
            assert(self.initialized);
            const raw_id = if (value) |v| traits.toRawId(v) else null;
            _ = raw.compiler_runtime.objc_storeWeak(&self.slot, raw_id);
        }

        /// Clears the referenced object to nil. The weak slot remains initialized.
        pub inline fn clear(self: *Self) void {
            self.store(null);
        }

        /// Loads and retains the referenced object atomically via `objc_loadWeakRetained`.
        ///
        /// Returns a strong `Retained(T)` owner, or `null` if the object has been deallocated or slot is uninitialized.
        /// This is the safest way to read a weak reference.
        pub fn loadRetained(self: *Self) ?Retained(T) {
            if (!self.initialized) return null;
            const raw_id = raw.compiler_runtime.objc_loadWeakRetained(&self.slot);
            if (raw_id) |p| {
                return Retained(T).adopt(traits.fromRawIdNonNull(T, p));
            }
            return null;
        }

        /// Loads the referenced object via `objc_loadWeak` (returns an autoreleased borrow), or `null` if uninitialized.
        pub fn loadBorrowed(self: *Self) ?T {
            if (!self.initialized) return null;
            const raw_id = raw.compiler_runtime.objc_loadWeak(&self.slot);
            if (raw_id) |p| {
                return traits.fromRawIdNonNull(T, p);
            }
            return null;
        }

        /// Copies a weak reference from `source` to `destination` via `objc_copyWeak`.
        /// `destination` must be uninitialized, and `source` must be initialized.
        pub fn copyFrom(destination: *Self, source: *const Self) void {
            assert(!destination.initialized);
            assert(source.initialized);
            raw.compiler_runtime.objc_copyWeak(&destination.slot, @constCast(&source.slot));
            destination.initialized = true;
        }

        /// Moves a weak reference from `source` to `destination` via `objc_moveWeak`.
        /// `destination` must be uninitialized, and `source` must be initialized.
        /// After the move, `source` is reset to uninitialized state.
        pub fn moveFrom(destination: *Self, source: *Self) void {
            assert(!destination.initialized);
            assert(source.initialized);
            raw.compiler_runtime.objc_moveWeak(&destination.slot, &source.slot);
            destination.initialized = true;
            source.initialized = false;
            source.slot = null;
        }

        /// Destroys the weak reference registration via `objc_destroyWeak`.
        /// Idempotent: safe to call multiple times.
        pub fn deinit(self: *Self) void {
            if (self.initialized) {
                raw.compiler_runtime.objc_destroyWeak(&self.slot);
                self.slot = null;
                self.initialized = false;
            }
        }
    };
}

var g_weak_dealloc_count: usize = 0;
var g_weak_super_dealloc_fn: ?*const fn (objc.raw.id, objc.raw.SEL) callconv(.c) void = null;

fn customWeakDealloc(self_id: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) void {
    g_weak_dealloc_count += 1;
    if (g_weak_super_dealloc_fn) |super_fn| super_fn(self_id, sel_val);
}

fn getOrCreateWeakTestClass() objc.Class {
    const class_name = "WeakLifecycleTestClass";
    if (objc.getClass(class_name)) |existing| return existing;

    const NSObject = objc.requireClass("NSObject");
    const cls = objc.allocateClassPair(NSObject, class_name).?;
    g_weak_super_dealloc_fn = @ptrCast(NSObject.instanceMethod(objc.sel("dealloc")).?.implementation().toRaw());
    _ = cls.addMethod(objc.sel("dealloc"), objc.Imp.fromRawNonNull(@ptrCast(&customWeakDealloc)), "v@:");
    objc.registerClassPair(cls);
    return cls;
}

test "Weak: in-place initialization and loadRetained while alive" {
    const cls = getOrCreateWeakTestClass();
    const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var strong = Retained(objc.Object).adopt(raw_obj);
    defer strong.deinit();
    var weak: Weak(objc.Object) = .{};
    weak.init(strong.borrow());
    defer weak.deinit();

    if (weak.loadRetained()) |*loaded| {
        var mutable = loaded.*;
        defer mutable.deinit();
        try testing.expectEqual(strong.borrow().toRaw(), mutable.borrow().toRaw());
    } else return error.ExpectedNonNullWeak;
}

test "Weak: automatic zeroing when strong owner deallocates" {
    const cls = getOrCreateWeakTestClass();
    const initial_dealloc = g_weak_dealloc_count;
    var weak: Weak(objc.Object) = .{};
    defer weak.deinit();
    {
        const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
        var strong = Retained(objc.Object).adopt(raw_obj);
        weak.init(strong.borrow());
        if (weak.loadRetained()) |*loaded| {
            var mutable = loaded.*;
            mutable.deinit();
        } else return error.ExpectedNonNullWeak;
        try testing.expectEqual(initial_dealloc, g_weak_dealloc_count);
        strong.deinit();
        try testing.expectEqual(initial_dealloc + 1, g_weak_dealloc_count);
    }
    try testing.expect(weak.loadRetained() == null);
}

test "Weak: store and clear" {
    const cls = getOrCreateWeakTestClass();
    const raw_obj1 = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var strong1 = Retained(objc.Object).adopt(raw_obj1);
    defer strong1.deinit();
    const raw_obj2 = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var strong2 = Retained(objc.Object).adopt(raw_obj2);
    defer strong2.deinit();
    var weak: Weak(objc.Object) = .{};
    weak.init(strong1.borrow());
    defer weak.deinit();

    try testing.expect(weak.loadRetained() != null);
    if (weak.loadRetained()) |*loaded| {
        var mutable = loaded.*;
        mutable.deinit();
    }
    weak.store(strong2.borrow());
    if (weak.loadRetained()) |*loaded| {
        var mutable = loaded.*;
        defer mutable.deinit();
        try testing.expectEqual(strong2.borrow().toRaw(), mutable.borrow().toRaw());
    } else return error.ExpectedNonNull;
    weak.clear();
    try testing.expect(weak.loadRetained() == null);
}

test "Weak: copyFrom and moveFrom" {
    const cls = getOrCreateWeakTestClass();
    const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var strong = Retained(objc.Object).adopt(raw_obj);
    defer strong.deinit();
    var weak1: Weak(objc.Object) = .{};
    weak1.init(strong.borrow());
    defer weak1.deinit();
    var weak2: Weak(objc.Object) = .{};
    defer weak2.deinit();
    weak2.copyFrom(&weak1);
    try testing.expect(weak1.loadRetained() != null);
    if (weak1.loadRetained()) |*loaded| {
        var mutable = loaded.*;
        mutable.deinit();
    }
    var weak3: Weak(objc.Object) = .{};
    defer weak3.deinit();
    weak3.moveFrom(&weak2);
    try testing.expect(weak2.loadRetained() == null);
    try testing.expect(weak3.loadRetained() != null);
    if (weak3.loadRetained()) |*loaded| {
        var mutable = loaded.*;
        mutable.deinit();
    }
}

test "Weak: loadBorrowed with autorelease pool" {
    const cls = getOrCreateWeakTestClass();
    const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var strong = Retained(objc.Object).adopt(raw_obj);
    defer strong.deinit();
    var weak: Weak(objc.Object) = .{};
    weak.init(strong.borrow());
    defer weak.deinit();
    var pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    try testing.expectEqual(strong.borrow().toRaw(), weak.loadBorrowed().?.toRaw());
}
