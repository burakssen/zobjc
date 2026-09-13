//! Typed non-owning Apple Block handle.
//!
//! Represents a borrowed reference to a valid Objective-C Block.
//! Provides direct invocation, Object conversion, signature introspection, and heap cloning.

const std = @import("std");
const raw = @import("../raw/root.zig");
const Object = @import("../runtime/object.zig").Object;
const validation = @import("validation.zig");
const invoke_mod = @import("invoke.zig");
const owned_mod = @import("owned.zig");
const imp_mod = @import("imp.zig");
const signature_mod = @import("signature.zig");

/// Typed non-owning handle to an Apple Block.
pub fn Block(comptime Signature: type) type {
    validation.validateBlockSignature(Signature);

    return struct {
        ptr: *raw.blocks.Block_layout,

        pub const Fn = Signature;
        const Self = @This();
        pub const Owned = owned_mod.OwnedBlock(Signature);

        /// Wrap a raw Block literal pointer.
        pub fn fromRaw(raw_ptr: *raw.blocks.Block_layout) Self {
            return .{ .ptr = raw_ptr };
        }

        /// Returns the underlying raw Block layout pointer.
        pub fn toRaw(self: Self) *raw.blocks.Block_layout {
            return self.ptr;
        }

        /// Views this Block as an Objective-C object.
        pub fn asObject(self: Self) Object {
            return Object.fromRaw(@ptrCast(self.ptr));
        }

        /// Calls the Block with typed arguments.
        pub fn call(self: Self, args: anytype) invoke_mod.ReturnType(Signature) {
            return invoke_mod.callBlock(Signature, self.ptr, args);
        }

        /// Copies this Block to the heap (or increments refcount) returning an OwnedBlock.
        pub fn copy(self: Self) !Owned {
            const copied = raw.blocks._Block_copy(self.ptr) orelse return error.OutOfMemory;
            return Owned.fromRaw(@ptrCast(@alignCast(copied)));
        }

        /// Determines if the Block literal has the BLOCK_USE_STRET flag set.
        pub fn usesStret(self: Self) bool {
            return (self.ptr.flags & raw.blocks.BLOCK_USE_STRET) != 0;
        }

        /// Determines if the Block literal has signature metadata.
        pub fn hasSignature(self: Self) bool {
            return (self.ptr.flags & raw.blocks.BLOCK_HAS_SIGNATURE) != 0;
        }

        /// Reads the Block signature string if present in the descriptor.
        pub fn signature(self: Self) ?[*:0]const u8 {
            if (!self.hasSignature()) return null;
            const desc_bytes: [*]const u8 = @ptrCast(self.ptr.descriptor);
            const has_copy_dispose = (self.ptr.flags & raw.blocks.BLOCK_HAS_COPY_DISPOSE) != 0;
            // // ponytail: direct offset calculation matching Apple large descriptor ABI
            const sig_offset: usize = if (has_copy_dispose) 32 else 16;
            const sig_ptr: *const ?[*:0]const u8 = @ptrCast(@alignCast(desc_bytes + sig_offset));
            return sig_ptr.*;
        }

        /// Validates that the runtime Block signature matches the expected static signature.
        pub fn validateSignature(self: Self) !void {
            const actual_sig = self.signature() orelse return error.MissingBlockSignature;
            const expected_sig = signature_mod.blockSignature(Signature);
            const actual_slice = std.mem.span(actual_sig);
            if (!std.mem.eql(u8, actual_slice, expected_sig)) {
                return error.BlockSignatureMismatch;
            }
        }

        /// Bridges this Block into an Objective-C IMP via imp_implementationWithBlock.
        pub fn makeImp(self: Self) !imp_mod.OwnedImp {
            return imp_mod.makeImp(self);
        }
    };
}
