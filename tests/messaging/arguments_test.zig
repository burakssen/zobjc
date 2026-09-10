//! Unit tests for argument type normalization and value conversion.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");
const raw = objc.raw;
const arguments = objc.messaging.arguments;

const TestEnum = enum(c_int) {
    first = 10,
    second = 20,
};

const Point = extern struct {
    x: f64,
    y: f64,
};

test "arguments: handle normalization to raw ABI types" {
    try testing.expectEqual(raw.id, arguments.AbiArgumentType(objc.Object));
    try testing.expectEqual(raw.id, arguments.AbiArgumentType(?objc.Object));
    try testing.expectEqual(raw.Class, arguments.AbiArgumentType(objc.Class));
    try testing.expectEqual(raw.Class, arguments.AbiArgumentType(?objc.Class));
    try testing.expectEqual(raw.SEL, arguments.AbiArgumentType(objc.Selector));
    try testing.expectEqual(raw.SEL, arguments.AbiArgumentType(?objc.Selector));
    try testing.expectEqual(raw.IMP, arguments.AbiArgumentType(objc.Imp));
}

test "arguments: enum normalization to tag type" {
    try testing.expectEqual(c_int, arguments.AbiArgumentType(TestEnum));
    try testing.expectEqual(@as(c_int, 20), arguments.toAbi(TestEnum.second));
}

test "arguments: string literal normalization to [*:0]const u8" {
    const literal = "hello world";
    try testing.expectEqual([*:0]const u8, arguments.AbiArgumentType(@TypeOf(literal)));

    const raw_ptr = arguments.toAbi(literal);
    try testing.expectEqualStrings("hello world", std.mem.span(raw_ptr));
}

test "arguments: extern struct remains unchanged" {
    try testing.expectEqual(Point, arguments.AbiArgumentType(Point));
    const pt = Point{ .x = 1.5, .y = 2.5 };
    const abi_pt = arguments.toAbi(pt);
    try testing.expectEqual(1.5, abi_pt.x);
    try testing.expectEqual(2.5, abi_pt.y);
}

test "arguments: tuple normalization" {
    const ArgsTuple = struct {
        objc.Object,
        TestEnum,
        *const [5:0]u8,
        Point,
    };
    const Normalized = arguments.NormalizeTupleTypes(ArgsTuple);
    const fields = @typeInfo(Normalized).@"struct".fields;

    try testing.expectEqual(raw.id, fields[0].type);
    try testing.expectEqual(c_int, fields[1].type);
    try testing.expectEqual([*:0]const u8, fields[2].type);
    try testing.expectEqual(Point, fields[3].type);
}
