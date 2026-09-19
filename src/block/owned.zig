//! Owning Apple Block handle.
//!
//! Represents single ownership of a heap-promoted Block literal.
//! Releases memory via _Block_release and duplicates ownership via _Block_copy.

const std = @import("std");
const raw = @import("raw");
const Object = @import("runtime").Object;
const block_mod = @import("block.zig");
const create_mod = @import("create.zig");
const imp_mod = @import("imp.zig");
const invoke_mod = @import("invoke.zig");
const Class = @import("runtime").Class;
const sel_fn = @import("runtime").sel;

const testing = std.testing;

/// Owning handle for an Apple Block.
///
/// Move-only by convention (Zig cannot enforce this): NEVER copy an
/// `OwnedBlock` by value — duplicate with `clone()` instead. All consuming
/// methods take pointer receivers (`deinit`, `intoRaw`) or invalidate-safe
/// borrows so accidental copies are minimized.
pub fn OwnedBlock(comptime Signature: type) type {
    return struct {
        ptr: ?*raw.blocks.Block_layout = null,

        const Self = @This();
        pub const Borrowed = block_mod.Block(Signature);

        /// Wrap a raw heap Block literal pointer.
        pub fn fromRaw(raw_ptr: *raw.blocks.Block_layout) Self {
            return .{ .ptr = raw_ptr };
        }

        /// Relinquishes ownership and returns the raw Block pointer.
        pub fn intoRaw(self: *Self) *raw.blocks.Block_layout {
            const p = self.ptr orelse @panic("attempted to use deinitialized OwnedBlock");
            self.ptr = null;
            return p;
        }

        /// Borrows the underlying raw Block pointer without relinquishing ownership.
        pub fn toRaw(self: Self) *raw.blocks.Block_layout {
            return self.ptr orelse @panic("attempted to use deinitialized OwnedBlock");
        }

        /// Borrows a typed non-owning reference to this Block.
        pub fn borrow(self: Self) Borrowed {
            const p = self.ptr orelse @panic("attempted to borrow deinitialized OwnedBlock");
            return Borrowed.fromRaw(p);
        }

        /// Creates an independent owning handle by incrementing the Block's reference count.
        pub fn clone(self: Self) !Self {
            const p = self.ptr orelse @panic("attempted to clone deinitialized OwnedBlock");
            const copied = raw.blocks._Block_copy(p) orelse return error.OutOfMemory;
            return Self{ .ptr = @ptrCast(@alignCast(copied)) };
        }

        /// Releases this Block via _Block_release and invalidates the handle.
        pub fn deinit(self: *Self) void {
            if (self.ptr) |p| {
                raw.blocks._Block_release(p);
                self.ptr = null;
            }
        }

        /// Calls the Block with typed arguments.
        pub fn call(self: Self, args: anytype) invoke_mod.ReturnType(Signature) {
            return self.borrow().call(args);
        }

        /// Views this Block as an Objective-C object.
        pub fn asObject(self: Self) Object {
            return self.borrow().asObject();
        }

        /// Bridges this Block into an Objective-C IMP.
        pub fn makeImp(self: Self) !imp_mod.OwnedImp {
            return self.borrow().makeImp();
        }

        /// Creates an OwnedBlock capturing variables from the caller.
        pub fn capture(
            comptime Captures: type,
            captures: Captures,
            callback: anytype,
        ) !Self {
            return create_mod.createBlock(Signature, Captures, captures, callback);
        }

        /// Creates an OwnedBlock without captures from a function.
        pub fn fromFunction(callback: anytype) !Self {
            return create_mod.createBlock(Signature, struct {}, .{}, callback);
        }
    };
}

test "imp: makeImp and method dispatch" {
    var blk = try OwnedBlock(fn (Object, c_int, c_int) c_int).fromFunction(struct {
        fn add(_: Object, x: c_int, y: c_int) c_int {
            return x + y;
        }
    }.add);
    defer blk.deinit();

    var owned_imp = try blk.makeImp();
    defer owned_imp.deinit();
    try testing.expect(owned_imp.raw_imp != null);
    try testing.expect(owned_imp.block() != null);

    const super_cls = Class.fromRaw(raw.runtime.objc_getClass("NSObject")).?;
    const dynamic_cls = raw.runtime.objc_allocateClassPair(super_cls.toRaw(), "DynamicBlockTestClass", 0).?;
    defer raw.runtime.objc_disposeClassPair(dynamic_cls);

    const added = raw.runtime.class_addMethod(dynamic_cls, sel_fn("add:and:").toRaw(), owned_imp.borrow().toRaw(), "i@:ii");
    try testing.expect(raw.boolResult(added));
    raw.runtime.objc_registerClassPair(dynamic_cls);

    const cls_handle = Class.fromRaw(dynamic_cls).?;
    const inst = cls_handle.send(Object, "alloc", .{}).send(Object, "init", .{});
    defer inst.send(void, "release", .{});
    try testing.expectEqual(@as(c_int, 42), inst.send(c_int, "add:and:", .{ @as(c_int, 20), @as(c_int, 22) }));
}

test "differential: Block to IMP bridge lifecycle" {
    const super_cls = Class.fromRaw(raw.runtime.objc_getClass("NSObject")).?;
    const cls = raw.runtime.objc_allocateClassPair(super_cls.toRaw(), "BlockImpBridgeTest", 0) orelse return;
    defer raw.runtime.objc_disposeClassPair(cls);

    var blk = try OwnedBlock(fn (Object, c_int) c_int).fromFunction(struct {
        fn bridgeFn(self: Object, val: c_int) c_int {
            _ = self;
            return val + 100;
        }
    }.bridgeFn);
    defer blk.deinit();

    var owned_imp = try imp_mod.makeImp(blk);
    defer owned_imp.deinit();

    const sel = sel_fn("bridgeTest:");
    try testing.expect(Class.fromRaw(cls).?.addMethod(sel, owned_imp.borrow(), "i@:i"));
    raw.runtime.objc_registerClassPair(cls);

    const inst = Class.fromRaw(cls).?.send(Object, "alloc", .{}).send(Object, "init", .{});
    defer inst.send(void, "release", .{});
    try testing.expectEqual(@as(c_int, 142), inst.send(c_int, "bridgeTest:", .{@as(c_int, 42)}));
}
