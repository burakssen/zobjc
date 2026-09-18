//! Strong-ownership smart pointer for Objective-C objects.
//!
//! A `Retained(T)` owns exactly one +1 reference to an Objective-C object.
//! Deinitializing it releases that reference via `objc_release`.

const std = @import("std");
const testing = std.testing;
const objc = @import("zobjc");
const raw = @import("raw");
const traits = @import("traits.zig");

/// A type-safe smart pointer that owns exactly one strong reference (+1) to an
/// Objective-C object of type `T`.
///
/// Move-only by convention (Zig cannot enforce this): NEVER copy a `Retained`
/// by value. `var b = a;` creates two Zig values for one +1 obligation and a
/// subsequent double `deinit()` double-releases. Pass owners by pointer
/// (`*Retained(T)`), transfer by returning by value, duplicate with `clone()`.
///
/// ```zig
/// var a = Retained(Object).adopt(obj);
/// defer a.deinit();
/// var b = a.clone(); // second independent +1 — the only legal "copy"
/// defer b.deinit();
/// ```
pub fn Retained(comptime T: type) type {
    comptime {
        if (!traits.isRetainable(T)) {
            @compileError(@typeName(T) ++ " is not an Objective-C retainable object type. " ++
                "Only Object and types implementing .asObject()/.fromObject() can be retained.");
        }
    }

    return struct {
        value: ?T,

        const Self = @This();

        /// Retains a borrowed (+0) reference to create a new strong ownership obligation (+1).
        pub fn retain(val: T) Self {
            const raw_id = traits.toRawId(val);
            _ = raw.compiler_runtime.objc_retain(raw_id);
            return .{ .value = val };
        }

        /// Adopts an existing +1 reference without incrementing the retain count.
        /// Transfers ownership responsibility to this wrapper.
        pub fn adopt(val: T) Self {
            return .{ .value = val };
        }

        /// Returns the underlying non-owning handle (+0).
        ///
        /// The returned handle remains valid only for the duration of this wrapper's lifetime.
        pub fn borrow(self: *const Self) T {
            return self.value orelse @panic("attempted to borrow from deinitialized Retained");
        }

        /// Creates a second independent strong owner (+1) for the same object.
        pub fn clone(self: *const Self) Self {
            return Self.retain(self.borrow());
        }

        /// Releases the owned reference (+1) via `objc_release`.
        /// Idempotent: safe to call multiple times (subsequent calls do nothing).
        pub fn deinit(self: *Self) void {
            if (self.value) |v| {
                const raw_id = traits.toRawId(v);
                raw.compiler_runtime.objc_release(raw_id);
                self.value = null;
            }
        }

        /// Transfers the +1 ownership obligation back to the caller without releasing.
        /// The wrapper becomes invalid after this call.
        pub fn intoUnmanaged(self: *Self) T {
            const v = self.value orelse @panic("attempted to call intoUnmanaged on deinitialized Retained");
            self.value = null;
            return v;
        }

        /// Convenience helper: retains an optional object if non-null.
        pub fn retainOptional(val: ?T) ?Self {
            if (val) |v| {
                return Self.retain(v);
            }
            return null;
        }

        /// Convenience helper: adopts an optional object if non-null.
        pub fn adoptOptional(val: ?T) ?Self {
            if (val) |v| {
                return Self.adopt(v);
            }
            return null;
        }
    };
}

var g_dealloc_count: usize = 0;
var g_super_dealloc_fn: ?*const fn (objc.raw.id, objc.raw.SEL) callconv(.c) void = null;

fn customDealloc(self_id: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) void {
    g_dealloc_count += 1;
    if (g_super_dealloc_fn) |super_fn| super_fn(self_id, sel_val);
}

fn getOrCreateTestClass() objc.Class {
    const class_name = "RetainedLifecycleTestClass";
    if (objc.getClass(class_name)) |existing| return existing;

    const NSObject = objc.requireClass("NSObject");
    const cls = objc.allocateClassPair(NSObject, class_name).?;
    g_super_dealloc_fn = @ptrCast(NSObject.instanceMethod(objc.sel("dealloc")).?.implementation().toRaw());
    _ = cls.addMethod(objc.sel("dealloc"), objc.Imp.fromRawNonNull(@ptrCast(&customDealloc)), "v@:");
    objc.registerClassPair(cls);
    return cls;
}

