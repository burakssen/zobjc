//! Example demonstrating dynamic class creation and method overriding.

const std = @import("std");
const objc = @import("objc");

pub fn main() void {
    const NSObject = objc.getClass("NSObject") orelse return;
    const MyClass = objc.allocateClassPair(NSObject, "CustomGreeterClass") orelse return;

    MyClass.replaceMethod("description", struct {
        fn customDescription(target: objc.c.id, sel_val: objc.c.SEL) callconv(.c) objc.c.id {
            _ = sel_val;
            _ = target;
            const NSString = objc.getClass("NSString").?;
            return NSString.msgSend(objc.c.id, "stringWithUTF8String:", .{"Greetings from custom subclass!"});
        }
    }.customDescription);

    objc.registerClassPair(MyClass);
    defer objc.disposeClassPair(MyClass);

    const instance = MyClass.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    defer instance.msgSend(void, "dealloc", .{});

    const desc = instance.msgSend(objc.Object, "description", .{});
    const utf8 = desc.getProperty([*c]const u8, "UTF8String");

    std.debug.print("Subclass description: {s}\n", .{std.mem.span(utf8)});
}
