//! Baseline behavioral tests for message dispatch.

const std = @import("std");
const objc = @import("objc");
const testing = std.testing;

test "messaging: class method and instance method invocation" {
    const NSNumber = objc.getClass("NSNumber").?;

    // Class method with scalar arg (autoreleased instance)
    const num = NSNumber.msgSend(objc.Object, "numberWithInt:", .{@as(c_int, 1234)});

    // Instance method with scalar return
    const val = num.msgSend(c_int, "intValue", .{});
    try testing.expectEqual(@as(c_int, 1234), val);
}

test "messaging: scalar arguments and return values" {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const NSNumber = objc.getClass("NSNumber").?;

    // f64 float arg and return
    const float_num = NSNumber.msgSend(objc.Object, "numberWithDouble:", .{@as(f64, 3.14159)});
    const float_val = float_num.msgSend(f64, "doubleValue", .{});
    try testing.expectApproxEqAbs(@as(f64, 3.14159), float_val, 0.0001);

    // bool arg and return
    const bool_num = NSNumber.msgSend(objc.Object, "numberWithBool:", .{true});
    const bool_val = bool_num.msgSend(bool, "boolValue", .{});
    try testing.expect(bool_val);
}

test "messaging: struct arguments (NSPoint/NSRange/etc)" {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const NSString = objc.getClass("NSString").?;
    const str = NSString.msgSend(objc.Object, "stringWithUTF8String:", .{"Hello, World!"});

    // NSRange is { location: c_ulong, length: c_ulong }
    const NSRange = extern struct {
        location: c_ulong,
        length: c_ulong,
    };

    const substr = str.msgSend(objc.Object, "substringWithRange:", .{NSRange{ .location = 0, .length = 5 }});
    const utf8 = substr.getProperty([*c]const u8, "UTF8String");
    try testing.expectEqualStrings("Hello", std.mem.span(utf8));
}

test "messaging: superclass dispatch" {
    const Subclass = objc.allocateClassPair(objc.getClass("NSObject").?, "MsgSendSuperTest").?;
    defer objc.disposeClassPair(Subclass);

    const str = struct {
        fn initMethod(target: objc.c.id, sel_val: objc.c.SEL) callconv(.c) objc.c.id {
            _ = sel_val;
            const self = objc.Object.fromId(target);
            self.msgSendSuper(objc.getClass("NSObject").?, void, "init", .{});
            return target;
        }
    };
    Subclass.replaceMethod("init", str.initMethod);
    objc.registerClassPair(Subclass);

    const obj = Subclass.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    defer obj.msgSend(void, "dealloc", .{});
    try testing.expect(obj.value != null);
}
