//! Objective-C method implementation pointer handle (`IMP`).
//!
//! A non-owning, non-null handle representing an untyped C function pointer to a
//! method implementation. Cannot be invoked directly without explicit casting via `as(F)`.

const std = @import("std");
const raw = @import("../raw/root.zig");

pub const Imp = struct {
    ptr: *const fn () callconv(.c) void,

    /// Converts a raw nullable `raw.IMP` into an optional `Imp`.
    pub inline fn fromRaw(val: raw.IMP) ?Imp {
        const p = val orelse return null;
        return .{ .ptr = p };
    }

    /// Converts this `Imp` into its raw `raw.IMP` pointer.
    pub inline fn toRaw(self: Imp) raw.IMP {
        return self.ptr;
    }

    /// Creates an `Imp` from a known non-null function pointer.
    pub inline fn fromRawNonNull(p: *const fn () callconv(.c) void) Imp {
        return .{ .ptr = p };
    }

    /// Tests implementation pointer equality.
    pub inline fn eql(self: Imp, other: Imp) bool {
        return self.ptr == other.ptr;
    }

    /// Safely casts this untyped implementation pointer to an exact C function pointer type.
    ///
    /// Validates at compile time that `F` is a pointer to a function with C calling convention.
    pub inline fn as(self: Imp, comptime F: type) F {
        const info = @typeInfo(F);
        comptime {
            if (info != .pointer or info.pointer.size != .one or @typeInfo(info.pointer.child) != .@"fn") {
                @compileError("Imp.as: expected function pointer type, found " ++ @typeName(F));
            }
            const fn_info = @typeInfo(info.pointer.child).@"fn";
            if (fn_info.calling_convention != .c) {
                @compileError("Imp.as: target function pointer must use callconv(.c), found " ++ @tagName(fn_info.calling_convention));
            }
        }
        return @ptrCast(self.ptr);
    }

    comptime {
        std.debug.assert(@sizeOf(@This()) == @sizeOf(raw.IMP));
        std.debug.assert(@alignOf(@This()) == @alignOf(raw.IMP));
    }
};
