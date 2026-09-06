//! Primitive and scalar encoding tests.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

fn expectEncoding(comptime T: type, expected: []const u8) !void {
    const enc = comptime objc.encoding.comptimeEncode(T);
    try testing.expectEqualStrings(expected, &enc);
}

test "primitive: integer types" {
    try expectEncoding(c_char, "c");
    try expectEncoding(i8, "c");
    try expectEncoding(u8, "C");

    try expectEncoding(c_short, "s");
    try expectEncoding(i16, "s");
    try expectEncoding(c_ushort, "S");
    try expectEncoding(u16, "S");

    try expectEncoding(c_int, "i");
    try expectEncoding(i32, "i");
    try expectEncoding(c_uint, "I");
    try expectEncoding(u32, "I");

    const expected_long = if (@sizeOf(c_long) == 8) "q" else "l";
    const expected_ulong = if (@sizeOf(c_ulong) == 8) "Q" else "L";
    try expectEncoding(c_long, expected_long);
    try expectEncoding(c_ulong, expected_ulong);

    try expectEncoding(c_longlong, "q");
    try expectEncoding(i64, "q");
    try expectEncoding(c_ulonglong, "Q");
    try expectEncoding(u64, "Q");
}

test "primitive: floating point types" {
    try expectEncoding(f32, "f");
    try expectEncoding(f64, "d");
    try expectEncoding(c_longdouble, "D");
}

test "primitive: boolean types" {
    try expectEncoding(bool, "B");
    const expected_bool = if (objc.raw.objc_bool_is_bool) "B" else "c";
    try expectEncoding(objc.raw.BOOL, expected_bool);
}

test "primitive: void and C strings" {
    try expectEncoding(void, "v");
    try expectEncoding([*c]const u8, "r*");
    try expectEncoding([*c]u8, "*");
    try expectEncoding([*:0]const u8, "r*");
    try expectEncoding([*:0]u8, "*");
    try expectEncoding(?[*:0]const u8, "r*");
    try expectEncoding(?[*:0]u8, "*");
}

test "primitive: Objective-C runtime handles" {
    try expectEncoding(objc.Object, "@");
    try expectEncoding(?objc.Object, "@");
    try expectEncoding(objc.Class, "#");
    try expectEncoding(?objc.Class, "#");
    try expectEncoding(objc.Selector, ":");
    try expectEncoding(?objc.Selector, ":");
    try expectEncoding(objc.raw.id, "@");
    try expectEncoding(objc.raw.Class, "#");
    try expectEncoding(objc.raw.SEL, ":");
}

test "primitive: pointers" {
    try expectEncoding(*i32, "^i");
    try expectEncoding(**i32, "^^i");
    try expectEncoding(?*i32, "^i");
    try expectEncoding(*anyopaque, "^v");
    try expectEncoding(?*anyopaque, "^v");
}

test "primitive: arrays" {
    try expectEncoding([4]i32, "[4i]");
    try expectEncoding([16]f32, "[16f]");
    try expectEncoding([2][3]i32, "[2[3i]]");
}

test "primitive: enums encode as their backing integer" {
    const EnumShort = enum(c_short) { first, second };
    try expectEncoding(EnumShort, "s");

    const EnumInt = enum(c_int) { a, b, c };
    try expectEncoding(EnumInt, "i");

    const EnumU64 = enum(u64) { x, y };
    try expectEncoding(EnumU64, "Q");
}

test "primitive: type validation predicates" {
    try testing.expect(objc.encoding.isObjCEncodable(i32));
    try testing.expect(objc.encoding.isObjCEncodable(f64));
    try testing.expect(objc.encoding.isObjCEncodable(objc.Object));
    try testing.expect(objc.encoding.isObjCEncodable(*i32));
    try testing.expect(objc.encoding.isObjCEncodable([4]i32));

    // Slices and error types are rejected
    try testing.expect(!objc.encoding.isObjCEncodable([]const u8));
    try testing.expect(!objc.encoding.isObjCEncodable(anyerror!i32));
}
