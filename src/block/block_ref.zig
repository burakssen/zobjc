//! Block reference capture wrapper.
//!
//! Captures another Block inside a Block literal and manages lifetime via
//! _Block_object_assign / _Block_object_dispose with BLOCK_FIELD_IS_BLOCK.

const std = @import("std");
const raw = @import("../raw/root.zig");

pub fn BlockRef(comptime Signature: type) type {
    return struct {
        pub const _is_zobjc_block_ref = true;
        pub const BlockSignature = Signature;

        raw_ptr: ?*raw.blocks.Block_layout,

        const Self = @This();

        /// Initialize with a Block handle, OwnedBlock, or raw Block pointer.
        pub fn init(blk: anytype) Self {
            const ArgType = @TypeOf(blk);
            if (ArgType == Self) return blk;
            if (@hasDecl(ArgType, "toRaw")) {
                return .{ .raw_ptr = blk.toRaw() };
            } else if (@hasDecl(ArgType, "borrow")) {
                return .{ .raw_ptr = blk.borrow().toRaw() };
            } else if (@typeInfo(ArgType) == .pointer) {
                return .{ .raw_ptr = @ptrCast(@constCast(blk)) };
            } else {
                @compileError("BlockRef requires a Block handle or pointer, got " ++ @typeName(ArgType));
            }
        }

        /// Returns the underlying raw Block pointer.
        pub fn rawPtr(self: Self) ?*raw.blocks.Block_layout {
            return self.raw_ptr;
        }
    };
}
