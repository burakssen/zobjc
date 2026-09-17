//! Low-level Block byref forwarding cell memory layout.
//!
//! Mirrors Apple libclosure's `struct Block_byref` and `struct Block_byref_2`.

const std = @import("std");
const raw = @import("raw");
const traits_mod = @import("capture_traits.zig");

/// Low-level memory layout for a __block (byref) cell storing value of type `T`.
pub fn ByRefCell(comptime T: type) type {
    const Traits = traits_mod.CaptureTraits(T);

    if (!Traits.requires_helpers) {
        return extern struct {
            isa: ?*anyopaque = null,
            forwarding: *Self,
            flags: c_int,
            size: u32,
            value: T,

            const Self = @This();

            pub fn initCell(self: *Self, val: T) void {
                self.isa = null;
                self.forwarding = self;
                self.flags = raw.blocks.BLOCK_BYREF_LAYOUT_NON_OBJECT;
                self.size = @sizeOf(Self);
                self.value = val;
            }
        };
    } else {
        return extern struct {
            isa: ?*anyopaque = null,
            forwarding: *Self,
            flags: c_int,
            size: u32,
            byref_keep: *const fn (dst: *anyopaque, src: *anyopaque) callconv(.c) void,
            byref_destroy: *const fn (src: *anyopaque) callconv(.c) void,
            value: T,

            const Self = @This();

            pub fn initCell(self: *Self, val: T) void {
                self.isa = null;
                self.forwarding = self;
                self.flags = raw.blocks.BLOCK_BYREF_HAS_COPY_DISPOSE | raw.blocks.BLOCK_BYREF_LAYOUT_STRONG;
                self.size = @sizeOf(Self);
                self.byref_keep = &keepHelper;
                self.byref_destroy = &destroyHelper;
                self.value = val;
            }

            fn keepHelper(dst_ptr: *anyopaque, src_ptr: *anyopaque) callconv(.c) void {
                const dst: *Self = @ptrCast(@alignCast(dst_ptr));
                const src: *Self = @ptrCast(@alignCast(src_ptr));
                raw.blocks._Block_object_assign(
                    @ptrCast(&dst.value.raw_ptr),
                    src.value.raw_ptr,
                    Traits.field_flags | raw.blocks.BLOCK_BYREF_CALLER,
                );
            }

            fn destroyHelper(src_ptr: *anyopaque) callconv(.c) void {
                const src: *Self = @ptrCast(@alignCast(src_ptr));
                raw.blocks._Block_object_dispose(
                    src.value.raw_ptr,
                    Traits.field_flags | raw.blocks.BLOCK_BYREF_CALLER,
                );
            }
        };
    }
}

test "ByRefCell layout" {
    const IntCell = ByRefCell(c_int);
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(IntCell));
    try std.testing.expectEqual(@as(usize, 0), @offsetOf(IntCell, "isa"));
    try std.testing.expectEqual(@as(usize, 8), @offsetOf(IntCell, "forwarding"));
    try std.testing.expectEqual(@as(usize, 16), @offsetOf(IntCell, "flags"));
    try std.testing.expectEqual(@as(usize, 20), @offsetOf(IntCell, "size"));
    try std.testing.expectEqual(@as(usize, 24), @offsetOf(IntCell, "value"));
}