test "Retained: compile-time retainable traits" {
    const traits_mod = objc.memory.traits;
    try testing.expect(traits_mod.isRetainable(objc.Object));
    try testing.expect(!traits_mod.isRetainable(objc.Class));
    try testing.expect(!traits_mod.isRetainable(i32));
}

test "Retained: adopt takes ownership and deinit releases" {
    const cls = getOrCreateTestClass();
    const initial_count = g_dealloc_count;
    const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var retained = Retained(objc.Object).adopt(raw_obj);
    try testing.expectEqual(initial_count, g_dealloc_count);
    try testing.expectEqual(raw_obj.toRaw(), retained.borrow().toRaw());
    retained.deinit();
    try testing.expectEqual(initial_count + 1, g_dealloc_count);
    retained.deinit();
}

test "Retained: retain increments retain count" {
    const cls = getOrCreateTestClass();
    const initial_count = g_dealloc_count;
    const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var r1 = Retained(objc.Object).adopt(raw_obj);
    var r2 = Retained(objc.Object).retain(r1.borrow());
    r1.deinit();
    try testing.expectEqual(initial_count, g_dealloc_count);
    r2.deinit();
    try testing.expectEqual(initial_count + 1, g_dealloc_count);
}

test "Retained: clone increments retain count" {
    const cls = getOrCreateTestClass();
    const initial_count = g_dealloc_count;
    const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var r1 = Retained(objc.Object).adopt(raw_obj);
    var r2 = r1.clone();
    r1.deinit();
    try testing.expectEqual(initial_count, g_dealloc_count);
    r2.deinit();
    try testing.expectEqual(initial_count + 1, g_dealloc_count);
}

test "Retained: intoUnmanaged relinquishes ownership without releasing" {
    const cls = getOrCreateTestClass();
    const initial_count = g_dealloc_count;
    const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var retained = Retained(objc.Object).adopt(raw_obj);
    const unmanaged = retained.intoUnmanaged();
    retained.deinit();
    try testing.expectEqual(initial_count, g_dealloc_count);
    _ = objc.raw.compiler_runtime.objc_release(unmanaged.toRaw());
    try testing.expectEqual(initial_count + 1, g_dealloc_count);
}

test "Retained: retainOptional and adoptOptional" {
    const cls = getOrCreateTestClass();
    const initial_count = g_dealloc_count;
    try testing.expect(Retained(objc.Object).adoptOptional(null) == null);
    try testing.expect(Retained(objc.Object).retainOptional(null) == null);

    const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    if (Retained(objc.Object).adoptOptional(raw_obj)) |*retained| {
        var mutable = retained.*;
        defer mutable.deinit();
        try testing.expectEqual(raw_obj.toRaw(), mutable.borrow().toRaw());
    } else return error.UnexpectedNull;
    try testing.expectEqual(initial_count + 1, g_dealloc_count);
}

test "Retained: createInstanceRetained on Class" {
    const cls = getOrCreateTestClass();
    const initial_count = g_dealloc_count;
    var retained = cls.createInstanceRetained(0).?;
    _ = retained.borrow().send(objc.Object, "init", .{});
    retained.deinit();
    try testing.expectEqual(initial_count + 1, g_dealloc_count);
}

fn consumeThroughPointer(owner: *Retained(objc.Object)) void {
    // Recommended pattern: owners travel by pointer, never by value.
    owner.deinit();
}

test "Retained: pointer-passing invalidates owner without copying" {
    const cls = getOrCreateTestClass();
    const initial_count = g_dealloc_count;
    const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var retained = Retained(objc.Object).adopt(raw_obj);
    consumeThroughPointer(&retained);
    try testing.expectEqual(initial_count + 1, g_dealloc_count);
    // Second deinit on the same (now empty) value is a safe no-op.
    retained.deinit();
    try testing.expectEqual(initial_count + 1, g_dealloc_count);
}
