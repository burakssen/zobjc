//! Zeroing weak reference wrapper for Objective-C objects.
//!
//! Apple's Objective-C runtime tracks the exact memory address of weak storage slots.
//! Therefore, Weak(T) must be initialized in-place:
//!
//! ```zig
//! var weak: objc.Weak(objc.Object) = .{};
//! weak.init(object);
//! defer weak.deinit();
//! ```

const std = @import("std");
const assert = std.debug.assert;
const raw = @import("raw");
const traits = @import("traits.zig");
const Retained = @import("retained.zig").Retained;

/// An address-sensitive zeroing weak reference to an Objective-C object of type `T`.
///
/// MUST NOT be copied by value with ordinary assignment after initialization.
/// Use `.copyFrom()` or `.moveFrom()` to copy or relocate weak storage.
pub fn Weak(comptime T: type) type {
    comptime {
        if (!traits.isRetainable(T)) {
            @compileError(@typeName(T) ++ " is not an Objective-C retainable object type. " ++
                "Only Object and types implementing .asObject()/.fromObject() can be weakly referenced.");
        }
    }

    return struct {
        slot: raw.id = null,
        initialized: bool = false,

        const Self = @This();

        /// Initializes the weak pointer variable in-place.
        ///
        /// Registers the address of `self.slot` with the Objective-C runtime weak table.
        pub fn init(self: *Self, value: ?T) void {
            assert(!self.initialized);
            const raw_id = if (value) |v| traits.toRawId(v) else null;
            _ = raw.compiler_runtime.objc_initWeak(&self.slot, raw_id);
            self.initialized = true;
        }

        /// Updates the referenced object, or sets it to nil without destroying the slot.
        pub fn store(self: *Self, value: ?T) void {
            assert(self.initialized);
            const raw_id = if (value) |v| traits.toRawId(v) else null;
            _ = raw.compiler_runtime.objc_storeWeak(&self.slot, raw_id);
        }

        /// Clears the referenced object to nil. The weak slot remains initialized.
        pub inline fn clear(self: *Self) void {
            self.store(null);
        }

        /// Loads and retains the referenced object atomically via `objc_loadWeakRetained`.
        ///
        /// Returns a strong `Retained(T)` owner, or `null` if the object has been deallocated or slot is uninitialized.
        /// This is the safest way to read a weak reference.
        pub fn loadRetained(self: *Self) ?Retained(T) {
            if (!self.initialized) return null;
            const raw_id = raw.compiler_runtime.objc_loadWeakRetained(&self.slot);
            if (raw_id) |p| {
                return Retained(T).adopt(traits.fromRawIdNonNull(T, p));
            }
            return null;
        }

        /// Loads the referenced object via `objc_loadWeak` (returns an autoreleased borrow), or `null` if uninitialized.
        pub fn loadBorrowed(self: *Self) ?T {
            if (!self.initialized) return null;
            const raw_id = raw.compiler_runtime.objc_loadWeak(&self.slot);
            if (raw_id) |p| {
                return traits.fromRawIdNonNull(T, p);
            }
            return null;
        }

        /// Copies a weak reference from `source` to `destination` via `objc_copyWeak`.
        /// `destination` must be uninitialized, and `source` must be initialized.
        pub fn copyFrom(destination: *Self, source: *const Self) void {
            assert(!destination.initialized);
            assert(source.initialized);
            raw.compiler_runtime.objc_copyWeak(&destination.slot, @constCast(&source.slot));
            destination.initialized = true;
        }

        /// Moves a weak reference from `source` to `destination` via `objc_moveWeak`.
        /// `destination` must be uninitialized, and `source` must be initialized.
        /// After the move, `source` is reset to uninitialized state.
        pub fn moveFrom(destination: *Self, source: *Self) void {
            assert(!destination.initialized);
            assert(source.initialized);
            raw.compiler_runtime.objc_moveWeak(&destination.slot, &source.slot);
            destination.initialized = true;
            source.initialized = false;
            source.slot = null;
        }

        /// Destroys the weak reference registration via `objc_destroyWeak`.
        /// Idempotent: safe to call multiple times.
        pub fn deinit(self: *Self) void {
            if (self.initialized) {
                raw.compiler_runtime.objc_destroyWeak(&self.slot);
                self.slot = null;
                self.initialized = false;
            }
        }
    };
}




