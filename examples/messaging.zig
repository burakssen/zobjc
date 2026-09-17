//! Example demonstrating unified Objective-C message dispatch and method invocation.
//!
//! Shows how zobjc's unified messaging pipeline handles:
//! - objc.send with scalar, object, and aggregate returns
//! - Super2 message dispatch with objc.sendSuper
//! - Direct Method and IMP invocation
//! - Checked messaging with respondsToSelector validation
//! - Safe nil receiver semantics

const std = @import("std");
const objc = @import("zobjc");

pub fn main() !void {
    std.debug.print("=== Unified Objective-C Messaging Engine ===\n\n", .{});

    var pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    // 1. Class and Instance Messaging
    std.debug.print("1. Basic Messaging (objc.send):\n", .{});
    const NSObject = objc.requireClass("NSObject");
    const object = objc.send(objc.Object, NSObject, "new", .{});
    defer objc.send(void, object, "dealloc", .{});
    const object_class = objc.send(objc.Class, object, "class", .{});
    std.debug.print("  NSObject.new -> {s}\n\n", .{object_class.name()});

    // 2. Class and object return conversion without Foundation.
    std.debug.print("2. Object and class return conversion:\n", .{});
    const returned_class = objc.send(objc.Class, object, "class", .{});
    std.debug.print("  class -> {s}\n\n", .{returned_class.name()});

    // 3. Direct Method and IMP Invocation
    std.debug.print("3. Direct Method & IMP Invocation:\n", .{});
    const method = NSObject.classMethod(objc.sel("new")).?;
    const imp = method.implementation();
    const object_via_imp = objc.callImp(objc.Object, imp, NSObject, "new", .{});
    defer objc.send(void, object_via_imp, "dealloc", .{});
    std.debug.print("  Direct IMP call result: {s}\n\n", .{object_via_imp.className()});

    // 4. Safe Nil-Receiver Messaging
    std.debug.print("4. Nil-Receiver Semantics:\n", .{});
    const nil_obj: ?objc.Object = null;
    const nil_int = objc.send(c_int, nil_obj, "hash", .{});
    const nil_ret = objc.send(?objc.Object, nil_obj, "description", .{});
    std.debug.print("  Messaging nil receiver: hash={d}, description={any}\n\n", .{ nil_int, nil_ret });

    // 5. Dynamic Class Hierarchy & Super2 Dispatch
    std.debug.print("5. Super2 Dispatch (objc.sendSuper):\n", .{});
    const BaseNSObject = objc.getClass("NSObject").?;
    const CustomBase = objc.allocateClassPair(BaseNSObject, "ExampleBaseClass").?;
    objc.registerClassPair(CustomBase);
    defer objc.disposeClassPair(CustomBase);

    const CustomChild = objc.allocateClassPair(CustomBase, "ExampleChildClass").?;
    objc.registerClassPair(CustomChild);
    defer objc.disposeClassPair(CustomChild);

    const child_instance = objc.send(objc.Object, CustomChild, "new", .{});
    const child_class = objc.send(objc.Class, child_instance, "class", .{});
    const super_class = objc.sendSuper(objc.Class, child_instance, CustomChild, "class", .{});
    std.debug.print("  Child class: {s}, super dispatch class: {s}\n\n", .{ child_class.name(), super_class.name() });

    objc.send(void, child_instance, "dealloc", .{});

    std.debug.print("All messaging demonstrations completed successfully!\n", .{});
}
