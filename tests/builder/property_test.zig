//! Declared property attribute synthesis and introspection tests.

const std = @import("std");
const objc = @import("objc");
const testing = std.testing;

test "Property: contradictory ownership options rejected" {
    const NSObject = objc.requireClass("NSObject");
    var builder = try objc.ClassBuilder.init("ZigTest_Property_Conflict", NSObject);
    defer builder.abort();

    // copy and retain conflict
    const res1 = builder.addProperty(?objc.Object, "conflict1", .{ .copy = true, .retain = true });
    try testing.expectError(error.InvalidPropertyAttributes, res1);

    // copy and weak conflict
    const res2 = builder.addProperty(?objc.Object, "conflict2", .{ .copy = true, .weak = true });
    try testing.expectError(error.InvalidPropertyAttributes, res2);

    // retain and weak conflict
    const res3 = builder.addProperty(?objc.Object, "conflict3", .{ .retain = true, .weak = true });
    try testing.expectError(error.InvalidPropertyAttributes, res3);
}

test "ClassBuilder: declared property metadata reflection" {
    const NSObject = objc.requireClass("NSObject");
    var builder = try objc.ClassBuilder.init("ZigTest_Property_Reflect", NSObject);
    errdefer builder.abort();

    try builder.addIvar(?objc.Object, "_delegate");
    try builder.addProperty(?objc.Object, "delegate", .{
        .weak = true,
        .nonatomic = true,
        .ivar = "_delegate",
    });

    try builder.addProperty(c_int, "count", .{
        .readonly = true,
        .getter = "customCount",
    });

    const cls = builder.register();

    // Inspect "delegate" property
    const prop_delegate = cls.property("delegate");
    try testing.expect(prop_delegate != null);
    try testing.expectEqualStrings("delegate", prop_delegate.?.name());

    const attrs_delegate = prop_delegate.?.attributes();
    var parsed_delegate = try objc.encoding.parseProperty(testing.allocator, attrs_delegate.?);
    defer parsed_delegate.deinit(testing.allocator);

    try testing.expect(parsed_delegate.weak);
    try testing.expect(parsed_delegate.nonatomic);
    try testing.expectEqualStrings("_delegate", parsed_delegate.ivar.?);

    // Inspect "count" property
    const prop_count = cls.property("count");
    try testing.expect(prop_count != null);
    try testing.expectEqualStrings("count", prop_count.?.name());

    const attrs_count = prop_count.?.attributes();
    var parsed_count = try objc.encoding.parseProperty(testing.allocator, attrs_count.?);
    defer parsed_count.deinit(testing.allocator);

    try testing.expect(parsed_count.readonly);
    try testing.expectEqualStrings("customCount", parsed_count.getter.?);
}
