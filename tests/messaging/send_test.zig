//! Integration tests for objc.send and object/class messaging.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

test "send: class method invocation and object creation" {
    const ABIFixture = objc.getClass("ABIFixture").?;

    // Class message via objc.send
    const sum = objc.send(c_int, ABIFixture, "addInt:to:", .{ @as(c_int, 20), @as(c_int, 22) });
    try testing.expectEqual(@as(c_int, 42), sum);

    // Instance creation and message via objc.send
    const inst = objc.send(objc.Object, ABIFixture, "new", .{});
    defer inst.release();

    const val = objc.send(c_int, inst, "echoInt:", .{@as(c_int, 42)});
    try testing.expectEqual(@as(c_int, 42), val);
}

test "send: scalar arguments and returns" {
    const ABIFixture = objc.getClass("ABIFixture").?;

    // Double
    const prod = objc.send(f64, ABIFixture, "multiplyDouble:by:", .{ @as(f64, 2.0), @as(f64, 3.14159) });
    try testing.expectApproxEqAbs(@as(f64, 6.28318), prod, 0.0001);

    // Instance returnInt
    const inst = objc.send(objc.Object, ABIFixture, "new", .{});
    defer inst.release();

    const val = objc.send(c_int, inst, "returnInt", .{});
    try testing.expectEqual(@as(c_int, 42), val);
}

test "send: aggregate argument and return (ABIPoint)" {
    const ABIFixture = objc.getClass("ABIFixture").?;
    const inst = objc.send(objc.Object, ABIFixture, "new", .{});
    defer inst.release();

    const ABIPoint = extern struct {
        x: f64,
        y: f64,
    };

    const pt = objc.send(ABIPoint, inst, "returnPoint", .{});
    try testing.expectEqual(@as(f64, 10.0), pt.x);
    try testing.expectEqual(@as(f64, 20.0), pt.y);
}

test "send: nil receiver semantics" {
    const nil_obj: ?objc.Object = null;

    // Messaging nil returns 0 / null without crashing
    const int_val = objc.send(c_int, nil_obj, "returnInt", .{});
    try testing.expectEqual(@as(c_int, 0), int_val);

    const obj_val = objc.send(?objc.Object, nil_obj, "description", .{});
    try testing.expectEqual(@as(?objc.Object, null), obj_val);
}

test "send: object and class convenience methods" {
    const ABIFixture = objc.getClass("ABIFixture").?;

    // Class.send
    const sum = ABIFixture.send(c_int, "addInt:to:", .{ @as(c_int, 40), @as(c_int, 60) });
    try testing.expectEqual(@as(c_int, 100), sum);

    const inst = ABIFixture.send(objc.Object, "new", .{});
    defer inst.release();

    // Object.send
    const val = inst.send(c_int, "echoInt:", .{@as(c_int, 100)});
    try testing.expectEqual(@as(c_int, 100), val);

    // Class.msgSend compatibility
    const sum2 = ABIFixture.msgSend(c_int, "addInt:to:", .{ @as(c_int, 150), @as(c_int, 50) });
    try testing.expectEqual(@as(c_int, 200), sum2);

    // Object.msgSend compatibility
    const val2 = inst.msgSend(c_int, "echoInt:", .{@as(c_int, 200)});
    try testing.expectEqual(@as(c_int, 200), val2);
}
