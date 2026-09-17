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
    _ = @import("association_test.zig");
    _ = @import("image_test.zig");
    _ = @import("enumeration_test.zig");
    _ = @import("swizzle_test.zig");
    _ = @import("advanced_test.zig");
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
    const Tracker = objc.getClass("DeallocTracker").?;
    const prop = Tracker.getProperty("identifier");
    try testing.expect(prop != null);
    try testing.expectEqualStrings("identifier", prop.?.getName());

    const missing_prop = Tracker.getProperty("nonExistentPropertyXYZ");
    try testing.expect(missing_prop == null);

    const prop_list = Tracker.copyPropertyList();
    defer objc.free(prop_list);
    try testing.expect(prop_list.len > 0);
}

test "runtime: protocol lookup and conformance" {
    const obj_proto = objc.getProtocol("NSObject") orelse return error.ProtocolNotFound;
    try testing.expectEqualStrings("NSObject", obj_proto.getName());

    // Dynamically construct protocols to verify conformance in pure libobjc
    var parent_builder = try objc.ProtocolBuilder.init("RuntimeTestParentProto");
    const parent_proto = parent_builder.register();

    var child_builder = try objc.ProtocolBuilder.init("RuntimeTestChildProto");
    try child_builder.inherit(parent_proto);
    const child_proto = child_builder.register();

    try testing.expect(child_proto.conformsToProtocol(parent_proto));
    try testing.expect(!parent_proto.conformsToProtocol(child_proto));
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

    // Test ivar access with an NSObject
    const val_obj = NSObject.msgSend(objc.Object, "new", .{});
    defer val_obj.release();

    instance.setInstanceVariable("custom_ivar", val_obj);
    const read_ivar = instance.getInstanceVariable("custom_ivar").?;
    try testing.expect(read_ivar.eql(val_obj));
}

test "runtime: object retain and release" {
    const NSObject = objc.getClass("NSObject").?;
    const obj = NSObject.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    defer obj.msgSend(void, "dealloc", .{});

    const retained = obj.retain();
    retained.release();
}
