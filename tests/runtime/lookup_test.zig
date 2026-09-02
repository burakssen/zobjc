//! Global class and protocol lookup tests.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

test "lookup: getClass and lookupClass" {
    // Existing class
    const cls1 = objc.getClass("NSObject");
    try testing.expect(cls1 != null);
    try testing.expectEqualStrings("NSObject", cls1.?.name());

    const cls2 = objc.lookupClass("NSObject");
    try testing.expect(cls2 != null);
    try testing.expect(cls1.?.eql(cls2.?));

    // Nonexistent class
    try testing.expectEqual(@as(?objc.Class, null), objc.getClass("NonExistentClass98765"));
    try testing.expectEqual(@as(?objc.Class, null), objc.lookupClass("NonExistentClass98765"));
}

test "lookup: requireClass" {
    const cls = objc.requireClass("NSObject");
    try testing.expectEqualStrings("NSObject", cls.name());
}

test "lookup: getMetaClass" {
    const meta = objc.getMetaClass("NSObject");
    try testing.expect(meta != null);
    try testing.expect(meta.?.isMetaClass());

    try testing.expectEqual(@as(?objc.Class, null), objc.getMetaClass("NonExistentMetaClass98765"));
}

test "lookup: getProtocol" {
    const proto = objc.getProtocol("NSObject");
    try testing.expect(proto != null);
    try testing.expectEqualStrings("NSObject", proto.?.name());

    try testing.expectEqual(@as(?objc.Protocol, null), objc.getProtocol("NonExistentProtocol98765"));
}
