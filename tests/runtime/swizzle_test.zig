//! Tests for method swizzling and reversible replacement.
// ponytail: minimalist, zero overhead, verify swizzle, scoped RAII, checked install, and conflict detection.

const std = @import("std");
const objc = @import("objc");
const raw = objc.raw;
const testing = std.testing;

fn setupSwizzleClass(name: [:0]const u8) !struct { cls: objc.Class, inst: objc.Object } {
    const super_cls = objc.requireClass("NSObject");
    const dyn_cls = raw.runtime.objc_allocateClassPair(super_cls.toRaw(), name.ptr, 0) orelse return error.ClassAllocFailed;

    const fnA = struct {
        fn imp(self: raw.id, sel_val: raw.SEL) callconv(.c) c_int {
            _ = self;
            _ = sel_val;
            return 100;
        }
    }.imp;

    const fnB = struct {
        fn imp(self: raw.id, sel_val: raw.SEL) callconv(.c) c_int {
            _ = self;
            _ = sel_val;
            return 200;
        }
    }.imp;

    const fnMismatched = struct {
        fn imp(self: raw.id, sel_val: raw.SEL) callconv(.c) f32 {
            _ = self;
            _ = sel_val;
            return 1.5;
        }
    }.imp;

    _ = raw.runtime.class_addMethod(dyn_cls, objc.sel("methodA").toRaw(), @ptrCast(&fnA), "i@:");
    _ = raw.runtime.class_addMethod(dyn_cls, objc.sel("methodB").toRaw(), @ptrCast(&fnB), "i@:");
    _ = raw.runtime.class_addMethod(dyn_cls, objc.sel("methodMismatched").toRaw(), @ptrCast(&fnMismatched), "f@:");

    raw.runtime.objc_registerClassPair(dyn_cls);

    const cls = objc.Class.fromRaw(dyn_cls).?;
    const inst = cls.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});

    return .{ .cls = cls, .inst = inst };
}

test "swizzle: basic swap and restore" {
    const env = try setupSwizzleClass("SwizzleBasicClass");
    defer {
        env.inst.msgSend(void, "dealloc", .{});
        objc.disposeClassPair(env.cls);
    }

    try testing.expectEqual(@as(c_int, 100), objc.send(c_int, env.inst, "methodA", .{}));
    try testing.expectEqual(@as(c_int, 200), objc.send(c_int, env.inst, "methodB", .{}));

    const mA = env.cls.instanceMethod(objc.sel("methodA")).?;
    const mB = env.cls.instanceMethod(objc.sel("methodB")).?;

    var swiz = objc.Swizzle.install(mA, mB);

    // Swapped
    try testing.expectEqual(@as(c_int, 200), objc.send(c_int, env.inst, "methodA", .{}));
    try testing.expectEqual(@as(c_int, 100), objc.send(c_int, env.inst, "methodB", .{}));

    // Restore
    swiz.restore();

    // Original returned
    try testing.expectEqual(@as(c_int, 100), objc.send(c_int, env.inst, "methodA", .{}));
    try testing.expectEqual(@as(c_int, 200), objc.send(c_int, env.inst, "methodB", .{}));
}

test "swizzle: scoped RAII swizzling" {
    const env = try setupSwizzleClass("SwizzleScopedClass");
    defer {
        env.inst.msgSend(void, "dealloc", .{});
        objc.disposeClassPair(env.cls);
    }

    const mA = env.cls.instanceMethod(objc.sel("methodA")).?;
    const mB = env.cls.instanceMethod(objc.sel("methodB")).?;

    {
        var scoped = objc.ScopedSwizzle.init(mA, mB);
        defer scoped.deinit();

        try testing.expectEqual(@as(c_int, 200), objc.send(c_int, env.inst, "methodA", .{}));
        try testing.expectEqual(@as(c_int, 100), objc.send(c_int, env.inst, "methodB", .{}));
    }

    // Automatically restored when scoped exited scope
    try testing.expectEqual(@as(c_int, 100), objc.send(c_int, env.inst, "methodA", .{}));
    try testing.expectEqual(@as(c_int, 200), objc.send(c_int, env.inst, "methodB", .{}));
}

test "swizzle: installChecked signature validation" {
    const env = try setupSwizzleClass("SwizzleCheckedClass");
    defer {
        env.inst.msgSend(void, "dealloc", .{});
        objc.disposeClassPair(env.cls);
    }

    const mA = env.cls.instanceMethod(objc.sel("methodA")).?;
    const mB = env.cls.instanceMethod(objc.sel("methodB")).?;
    const mMismatched = env.cls.instanceMethod(objc.sel("methodMismatched")).?;

    // Matching signatures ("i@:")
    var swiz = try objc.Swizzle.installChecked(testing.allocator, mA, mB);
    defer swiz.restore();

    // Mismatched signatures ("i@:" vs "f@:")
    const result = objc.Swizzle.installChecked(testing.allocator, mA, mMismatched);
    try testing.expectError(error.IncompatibleSignatures, result);
}

test "method replacement: replaceWith and conflict detection" {
    const env = try setupSwizzleClass("ReplacementClass");
    defer {
        env.inst.msgSend(void, "dealloc", .{});
        objc.disposeClassPair(env.cls);
    }

    const mA = env.cls.instanceMethod(objc.sel("methodA")).?;

    var replacement = objc.MethodReplacement.replaceWith(mA, struct {
        fn customImp(self: objc.Object, _cmd: objc.Selector) c_int {
            _ = self;
            _ = _cmd;
            return 999;
        }
    }.customImp);

    // Call replaced method
    try testing.expectEqual(@as(c_int, 999), objc.send(c_int, env.inst, "methodA", .{}));

    // Restore cleanly
    try replacement.restore();
    try testing.expectEqual(@as(c_int, 100), objc.send(c_int, env.inst, "methodA", .{}));

    // Now test conflict detection (intervening replacement)
    var repl2 = objc.MethodReplacement.replaceWith(mA, struct {
        fn secondImp(self: objc.Object, _cmd: objc.Selector) c_int {
            _ = self;
            _ = _cmd;
            return 888;
        }
    }.secondImp);

    // Intervene behind repl2's back
    const interveningImp = struct {
        fn thirdImp(self: raw.id, _cmd: raw.SEL) callconv(.c) c_int {
            _ = self;
            _ = _cmd;
            return 777;
        }
    }.thirdImp;
    _ = mA.setImplementation(objc.Imp.fromRawNonNull(@ptrCast(&interveningImp)));

    // repl2.restore() should detect that implementation changed and refuse to overwrite
    try testing.expectError(error.ImplementationChanged, repl2.restore());
}

test "method replacement: BlockMethodReplacement" {
    const env = try setupSwizzleClass("BlockReplacementClass");
    defer {
        env.inst.msgSend(void, "dealloc", .{});
        objc.disposeClassPair(env.cls);
    }

    const mA = env.cls.instanceMethod(objc.sel("methodA")).?;

    var blk = try objc.OwnedBlock(fn (objc.Object) c_int).fromFunction(struct {
        fn blockImp(_: objc.Object) c_int {
            return 555;
        }
    }.blockImp);
    defer blk.deinit();

    var replacement = try objc.BlockMethodReplacement.replace(mA, blk);

    try testing.expectEqual(@as(c_int, 555), objc.send(c_int, env.inst, "methodA", .{}));

    try replacement.restore();

    try testing.expectEqual(@as(c_int, 100), objc.send(c_int, env.inst, "methodA", .{}));
}
