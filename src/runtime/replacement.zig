//! Reversible Objective-C method implementation replacement.
//!
//! Replaces method implementations with raw IMPs, Zig callbacks, or Blocks,
//! verifying that no intervening modifications occurred before restoration.

const std = @import("std");
const raw = @import("../raw/root.zig");
const Method = @import("method.zig").Method;
const Imp = @import("imp.zig").Imp;
const block = @import("../block/root.zig");
const builder_callback = @import("../builder/internal/callback.zig");

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

    /// Replaces `method` implementation with a typed Zig callback function.
    pub fn replaceWith(method: Method, comptime callback: anytype) MethodReplacement {
        // // ponytail: reuse Phase 7 method trampoline and signature check
        const trampoline = builder_callback.MethodTrampoline(callback).Runner.trampoline;
        const new_imp = Imp.fromRawNonNull(@ptrCast(&trampoline));

        return replace(method, new_imp);
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
