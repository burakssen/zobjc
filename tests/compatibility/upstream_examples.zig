//! Compatibility tests verifying that the original Mitchellh upstream README code snippets
//! continue to compile and function without modification.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

test "upstream README: basic object instantiation and messaging" {
    // Upstream pattern:
    // const Class = objc.getClass("NSObject").?;
    // const obj = Class.msgSend(objc.Object, "alloc", .{}).msgSend(objc.Object, "init", .{});
    const Class = objc.getClass("NSObject").?;
    const obj = Class.msgSend(objc.Object, "alloc", .{}).msgSend(objc.Object, "init", .{});
    defer obj.msgSend(void, "dealloc", .{});

    try testing.expect(obj.toRaw() != null);
    try testing.expectEqualStrings("NSObject", obj.getClassName());
}

test "upstream README: subclass creation with custom method" {
    // Upstream pattern:
    // var SuperClass = objc.getClass("NSObject").?;
    // var NewClass = objc.allocateClassPair(SuperClass, "UpstreamSubclass").?;
    // _ = NewClass.addMethod(objc.sel("meaningOfLife"), ...);
    // objc.registerClassPair(NewClass);
    const SuperClass = objc.getClass("NSObject").?;
    const NewClass = objc.allocateClassPair(SuperClass, "UpstreamSubclass").?;

    const helper = struct {
        fn meaning(self: objc.c.id, _cmd: objc.c.SEL) callconv(.c) i32 {
            _ = self;
            _ = _cmd;
            return 42;
        }
    };

    _ = NewClass.addMethod(
        objc.sel("meaningOfLife"),
        objc.Imp.fromRawNonNull(@ptrCast(&helper.meaning)),
        "i@:",
    );
    objc.registerClassPair(NewClass);

    const inst = NewClass.msgSend(objc.Object, "alloc", .{}).msgSend(objc.Object, "init", .{});
    defer inst.msgSend(void, "dealloc", .{});

    const val = inst.msgSend(i32, "meaningOfLife", .{});
    try testing.expectEqual(@as(i32, 42), val);
}

test "upstream README: autorelease pool pattern" {
    // Upstream pattern:
    // var pool = objc.AutoreleasePool.init();
    // defer pool.deinit();
    var pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const NSObject = objc.getClass("NSObject").?;
    const obj = NSObject.msgSend(objc.Object, "alloc", .{}).msgSend(objc.Object, "init", .{});
    obj.msgSend(void, "dealloc", .{});
}
