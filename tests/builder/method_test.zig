//! Dynamic method and class method registration tests.

const std = @import("std");
const objc = @import("objc");
const testing = std.testing;

test "ClassBuilder: selector arity mismatch detection" {
    const NSObject = objc.requireClass("NSObject");
    var builder = try objc.ClassBuilder.init("ZigTest_Method_Arity", NSObject);
    defer builder.abort();

    // "count" has 0 colons, but callback takes 1 argument
    const mismatch1 = builder.addMethod("count", struct {
        fn run(_: objc.Object, _: objc.Selector, _: c_int) c_int {
            return 0;
        }
    }.run);
    try testing.expectError(error.SelectorArityMismatch, mismatch1);

    // "setCount:" has 1 colon, but callback takes 0 arguments
    const mismatch2 = builder.addMethod("setCount:", struct {
        fn run(_: objc.Object, _: objc.Selector) void {}
    }.run);
    try testing.expectError(error.SelectorArityMismatch, mismatch2);
}

test "ClassBuilder: raw C-ABI instance methods" {
    const NSObject = objc.requireClass("NSObject");
    var builder = try objc.ClassBuilder.init("ZigTest_Method_RawC", NSObject);
    errdefer builder.abort();

    const rawGetAnswer = struct {
        fn run(_: objc.raw.id, _: objc.raw.SEL) callconv(.c) c_int {
            return 42;
        }
    }.run;

    try builder.addMethod("answer", rawGetAnswer);

    const cls = builder.register();
    const method = cls.instanceMethod(objc.sel("answer"));
    try testing.expect(method != null);
    try testing.expectEqualStrings("i@:", method.?.typeEncoding().?);

    // Allocate an instance and dispatch the message
    const instance = cls.send(objc.Object, "new", .{});
    const ans = instance.send(c_int, "answer", .{});
    try testing.expectEqual(42, ans);
}

test "ClassBuilder: ergonomic trampolined methods with multiple arguments" {
    const NSObject = objc.requireClass("NSObject");
    var builder = try objc.ClassBuilder.init("ZigTest_Method_Ergonomic", NSObject);
    errdefer builder.abort();

    const addFn = struct {
        fn add(_: objc.Object, _: objc.Selector, a: c_int, b: c_int) c_int {
            return a + b;
        }
    }.add;

    try builder.addMethod("add:and:", addFn);

    const cls = builder.register();
    const method = cls.instanceMethod(objc.sel("add:and:"));
    try testing.expect(method != null);
    try testing.expectEqualStrings("i@:ii", method.?.typeEncoding().?);

    // Dispatch via objc.send
    const instance = cls.send(objc.Object, "new", .{});
    const sum = instance.send(c_int, "add:and:", .{ @as(c_int, 15), @as(c_int, 27) });
    try testing.expectEqual(42, sum);
}

test "ClassBuilder: addClassMethod registers on metaclass" {
    const NSObject = objc.requireClass("NSObject");
    var builder = try objc.ClassBuilder.init("ZigTest_Method_ClassMethod", NSObject);
    errdefer builder.abort();

    const classAnswerFn = struct {
        fn get(_: objc.Class, _: objc.Selector) c_int {
            return 999;
        }
    }.get;

    try builder.addClassMethod("classAnswer", classAnswerFn);

    const cls = builder.register();

    // Verify it exists as a class method
    const cm = cls.classMethod(objc.sel("classAnswer"));
    try testing.expect(cm != null);
    try testing.expectEqualStrings("i@:", cm.?.typeEncoding().?);

    // Dispatch class message via objc.send
    const val = cls.send(c_int, "classAnswer", .{});
    try testing.expectEqual(999, val);
}
