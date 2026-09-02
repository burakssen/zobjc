//! Ivar handle tests.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

test "ivar: dynamic class ivar introspection" {
    const NSObject = objc.requireClass("NSObject");
    const Subclass = objc.allocateClassPair(NSObject, "IvarTestClass").?;

    _ = Subclass.addIvar("test_int", @sizeOf(i32), @truncate(std.math.log2(@alignOf(i32))), "i");
    _ = Subclass.addIvar("test_ptr", @sizeOf(objc.raw.id), @truncate(std.math.log2(@alignOf(objc.raw.id))), "@");

    objc.registerClassPair(Subclass);
    defer objc.disposeClassPair(Subclass);

    const ivar_int = Subclass.instanceIvar("test_int").?;
    const ivar_ptr = Subclass.instanceIvar("test_ptr").?;

    // Name
    try testing.expectEqualStrings("test_int", ivar_int.name().?);
    try testing.expectEqualStrings("test_ptr", ivar_ptr.name().?);

    // Type encoding
    try testing.expectEqualStrings("i", ivar_int.typeEncoding().?);
    try testing.expectEqualStrings("@", ivar_ptr.typeEncoding().?);

    // Offsets should be non-negative and distinct
    const off_int = ivar_int.offset();
    const off_ptr = ivar_ptr.offset();
    try testing.expect(off_int >= 0);
    try testing.expect(off_ptr >= 0);
    try testing.expect(off_int != off_ptr);

    // Equality
    try testing.expect(ivar_int.eql(ivar_int));
    try testing.expect(!ivar_int.eql(ivar_ptr));
}
