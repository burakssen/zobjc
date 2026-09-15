//! Example demonstrating Phase 9 advanced runtime facilities:
//! image discovery, class enumeration, associations, swizzling, and manual instance management.

const std = @import("std");
const objc = @import("objc");

pub fn main() !void {
    std.debug.print("=== Objective-C Runtime Inspector (Phase 9) ===\n\n", .{});

    // 1. Mach-O Image Introspection
    std.debug.print("--- Loaded Mach-O Images ---\n", .{});
    var img_list = objc.runtime.images();
    defer img_list.deinit();

    std.debug.print("Total loaded images: {d}\n", .{img_list.count()});
    var img_iter = img_list.iterator();
    var shown: usize = 0;
    while (img_iter.next()) |img_name| {
        if (shown < 3) {
            std.debug.print("  [{d}] {s}\n", .{ shown, img_name });
            shown += 1;
        }
    }
    if (img_list.count() > 3) {
        std.debug.print("  ... and {d} more images\n", .{img_list.count() - 3});
    }

    // 2. Class Names for a Specific Image
    const NSString = objc.requireClass("NSString");
    if (NSString.imageName()) |str_img| {
        std.debug.print("\n--- Classes in NSString Image ---\n", .{});
        std.debug.print("Image: {s}\n", .{str_img});
        var cls_names = objc.runtime.classNamesForImage(str_img);
        defer cls_names.deinit();
        std.debug.print("Total classes in image: {d}\n", .{cls_names.count()});
    }

    // 3. Class Hierarchy Introspection
    std.debug.print("\n--- Subclass Hierarchy ---\n", .{});
    const NSObject = objc.requireClass("NSObject");
    std.debug.print("NSString.isSubclassOf(NSObject): {}\n", .{NSString.isSubclassOf(NSObject)});
    std.debug.print("NSString.isStrictSubclassOf(NSObject): {}\n", .{NSString.isStrictSubclassOf(NSObject)});
    std.debug.print("NSObject.isStrictSubclassOf(NSObject): {}\n", .{NSObject.isStrictSubclassOf(NSObject)});

    // 4. Associated Objects
    std.debug.print("\n--- Associated Objects ---\n", .{});
    const host = NSObject.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    defer host.msgSend(void, "dealloc", .{});

    const key = objc.AssociationKey.init();
    host.setAssociated(&key, host, .assign);
    const associated_obj = host.associated(&key);
    std.debug.print("Associated object attached: {}\n", .{associated_obj != null});
    host.clearAssociated(&key);
    std.debug.print("Associated object cleared: {}\n", .{host.associated(&key) == null});

    // 5. Method Swizzling
    std.debug.print("\n--- Method Swizzling ---\n", .{});
    const super_cls = objc.requireClass("NSObject");
    const dyn_cls = objc.raw.runtime.objc_allocateClassPair(super_cls.toRaw(), "InspectorDemoClass", 0).?;

    const impA = struct {
        fn imp(self: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) c_int {
            _ = self;
            _ = sel_val;
            return 111;
        }
    }.imp;
    const impB = struct {
        fn imp(self: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) c_int {
            _ = self;
            _ = sel_val;
            return 222;
        }
    }.imp;

    _ = objc.raw.runtime.class_addMethod(dyn_cls, objc.sel("methodA").toRaw(), @ptrCast(&impA), "i@:");
    _ = objc.raw.runtime.class_addMethod(dyn_cls, objc.sel("methodB").toRaw(), @ptrCast(&impB), "i@:");
    objc.raw.runtime.objc_registerClassPair(dyn_cls);

    const demo_cls = objc.Class.fromRaw(dyn_cls).?;
    defer objc.disposeClassPair(demo_cls);

    const demo_inst = demo_cls.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    defer demo_inst.msgSend(void, "dealloc", .{});

    const mA = demo_cls.instanceMethod(objc.sel("methodA")).?;
    const mB = demo_cls.instanceMethod(objc.sel("methodB")).?;

    std.debug.print("Before swizzle: methodA = {d}, methodB = {d}\n", .{
        objc.send(c_int, demo_inst, "methodA", .{}),
        objc.send(c_int, demo_inst, "methodB", .{}),
    });

    var swizzle = objc.Swizzle.install(mA, mB);
    std.debug.print("After swizzle:  methodA = {d}, methodB = {d}\n", .{
        objc.send(c_int, demo_inst, "methodA", .{}),
        objc.send(c_int, demo_inst, "methodB", .{}),
    });

    swizzle.restore();
    std.debug.print("After restore:  methodA = {d}, methodB = {d}\n", .{
        objc.send(c_int, demo_inst, "methodA", .{}),
        objc.send(c_int, demo_inst, "methodB", .{}),
    });

    // 6. Manual Instance Construction
    std.debug.print("\n--- Manual Instance Construction ---\n", .{});
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const instance_size = NSObject.instanceSize();
    const storage = try allocator.alignedAlloc(u8, .fromByteUnits(@alignOf(objc.raw.id)), instance_size);
    @memset(storage, 0);

    const constructed = objc.advanced.constructInstance(NSObject, storage.ptr).?;
    _ = constructed.msgSend(objc.Object, "init", .{});
    std.debug.print("Constructed instance of: {s}\n", .{constructed.class().name()});

    const returned_buf = objc.advanced.destructInstance(constructed);
    std.debug.print("Destructed instance, returned buffer: {}\n", .{returned_buf == @as(?*anyopaque, @ptrCast(storage.ptr))});

    std.debug.print("\nInspector completed successfully.\n", .{});
}
