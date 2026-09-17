//! Differential tests comparing objc.send() / sendSuper() / Method.invoke()
//! against native Objective-C execution and Clang codegen under register pressure.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

const ABIPoint = extern struct { x: f64, y: f64 };
const ABISize32 = extern struct { a: f64, b: f64, c: f64, d: f64 };

test "differential: scalar message sending matches native Objective-C" {
    const ABIFixture = objc.getClass("ABIFixture").?;
    const fixture = objc.send(objc.Object, ABIFixture, "alloc", .{}).send(objc.Object, "init", .{});
    defer fixture.send(void, "dealloc", .{});

    const val_int = fixture.send(c_int, "returnInt", .{});
    try testing.expectEqual(@as(c_int, 42), val_int);

    const val_float = fixture.send(f32, "returnFloat", .{});
    try testing.expectApproxEqAbs(@as(f32, 3.14), val_float, 0.001);

    const val_double = fixture.send(f64, "returnDouble", .{});
    try testing.expectApproxEqAbs(@as(f64, 2.718281828), val_double, 0.00001);
}

test "differential: aggregate return matches native Objective-C" {
    const ABIFixture = objc.getClass("ABIFixture").?;
    const fixture = objc.send(objc.Object, ABIFixture, "alloc", .{}).send(objc.Object, "init", .{});
    defer fixture.send(void, "dealloc", .{});

    const pt = fixture.send(ABIPoint, "returnPoint", .{});
    try testing.expectEqual(@as(f64, 10.0), pt.x);
    try testing.expectEqual(@as(f64, 20.0), pt.y);
}

test "differential: register pressure with 10 integers (register spilling)" {
    const ABIFixture = objc.getClass("ABIFixture").?;
    const fixture = objc.send(objc.Object, ABIFixture, "alloc", .{}).send(objc.Object, "init", .{});
    defer fixture.send(void, "dealloc", .{});

    // 10 int arguments exhausts the 8 integer argument registers (x0-x7 on arm64 / rdi..r9 on x86_64)
    // forcing the remaining arguments onto the stack frame
    const sum = fixture.send(c_int, "sum10Ints:b:c:d:e:f:g:h:i:j:", .{
        @as(c_int, 1),
        @as(c_int, 2),
        @as(c_int, 3),
        @as(c_int, 4),
        @as(c_int, 5),
        @as(c_int, 6),
        @as(c_int, 7),
        @as(c_int, 8),
        @as(c_int, 9),
        @as(c_int, 10),
    });
    try testing.expectEqual(@as(c_int, 55), sum);
}

test "differential: register pressure with 10 doubles (vector register spilling)" {
    const ABIFixture = objc.getClass("ABIFixture").?;
    const fixture = objc.send(objc.Object, ABIFixture, "alloc", .{}).send(objc.Object, "init", .{});
    defer fixture.send(void, "dealloc", .{});

    // 10 double arguments exhausts the 8 floating point registers (d0-d7 on arm64 / xmm0-xmm7 on x86_64)
    const sum = fixture.send(f64, "sum10Doubles:b:c:d:e:f:g:h:i:j:", .{
        @as(f64, 1.0),
        @as(f64, 2.0),
        @as(f64, 3.0),
        @as(f64, 4.0),
        @as(f64, 5.0),
        @as(f64, 6.0),
        @as(f64, 7.0),
        @as(f64, 8.0),
        @as(f64, 9.0),
        @as(f64, 10.0),
    });
    try testing.expectEqual(@as(f64, 55.0), sum);
}

test "differential: large by-value aggregate argument passing (32 bytes)" {
    const ABIFixture = objc.getClass("ABIFixture").?;
    const fixture = objc.send(objc.Object, ABIFixture, "alloc", .{}).send(objc.Object, "init", .{});
    defer fixture.send(void, "dealloc", .{});

    const s = ABISize32{ .a = 10.0, .b = 20.0, .c = 30.0, .d = 40.0 };
    const sum = fixture.send(f64, "passSize32:", .{s});
    try testing.expectEqual(@as(f64, 100.0), sum);
}

test "differential: super dispatch matches native Objective-C super behavior" {
    const ABISubclass = objc.getClass("ABISubclass").?;
    const sub = objc.send(objc.Object, ABISubclass, "alloc", .{}).send(objc.Object, "init", .{});
    defer sub.send(void, "dealloc", .{});

    // Native subclass override multiplies by 10
    const overridden = sub.send(c_int, "echoInt:", .{@as(c_int, 5)});
    try testing.expectEqual(@as(c_int, 50), overridden);

    // Native helper calling [super echoInt:]
    const native_super = sub.send(c_int, "callSuperEcho:", .{@as(c_int, 5)});
    try testing.expectEqual(@as(c_int, 5), native_super);

    // objc.sendSuper direct dispatch from Zig
    const zig_super = objc.sendSuper(c_int, sub, ABISubclass, "echoInt:", .{@as(c_int, 5)});
    try testing.expectEqual(@as(c_int, 5), zig_super);
}

test "differential: Method.invoke() agrees with ordinary message dispatch" {
    const ABIFixture = objc.getClass("ABIFixture").?;
    const fixture = objc.send(objc.Object, ABIFixture, "alloc", .{}).send(objc.Object, "init", .{});
    defer fixture.send(void, "dealloc", .{});

    const method = ABIFixture.instanceMethod(objc.sel("echoInt:")).?;

    // Compare objc.send vs Method.invoke
    const res1 = fixture.send(c_int, "echoInt:", .{@as(c_int, 123)});
    const res2 = method.invoke(c_int, fixture, .{@as(c_int, 123)});

    try testing.expectEqual(res1, res2);
    try testing.expectEqual(@as(c_int, 123), res2);
}

test "differential: wrapper ABI decay regression test" {
    // Verify that objc.Object, objc.Class, objc.Selector decay to their raw pointer types
    // and never appear as Zig aggregate structs across the C ABI
    try testing.expectEqual(@sizeOf(objc.Object), @sizeOf(objc.raw.id));
    try testing.expectEqual(@alignOf(objc.Object), @alignOf(objc.raw.id));

    try testing.expectEqual(@sizeOf(objc.Class), @sizeOf(objc.raw.Class));
    try testing.expectEqual(@alignOf(objc.Class), @alignOf(objc.raw.Class));

    try testing.expectEqual(@sizeOf(objc.Selector), @sizeOf(objc.raw.SEL));
    try testing.expectEqual(@alignOf(objc.Selector), @alignOf(objc.raw.SEL));
}
