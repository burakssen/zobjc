//! Master test suite for the Objective-C encoding subsystem.

const std = @import("std");
const objc = @import("objc");
const testing = std.testing;

test {
    _ = @import("primitive_test.zig");
    _ = @import("aggregate_test.zig");
    _ = @import("parser_test.zig");
    _ = @import("method_test.zig");
    _ = @import("property_test.zig");
    _ = @import("differential_test.zig");
    _ = @import("corpus_test.zig");
}

fn expectEncoding(comptime T: type, expected: []const u8) !void {
    const enc = comptime objc.comptimeEncode(T);
    try testing.expectEqualStrings(expected, &enc);
}

test "encoding: primitives baseline" {
    try expectEncoding(i8, "c");
    try expectEncoding(i32, "i");
    try expectEncoding(i64, "q");
    try expectEncoding(u8, "C");
    try expectEncoding(u32, "I");
    try expectEncoding(u64, "Q");
    try expectEncoding(f32, "f");
    try expectEncoding(f64, "d");
    try expectEncoding(bool, "B");
    try expectEncoding(void, "v");
}

test "encoding: pointers and strings baseline" {
    try expectEncoding([*c]const u8, "r*");
    try expectEncoding([*c]u8, "*");
    try expectEncoding(*i32, "^i");
    try expectEncoding(**i32, "^^i");
    try expectEncoding(?*i32, "^i");
}

test "encoding: arrays baseline" {
    try expectEncoding([8]i32, "[8i]");
}

test "encoding: extern structs baseline" {
    const Point = extern struct {
        x: f64,
        y: f64,
    };
    try expectEncoding(Point, "{Point=dd}");
    try expectEncoding(*Point, "^{Point=dd}");
    try expectEncoding(**Point, "^^{Point}");
}

test "encoding: functions baseline" {
    const F = fn (objc.c.id, objc.c.SEL, i32) callconv(.c) i32;
    try expectEncoding(F, "i@:i");
}
