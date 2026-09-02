//! Baseline and modular unit tests for the runtime subsystem.

const std = @import("std");
const objc = @import("objc");
const testing = std.testing;

test {
    _ = @import("handle_sizes_test.zig");
    _ = @import("conversion_test.zig");
    _ = @import("selector_test.zig");
    _ = @import("class_test.zig");
    _ = @import("method_test.zig");
    _ = @import("ivar_test.zig");
    _ = @import("property_test.zig");
    _ = @import("protocol_test.zig");
    _ = @import("object_test.zig");
    _ = @import("lookup_test.zig");
    _ = @import("mutation_test.zig");
}

test "runtime: class lookup and metaclass lookup" {
    const NSObject = objc.getClass("NSObject");
    try testing.expect(NSObject != null);
    try testing.expect(objc.getClass("NonExistent_Class_404") == null);

    const meta = objc.getMetaClass("NSObject");
    try testing.expect(meta != null);
    try testing.expect(meta.?.isMetaClass());
    try testing.expect(!NSObject.?.isMetaClass());
}

test "runtime: selector registration and inspection" {
    const s = objc.Selector.registerName("description");
    try testing.expectEqualStrings("description", s.getName());

    const s2 = objc.sel("count");
    try testing.expectEqualStrings("count", s2.getName());
}

test "runtime: property introspection" {
    const NSObject = objc.getClass("NSObject").?;
    const prop = NSObject.getProperty("className");
    try testing.expect(prop != null);
    try testing.expectEqualStrings("className", prop.?.getName());

    const missing_prop = NSObject.getProperty("nonExistentPropertyXYZ");
    try testing.expect(missing_prop == null);

    const prop_list = NSObject.copyPropertyList();
    defer objc.free(prop_list);
    try testing.expect(prop_list.len > 0);
}

test "runtime: protocol lookup and conformance" {
    // Touch NSFileManager so the runtime loads its delegate protocol
    _ = objc.getClass("NSFileManager");

    const obj_proto = objc.getProtocol("NSObject") orelse return error.ProtocolNotFound;
    try testing.expectEqualStrings("NSObject", obj_proto.getName());

    const fm_proto = objc.getProtocol("NSFileManagerDelegate") orelse return error.ProtocolNotFound;
    try testing.expectEqualStrings("NSFileManagerDelegate", fm_proto.getName());
    try testing.expect(fm_proto.conformsToProtocol(obj_proto));

    const url_proto = objc.getProtocol("NSURLSessionDelegate") orelse return error.ProtocolNotFound;
    try testing.expect(!fm_proto.conformsToProtocol(url_proto));
}

test "runtime: subclass creation, method replacement, and ivar addition" {
    const NSObject = objc.getClass("NSObject").?;
    var dynamic_class = objc.allocateClassPair(NSObject, "DynamicTestClass").?;

    // Add an ivar
    try testing.expect(dynamic_class.addIvar("custom_ivar", @sizeOf(objc.raw.id), @truncate(std.math.log2(@alignOf(objc.raw.id))), "@"));

    // Replace a method
    _ = dynamic_class.replaceMethod(objc.sel("hash"), objc.Imp.fromRawNonNull(@ptrCast(&struct {
        fn inner(target: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) u64 {
            _ = target;
            _ = sel_val;
            return 42;
        }
    }.inner)), "Q@:");

    // Add a new method
    try testing.expect(dynamic_class.addMethod(objc.sel("multiplyByTwo:"), objc.Imp.fromRawNonNull(@ptrCast(&struct {
        fn imp(target: objc.raw.id, sel_val: objc.raw.SEL, val: i32) callconv(.c) i32 {
            _ = target;
            _ = sel_val;
            return val * 2;
        }
    }.imp)), "i@:i"));

    objc.registerClassPair(dynamic_class);
    defer objc.disposeClassPair(dynamic_class);

    const instance = dynamic_class.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    defer instance.msgSend(void, "dealloc", .{});

    // Test replaced method
    const hash_val = instance.msgSend(u64, "hash", .{});
    try testing.expectEqual(@as(u64, 42), hash_val);

    // Test added method
    const mul_val = instance.msgSend(i32, "multiplyByTwo:", .{@as(i32, 21)});
    try testing.expectEqual(@as(i32, 42), mul_val);

    // Test ivar access
    const NSString = objc.getClass("NSString").?;
    const str = NSString.msgSend(objc.Object, "stringWithUTF8String:", .{"ivar_test_val"});
    defer str.msgSend(void, "dealloc", .{});

    instance.setInstanceVariable("custom_ivar", str);
    const read_ivar = instance.getInstanceVariable("custom_ivar").?;
    const utf8 = read_ivar.getProperty([*c]const u8, "UTF8String");
    try testing.expectEqualStrings("ivar_test_val", std.mem.span(utf8));
}

test "runtime: object retain and release" {
    const NSObject = objc.getClass("NSObject").?;
    const obj = NSObject.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    defer obj.msgSend(void, "dealloc", .{});

    const retained = obj.retain();
    retained.release();
}
