//! Objective-C instance variable (Ivar) handle.
//!
//! A non-owning, non-null handle to an Objective-C instance variable (`Ivar`).

const std = @import("std");
const testing = std.testing;
const objc = @import("zobjc");
const raw = @import("raw");
const conversion = @import("conversion.zig");
const encoding = @import("encoding");

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

test "ivar: dynamic class ivar introspection" {
    const NSObject = objc.requireClass("NSObject");
    const Subclass = objc.allocateClassPair(NSObject, "IvarTestClass").?;

    _ = Subclass.addIvar("test_int", @sizeOf(i32), @truncate(std.math.log2(@alignOf(i32))), "i");
    _ = Subclass.addIvar("test_ptr", @sizeOf(objc.raw.id), @truncate(std.math.log2(@alignOf(objc.raw.id))), "@");

    objc.registerClassPair(Subclass);
    defer objc.disposeClassPair(Subclass);

    const ivar_int = Subclass.instanceIvar("test_int").?;
    const ivar_ptr = Subclass.instanceIvar("test_ptr").?;
    try testing.expectEqualStrings("test_int", ivar_int.name().?);
    try testing.expectEqualStrings("test_ptr", ivar_ptr.name().?);
    try testing.expectEqualStrings("i", ivar_int.typeEncoding().?);
    try testing.expectEqualStrings("@", ivar_ptr.typeEncoding().?);

    const off_int = ivar_int.offset();
    const off_ptr = ivar_ptr.offset();
    try testing.expect(off_int >= 0);
    try testing.expect(off_ptr >= 0);
    try testing.expect(off_int != off_ptr);
    try testing.expect(ivar_int.eql(ivar_int));
    try testing.expect(!ivar_int.eql(ivar_ptr));
}

test "conversion: Ivar handle is pointer-sized and pointer-aligned" {
    try testing.expectEqual(@sizeOf(usize), @sizeOf(Ivar));
    try testing.expectEqual(@alignOf(usize), @alignOf(Ivar));
}
