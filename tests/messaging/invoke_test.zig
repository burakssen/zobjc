//! Integration tests for Method.invoke and direct IMP invocation.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

test "invoke: Method.invoke matches objc.send" {
    const ABIFixture = objc.getClass("ABIFixture").?;
    const inst = objc.send(objc.Object, ABIFixture, "new", .{});
    defer inst.release();

    // Lookup Method handle for -returnInt
    const method = ABIFixture.instanceMethod(objc.sel("returnInt")).?;

    // Method.invoke directly
    const val = method.invoke(c_int, inst, .{});
    try testing.expectEqual(@as(c_int, 42), val);

    // Matches objc.send
    const send_val = objc.send(c_int, inst, "returnInt", .{});
    try testing.expectEqual(send_val, val);
}

test "invoke: callImp directly invokes IMP function pointer" {
    const ABIFixture = objc.getClass("ABIFixture").?;
    const inst = objc.send(objc.Object, ABIFixture, "new", .{});
    defer inst.release();

    const method = ABIFixture.instanceMethod(objc.sel("returnInt")).?;
    const imp = method.implementation();

    // Call IMP directly
    const val = objc.callImp(c_int, imp, inst, objc.sel("returnInt"), .{});
    try testing.expectEqual(@as(c_int, 42), val);
}
