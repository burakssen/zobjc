//! Method handle tests.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

test "method: NSObject description method introspection" {
    const cls = objc.requireClass("NSObject");
    const desc_sel = objc.sel("description");
    const method = cls.instanceMethod(desc_sel).?;

    // Selector
    try testing.expect(method.selector().eql(desc_sel));

    // Implementation
    const imp = method.implementation();
    try testing.expect(@intFromPtr(imp.ptr) != 0);

    // Type encoding
    const enc = method.typeEncoding();
    try testing.expect(enc != null);
    try testing.expect(enc.?.len > 0);

    // Argument count (at least self and _cmd)
    try testing.expect(method.argumentCount() >= 2);

    // Return type buffer
    var ret_buf: [128]u8 = undefined;
    method.returnType(&ret_buf);
    const ret_slice = std.mem.sliceTo(&ret_buf, 0);
    try testing.expectEqualStrings("@", ret_slice);

    // Argument types (arg 0 is self '@', arg 1 is _cmd ':')
    var arg0_buf: [128]u8 = undefined;
    method.argumentType(0, &arg0_buf);
    const arg0_slice = std.mem.sliceTo(&arg0_buf, 0);
    try testing.expectEqualStrings("@", arg0_slice);

    var arg1_buf: [128]u8 = undefined;
    method.argumentType(1, &arg1_buf);
    const arg1_slice = std.mem.sliceTo(&arg1_buf, 0);
    try testing.expectEqualStrings(":", arg1_slice);

    // Description struct
    const desc_struct = method.description();
    try testing.expect(desc_struct != null);
    try testing.expect(desc_struct.?.selector.?.eql(desc_sel));
}

test "method: exchange implementations" {
    const NSObject = objc.requireClass("NSObject");
    const Subclass = objc.allocateClassPair(NSObject, "MethodExchangeTestClass").?;

    const Dummy = struct {
        fn m1(target: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) i32 {
            _ = target;
            _ = sel_val;
            return 100;
        }
        fn m2(target: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) i32 {
            _ = target;
            _ = sel_val;
            return 200;
        }
    };

    const sel1 = objc.sel("methodOne");
    const sel2 = objc.sel("methodTwo");
    _ = Subclass.addMethod(sel1, objc.Imp.fromRawNonNull(@ptrCast(&Dummy.m1)), "i@:");
    _ = Subclass.addMethod(sel2, objc.Imp.fromRawNonNull(@ptrCast(&Dummy.m2)), "i@:");

    objc.registerClassPair(Subclass);
    defer objc.disposeClassPair(Subclass);

    const method1 = Subclass.instanceMethod(sel1).?;
    const method2 = Subclass.instanceMethod(sel2).?;

    const inst = Subclass.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    defer inst.msgSend(void, "dealloc", .{});

    try testing.expectEqual(@as(i32, 100), inst.msgSend(i32, sel1, .{}));
    try testing.expectEqual(@as(i32, 200), inst.msgSend(i32, sel2, .{}));

    // Exchange
    method1.exchange(method2);

    try testing.expectEqual(@as(i32, 200), inst.msgSend(i32, sel1, .{}));
    try testing.expectEqual(@as(i32, 100), inst.msgSend(i32, sel2, .{}));
}
