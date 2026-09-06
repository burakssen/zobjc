//! Tests for Objective-C property attribute parsing.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

test "property: basic object property" {
    const allocator = testing.allocator;

    // T@"NSString",R,C,N,V_title
    var prop = try objc.encoding.parseProperty(allocator, "T@\"NSString\",R,C,N,V_title");
    defer prop.deinit(allocator);

    try testing.expect(prop.type != null);
    try testing.expect(prop.type.?.type == .object);
    try testing.expectEqualStrings("NSString", prop.type.?.type.object.class_name.?);
    try testing.expect(prop.readonly);
    try testing.expect(prop.copy);
    try testing.expect(prop.nonatomic);
    try testing.expect(!prop.retain);
    try testing.expect(!prop.weak);
    try testing.expect(!prop.dynamic);
    try testing.expectEqualStrings("_title", prop.ivar.?);
    try testing.expectEqual(@as(?[]const u8, null), prop.getter);
    try testing.expectEqual(@as(?[]const u8, null), prop.setter);
}

test "property: primitive with custom accessors" {
    const allocator = testing.allocator;

    // Ti,GcustomGet,ScustomSet:,Vcount
    var prop = try objc.encoding.parseProperty(allocator, "Ti,GcustomGet,ScustomSet:,Vcount");
    defer prop.deinit(allocator);

    try testing.expect(prop.type != null);
    try testing.expect(prop.type.?.type == .scalar);
    try testing.expectEqual(.int, prop.type.?.type.scalar);
    try testing.expect(!prop.readonly);
    try testing.expectEqualStrings("customGet", prop.getter.?);
    try testing.expectEqualStrings("customSet:", prop.setter.?);
    try testing.expectEqualStrings("count", prop.ivar.?);
}

test "property: weak, retain, dynamic attributes" {
    const allocator = testing.allocator;

    var weak_prop = try objc.encoding.parseProperty(allocator, "T@,W,N,V_delegate");
    defer weak_prop.deinit(allocator);
    try testing.expect(weak_prop.weak);
    try testing.expect(weak_prop.nonatomic);
    try testing.expectEqualStrings("_delegate", weak_prop.ivar.?);

    var retain_prop = try objc.encoding.parseProperty(allocator, "T@,&,V_child");
    defer retain_prop.deinit(allocator);
    try testing.expect(retain_prop.retain);
    try testing.expectEqualStrings("_child", retain_prop.ivar.?);

    var dyn_prop = try objc.encoding.parseProperty(allocator, "Td,D");
    defer dyn_prop.deinit(allocator);
    try testing.expect(dyn_prop.dynamic);
    try testing.expect(dyn_prop.type.?.type == .scalar);
    try testing.expectEqual(.double, dyn_prop.type.?.type.scalar);
    try testing.expectEqual(@as(?[]const u8, null), dyn_prop.ivar);
}

test "property: empty or unknown attributes tolerated" {
    const allocator = testing.allocator;

    var prop = try objc.encoding.parseProperty(allocator, "Ti,,P,t");
    defer prop.deinit(allocator);
    try testing.expect(prop.type != null);
    try testing.expect(prop.type.?.type == .scalar);
    try testing.expectEqual(.int, prop.type.?.type.scalar);
}
