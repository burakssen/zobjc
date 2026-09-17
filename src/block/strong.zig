//! Objective-C strong object capture wrapper for Blocks.
//!
//! Stores the raw pointer in the Block literal and manages lifetime via
//! _Block_object_assign / _Block_object_dispose with BLOCK_FIELD_IS_OBJECT.

const std = @import("std");
const raw = @import("raw");
const Object = @import("runtime").Object;

/// Type-safe strong object capture wrapper for Apple Blocks.
pub fn Strong(comptime T: type) type {
    return struct {
        pub const _is_zobjc_strong = true;
        pub const ReferentType = T;

        raw_ptr: ?*anyopaque,

        const Self = @This();

        /// Initialize with an Objective-C object, wrapper, or raw pointer.
        pub fn init(obj: anytype) Self {
            const ArgType = @TypeOf(obj);
            if (ArgType == Self) return obj;
            if (ArgType == Object) {
                return .{ .raw_ptr = @ptrCast(obj.toRaw()) };
            } else if (ArgType == ?Object) {
                if (obj) |o| {
                    return .{ .raw_ptr = @ptrCast(o.toRaw()) };
                }
                return .{ .raw_ptr = null };
            } else if (@typeInfo(ArgType) == .pointer) {
                return .{ .raw_ptr = @ptrCast(@constCast(obj)) };
            } else if (@typeInfo(ArgType) == .optional and @typeInfo(@typeInfo(ArgType).optional.child) == .pointer) {
                if (obj) |p| {
                    return .{ .raw_ptr = @ptrCast(@constCast(p)) };
                }
                return .{ .raw_ptr = null };
            } else if (@hasDecl(ArgType, "toRaw")) {
                return .{ .raw_ptr = @ptrCast(obj.toRaw()) };
            } else {
                @compileError("Strong(T) requires an Objective-C object or pointer, got " ++ @typeName(ArgType));
            }
        }

        /// Returns the wrapped object as its target type.
        pub fn borrow(self: Self) T {
            if (T == Object) {
                const p = self.raw_ptr orelse @panic("attempted to borrow nil Strong(Object)");
                return Object.fromRaw(@ptrCast(p)).?;
            } else if (T == ?Object) {
                if (self.raw_ptr) |p| {
                    return Object.fromRaw(@ptrCast(p));
                }
                return null;
            } else if (@typeInfo(T) == .pointer) {
                const p = self.raw_ptr orelse @panic("attempted to borrow nil pointer");
                return @ptrCast(@alignCast(p));
            } else if (@typeInfo(T) == .optional) {
                if (self.raw_ptr) |p| {
                    return @ptrCast(@alignCast(p));
                }
                return null;
            } else {
                @compileError("Unsupported Strong referent type " ++ @typeName(T));
            }
        }

        /// Returns the underlying raw pointer.
        pub fn rawPtr(self: Self) ?*anyopaque {
            return self.raw_ptr;
        }

        /// Returns raw id handle for Objective-C runtime functions.
        pub fn rawId(self: Self) raw.id {
            return @ptrCast(self.raw_ptr);
        }
    };
}

test "Strong(Object) wrapper" {
    const NSObject = Object.fromRaw(@ptrCast(raw.runtime.objc_getClass("NSObject").?)).?;
    const strong = Strong(Object).init(NSObject);
    try std.testing.expect(strong.rawPtr() != null);
    const borrowed = strong.borrow();
    try std.testing.expectEqual(NSObject.toRaw(), borrowed.toRaw());
}
