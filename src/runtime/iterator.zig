//! Fast enumeration protocol iterator for Objective-C collections.
//!
//! TODO(phase-10): Move NSFastEnumeration integration into foundation/.

const std = @import("std");
const raw = @import("../raw/root.zig");
const c = raw.c;
const selector_pkg = @import("selector.zig");
const Selector = selector_pkg.Selector;
const sel_fn = selector_pkg.sel;
const Object = @import("object.zig").Object;

// From <Foundation/NSEnumerator.h>.
const NSFastEnumerationState = extern struct {
    state: c_ulong = 0,
    itemsPtr: ?[*]c.id = null,
    mutationsPtr: ?*c_ulong = null,
    extra: [5]c_ulong = [_]c_ulong{0} ** 5,
};

/// An iterator that uses the fast enumeration protocol to iterate over
/// objects in an Objective-C collection conforming to `NSFastEnumeration`.
pub const Iterator = struct {
    object: Object,
    sel: Selector,
    state: NSFastEnumerationState = .{},
    initial_mutations_value: ?c_ulong = null,
    buffer: [16]c.id = [_]c.id{null} ** 16,
    slice: []const c.id = &.{},

    pub fn init(object: Object) Iterator {
        return .{
            .object = object,
            .sel = sel_fn("countByEnumeratingWithState:objects:count:"),
        };
    }

    pub fn next(self: *Iterator) ?Object {
        if (self.slice.len == 0) {
            const count = self.object.msgSend(c_ulong, self.sel, .{
                &self.state,
                &self.buffer,
                self.buffer.len,
            });
            if (self.initial_mutations_value) |value| {
                if (value != self.state.mutationsPtr.?.*) {
                    c.objc_enumerationMutation(self.object.value);
                }
            } else {
                self.initial_mutations_value = self.state.mutationsPtr.?.*;
            }
            self.slice = self.state.itemsPtr.?[0..count];
        }

        if (self.slice.len == 0) return null;

        const first = self.slice[0];
        self.slice = self.slice[1..];
        return Object.fromId(first);
    }
};
