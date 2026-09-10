//! Integration tests for objc.send and object/class messaging.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

test "send: class method invocation and object creation" {
    var pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const NSNumber = objc.getClass("NSNumber").?;

    // Class message via objc.send
    const num = objc.send(objc.Object, NSNumber, "numberWithInt:", .{@as(c_int, 42)});

    // Instance message via objc.send
    const val = objc.send(c_int, num, "intValue", .{});
    try testing.expectEqual(@as(c_int, 42), val);
}

test "send: scalar arguments and returns" {
    var pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const NSNumber = objc.getClass("NSNumber").?;

    // Double
    const dbl_obj = objc.send(objc.Object, NSNumber, "numberWithDouble:", .{@as(f64, 2.718281828)});
    const dbl_val = objc.send(f64, dbl_obj, "doubleValue", .{});
    try testing.expectApproxEqAbs(@as(f64, 2.718281828), dbl_val, 0.000001);

    // Bool
    const bool_obj = objc.send(objc.Object, NSNumber, "numberWithBool:", .{true});
    const bool_val = objc.send(bool, bool_obj, "boolValue", .{});
    try testing.expect(bool_val);
}

test "send: string literal normalization" {
    var pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const NSString = objc.getClass("NSString").?;

    // Passing string literal "Hello from zobjc"
    const str = objc.send(objc.Object, NSString, "stringWithUTF8String:", .{"Hello from zobjc"});
    const len = objc.send(usize, str, "length", .{});
    try testing.expectEqual(@as(usize, 16), len);

    const c_str = objc.send([*:0]const u8, str, "UTF8String", .{});
    try testing.expectEqualStrings("Hello from zobjc", std.mem.span(c_str));
}

test "send: aggregate argument and return (NSRange)" {
    var pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const NSString = objc.getClass("NSString").?;
    const str = objc.send(objc.Object, NSString, "stringWithUTF8String:", .{"Hello, World!"});

    const NSRange = extern struct {
        location: c_ulong,
        length: c_ulong,
    };

    const sub = objc.send(objc.Object, str, "substringWithRange:", .{NSRange{ .location = 7, .length = 5 }});
    const sub_utf8 = objc.send([*:0]const u8, sub, "UTF8String", .{});
    try testing.expectEqualStrings("World", std.mem.span(sub_utf8));
}

test "send: nil receiver semantics" {
    const nil_obj: ?objc.Object = null;

    // Messaging nil returns 0 / null without crashing
    const int_val = objc.send(c_int, nil_obj, "intValue", .{});
    try testing.expectEqual(@as(c_int, 0), int_val);

    const obj_val = objc.send(?objc.Object, nil_obj, "description", .{});
    try testing.expectEqual(@as(?objc.Object, null), obj_val);
}

test "send: object and class convenience methods" {
    var pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const NSNumber = objc.getClass("NSNumber").?;

    // Class.send
    const num = NSNumber.send(objc.Object, "numberWithInt:", .{@as(c_int, 100)});

    // Object.send
    const val = num.send(c_int, "intValue", .{});
    try testing.expectEqual(@as(c_int, 100), val);

    // Class.msgSend compatibility
    const num2 = NSNumber.msgSend(objc.Object, "numberWithInt:", .{@as(c_int, 200)});

    // Object.msgSend compatibility
    const val2 = num2.msgSend(c_int, "intValue", .{});
    try testing.expectEqual(@as(c_int, 200), val2);
}
