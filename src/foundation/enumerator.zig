//! Typed handle for Foundation NSEnumerator objects.
// ponytail: minimalist wrapper around nextObject and allObjects, standard Zig iterator interface.

const std = @import("std");
const objc = @import("objc");

/// Typed handle to an Objective-C `NSEnumerator` instance.
pub const NSEnumerator = struct {
    object: objc.Object,

    pub inline fn asObject(self: NSEnumerator) objc.Object {
        return self.object;
    }

    pub inline fn fromObject(obj: objc.Object) NSEnumerator {
        return .{ .object = obj };
    }

    pub inline fn toRaw(self: NSEnumerator) objc.raw.id {
        return self.object.ptr;
    }

    /// Fetches the next object from the enumerator, or `null` when exhausted.
    pub fn nextObject(self: NSEnumerator) ?objc.Object {
        return objc.send(?objc.Object, self.object, "nextObject", .{});
    }

    /// Returns an NSArray of all remaining objects in the enumerator.
    pub fn allObjects(self: NSEnumerator) objc.Object {
        return objc.send(objc.Object, self.object, "allObjects", .{});
    }

    /// Returns a standard Zig iterator over this enumerator.
    pub fn iterator(self: NSEnumerator) Iterator {
        return .{ .enumerator = self };
    }

    pub const Iterator = struct {
        enumerator: NSEnumerator,

        pub fn next(self: *Iterator) ?objc.Object {
            return self.enumerator.nextObject();
        }
    };
};

comptime {
    std.debug.assert(@sizeOf(NSEnumerator) == @sizeOf(objc.Object));
    std.debug.assert(@alignOf(NSEnumerator) == @alignOf(objc.Object));
}
