//! Class handle introspection tests.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

test "class: NSObject introspection" {
    const cls = objc.requireClass("NSObject");

    // Name
    try testing.expectEqualStrings("NSObject", cls.name());

    // Metaclass
    try testing.expect(!cls.isMetaClass());

    // Root class has no superclass
    try testing.expectEqual(@as(?objc.Class, null), cls.superclass());

    // Instance size
    try testing.expect(cls.instanceSize() >= @sizeOf(usize));

    // Version
    const v = cls.version();
    cls.setVersion(v + 1);
    try testing.expectEqual(v + 1, cls.version());
    cls.setVersion(v); // restore

    // Methods
    const init_sel = objc.sel("init");
    try testing.expect(cls.respondsTo(init_sel));
    try testing.expect(cls.instanceMethod(init_sel) != null);
    try testing.expect(cls.methodImplementation(init_sel) != null);

    const alloc_sel = objc.sel("alloc");
    try testing.expect(cls.classMethod(alloc_sel) != null);

    // Protocol conformance
    if (objc.getProtocol("NSObject")) |proto| {
        try testing.expect(cls.conformsTo(proto));
    }

    // Image name
    if (cls.imageName()) |img| {
        try testing.expect(img.len > 0);
    }

    // Equality and hash
    const cls_again = objc.getClass("NSObject").?;
    try testing.expect(cls.eql(cls_again));
    try testing.expect(cls.hash() == cls_again.hash());
}

test "class: subclass superclass hierarchy" {
    const fixture_cls = objc.requireClass("ABIFixture");
    const super_cls = fixture_cls.superclass();
    try testing.expect(super_cls != null);
    try testing.expectEqualStrings("NSObject", super_cls.?.name());
}

test "class: createInstance creates non-null object" {
    const cls = objc.requireClass("NSObject");
    const inst = cls.createInstance(0);
    try testing.expect(inst != null);
    defer inst.?.dispose();

    try testing.expect(inst.?.class().eql(cls));
}
