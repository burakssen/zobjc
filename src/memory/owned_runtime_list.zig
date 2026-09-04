//! Generic caller-freed list wrapper for Objective-C runtime copy arrays.
//!
//! Wraps count-delimited arrays returned by APIs such as `class_copyMethodList`,
//! `class_copyIvarList`, `class_copyPropertyList`, `class_copyProtocolList`,
//! `objc_copyClassList`, etc.
//!
//! Frees the underlying array buffer with `free()` upon `deinit()`.

const std = @import("std");
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
