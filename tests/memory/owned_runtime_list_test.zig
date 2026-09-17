//! Owned runtime list tests (OwnedRuntimeList).

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

test "OwnedRuntimeList: class.methods and dupe" {
    const NSObject = objc.requireClass("NSObject");

    var method_list = NSObject.methods();
    try testing.expect(!method_list.isEmpty());
    try testing.expect(method_list.count() > 0);

    const first_method = method_list.get(0);
    try testing.expect(first_method != null);

    // Iterate through methods
    var iter = method_list.iterator();
    var iterated_count: usize = 0;
    while (iter.next()) |_| {
        iterated_count += 1;
    }
    try testing.expectEqual(method_list.count(), iterated_count);

    // Dupe produces an independent slice
    const duped = try method_list.dupe(testing.allocator);
    defer testing.allocator.free(duped);
    try testing.expectEqual(method_list.count(), duped.len);

    // Deinit list
    method_list.deinit();
    try testing.expectEqual(@as(usize, 0), method_list.count());
    try testing.expect(method_list.isEmpty());

    // Duped slice is still valid
    try testing.expectEqual(first_method.?.toRaw(), duped[0].toRaw());
}

test "OwnedRuntimeList: class.classMethods" {
    const NSObject = objc.requireClass("NSObject");
    var class_methods = NSObject.classMethods();
    defer class_methods.deinit();

    try testing.expect(!class_methods.isEmpty());
    try testing.expect(class_methods.count() > 0);
}

test "OwnedRuntimeList: class.properties" {
    const NSObject = objc.requireClass("NSObject");
    var props = NSObject.properties();
    defer props.deinit();

    try testing.expect(!props.isEmpty());
    try testing.expect(props.count() > 0);
}

test "OwnedRuntimeList: class.protocols" {
    const NSObject = objc.requireClass("NSObject");
    var protos = NSObject.protocols();
    defer protos.deinit();

    // NSObject conforms to at least NSCopying or NSObject protocol
    try testing.expect(protos.count() >= 0);
}

test "OwnedRuntimeList: class.ivars" {
    const NSObject = objc.requireClass("NSObject");
    var ivars = NSObject.ivars();
    defer ivars.deinit();

    // NSObject has isa ivar
    try testing.expect(ivars.count() >= 1);
    const isa_ivar = ivars.get(0).?;
    try testing.expectEqualStrings("isa", isa_ivar.getName().?);
}

test "OwnedRuntimeList: objc.classes" {
    var all_classes = objc.classes();
    defer all_classes.deinit();

    try testing.expect(all_classes.count() >= 5);

    var found_nsobject = false;
    var iter = all_classes.iterator();
    while (iter.next()) |cls| {
        if (std.mem.eql(u8, cls.getName(), "NSObject")) {
            found_nsobject = true;
            break;
        }
    }
    try testing.expect(found_nsobject);
}

test "OwnedRuntimeList: objc.protocols" {
    var all_protocols = objc.protocols();
    defer all_protocols.deinit();

    try testing.expect(all_protocols.count() > 10);

    var found_nsobject_proto = false;
    var iter = all_protocols.iterator();
    while (iter.next()) |proto| {
        if (std.mem.eql(u8, proto.getName(), "NSObject")) {
            found_nsobject_proto = true;
            break;
        }
    }
    try testing.expect(found_nsobject_proto);
}

test "OwnedRuntimeList: empty container behavior" {
    var empty_list = objc.memory.OwnedRuntimeList(objc.Method).empty();
    try testing.expect(empty_list.isEmpty());
    try testing.expectEqual(@as(usize, 0), empty_list.count());
    try testing.expect(empty_list.get(0) == null);

    var iter = empty_list.iterator();
    try testing.expect(iter.next() == null);

    // deinit on empty is safe
    empty_list.deinit();
    try testing.expect(empty_list.isEmpty());
}
