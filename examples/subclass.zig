//! Example demonstrating dynamic class creation and method overriding.

const std = @import("std");
const objc = @import("zobjc");

pub fn main() void {
    const NSObject = objc.getClass("NSObject") orelse return;
    const MyClass = objc.allocateClassPair(NSObject, "CustomGreeterClass") orelse return;

    _ = MyClass.replaceMethod(objc.sel("description"), objc.Imp.fromRawNonNull(@ptrCast(&struct {
        fn customDescription(target: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) objc.raw.id {
            _ = sel_val;
            return target;
        }
    }.customDescription)), "@:@");

    objc.registerClassPair(MyClass);
    defer objc.disposeClassPair(MyClass);

    const instance = MyClass.send(objc.Object, "alloc", .{})
        .send(objc.Object, "init", .{});
    defer instance.send(void, "dealloc", .{});

    const desc = instance.send(objc.Object, "description", .{});
    std.debug.print("Subclass description returned an {s} instance\n", .{desc.className()});
}
