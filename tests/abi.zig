const objc = @import("zobjc");
const std = @import("std");
const testing = std.testing;

test "integration: handles classify like raw handles on both macos targets" {
    const HandlePair = struct { handle: type, raw_handle: type };
    const pairs = [_]HandlePair{
        .{ .handle = objc.Object, .raw_handle = objc.raw.id },
        .{ .handle = ?objc.Object, .raw_handle = objc.raw.id },
        .{ .handle = objc.Class, .raw_handle = objc.raw.Class },
        .{ .handle = ?objc.Class, .raw_handle = objc.raw.Class },
        .{ .handle = objc.Selector, .raw_handle = objc.raw.SEL },
        .{ .handle = ?objc.Selector, .raw_handle = objc.raw.SEL },
        .{ .handle = objc.Imp, .raw_handle = objc.raw.IMP },
        .{ .handle = ?objc.Imp, .raw_handle = objc.raw.IMP },
        .{ .handle = objc.Protocol, .raw_handle = objc.raw.id },
        .{ .handle = ?objc.Protocol, .raw_handle = objc.raw.id },
    };
    inline for ([_]objc.abi.Target{ objc.abi.Target.macos_arm64, objc.abi.Target.macos_x86_64 }) |target| {
        inline for (pairs) |pair| {
            try std.testing.expectEqual(
                objc.abi.returnConventionFor(target, pair.raw_handle),
                objc.abi.returnConventionFor(target, pair.handle),
            );
            try std.testing.expectEqual(
                .normal,
                objc.abi.returnConventionFor(target, pair.handle),
            );
            try std.testing.expectEqual(
                objc.abi.classifyReturn(target, pair.raw_handle),
                objc.abi.classifyReturn(target, pair.handle),
            );
        }
    }
}

test "integration: real handle encodings match wrapper-trait semantics" {
    const check = struct {
        fn enc(comptime T: type, expected: []const u8) !void {
            const actual = comptime objc.encoding.comptimeEncode(T);
            try std.testing.expectEqualStrings(expected, &actual);
        }
    }.enc;
    try check(objc.Object, "@");
    try check(?objc.Object, "@");
    try check(objc.Class, "#");
    try check(?objc.Class, "#");
    try check(objc.Selector, ":");
    try check(?objc.Selector, ":");
    try check(objc.Imp, "^?");
    try check(objc.Protocol, "@");
    try std.testing.expect(objc.encoding.zig_type.isObjCEncodable(objc.Protocol));
    try std.testing.expect(objc.encoding.zig_type.isObjCEncodable(objc.Imp));
    try std.testing.expectEqual(objc.raw.id, objc.encoding.StorageType(objc.Object));
    try std.testing.expectEqual(objc.raw.Class, objc.encoding.StorageType(objc.Class));
    try std.testing.expectEqual(objc.raw.SEL, objc.encoding.StorageType(objc.Selector));
    try std.testing.expectEqual(objc.raw.IMP, objc.encoding.StorageType(objc.Imp));
    try std.testing.expectEqual(objc.raw.Protocol, objc.encoding.StorageType(objc.Protocol));
    const InstanceCallback = fn (objc.Object, objc.Selector, i32) callconv(.c) void;
    const ClassCallback = fn (objc.Class, objc.Selector, i32) callconv(.c) void;
    try std.testing.expectEqualStrings("v@:i", &objc.encoding.methodEncoding(InstanceCallback));
    try std.testing.expectEqualStrings("v@:i", &objc.encoding.methodEncoding(ClassCallback));
}
