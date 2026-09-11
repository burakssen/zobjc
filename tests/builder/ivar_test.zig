//! Instance variable layout, alignment, and storage tests.

const std = @import("std");
const objc = @import("objc");
const testing = std.testing;

test "Ivar: alignment log2 computation permanent regression test" {
    // Permanent regression test for the byte-alignment vs log2-alignment bug.
    // 8-byte pointer alignment must yield log2(8) == 3, NOT 8!
    const StoragePtr = objc.StorageType(?objc.Object);
    try testing.expectEqual(8, @alignOf(StoragePtr));
    const log2_ptr: u8 = @intCast(std.math.log2_int(usize, @alignOf(StoragePtr)));
    try testing.expectEqual(3, log2_ptr);

    // 4-byte integer alignment must yield log2(4) == 2
    const StorageInt = objc.StorageType(c_int);
    try testing.expectEqual(4, @alignOf(StorageInt));
    const log2_int: u8 = @intCast(std.math.log2_int(usize, @alignOf(StorageInt)));
    try testing.expectEqual(2, log2_int);

    // 2-byte short alignment must yield log2(2) == 1
    const StorageShort = objc.StorageType(c_short);
    try testing.expectEqual(2, @alignOf(StorageShort));
    const log2_short: u8 = @intCast(std.math.log2_int(usize, @alignOf(StorageShort)));
    try testing.expectEqual(1, log2_short);

    // 1-byte char/bool alignment must yield log2(1) == 0
    const StorageByte = objc.StorageType(u8);
    try testing.expectEqual(1, @alignOf(StorageByte));
    const log2_byte: u8 = @intCast(std.math.log2_int(usize, @alignOf(StorageByte)));
    try testing.expectEqual(0, log2_byte);
}

test "ClassBuilder: adding typed ivars and inspecting metadata" {
    const NSObject = objc.requireClass("NSObject");
    var builder = try objc.ClassBuilder.init("ZigTest_Ivar_Typed", NSObject);
    errdefer builder.abort();

    try builder.addIvar(c_int, "_intVal");
    try builder.addIvar(f64, "_doubleVal");
    try builder.addIvar(?objc.Object, "_objVal");

    const cls = builder.register();

    // Inspect _intVal
    const ivar_int = cls.instanceIvar("_intVal");
    try testing.expect(ivar_int != null);
    try testing.expectEqualStrings("_intVal", ivar_int.?.name().?);
    try testing.expectEqualStrings("i", ivar_int.?.typeEncoding().?);

    // Inspect _doubleVal
    const ivar_double = cls.instanceIvar("_doubleVal");
    try testing.expect(ivar_double != null);
    try testing.expectEqualStrings("_doubleVal", ivar_double.?.name().?);
    try testing.expectEqualStrings("d", ivar_double.?.typeEncoding().?);

    // Inspect _objVal
    const ivar_obj = cls.instanceIvar("_objVal");
    try testing.expect(ivar_obj != null);
    try testing.expectEqualStrings("_objVal", ivar_obj.?.name().?);
    try testing.expectEqualStrings("@", ivar_obj.?.typeEncoding().?);
}

test "ClassBuilder: duplicate ivar detection" {
    const NSObject = objc.requireClass("NSObject");
    var builder = try objc.ClassBuilder.init("ZigTest_Ivar_Duplicate", NSObject);
    defer builder.abort();

    try builder.addIvar(c_int, "_dup");
    const dup_res = builder.addIvar(c_int, "_dup");
    try testing.expectError(error.IvarAlreadyExists, dup_res);
}

test "ClassBuilder: addIvarEncoded escape hatch" {
    const NSObject = objc.requireClass("NSObject");
    var builder = try objc.ClassBuilder.init("ZigTest_Ivar_Encoded", NSObject);
    errdefer builder.abort();

    // Custom ivar with 16 bytes, alignment 4 (log2 2), custom encoding
    try builder.addIvarEncoded("_custom", 16, 2, "[4i]");

    const cls = builder.register();
    const ivar_custom = cls.instanceIvar("_custom");
    try testing.expect(ivar_custom != null);
    try testing.expectEqualStrings("_custom", ivar_custom.?.name().?);
    try testing.expectEqualStrings("[4i]", ivar_custom.?.typeEncoding().?);
}
