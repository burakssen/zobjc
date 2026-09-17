//! Structured Objective-C method swizzling.
//!
//! Provides reversible method implementation swapping with explicit restoration,
//! signature compatibility checks, and test-scoped RAII helpers.

const std = @import("std");
const testing = std.testing;
const objc = @import("zobjc");
const raw = @import("raw");
const Method = @import("method.zig").Method;
const encoding = @import("encoding");

/// Structured representation of an active or restorable method swizzle.
///
/// WARNING: Swizzling mutates global process runtime state. Automatic restoration
/// on deinit is provided only by `ScopedSwizzle` for isolated unit tests.
pub const Swizzle = struct {
    first: Method,
    second: Method,
    active: bool,

    const Self = @This();

    /// Exchanges the implementations of `first` and `second`.
    pub fn install(first: Method, second: Method) Swizzle {
        first.exchange(second);
        return .{
            .first = first,
            .second = second,
            .active = true,
        };
    }

    /// Validates signature compatibility before exchanging method implementations.
    pub fn installChecked(
        allocator: std.mem.Allocator,
        first: Method,
        second: Method,
    ) !Swizzle {
        var sig1 = try first.parsedSignature(allocator);
        defer sig1.deinit(allocator);
        var sig2 = try second.parsedSignature(allocator);
        defer sig2.deinit(allocator);

        // Verify receiver kind and parameter/return types
        if (!sig1.eql(sig2)) {
            return error.IncompatibleSignatures;
        }

        return install(first, second);
    }

    /// Restores the original implementations.
    pub fn restore(self: *Self) void {
        if (self.active) {
            self.first.exchange(self.second);
            self.active = false;
        }
    }
};

/// Scoped RAII wrapper for method swizzling in controlled test environments.
///
/// Automatically restores original method implementations upon `deinit()`.
pub const ScopedSwizzle = struct {
    swizzle: Swizzle,

    const Self = @This();

    pub fn init(first: Method, second: Method) Self {
        return .{ .swizzle = Swizzle.install(first, second) };
    }

    pub fn initChecked(allocator: std.mem.Allocator, first: Method, second: Method) !Self {
        return .{ .swizzle = try Swizzle.installChecked(allocator, first, second) };
    }

    pub fn deinit(self: *Self) void {
        self.swizzle.restore();
    }
};

fn setupSwizzleClass(name: [:0]const u8) !struct { cls: objc.Class, inst: objc.Object } {
    const super_cls = objc.requireClass("NSObject");
    const dyn_cls = raw.runtime.objc_allocateClassPair(super_cls.toRaw(), name.ptr, 0) orelse
        return error.ClassAllocFailed;

    const fn_a = struct {
        fn imp(self: raw.id, sel_val: raw.SEL) callconv(.c) c_int {
            _ = self;
            _ = sel_val;
            return 100;
        }
    }.imp;
    const fn_b = struct {
        fn imp(self: raw.id, sel_val: raw.SEL) callconv(.c) c_int {
            _ = self;
            _ = sel_val;
            return 200;
        }
    }.imp;
    const fn_mismatched = struct {
        fn imp(self: raw.id, sel_val: raw.SEL) callconv(.c) f32 {
            _ = self;
            _ = sel_val;
            return 1.5;
        }
    }.imp;

    _ = raw.runtime.class_addMethod(dyn_cls, objc.sel("methodA").toRaw(), @ptrCast(&fn_a), "i@:");
    _ = raw.runtime.class_addMethod(dyn_cls, objc.sel("methodB").toRaw(), @ptrCast(&fn_b), "i@:");
    _ = raw.runtime.class_addMethod(dyn_cls, objc.sel("methodMismatched").toRaw(), @ptrCast(&fn_mismatched), "f@:");
    raw.runtime.objc_registerClassPair(dyn_cls);

    const cls = objc.Class.fromRaw(dyn_cls).?;
    const inst = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    return .{ .cls = cls, .inst = inst };
}

test "swizzle: basic swap and restore" {
    const env = try setupSwizzleClass("SwizzleBasicClass");
    defer {
        env.inst.send(void, "dealloc", .{});
        objc.disposeClassPair(env.cls);
    }

    try testing.expectEqual(@as(c_int, 100), objc.send(c_int, env.inst, "methodA", .{}));
    try testing.expectEqual(@as(c_int, 200), objc.send(c_int, env.inst, "methodB", .{}));
    var swiz = Swizzle.install(env.cls.instanceMethod(objc.sel("methodA")).?, env.cls.instanceMethod(objc.sel("methodB")).?);
    try testing.expectEqual(@as(c_int, 200), objc.send(c_int, env.inst, "methodA", .{}));
    try testing.expectEqual(@as(c_int, 100), objc.send(c_int, env.inst, "methodB", .{}));
    swiz.restore();
    try testing.expectEqual(@as(c_int, 100), objc.send(c_int, env.inst, "methodA", .{}));
    try testing.expectEqual(@as(c_int, 200), objc.send(c_int, env.inst, "methodB", .{}));
}

test "swizzle: scoped RAII swizzling" {
    const env = try setupSwizzleClass("SwizzleScopedClass");
    defer {
        env.inst.send(void, "dealloc", .{});
        objc.disposeClassPair(env.cls);
    }

    const m_a = env.cls.instanceMethod(objc.sel("methodA")).?;
    const m_b = env.cls.instanceMethod(objc.sel("methodB")).?;
    {
        var scoped = ScopedSwizzle.init(m_a, m_b);
        defer scoped.deinit();
        try testing.expectEqual(@as(c_int, 200), objc.send(c_int, env.inst, "methodA", .{}));
        try testing.expectEqual(@as(c_int, 100), objc.send(c_int, env.inst, "methodB", .{}));
    }
    try testing.expectEqual(@as(c_int, 100), objc.send(c_int, env.inst, "methodA", .{}));
    try testing.expectEqual(@as(c_int, 200), objc.send(c_int, env.inst, "methodB", .{}));
}

test "swizzle: installChecked signature validation" {
    const env = try setupSwizzleClass("SwizzleCheckedClass");
    defer {
        env.inst.send(void, "dealloc", .{});
        objc.disposeClassPair(env.cls);
    }

    const m_a = env.cls.instanceMethod(objc.sel("methodA")).?;
    const m_b = env.cls.instanceMethod(objc.sel("methodB")).?;
    const mismatched = env.cls.instanceMethod(objc.sel("methodMismatched")).?;
    var swiz = try Swizzle.installChecked(testing.allocator, m_a, m_b);
    defer swiz.restore();
    try testing.expectError(error.IncompatibleSignatures, Swizzle.installChecked(testing.allocator, m_a, mismatched));
}
