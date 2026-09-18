//! Block-backed method implementation replacement.
//!
//! Integrates a runtime `Method` with a Block-owned `IMP`, managing the
//! backing Block lifetime across installation and restoration. Lives in
//! `block` (not `runtime`) so the runtime module does not depend upward.

const raw = @import("raw");
const Method = @import("runtime").Method;
const Imp = @import("runtime").Imp;
const imp_mod = @import("imp.zig");

/// Block-backed method replacement managing `OwnedImp` lifetime.
pub const BlockMethodReplacement = struct {
    method: Method,
    imp: imp_mod.OwnedImp,
    previous: Imp,
    active: bool,

    const Self = @This();

    /// Replaces `method` implementation with an Objective-C Block.
    pub fn replace(method: Method, block_handle: anytype) !BlockMethodReplacement {
        var owned_imp = try imp_mod.makeImp(block_handle);
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
