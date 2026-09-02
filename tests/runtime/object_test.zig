//! Object handle tests.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

test "object: instance class and identity" {
    const cls = objc.requireClass("NSObject");
    const obj1 = cls.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    defer obj1.msgSend(void, "dealloc", .{});

    const obj2 = cls.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    defer obj2.msgSend(void, "dealloc", .{});

    // Class
    try testing.expect(obj1.class().eql(cls));
    try testing.expectEqualStrings("NSObject", obj1.className());

    // isClass
    try testing.expect(!obj1.isClass());

    // Identity equality
    try testing.expect(obj1.eql(obj1));
    try testing.expect(!obj1.eql(obj2));
}

test "object: setClass dynamic isa swizzling" {
    const Base = objc.requireClass("NSObject");
    const Subclass = objc.allocateClassPair(Base, "ObjectSetClassSubclass").?;
    objc.registerClassPair(Subclass);
    defer objc.disposeClassPair(Subclass);

    const obj = Base.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    defer obj.msgSend(void, "dealloc", .{});

    try testing.expect(obj.class().eql(Base));

    const old_cls = obj.setClass(Subclass);
    try testing.expect(old_cls.eql(Base));
    try testing.expect(obj.class().eql(Subclass));

    _ = obj.setClass(Base); // restore
}

test "object: getIvar and setIvar" {
    const Base = objc.requireClass("NSObject");
    const Subclass = objc.allocateClassPair(Base, "ObjectIvarTestClass").?;

    _ = Subclass.addIvar("_child", @sizeOf(objc.raw.id), @truncate(std.math.log2(@alignOf(objc.raw.id))), "@");
    objc.registerClassPair(Subclass);
    defer objc.disposeClassPair(Subclass);

    const ivar = Subclass.instanceIvar("_child").?;

    const parent = Subclass.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    defer parent.msgSend(void, "dealloc", .{});

    const child = Base.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    defer child.msgSend(void, "dealloc", .{});

    // Initially null
    try testing.expectEqual(@as(?objc.Object, null), parent.getIvar(ivar));

    // Set ivar
    parent.setIvar(ivar, child);
    const retrieved = parent.getIvar(ivar);
    try testing.expect(retrieved != null);
    try testing.expect(retrieved.?.eql(child));

    // Clear ivar
    parent.setIvar(ivar, null);
    try testing.expectEqual(@as(?objc.Object, null), parent.getIvar(ivar));
}
