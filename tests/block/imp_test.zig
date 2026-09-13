//! Objective-C Block ↔ IMP bridging tests.

const std = @import("std");
const objc = @import("objc");
const raw = objc.raw;
const testing = std.testing;

test "imp: makeImp and method dispatch" {
    // 1. Create a block matching imp_implementationWithBlock: ^(self, x, y)
    var blk = try objc.OwnedBlock(fn (objc.Object, c_int, c_int) c_int).fromFunction(struct {
        fn add(_: objc.Object, x: c_int, y: c_int) c_int {
            return x + y;
        }
    }.add);
    defer blk.deinit();

    // 2. Bridge block into an OwnedImp
    var owned_imp = try blk.makeImp();
    defer owned_imp.deinit();

    try testing.expect(owned_imp.raw_imp != null);
    const associated_block = owned_imp.block();
    try testing.expect(associated_block != null);

    // 3. Register a dynamic class and attach the IMP
    const super_cls = objc.requireClass("NSObject");
    const dynamic_cls = raw.runtime.objc_allocateClassPair(super_cls.toRaw(), "DynamicBlockTestClass", 0).?;
    defer raw.runtime.objc_disposeClassPair(dynamic_cls);

    const sel = objc.sel("add:and:").toRaw();
    const added = raw.runtime.class_addMethod(
        dynamic_cls,
        sel,
        owned_imp.borrow().toRaw(),
        "i@:ii",
    );
    try testing.expect(added);
    raw.runtime.objc_registerClassPair(dynamic_cls);

    // 4. Instantiate and dispatch message through Objective-C runtime
    const cls_handle = objc.Class.fromRaw(dynamic_cls).?;
    const inst = cls_handle.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    defer inst.msgSend(void, "release", .{});

    const result = objc.send(c_int, inst, "add:and:", .{ @as(c_int, 20), @as(c_int, 22) });
    try testing.expectEqual(@as(c_int, 42), result);
}
