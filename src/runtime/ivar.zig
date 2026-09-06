//! Objective-C instance variable (Ivar) handle.
//!
//! A non-owning, non-null handle to an Objective-C instance variable (`Ivar`).

const std = @import("std");
const raw = @import("../raw/root.zig");
const conversion = @import("conversion.zig");
const encoding = @import("../encoding/root.zig");

pub const Ivar = struct {
    ptr: *raw.objc_ivar,

    /// Converts a raw nullable `raw.Ivar` into an optional `Ivar`.
    pub inline fn fromRaw(val: raw.Ivar) ?Ivar {
        const p = val orelse return null;
        return .{ .ptr = p };
    }

    /// Converts this `Ivar` into its raw `raw.Ivar` pointer.
    pub inline fn toRaw(self: Ivar) raw.Ivar {
        return self.ptr;
    }

    /// Creates an `Ivar` from a known non-null raw ivar pointer.
    pub inline fn fromRawNonNull(p: *raw.objc_ivar) Ivar {
        return .{ .ptr = p };
    }

    /// Returns the name of the instance variable.
    pub inline fn name(self: Ivar) ?[:0]const u8 {
        return conversion.spanNullableCString(raw.runtime.ivar_getName(self.ptr));
    }

    /// Alias for name() to match naming parity.
    pub inline fn getName(self: Ivar) ?[:0]const u8 {
        return self.name();
    }

    /// Returns the type encoding string of the instance variable.
    pub inline fn typeEncoding(self: Ivar) ?[:0]const u8 {
        return conversion.spanNullableCString(raw.runtime.ivar_getTypeEncoding(self.ptr));
    }

    /// Returns the byte offset of the instance variable from the base of the object instance.
    pub inline fn offset(self: Ivar) isize {
        return raw.runtime.ivar_getOffset(self.ptr);
    }

    /// Tests ivar equality by comparing pointer addresses.
    pub inline fn eql(self: Ivar, other: Ivar) bool {
        return self.ptr == other.ptr;
    }

    /// Parses the instance variable's type encoding into a structured `QualifiedType`.
    pub fn parsedType(self: Ivar, allocator: std.mem.Allocator) !?encoding.QualifiedType {
        const enc = self.typeEncoding() orelse return null;
        return try encoding.parse(allocator, enc);
    }

    comptime {
        std.debug.assert(@sizeOf(@This()) == @sizeOf(raw.Ivar));
        std.debug.assert(@alignOf(@This()) == @alignOf(raw.Ivar));
    }
};
