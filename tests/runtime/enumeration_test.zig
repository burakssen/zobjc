//! Tests for filtered class enumeration and subclass hierarchy introspection.
// ponytail: minimalist, zero overhead, verify early-stop and filters.

const std = @import("std");
const objc = @import("objc");
const testing = std.testing;

test "hierarchy introspection: isSubclassOf and isStrictSubclassOf" {
    const NSObject = objc.requireClass("NSObject");
    const NSString = objc.requireClass("NSString");

    // Reflexive
    try testing.expect(NSObject.isSubclassOf(NSObject));
    try testing.expect(!NSObject.isStrictSubclassOf(NSObject));

    // Subclass
    try testing.expect(NSString.isSubclassOf(NSObject));
    try testing.expect(NSString.isStrictSubclassOf(NSObject));

    // Reverse
    try testing.expect(!NSObject.isSubclassOf(NSString));
    try testing.expect(!NSObject.isStrictSubclassOf(NSString));
}

test "class enumeration: early stop" {
    if (!objc.runtime.hasClassEnumeration()) return;

    var count: usize = 0;
    try objc.runtime.enumerateClasses(.{}, &count, struct {
        fn cb(c_ptr: *usize, cls: objc.Class) bool {
            _ = cls;
            c_ptr.* += 1;
            return c_ptr.* < 2;
        }
    }.cb);

    try testing.expectEqual(@as(usize, 2), count);
}

test "class enumeration: prefix filter" {
    if (!objc.runtime.hasClassEnumeration()) return;

    var count: usize = 0;
    var all_start_with_dealloc = true;

    var ctx = struct {
        cnt: *usize,
        matched: *bool,
    }{ .cnt = &count, .matched = &all_start_with_dealloc };

    try objc.runtime.enumerateClasses(.{ .name_prefix = "Dealloc" }, &ctx, struct {
        fn cb(c: anytype, cls: objc.Class) bool {
            c.cnt.* += 1;
            const cls_name = cls.name();
            if (!std.mem.startsWith(u8, cls_name, "Dealloc")) {
                c.matched.* = false;
                return false;
            }
            return true;
        }
    }.cb);

    try testing.expect(count > 0);
    try testing.expect(all_start_with_dealloc);
}

test "class enumeration: protocol filter" {
    if (!objc.runtime.hasClassEnumeration()) return;

    // Load protocol
    const NSCopying = objc.getProtocol("NSCopying") orelse return;

    var count: usize = 0;
    var all_conform = true;

    var ctx = struct {
        cnt: *usize,
        matched: *bool,
        proto: objc.Protocol,
    }{ .cnt = &count, .matched = &all_conform, .proto = NSCopying };

    try objc.runtime.enumerateClasses(.{ .conforming_to = NSCopying }, &ctx, struct {
        fn cb(c: anytype, cls: objc.Class) bool {
            c.cnt.* += 1;
            if (!cls.conformsToProtocol(c.proto)) {
                c.matched.* = false;
                return false;
            }
            return c.cnt.* < 15;
        }
    }.cb);

    try testing.expect(count > 0);
    try testing.expect(all_conform);
}

test "class enumeration: superclass filter" {
    if (!objc.runtime.hasClassEnumeration()) return;

    const NSObject = objc.requireClass("NSObject");

    var count: usize = 0;
    var all_subclasses = true;

    var ctx = struct {
        cnt: *usize,
        matched: *bool,
        super_cls: objc.Class,
    }{ .cnt = &count, .matched = &all_subclasses, .super_cls = NSObject };

    try objc.runtime.enumerateClasses(.{ .subclassing = NSObject }, &ctx, struct {
        fn cb(c: anytype, cls: objc.Class) bool {
            c.cnt.* += 1;
            if (!cls.isSubclassOf(c.super_cls)) {
                c.matched.* = false;
                return false;
            }
            return c.cnt.* < 20;
        }
    }.cb);

    try testing.expect(count > 0);
    try testing.expect(all_subclasses);
}

test "class enumeration: dynamic class filter" {
    if (!objc.runtime.hasClassEnumeration()) return;

    const NSObject = objc.requireClass("NSObject");
    const dyn_cls = objc.allocateClassPair(NSObject, "EnumTestDynamicClass").?;
    objc.registerClassPair(dyn_cls);
    defer objc.disposeClassPair(dyn_cls);

    var found_dyn = false;
    try objc.runtime.enumerateClasses(.{ .image = .dynamic }, &found_dyn, struct {
        fn cb(found: *bool, cls: objc.Class) bool {
            if (std.mem.eql(u8, cls.name(), "EnumTestDynamicClass")) {
                found.* = true;
                return false;
            }
            return true;
        }
    }.cb);

    try testing.expect(found_dyn);
}
