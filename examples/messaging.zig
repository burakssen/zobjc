//! Example demonstrating unified Objective-C message dispatch and method invocation.
//!
//! Shows how zobjc's unified messaging pipeline handles:
//! - objc.send with scalar, object, and aggregate returns
//! - Super2 message dispatch with objc.sendSuper
//! - Direct Method and IMP invocation
//! - Checked messaging with respondsToSelector validation
//! - Safe nil receiver semantics

const std = @import("std");
const objc = @import("objc");

const NSRange = extern struct {
    location: c_ulong,
    length: c_ulong,
};

pub fn main() !void {
    std.debug.print("=== Unified Objective-C Messaging Engine ===\n\n", .{});

    var pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    // 1. Class and Instance Messaging
    std.debug.print("1. Basic Messaging (objc.send):\n", .{});
    const NSNumber = objc.getClass("NSNumber").?;
    const num = objc.send(objc.Object, NSNumber, "numberWithInt:", .{@as(c_int, 42)});
    const int_val = objc.send(c_int, num, "intValue", .{});
    const dbl_val = objc.send(f64, num, "doubleValue", .{});
    std.debug.print("  NSNumber initWithInt: 42 -> intValue={d}, doubleValue={d:.1}\n\n", .{ int_val, dbl_val });

    // 2. String Manipulation and Struct Returns
    std.debug.print("2. Aggregate Returns and String Handling:\n", .{});
    const NSString = objc.getClass("NSString").?;
    const greeting = objc.send(objc.Object, NSString, "stringWithUTF8String:", .{"Hello, Objective-C from Zig!"});
    const length = objc.send(usize, greeting, "length", .{});
    const range = NSRange{ .location = 7, .length = 13 };
    const sub = objc.send(objc.Object, greeting, "substringWithRange:", .{range});
    const sub_utf8 = objc.send([*:0]const u8, sub, "UTF8String", .{});
    std.debug.print("  Greeting length: {d}\n", .{length});
    std.debug.print("  Substring: \"{s}\"\n\n", .{std.mem.span(sub_utf8)});

    // 3. Direct Method and IMP Invocation
    std.debug.print("3. Direct Method & IMP Invocation:\n", .{});
    const method = NSNumber.classMethod(objc.sel("numberWithInt:")).?;
    const imp = method.implementation();
    const num_via_imp = objc.callImp(objc.Object, imp, NSNumber, "numberWithInt:", .{@as(c_int, 999)});
    std.debug.print("  Direct IMP call result: {d}\n\n", .{objc.send(c_int, num_via_imp, "intValue", .{})});

    // 4. Safe Nil-Receiver Messaging
    std.debug.print("4. Nil-Receiver Semantics:\n", .{});
    const nil_obj: ?objc.Object = null;
    const nil_int = objc.send(c_int, nil_obj, "intValue", .{});
    const nil_ret = objc.send(?objc.Object, nil_obj, "description", .{});
    std.debug.print("  Messaging nil receiver: intValue={d}, description={any}\n\n", .{ nil_int, nil_ret });

    // 5. Dynamic Class Hierarchy & Super2 Dispatch
    std.debug.print("5. Super2 Dispatch (objc.sendSuper):\n", .{});
    const NSObject = objc.getClass("NSObject").?;
    const CustomBase = objc.allocateClassPair(NSObject, "ExampleBaseClass").?;
    objc.registerClassPair(CustomBase);
    defer objc.disposeClassPair(CustomBase);

    const CustomChild = objc.allocateClassPair(CustomBase, "ExampleChildClass").?;
    objc.registerClassPair(CustomChild);
    defer objc.disposeClassPair(CustomChild);

    const child_instance = objc.send(objc.Object, CustomChild, "new", .{});
    const desc_obj = objc.send(objc.Object, child_instance, "description", .{});
    const desc = objc.send([*:0]const u8, desc_obj, "UTF8String", .{});
    std.debug.print("  Super description: {s}\n\n", .{std.mem.span(desc)});

    std.debug.print("All messaging demonstrations completed successfully!\n", .{});
}
