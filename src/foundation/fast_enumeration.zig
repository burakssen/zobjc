//! Fast enumeration protocol iterator for Objective-C collections.
// ponytail: stack-allocated buffer (zero heap allocation), safe mutation detection returning error.CollectionMutated.

const std = @import("std");
const objc = @import("objc");

/// Fast enumeration state structure matching Apple's `<Foundation/NSEnumerator.h>` ABI.
pub const NSFastEnumerationState = extern struct {
    state: c_ulong = 0,
    items_ptr: ?[*]objc.raw.id = null,
    mutations_ptr: ?*c_ulong = null,
    extra: [5]c_ulong = [_]c_ulong{0} ** 5,
};

/// High-performance iterator for Objective-C collections conforming to `NSFastEnumeration`.
///
/// Uses a stack-allocated buffer of `capacity` element pointers, incurring zero heap allocations.
/// Transparently handles collections pointing `items_ptr` to internal backing arrays.
/// Detects concurrent collection mutation and returns `error.CollectionMutated`.
pub fn FastEnumerationIterator(comptime capacity: usize) type {
    return struct {
        const Self = @This();

        collection: objc.Object,
        sel: objc.Selector,
        state: NSFastEnumerationState = .{},
        initial_mutations: ?c_ulong = null,
        buffer: [capacity]objc.raw.id = [_]objc.raw.id{null} ** capacity,
        slice: []const objc.raw.id = &.{},

        /// Initializes a fast enumeration iterator over the given collection object.
        pub fn init(collection: objc.Object) Self {
            return .{
                .collection = collection,
                .sel = objc.sel("countByEnumeratingWithState:objects:count:"),
            };
        }

        /// Fetches the next object in the collection.
        ///
        /// Returns `null` when the iteration finishes.
        /// Returns `error.CollectionMutated` if the collection was modified during iteration.
        pub fn next(self: *Self) !?objc.Object {
            // Verify mutation guard on each element, matching Clang for-in code generation
            if (self.state.mutations_ptr) |mut_ptr| {
                const current_mut = mut_ptr.*;
                if (self.initial_mutations) |init_mut| {
                    if (init_mut != current_mut) {
                        return error.CollectionMutated;
                    }
                }
            }

            if (self.slice.len == 0) {
                const count = self.collection.msgSend(
                    c_ulong,
                    self.sel,
                    .{
                        &self.state,
                        &self.buffer,
                        @as(c_ulong, @intCast(capacity)),
                    },
                );

                if (count == 0) return null;

                if (self.state.mutations_ptr) |mut_ptr| {
                    const current_mut = mut_ptr.*;
                    if (self.initial_mutations) |init_mut| {
                        if (init_mut != current_mut) {
                            return error.CollectionMutated;
                        }
                    } else {
                        self.initial_mutations = current_mut;
                    }
                }

                const items = self.state.items_ptr orelse return null;
                self.slice = items[0..count];
            }

            if (self.slice.len == 0) return null;

            const first = self.slice[0];
            self.slice = self.slice[1..];
            if (first == null) return null;
            return objc.Object.fromId(first);
        }
    };
}

/// Convenience helper to create a default 16-element stack-buffered fast enumeration iterator.
pub fn fastIterate(collection: anytype) FastEnumerationIterator(16) {
    const T = @TypeOf(collection);
    const obj = if (T == objc.Object)
        collection
    else if (@hasDecl(T, "asObject"))
        collection.asObject()
    else
        @compileError("fastIterate requires an objc.Object or a type implementing .asObject()");

    return FastEnumerationIterator(16).init(obj);
}

comptime {
    std.debug.assert(@sizeOf(NSFastEnumerationState) == 64);
    std.debug.assert(@alignOf(NSFastEnumerationState) == 8);
}
