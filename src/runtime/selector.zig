//! Objective-C method selector representation.

const std = @import("std");
const raw = @import("../raw/root.zig");

/// Shorthand, equivalent to Selector.registerName.
pub inline fn sel(name: [:0]const u8) Selector {
    return Selector.registerName(name);
}

/// A typed wrapper representing an Objective-C selector (`SEL`).
pub const Selector = struct {
    value: raw.SEL,

    /// Registers a method with the Objective-C runtime system, maps the
    /// method name to a selector, and returns the selector value.
    pub fn registerName(name: [:0]const u8) Selector {
        return Selector{
            .value = raw.objc.sel_registerName(name.ptr),
        };
    }

    /// Returns the name of the method specified by a given selector.
    pub fn getName(self: Selector) [:0]const u8 {
        return std.mem.span(raw.objc.sel_getName(self.value));
    }
};

/// Backward compatibility alias for Selector.
pub const Sel = Selector;
