//! Integration tests for Method.invoke and direct IMP invocation.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

test "invoke: Method.invoke matches objc.send" {
    var pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const NSNumber = objc.getClass("NSNumber").?;
    const num = objc.send(objc.Object, NSNumber, "numberWithInt:", .{@as(c_int, 777)});

    // Lookup Method handle for -intValue
    const method = NSNumber.instanceMethod(objc.sel("intValue")).?;

    // Method.invoke directly
    const val = method.invoke(c_int, num, .{});
    try testing.expectEqual(@as(c_int, 777), val);

    // Matches objc.send
    const send_val = objc.send(c_int, num, "intValue", .{});
    try testing.expectEqual(send_val, val);
}

test "invoke: callImp directly invokes IMP function pointer" {
    var pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const NSNumber = objc.getClass("NSNumber").?;
    const num = objc.send(objc.Object, NSNumber, "numberWithInt:", .{@as(c_int, 888)});

    const method = NSNumber.instanceMethod(objc.sel("intValue")).?;
    const imp = method.implementation();

    // Call IMP directly
    const val = objc.callImp(c_int, imp, num, objc.sel("intValue"), .{});
    try testing.expectEqual(@as(c_int, 888), val);
}
