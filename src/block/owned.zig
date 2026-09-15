//! Owning Apple Block handle.
//!
//! Represents single ownership of a heap-promoted Block literal.
//! Releases memory via _Block_release and duplicates ownership via _Block_copy.

const std = @import("std");
const raw = @import("../raw/root.zig");
const Object = @import("../runtime/object.zig").Object;
const block_mod = @import("block.zig");
const create_mod = @import("create.zig");
const imp_mod = @import("imp.zig");
const invoke_mod = @import("invoke.zig");

/// Owning handle for an Apple Block.
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
            return create_mod.fromFunction(Signature, callback);
        }
    };
}
