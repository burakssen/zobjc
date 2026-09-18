//! Reversible Objective-C method implementation replacement.
//!
//! Replaces method implementations with raw IMPs, Zig callbacks, or Blocks,
//! verifying that no intervening modifications occurred before restoration.

const raw = @import("raw");
const Method = @import("method.zig").Method;
const Imp = @import("imp.zig").Imp;

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
