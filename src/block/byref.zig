//! High-level Objective-C __block (ByRef) variable abstraction.
//!
//! Provides in-place initialized stack cells with self-referential forwarding pointers
//! that seamlessly migrate to the heap when copied by an Apple Block.

const std = @import("std");
const raw = @import("../raw/root.zig");
const cell_mod = @import("byref_cell.zig");
const traits_mod = @import("capture_traits.zig");

/// Token representing a captured ByRef cell inside a Block literal.
pub fn ByRefCapture(comptime T: type) type {
    return struct {
        pub const _is_zobjc_byref_capture = true;
        pub const ReferentType = T;

        cell_ptr: *anyopaque,

        const Self = @This();
        const Cell = cell_mod.ByRefCell(T);

        /// Returns a pointer to the value through the forwarding pointer.
        pub inline fn get(self: Self) *T {
            const cell: *Cell = @ptrCast(@alignCast(self.cell_ptr));
            return &cell.forwarding.value;
        }

        /// Sets the value through the forwarding pointer.
        pub inline fn set(self: Self, val: T) void {
            self.get().* = val;
        }
    };
}

/// Address-stable holder for an Objective-C `__block` variable.
///
/// Usage:
/// ```zig
/// var counter: objc.block.ByRef(c_int) = .{};
/// counter.init(0);
/// defer counter.deinit();
///
/// var block = try Handler.capture(Captures, .{ .c = counter.capture() }, callback);
/// defer block.deinit();
/// ```
pub fn ByRef(comptime T: type) type {
    return struct {
        cell: Cell = undefined,
        initialized: bool = false,

        const Self = @This();
        const Traits = traits_mod.CaptureTraits(T);
        pub const Cell = cell_mod.ByRefCell(T);
        pub const Capture = ByRefCapture(T);

        /// Initializes the byref cell in-place.
        ///
        /// IMPORTANT: ByRef must not be moved or bitwise-copied after initialization,
        /// as its internal forwarding pointer refers directly to its address.
        pub fn init(self: *Self, value: T) void {
            self.cell.initCell(value);
            self.initialized = true;
        }

        /// Releases this scope's reference to the byref cell.
        ///
        /// If the cell was promoted to the heap by a Block copy, decrements the heap cell's
        /// refcount via _Block_object_dispose. If it remained on the stack, performs immediate cleanup.
        pub fn deinit(self: *Self) void {
            if (self.initialized) {
                if (Traits.requires_helpers and self.cell.forwarding == &self.cell) {
                    Traits.dispose(&self.cell.value.raw_ptr);
                } else {
                    raw.blocks._Block_object_dispose(
                        &self.cell,
                        raw.blocks.BLOCK_FIELD_IS_BYREF,
                    );
                }
                self.initialized = false;
            }
        }

        /// Returns a pointer to the current value, automatically following forwarding pointers.
        pub fn get(self: *Self) *T {
            std.debug.assert(self.initialized);
            return &self.cell.forwarding.value;
        }

        /// Creates a Block capture token referencing this cell.
        pub fn capture(self: *Self) Capture {
            std.debug.assert(self.initialized);
            return .{ .cell_ptr = @ptrCast(&self.cell) };
        }
    };
}

test "ByRef basic stack initialization and mutation" {
    var cell: ByRef(c_int) = .{};
    cell.init(42);
    defer cell.deinit();

    try std.testing.expectEqual(@as(c_int, 42), cell.get().*);
    cell.get().* = 100;
    try std.testing.expectEqual(@as(c_int, 100), cell.get().*);
}
