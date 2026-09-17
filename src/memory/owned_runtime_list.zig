//! Generic caller-freed list wrapper for Objective-C runtime copy arrays.
//!
//! Wraps count-delimited arrays returned by APIs such as `class_copyMethodList`,
//! `class_copyIvarList`, `class_copyPropertyList`, `class_copyProtocolList`,
//! `objc_copyClassList`, etc.
//!
//! Frees the underlying array buffer with `free()` upon `deinit()`.

const std = @import("std");
const testing = std.testing;
const objc = @import("zobjc");
const assert = std.debug.assert;
const c_free = @import("c_free.zig");

/// An owning wrapper for a runtime-allocated array of typed Objective-C handles `T`.
///
/// MUST NOT be copied by value.
pub fn OwnedRuntimeList(comptime T: type) type {
    const RawElement = @TypeOf(@as(T, undefined).toRaw());

    return struct {
        raw_ptr: ?*anyopaque,
        len: usize,

        const Self = @This();

        /// Creates an owned list from a raw pointer and element count.
        pub fn fromRaw(ptr: ?*anyopaque, count_val: usize) Self {
            if (ptr == null or count_val == 0) {
                // If the runtime returned an empty buffer, free it immediately and return empty
                if (ptr) |p| c_free.free(p);
                return Self.empty();
            }
            return .{
                .raw_ptr = ptr,
                .len = count_val,
            };
        }

        /// Returns a valid empty list.
        pub fn empty() Self {
            return .{
                .raw_ptr = null,
                .len = 0,
            };
        }

        /// Returns the number of items in the list.
        pub fn count(self: *const Self) usize {
            return self.len;
        }

        /// Returns whether the list is empty.
        pub fn isEmpty(self: *const Self) bool {
            return self.len == 0;
        }

        /// Returns the typed handle at the specified index, or null if out of bounds.
        pub fn get(self: *const Self, index: usize) ?T {
            if (index >= self.len or self.raw_ptr == null) {
                return null;
            }
            const slice: [*]const RawElement = @ptrCast(@alignCast(self.raw_ptr.?));
            return T.fromRaw(slice[index]);
        }

        /// Returns a standard iterator over the elements.
        pub fn iterator(self: *const Self) Iterator {
            return .{ .list = self, .index = 0 };
        }

        pub const Iterator = struct {
            list: *const Self,
            index: usize = 0,

            pub fn next(self: *Iterator) ?T {
                if (self.index >= self.list.len) return null;
                const item = self.list.get(self.index);
                self.index += 1;
                return item;
            }
        };

        /// Frees the allocated array buffer via `free()`.
        /// Idempotent: safe to call multiple times.
        pub fn deinit(self: *Self) void {
            if (self.raw_ptr) |p| {
                c_free.free(p);
                self.raw_ptr = null;
                self.len = 0;
            }
        }

        /// Allocates a normal Zig-owned slice of `T` using the provided allocator.
        pub fn dupe(self: *const Self, allocator: std.mem.Allocator) ![]T {
            const result = try allocator.alloc(T, self.len);
            errdefer allocator.free(result);
            for (0..self.len) |i| {
                result[i] = self.get(i).?;
            }
            return result;
        }
    };
}

test "OwnedRuntimeList: class.methods and dupe" {
    const NSObject = objc.requireClass("NSObject");
    var method_list = NSObject.methods();
    try testing.expect(!method_list.isEmpty());
    try testing.expect(method_list.count() > 0);
    const first_method = method_list.get(0).?;

    var iter = method_list.iterator();
    var iterated_count: usize = 0;
    while (iter.next()) |_| iterated_count += 1;
    try testing.expectEqual(method_list.count(), iterated_count);

    const duped = try method_list.dupe(testing.allocator);
    defer testing.allocator.free(duped);
    try testing.expectEqual(method_list.count(), duped.len);
    method_list.deinit();
    try testing.expect(method_list.isEmpty());
    try testing.expectEqual(first_method.toRaw(), duped[0].toRaw());
}

test "OwnedRuntimeList: class.classMethods" {
    var class_methods = objc.requireClass("NSObject").classMethods();
    defer class_methods.deinit();
    try testing.expect(!class_methods.isEmpty());
    try testing.expect(class_methods.count() > 0);
}

test "OwnedRuntimeList: class.properties" {
    var props = objc.requireClass("NSObject").properties();
    defer props.deinit();
    try testing.expect(!props.isEmpty());
    try testing.expect(props.count() > 0);
}

test "OwnedRuntimeList: class.protocols" {
    var protos = objc.requireClass("NSObject").protocols();
    defer protos.deinit();
    try testing.expect(protos.count() >= 0);
}

test "OwnedRuntimeList: class.ivars" {
    var ivars = objc.requireClass("NSObject").ivars();
    defer ivars.deinit();
    try testing.expect(ivars.count() >= 1);
    try testing.expectEqualStrings("isa", ivars.get(0).?.name().?);
}

test "OwnedRuntimeList: objc.classes" {
    var all_classes = objc.classes();
    defer all_classes.deinit();
    try testing.expect(all_classes.count() >= 5);

    var found_nsobject = false;
    var iter = all_classes.iterator();
    while (iter.next()) |cls| {
        if (std.mem.eql(u8, cls.name(), "NSObject")) {
            found_nsobject = true;
            break;
        }
    }
    try testing.expect(found_nsobject);
}

test "OwnedRuntimeList: objc.protocols" {
    var all_protocols = objc.protocols();
    defer all_protocols.deinit();
    try testing.expect(all_protocols.count() > 10);

    var found_nsobject_proto = false;
    var iter = all_protocols.iterator();
    while (iter.next()) |proto| {
        if (std.mem.eql(u8, proto.name(), "NSObject")) {
            found_nsobject_proto = true;
            break;
        }
    }
    try testing.expect(found_nsobject_proto);
}

test "OwnedRuntimeList: empty container behavior" {
    var empty_list = objc.memory.OwnedRuntimeList(objc.Method).empty();
    try testing.expect(empty_list.isEmpty());
    try testing.expectEqual(@as(usize, 0), empty_list.count());
    try testing.expect(empty_list.get(0) == null);
    var iter = empty_list.iterator();
    try testing.expect(iter.next() == null);
    empty_list.deinit();
    try testing.expect(empty_list.isEmpty());
}
