//! Objective-C Block literal memory layout.
//!
//! Synthesizes the contiguous memory layout comprising the standard 32-byte
//! Block header followed immediately by the capture storage.

const std = @import("std");
const raw = @import("raw");

/// Synthesizes the complete Block literal type including capture payload.
pub fn Literal(comptime Captures: type) type {
    const size = @sizeOf(Captures);
    const alignment = @alignOf(Captures);

    if (size == 0) {
        return extern struct {
            header: raw.blocks.Block_layout,

            const Self = @This();

            pub fn getHeader(self: *Self) *raw.blocks.Block_layout {
                return &self.header;
            }

            pub fn getCaptures(self: anytype) if (@TypeOf(self) == *const Self) *const Captures else *Captures {
                const Dummy = struct {
                    var val: Captures = .{};
                };
                return &Dummy.val;
            }
        };
    }

    return extern struct {
        header: raw.blocks.Block_layout,
        captures_bytes: [size]u8 align(alignment),

        const Self = @This();

        pub fn getHeader(self: *Self) *raw.blocks.Block_layout {
            return &self.header;
        }

        pub fn getCaptures(self: anytype) if (@TypeOf(self) == *const Self) *const Captures else *Captures {
            return @ptrCast(@alignCast(&self.captures_bytes));
        }
    };
}

test "Literal layout" {
    const LitEmpty = Literal(struct {});
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(LitEmpty));

    const LitInt = Literal(struct { x: c_int });
    try std.testing.expectEqual(@as(usize, 40), @sizeOf(LitInt));
    try std.testing.expectEqual(@as(usize, 32), @offsetOf(LitInt, "captures_bytes"));
}
