//! Aggregate encoding tests (structs and unions).

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

fn expectEncoding(comptime T: type, expected: []const u8) !void {
    const enc = comptime objc.encoding.comptimeEncode(T);
    try testing.expectEqualStrings(expected, &enc);
}

test "aggregate: simple extern struct" {
    const Point = extern struct {
        x: f64,
        y: f64,
    };
    try expectEncoding(Point, "{Point=dd}");
}

test "aggregate: struct with explicit objc_encoding_name" {
    const CustomPoint = extern struct {
        pub const objc_encoding_name = "CGPoint";

        x: f64,
        y: f64,
    };
    try expectEncoding(CustomPoint, "{CGPoint=dd}");
}

test "aggregate: struct with explicit objc_type_encoding override" {
    const OpaqueType = extern struct {
        pub const objc_type_encoding = "{OpaqueSpecial}";
        unused: usize,
    };
    try expectEncoding(OpaqueType, "{OpaqueSpecial}");
}

test "aggregate: nested extern structs" {
    const Inner = extern struct {
        val: i32,
    };
    const Outer = extern struct {
        inner: Inner,
        flag: bool,
    };
    try expectEncoding(Outer, "{Outer={Inner=i}B}");
}

test "aggregate: extern unions" {
    const ValueUnion = extern union {
        pub const objc_encoding_name = "U1";
        i: i32,
        f: f32,
    };
    try expectEncoding(ValueUnion, "(U1=if)");
}

test "aggregate: pointer indirection levels for aggregates" {
    const Point = extern struct {
        pub const objc_encoding_name = "CGPoint";
        x: f64,
        y: f64,
    };

    // Level 1 pointer includes field types
    try expectEncoding(*Point, "^{CGPoint=dd}");

    // Level 2+ pointer omits field types
    try expectEncoding(**Point, "^^{CGPoint}");
    try expectEncoding(***Point, "^^^{CGPoint}");
}

test "aggregate: validation rejects non-extern structs and tagged unions" {
    const ZigStruct = struct {
        a: i32,
    };
    try testing.expect(!objc.encoding.isObjCEncodable(ZigStruct));

    const PackedStruct = packed struct {
        a: u8,
    };
    try testing.expect(!objc.encoding.isObjCEncodable(PackedStruct));

    const TaggedUnion = union(enum) {
        a: i32,
        b: f32,
    };
    try testing.expect(!objc.encoding.isObjCEncodable(TaggedUnion));
}
