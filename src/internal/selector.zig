//! Shared Objective-C selector handle.
//!
//! Lives below `runtime`/`memory` so both can name the type without an
//! upward dependency. `runtime.Selector` is an alias of this struct.

const std = @import("std");
const raw = @import("raw");

/// A non-owning, non-null typed wrapper representing an Objective-C selector (`SEL`).
pub const Selector = struct {
    ptr: *raw.objc_selector,
    pub const objc_wrapper = true;

    /// Converts a raw nullable `raw.SEL` into an optional `Selector`.
    pub inline fn fromRaw(val: raw.SEL) ?Selector {
        const p = val orelse return null;
        return .{ .ptr = p };
    }

    /// Converts this `Selector` into its raw `raw.SEL` pointer.
    pub inline fn toRaw(self: Selector) raw.SEL {
        return self.ptr;
    }

    /// Creates a `Selector` from a known non-null raw selector pointer.
    pub inline fn fromRawNonNull(p: *raw.objc_selector) Selector {
        return .{ .ptr = p };
    }

    /// Registers a method name with the Objective-C runtime and returns the selector.
    pub fn register(sel_name: [:0]const u8) Selector {
        return .{ .ptr = raw.objc.sel_registerName(sel_name.ptr).? };
    }

    /// Returns the selector UID for a given method name.
    pub fn getUid(sel_name: [:0]const u8) Selector {
        return .{ .ptr = raw.objc.sel_getUid(sel_name.ptr).? };
    }

    /// Returns the name of the method specified by this selector.
    pub inline fn name(self: Selector) [:0]const u8 {
        return std.mem.span(raw.objc.sel_getName(self.ptr));
    }

    /// Returns whether this selector is registered with the runtime.
    pub inline fn isMapped(self: Selector) bool {
        return raw.boolResult(raw.objc.sel_isMapped(self.ptr));
    }

    /// Tests selector equality by comparing interned selector pointers.
    pub inline fn eql(self: Selector, other: Selector) bool {
        return self.ptr == other.ptr;
    }

    /// Returns a hash value for use in hash maps based on pointer address.
    pub inline fn hash(self: Selector) usize {
        return @intFromPtr(self.ptr);
    }

    comptime {
        std.debug.assert(@sizeOf(@This()) == @sizeOf(raw.SEL));
        std.debug.assert(@alignOf(@This()) == @alignOf(raw.SEL));
    }
};
