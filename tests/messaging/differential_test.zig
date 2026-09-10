//! Differential tests verifying that objc.send correctly receives values from Objective-C.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

// --- Fixture Mirror Types (matching tests/fixtures/abi/fixtures.h) ---

const ABISize1 = extern struct { a: u8 };
const ABISize4 = extern struct { a: i32 };
const ABISize8 = extern struct { a: i64 };
const ABISize16Int = extern struct { a: i64, b: i64 };
const ABISize16Float = extern struct { a: f64, b: f64 };
const ABIPoint = extern struct { x: f64, y: f64 };
const ABISize = extern struct { width: f64, height: f64 };
const ABIRect = extern struct { origin: ABIPoint, size: ABISize };
const ABISize24 = extern struct { a: f64, b: f64, c: f64 };
const ABISize32 = extern struct { a: f64, b: f64, c: f64, d: f64 };

test "differential: scalar methods on ABIFixture" {
    const ABIFixture = objc.getClass("ABIFixture").?;
    const fixture = objc.send(objc.Object, ABIFixture, "new", .{});

    // Void
    objc.send(void, fixture, "returnVoid", .{});

    // Int
    const int_val = objc.send(c_int, fixture, "returnInt", .{});
    try testing.expectEqual(@as(c_int, 42), int_val);

    // Float
    const float_val = objc.send(f32, fixture, "returnFloat", .{});
    try testing.expectApproxEqAbs(@as(f32, 3.14), float_val, 0.001);

    // Double
    const dbl_val = objc.send(f64, fixture, "returnDouble", .{});
    try testing.expectApproxEqAbs(@as(f64, 2.718281828), dbl_val, 0.000001);
}

test "differential: small structures (<= 16 bytes) on ABIFixture" {
    const ABIFixture = objc.getClass("ABIFixture").?;
    const fixture = objc.send(objc.Object, ABIFixture, "new", .{});

    // ABISize1
    const s1 = objc.send(ABISize1, fixture, "returnSize1", .{});
    try testing.expectEqual(@as(u8, 'A'), @as(u8, @intCast(s1.a)));

    // ABISize4
    const s4 = objc.send(ABISize4, fixture, "returnSize4", .{});
    try testing.expectEqual(@as(c_int, 1000), s4.a);

    // ABISize8
    const s8 = objc.send(ABISize8, fixture, "returnSize8", .{});
    try testing.expectEqual(@as(c_longlong, 1234567890123), s8.a);

    // ABISize16Int
    const s16i = objc.send(ABISize16Int, fixture, "returnSize16Int", .{});
    try testing.expectEqual(@as(c_longlong, 100), s16i.a);
    try testing.expectEqual(@as(c_longlong, 200), s16i.b);

    // ABISize16Float
    const s16f = objc.send(ABISize16Float, fixture, "returnSize16Float", .{});
    try testing.expectEqual(1.5, s16f.a);
    try testing.expectEqual(2.5, s16f.b);

    // ABIPoint
    const pt = objc.send(ABIPoint, fixture, "returnPoint", .{});
    try testing.expectEqual(10.0, pt.x);
    try testing.expectEqual(20.0, pt.y);
}

test "differential: large structures (> 16 bytes) on ABIFixture" {
    const ABIFixture = objc.getClass("ABIFixture").?;
    const fixture = objc.send(objc.Object, ABIFixture, "new", .{});

    // ABISize24
    const s24 = objc.send(ABISize24, fixture, "returnSize24", .{});
    try testing.expectEqual(1.0, s24.a);
    try testing.expectEqual(2.0, s24.b);
    try testing.expectEqual(3.0, s24.c);

    // ABISize32
    const s32 = objc.send(ABISize32, fixture, "returnSize32", .{});
    try testing.expectEqual(1.0, s32.a);
    try testing.expectEqual(2.0, s32.b);
    try testing.expectEqual(3.0, s32.c);
    try testing.expectEqual(4.0, s32.d);

    // ABIRect (nested 32 bytes)
    const rect = objc.send(ABIRect, fixture, "returnRect", .{});
    try testing.expectEqual(10.0, rect.origin.x);
    try testing.expectEqual(20.0, rect.origin.y);
    try testing.expectEqual(100.0, rect.size.width);
    try testing.expectEqual(200.0, rect.size.height);
}
