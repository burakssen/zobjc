//! Objective-C weak object capture wrapper for Blocks.
//!
//! Stores a weak reference in the Block literal and manages lifetime via
//! _Block_object_assign / _Block_object_dispose with BLOCK_FIELD_IS_WEAK | BLOCK_FIELD_IS_OBJECT.

const std = @import("std");
const raw = @import("raw");
const Object = @import("runtime").Object;

/// Type-safe weak object capture wrapper for Apple Blocks.
pub fn Weak(comptime T: type) type {
    return struct {
        pub const _is_zobjc_weak = true;
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
                @compileError("Weak(T) requires an Objective-C object or pointer, got " ++ @typeName(ArgType));
            }
        }

        /// Returns the wrapped object as its target type.
        pub fn borrow(self: Self) ?T {
            if (self.raw_ptr) |p| {
                if (T == Object or T == ?Object) {
                    return Object.fromRaw(@ptrCast(p));
                } else if (@typeInfo(T) == .pointer) {
                    return @ptrCast(@alignCast(p));
                }
            }
            return null;
        }

        /// Returns the underlying raw pointer.
        pub fn rawPtr(self: Self) ?*anyopaque {
            return self.raw_ptr;
        }
    };
}
