//! Strong-ownership smart pointer for Objective-C objects.
//!
//! A `Retained(T)` owns exactly one +1 reference to an Objective-C object.
//! Deinitializing it releases that reference via `objc_release`.

const raw = @import("raw");
const traits = @import("traits.zig");

/// A type-safe smart pointer that owns exactly one strong reference (+1) to an
/// Objective-C object of type `T`.
///
/// Move-only by convention (Zig cannot enforce this): NEVER copy a `Retained`
/// by value. `var b = a;` creates two Zig values for one +1 obligation and a
/// subsequent double `deinit()` double-releases. Pass owners by pointer
/// (`*Retained(T)`), transfer by returning by value, duplicate with `clone()`.
///
/// ```zig
/// var a = Retained(Object).adopt(obj);
/// defer a.deinit();
/// var b = a.clone(); // second independent +1 — the only legal "copy"
/// defer b.deinit();
/// ```
pub fn Retained(comptime T: type) type {
    comptime {
        if (!traits.isRetainable(T)) {
            @compileError(@typeName(T) ++ " is not an Objective-C retainable object type. " ++
                "Only Object and types implementing .asObject()/.fromObject() can be retained.");
        }
    }

    return struct {
        value: ?T,

        const Self = @This();

        /// Retains a borrowed (+0) reference to create a new strong ownership obligation (+1).
        pub fn retain(val: T) Self {
            const raw_id = traits.toRawId(val);
            _ = raw.compiler_runtime.objc_retain(raw_id);
            return .{ .value = val };
        }

        /// Adopts an existing +1 reference without incrementing the retain count.
        /// Transfers ownership responsibility to this wrapper.
        pub fn adopt(val: T) Self {
            return .{ .value = val };
        }

        /// Returns the underlying non-owning handle (+0).
        ///
        /// The returned handle remains valid only for the duration of this wrapper's lifetime.
        pub fn borrow(self: *const Self) T {
            return self.value orelse @panic("attempted to borrow from deinitialized Retained");
        }

        /// Creates a second independent strong owner (+1) for the same object.
        pub fn clone(self: *const Self) Self {
            return Self.retain(self.borrow());
        }

        /// Releases the owned reference (+1) via `objc_release`.
        /// Idempotent: safe to call multiple times (subsequent calls do nothing).
        pub fn deinit(self: *Self) void {
            if (self.value) |v| {
                const raw_id = traits.toRawId(v);
                raw.compiler_runtime.objc_release(raw_id);
                self.value = null;
            }
        }

        /// Transfers the +1 ownership obligation back to the caller without releasing.
        /// The wrapper becomes invalid after this call.
        pub fn intoUnmanaged(self: *Self) T {
            const v = self.value orelse @panic("attempted to call intoUnmanaged on deinitialized Retained");
            self.value = null;
            return v;
        }

        /// Convenience helper: retains an optional object if non-null.
        pub fn retainOptional(val: ?T) ?Self {
            if (val) |v| {
                return Self.retain(v);
            }
            return null;
        }

        /// Convenience helper: adopts an optional object if non-null.
        pub fn adoptOptional(val: ?T) ?Self {
            if (val) |v| {
                return Self.adopt(v);
            }
            return null;
        }
    };
}




