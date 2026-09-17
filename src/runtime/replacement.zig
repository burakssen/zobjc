//! Reversible Objective-C method implementation replacement.
//!
//! Replaces method implementations with raw IMPs, Zig callbacks, or Blocks,
//! verifying that no intervening modifications occurred before restoration.

const std = @import("std");
const testing = std.testing;
const objc = @import("zobjc");
const raw = @import("raw");
const Method = @import("method.zig").Method;
const Imp = @import("imp.zig").Imp;
const block = @import("block");

/// Reversible method implementation replacement record.
pub const MethodReplacement = struct {
    method: Method,
    previous: Imp,
    installed: Imp,
    active: bool,

    const Self = @This();

    /// Replaces the implementation of `method` with `replacement`.
    pub fn replace(method: Method, replacement: Imp) MethodReplacement {
        const prev = method.setImplementation(replacement);
        return .{
            .method = method,
            .previous = prev,
            .installed = replacement,
            .active = true,
        };
    }

    /// Restores the previous implementation, verifying that the current implementation matches `installed`.
    ///
    /// If another caller or patch modified the method in the meantime, returns `error.ImplementationChanged`
    /// to avoid blindly overwriting the subsequent modification.
    pub fn restore(self: *Self) !void {
        if (!self.active) return;
        if (!self.method.implementation().eql(self.installed)) {
            return error.ImplementationChanged;
        }
        _ = self.method.setImplementation(self.previous);
        self.active = false;
    }
};

/// Block-backed method replacement managing `OwnedImp` lifetime.
pub const BlockMethodReplacement = struct {
    method: Method,
    imp: block.OwnedImp,
    previous: Imp,
    active: bool,

    const Self = @This();

    /// Replaces `method` implementation with an Objective-C Block.
    pub fn replace(method: Method, block_handle: anytype) !BlockMethodReplacement {
        var owned_imp = try block.makeImp(block_handle);
        errdefer owned_imp.deinit();

        const prev = method.setImplementation(owned_imp.borrow());
        return .{
            .method = method,
            .imp = owned_imp,
            .previous = prev,
            .active = true,
        };
    }

    /// Restores the previous method implementation and releases the backing Block IMP.
    ///
    /// Correct ordering:
    /// 1. Verifies that the current implementation still matches our installed IMP.
    /// 2. Restores the previous implementation on the method.
    /// 3. Releases the Block IMP via `imp_removeBlock`.
    pub fn restore(self: *Self) !void {
        if (!self.active) return;
        if (!self.method.implementation().eql(self.imp.borrow())) {
            return error.ImplementationChanged;
        }
        _ = self.method.setImplementation(self.previous);
        self.imp.deinit();
        self.active = false;
    }
};

fn setupReplacementClass(name: [:0]const u8) !struct { cls: objc.Class, inst: objc.Object } {
    const super_cls = objc.requireClass("NSObject");
    const dyn_cls = raw.runtime.objc_allocateClassPair(super_cls.toRaw(), name.ptr, 0) orelse
        return error.ClassAllocFailed;

    const original_imp = struct {
        fn call(self: raw.id, sel_val: raw.SEL) callconv(.c) c_int {
            _ = self;
            _ = sel_val;
            return 100;
        }
    }.call;
    _ = raw.runtime.class_addMethod(dyn_cls, objc.sel("methodA").toRaw(), @ptrCast(&original_imp), "i@:");
    raw.runtime.objc_registerClassPair(dyn_cls);

    const cls = objc.Class.fromRaw(dyn_cls).?;
    const inst = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    return .{ .cls = cls, .inst = inst };
}

test "method replacement: replaceWith and conflict detection" {
    const env = try setupReplacementClass("ReplacementClass");
    defer {
        env.inst.send(void, "dealloc", .{});
        objc.disposeClassPair(env.cls);
    }

    const method = env.cls.instanceMethod(objc.sel("methodA")).?;
    const custom_imp = struct {
        fn call(self: raw.id, sel_val: raw.SEL) callconv(.c) c_int {
            _ = self;
            _ = sel_val;
            return 999;
        }
    }.call;
    var replacement = MethodReplacement.replace(method, Imp.fromRawNonNull(@ptrCast(&custom_imp)));
    try testing.expectEqual(@as(c_int, 999), objc.send(c_int, env.inst, "methodA", .{}));
    try replacement.restore();
    try testing.expectEqual(@as(c_int, 100), objc.send(c_int, env.inst, "methodA", .{}));

    const second_imp = struct {
        fn call(self: raw.id, sel_val: raw.SEL) callconv(.c) c_int {
            _ = self;
            _ = sel_val;
            return 888;
        }
    }.call;
    var replacement_two = MethodReplacement.replace(method, Imp.fromRawNonNull(@ptrCast(&second_imp)));
    const intervening_imp = struct {
        fn call(self: raw.id, sel_val: raw.SEL) callconv(.c) c_int {
            _ = self;
            _ = sel_val;
            return 777;
        }
    }.call;
    _ = method.setImplementation(Imp.fromRawNonNull(@ptrCast(&intervening_imp)));
    try testing.expectError(error.ImplementationChanged, replacement_two.restore());
}

test "method replacement: BlockMethodReplacement" {
    const env = try setupReplacementClass("BlockReplacementClass");
    defer {
        env.inst.send(void, "dealloc", .{});
        objc.disposeClassPair(env.cls);
    }

    const method = env.cls.instanceMethod(objc.sel("methodA")).?;
    var block_handle = try objc.OwnedBlock(fn (objc.Object) c_int).fromFunction(struct {
        fn blockImp(_: objc.Object) c_int {
            return 555;
        }
    }.blockImp);
    defer block_handle.deinit();

    var replacement = try BlockMethodReplacement.replace(method, block_handle);
    try testing.expectEqual(@as(c_int, 555), objc.send(c_int, env.inst, "methodA", .{}));
    try replacement.restore();
    try testing.expectEqual(@as(c_int, 100), objc.send(c_int, env.inst, "methodA", .{}));
}
