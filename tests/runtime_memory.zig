const objc = @import("zobjc");
const std = @import("std");
const testing = std.testing;

// --- Runtime/memory integration: live runtime and ownership tests. ---
extern "c" fn get_dealloc_count() c_int;
extern "c" fn reset_dealloc_count() void;
// Pure conversion/layout tests stay in their modules; anything using
// the facade API or fixtures lives here.


// --- globals from src/memory/retained.zig ---
var g_dealloc_count: usize = 0;

// --- globals from src/memory/weak.zig ---
var g_weak_dealloc_count: usize = 0;

// --- globals from src/memory/autorelease_pool.zig ---
var g_pool_dealloc_count: usize = 0;

// --- from src/runtime/association.zig ---
test "associated objects: assign policy" {
    const key = objc.AssociationKey.init();
    const host = objc.requireClass("NSObject").send(objc.Object, "alloc", .{})
        .send(objc.Object, "init", .{});
    defer host.send(void, "release", .{});

    const target = objc.requireClass("NSObject").send(objc.Object, "alloc", .{})
        .send(objc.Object, "init", .{});
    defer target.send(void, "release", .{});

    try std.testing.expect(host.associated(&key) == null);
    host.setAssociated(&key, target, .assign);
    const read = host.associated(&key);
    try std.testing.expect(read != null);
    try std.testing.expectEqual(target.ptr, read.?.ptr);
    host.clearAssociated(&key);
    try std.testing.expect(host.associated(&key) == null);
}

test "associated objects: retain policies and lifetime" {
    const key1 = objc.AssociationKey.init();
    const key2 = objc.AssociationKey.init();
    reset_dealloc_count();

    const host = objc.requireClass("NSObject").send(objc.Object, "alloc", .{})
        .send(objc.Object, "init", .{});
    const tracker1 = objc.requireClass("DeallocTracker").send(objc.Object, "alloc", .{})
        .send(objc.Object, "initWithIdentifier:", .{@as(c_int, 101)});
    const tracker2 = objc.requireClass("DeallocTracker").send(objc.Object, "alloc", .{})
        .send(objc.Object, "initWithIdentifier:", .{@as(c_int, 102)});

    host.setAssociated(&key1, tracker1, .retain_nonatomic);
    host.setAssociated(&key2, tracker2, .retain);
    tracker1.send(void, "release", .{});
    tracker2.send(void, "release", .{});

    try std.testing.expectEqual(@as(c_int, 0), get_dealloc_count());
    {
        var retained = host.associatedRetained(&key1);
        try std.testing.expect(retained != null);
        try std.testing.expectEqual(tracker1.ptr, retained.?.borrow().ptr);
        retained.?.deinit();
    }
    try std.testing.expectEqual(@as(c_int, 0), get_dealloc_count());

    host.clearAssociated(&key1);
    try std.testing.expectEqual(@as(c_int, 1), get_dealloc_count());
    try std.testing.expect(host.associated(&key1) == null);

    {
        var pool = objc.AutoreleasePool.init();
        try std.testing.expect(host.associated(&key2) != null);
        host.clearAssociated(&key2);
        pool.drain();
    }
    try std.testing.expectEqual(@as(c_int, 2), get_dealloc_count());
    try std.testing.expect(host.associated(&key2) == null);
    host.send(void, "release", .{});
}

test "associated objects: copy policies" {
    const key_non_atomic = objc.AssociationKey.init();
    const key_atomic = objc.AssociationKey.init();
    const host = objc.requireClass("NSObject").send(objc.Object, "alloc", .{})
        .send(objc.Object, "init", .{});
    defer host.send(void, "release", .{});

    const original = objc.requireClass("CopyableTracker").send(objc.Object, "alloc", .{})
        .send(objc.Object, "initWithIdentifier:", .{@as(c_int, 200)});
    defer original.send(void, "release", .{});

    try std.testing.expectEqual(@as(c_int, 0), original.send(c_int, "copyCount", .{}));
    host.setAssociated(&key_non_atomic, original, .copy_nonatomic);
    const copied1 = host.associated(&key_non_atomic).?;
    try std.testing.expect(copied1.ptr != original.ptr);
    try std.testing.expectEqual(@as(c_int, 1), copied1.send(c_int, "copyCount", .{}));

    host.setAssociated(&key_atomic, original, .copy);
    const copied2 = host.associated(&key_atomic).?;
    try std.testing.expect(copied2.ptr != original.ptr);
    try std.testing.expectEqual(@as(c_int, 1), copied2.send(c_int, "copyCount", .{}));
}

// --- from src/runtime/class.zig ---
test "class: NSObject introspection" {
    const cls = objc.requireClass("NSObject");

    try std.testing.expectEqualStrings("NSObject", cls.name());
    try std.testing.expect(!cls.isMetaClass());
    try std.testing.expectEqual(@as(?objc.Class, null), cls.superclass());
    try std.testing.expect(cls.instanceSize() >= @sizeOf(usize));

    const v = cls.version();
    cls.setVersion(v + 1);
    try std.testing.expectEqual(v + 1, cls.version());
    cls.setVersion(v);

    const init_sel = objc.sel("init");
    try std.testing.expect(cls.respondsTo(init_sel));
    try std.testing.expect(cls.instanceMethod(init_sel) != null);
    try std.testing.expect(cls.methodImplementation(init_sel) != null);
    try std.testing.expect(cls.classMethod(objc.sel("alloc")) != null);

    if (objc.getProtocol("NSObject")) |proto| {
        try std.testing.expect(cls.conformsTo(proto));
    }
    if (cls.imageName()) |img| {
        try std.testing.expect(img.len > 0);
    }

    const cls_again = objc.getClass("NSObject").?;
    try std.testing.expect(cls.eql(cls_again));
    try std.testing.expect(cls.hash() == cls_again.hash());
}

test "class: subclass superclass hierarchy" {
    const fixture_cls = objc.requireClass("ABIFixture");
    const super_cls = fixture_cls.superclass();
    try std.testing.expect(super_cls != null);
    try std.testing.expectEqualStrings("NSObject", super_cls.?.name());
}

test "class: createInstance creates non-null object" {
    const cls = objc.requireClass("NSObject");
    const inst = cls.createInstance(0);
    try std.testing.expect(inst != null);
    defer inst.?.disposeObjectMemory();

    try std.testing.expect(inst.?.class().eql(cls));
}

test "hierarchy introspection: isSubclassOf and isStrictSubclassOf" {
    const NSObject = objc.requireClass("NSObject");
    const FixtureCls = objc.requireClass("ABIFixture");

    try std.testing.expect(NSObject.isSubclassOf(NSObject));
    try std.testing.expect(!NSObject.isStrictSubclassOf(NSObject));
    try std.testing.expect(FixtureCls.isSubclassOf(NSObject));
    try std.testing.expect(FixtureCls.isStrictSubclassOf(NSObject));
    try std.testing.expect(!NSObject.isSubclassOf(FixtureCls));
    try std.testing.expect(!NSObject.isStrictSubclassOf(FixtureCls));
}

test "runtime: property introspection" {
    const Tracker = objc.getClass("DeallocTracker").?;
    const prop = Tracker.property("identifier");
    try std.testing.expect(prop != null);
    try std.testing.expectEqualStrings("identifier", prop.?.name());

    try std.testing.expect(Tracker.property("nonExistentPropertyXYZ") == null);

    var prop_list = Tracker.properties();
    defer prop_list.deinit();
    try std.testing.expect(prop_list.count() > 0);
}

test "runtime: subclass creation, method replacement, and ivar addition" {
    const NSObject = objc.getClass("NSObject").?;
    var dynamic_class = objc.allocateClassPair(NSObject, "DynamicTestClass").?;
    try std.testing.expect(dynamic_class.addIvar(
        "custom_ivar",
        @sizeOf(objc.raw.id),
        @truncate(std.math.log2(@alignOf(objc.raw.id))),
        "@",
    ));

    _ = dynamic_class.replaceMethod(objc.sel("hash"), objc.Imp.fromRawNonNull(@ptrCast(&struct {
        fn inner(target: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) u64 {
            _ = target;
            _ = sel_val;
            return 42;
        }
    }.inner)), "Q@:");

    try std.testing.expect(dynamic_class.addMethod(objc.sel("multiplyByTwo:"), objc.Imp.fromRawNonNull(@ptrCast(&struct {
        fn imp(target: objc.raw.id, sel_val: objc.raw.SEL, val: i32) callconv(.c) i32 {
            _ = target;
            _ = sel_val;
            return val * 2;
        }
    }.imp)), "i@:i"));

    objc.registerClassPair(dynamic_class);
    defer objc.disposeClassPair(dynamic_class);

    const instance = dynamic_class.send(objc.Object, "alloc", .{})
        .send(objc.Object, "init", .{});
    defer instance.send(void, "release", .{});

    try std.testing.expectEqual(@as(u64, 42), instance.send(u64, "hash", .{}));
    try std.testing.expectEqual(@as(i32, 42), instance.send(i32, "multiplyByTwo:", .{@as(i32, 21)}));

    const val_obj = NSObject.send(objc.Object, "new", .{});
    defer val_obj.send(void, "release", .{});
    instance.setInstanceVariable("custom_ivar", val_obj);
    try std.testing.expect(instance.getInstanceVariable("custom_ivar").?.eql(val_obj));
}

test "mutation: dynamic class creation, methods, ivars, protocols, and properties" {
    const NSObject = objc.requireClass("NSObject");
    const DynClass = objc.allocateClassPair(NSObject, "DynamicMutationFullTest").?;

    try std.testing.expect(DynClass.addIvar(
        "counter",
        @sizeOf(i64),
        @truncate(std.math.log2(@alignOf(i64))),
        "q",
    ));

    const add_fn = struct {
        fn add(target: objc.raw.id, sel_val: objc.raw.SEL, a: i32, b: i32) callconv(.c) i32 {
            _ = target;
            _ = sel_val;
            return a + b;
        }
    }.add;
    const add_sel = objc.sel("add:and:");
    try std.testing.expect(DynClass.addMethod(add_sel, objc.Imp.fromRawNonNull(@ptrCast(&add_fn)), "i@:ii"));

    if (objc.getProtocol("NSObject")) |proto| {
        try std.testing.expect(DynClass.addProtocol(proto));
    }

    const attrs = [_]objc.PropertyAttribute{
        .{ .name = "T", .value = "q" },
        .{ .name = "V", .value = "counter" },
    };
    try std.testing.expect(DynClass.addProperty("counter", &attrs));

    objc.registerClassPair(DynClass);
    defer objc.disposeClassPair(DynClass);

    const new_add_fn = struct {
        fn new_add(target: objc.raw.id, sel_val: objc.raw.SEL, a: i32, b: i32) callconv(.c) i32 {
            _ = target;
            _ = sel_val;
            return (a + b) * 10;
        }
    }.new_add;
    try std.testing.expect(DynClass.replaceMethod(add_sel, objc.Imp.fromRawNonNull(@ptrCast(&new_add_fn)), "i@:ii") != null);

    const inst = DynClass.send(objc.Object, "alloc", .{})
        .send(objc.Object, "init", .{});
    defer inst.send(void, "release", .{});
    try std.testing.expectEqual(@as(i32, 50), inst.send(i32, add_sel, .{ @as(i32, 2), @as(i32, 3) }));

    if (objc.getProtocol("NSObject")) |proto| {
        try std.testing.expect(DynClass.conformsTo(proto));
    }
    const prop = DynClass.property("counter");
    try std.testing.expect(prop != null);
    try std.testing.expectEqualStrings("counter", prop.?.name());
}


// --- from src/runtime/enumeration.zig ---
test "class enumeration: protocol filter" {
    if (!objc.runtime.hasClassEnumeration()) return;
    const NSCopying = objc.getProtocol("NSCopying") orelse return;

    var count: usize = 0;
    var all_conform = true;
    var ctx = struct {
        cnt: *usize,
        matched: *bool,
        proto: objc.Protocol,
    }{ .cnt = &count, .matched = &all_conform, .proto = NSCopying };

    try objc.block.enumerateClasses(.{ .conforming_to = NSCopying }, &ctx, struct {
        fn cb(c: anytype, cls: objc.Class) bool {
            c.cnt.* += 1;
            if (!cls.conformsTo(c.proto)) {
                c.matched.* = false;
                return false;
            }
            return c.cnt.* < 15;
        }
    }.cb);

    try std.testing.expect(count > 0);
    try std.testing.expect(all_conform);
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

    try objc.block.enumerateClasses(.{ .subclassing = NSObject }, &ctx, struct {
        fn cb(c: anytype, cls: objc.Class) bool {
            c.cnt.* += 1;
            if (!cls.isSubclassOf(c.super_cls)) {
                c.matched.* = false;
                return false;
            }
            return c.cnt.* < 20;
        }
    }.cb);

    try std.testing.expect(count > 0);
    try std.testing.expect(all_subclasses);
}

test "class enumeration: dynamic class filter" {
    if (!objc.runtime.hasClassEnumeration()) return;

    const NSObject = objc.requireClass("NSObject");
    const dyn_cls = objc.allocateClassPair(NSObject, "EnumTestDynamicClass").?;
    objc.registerClassPair(dyn_cls);
    defer objc.disposeClassPair(dyn_cls);

    var found_dyn = false;
    try objc.block.enumerateClasses(.{ .image = .dynamic }, &found_dyn, struct {
        fn cb(found: *bool, cls: objc.Class) bool {
            if (std.mem.eql(u8, cls.name(), "EnumTestDynamicClass")) {
                found.* = true;
                return false;
            }
            return true;
        }
    }.cb);
    try std.testing.expect(found_dyn);
}

// --- from src/runtime/image.zig ---
test "image introspection: loaded images enumeration" {
    var image_list = objc.runtime.images();
    defer image_list.deinit();

    try std.testing.expect(image_list.len > 0);
    var found_libobjc = false;
    var iter = image_list.iterator();
    while (iter.next()) |name| {
        if (std.mem.indexOf(u8, name, "libobjc") != null) {
            found_libobjc = true;
            break;
        }
    }
    try std.testing.expect(found_libobjc);
}

test "image introspection: class names for image" {
    const NSObject = objc.requireClass("NSObject");
    const nsobject_image = NSObject.imageName() orelse return;

    var class_names = objc.runtime.classNamesForImage(nsobject_image);
    defer class_names.deinit();
    try std.testing.expect(class_names.len > 0);

    var found_nsobject = false;
    var name_iter = class_names.iterator();
    while (name_iter.next()) |cls_name| {
        if (std.mem.eql(u8, cls_name, "NSObject")) {
            found_nsobject = true;
            break;
        }
    }
    try std.testing.expect(found_nsobject);
}

test "image introspection: unknown image returns empty list" {
    var class_names = objc.runtime.classNamesForImage("/nonexistent/image/path.dylib");
    defer class_names.deinit();

    try std.testing.expectEqual(@as(usize, 0), class_names.len);
    try std.testing.expect(class_names.isEmpty());
}

test "image introspection: class.imageName" {
    const NSObject = objc.requireClass("NSObject");
    const image_name = NSObject.imageName();
    try std.testing.expect(image_name != null);
    try std.testing.expect(image_name.?.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, image_name.?, "libobjc") != null or
        std.mem.indexOf(u8, image_name.?, "Foundation") != null);
}

// --- from src/runtime/imp.zig ---
test "conversion: objc.Imp fromRaw and toRaw roundtrip" {
    const imp = objc.requireClass("NSObject").methodImplementation(objc.sel("init")).?;
    try std.testing.expect(imp.eql(objc.Imp.fromRaw(imp.toRaw()).?));
    try std.testing.expectEqual(@as(?objc.Imp, null), objc.Imp.fromRaw(null));
}


// --- from src/runtime/ivar.zig ---
test "ivar: dynamic class ivar introspection" {
    const NSObject = objc.requireClass("NSObject");
    const Subclass = objc.allocateClassPair(NSObject, "IvarTestClass").?;

    _ = Subclass.addIvar("test_int", @sizeOf(i32), @truncate(std.math.log2(@alignOf(i32))), "i");
    _ = Subclass.addIvar("test_ptr", @sizeOf(objc.raw.id), @truncate(std.math.log2(@alignOf(objc.raw.id))), "@");

    objc.registerClassPair(Subclass);
    defer objc.disposeClassPair(Subclass);

    const ivar_int = Subclass.instanceIvar("test_int").?;
    const ivar_ptr = Subclass.instanceIvar("test_ptr").?;
    try std.testing.expectEqualStrings("test_int", ivar_int.name().?);
    try std.testing.expectEqualStrings("test_ptr", ivar_ptr.name().?);
    try std.testing.expectEqualStrings("i", ivar_int.typeEncoding().?);
    try std.testing.expectEqualStrings("@", ivar_ptr.typeEncoding().?);

    const off_int = ivar_int.offset();
    const off_ptr = ivar_ptr.offset();
    try std.testing.expect(off_int >= 0);
    try std.testing.expect(off_ptr >= 0);
    try std.testing.expect(off_int != off_ptr);
    try std.testing.expect(ivar_int.eql(ivar_int));
    try std.testing.expect(!ivar_int.eql(ivar_ptr));
}


// --- from src/runtime/method.zig ---
test "method: NSObject description method introspection" {
    const cls = objc.requireClass("NSObject");
    const desc_sel = objc.sel("description");
    const method = cls.instanceMethod(desc_sel).?;

    try std.testing.expect(method.selector().eql(desc_sel));
    try std.testing.expect(@intFromPtr(method.implementation().ptr) != 0);

    const enc = method.typeEncoding();
    try std.testing.expect(enc != null);
    try std.testing.expect(enc.?.len > 0);
    try std.testing.expect(method.argumentCount() >= 2);

    var ret_buf: [128]u8 = undefined;
    method.returnType(&ret_buf);
    try std.testing.expectEqualStrings("@", std.mem.sliceTo(&ret_buf, 0));

    var arg0_buf: [128]u8 = undefined;
    method.argumentType(0, &arg0_buf);
    try std.testing.expectEqualStrings("@", std.mem.sliceTo(&arg0_buf, 0));

    var arg1_buf: [128]u8 = undefined;
    method.argumentType(1, &arg1_buf);
    try std.testing.expectEqualStrings(":", std.mem.sliceTo(&arg1_buf, 0));

    const desc_struct = method.description();
    try std.testing.expect(desc_struct != null);
    try std.testing.expect(desc_struct.?.selector.?.eql(desc_sel));
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
    const inst = Subclass.send(objc.Object, "alloc", .{})
        .send(objc.Object, "init", .{});
    defer inst.send(void, "release", .{});

    try std.testing.expectEqual(@as(i32, 100), inst.send(i32, sel1, .{}));
    try std.testing.expectEqual(@as(i32, 200), inst.send(i32, sel2, .{}));
    method1.exchange(method2);
    try std.testing.expectEqual(@as(i32, 200), inst.send(i32, sel1, .{}));
    try std.testing.expectEqual(@as(i32, 100), inst.send(i32, sel2, .{}));
}

test "conversion: objc.Method fromRaw and toRaw roundtrip" {
    const cls = objc.requireClass("NSObject");
    const method = cls.instanceMethod(objc.sel("init")).?;
    const raw_method = method.toRaw();
    try std.testing.expect(method.eql(objc.Method.fromRaw(raw_method).?));
    try std.testing.expectEqual(@as(?objc.Method, null), objc.Method.fromRaw(null));
}


// --- from src/runtime/object.zig ---
test "object: instance class and identity" {
    const cls = objc.requireClass("NSObject");
    const obj1 = cls.send(objc.Object, "alloc", .{})
        .send(objc.Object, "init", .{});
    defer obj1.send(void, "release", .{});

    const obj2 = cls.send(objc.Object, "alloc", .{})
        .send(objc.Object, "init", .{});
    defer obj2.send(void, "release", .{});

    try std.testing.expect(obj1.class().eql(cls));
    try std.testing.expectEqualStrings("NSObject", obj1.className());
    try std.testing.expect(!obj1.isClass());
    try std.testing.expect(obj1.eql(obj1));
    try std.testing.expect(!obj1.eql(obj2));
}

test "object: setClass dynamic isa swizzling" {
    const Base = objc.requireClass("NSObject");
    const Subclass = objc.allocateClassPair(Base, "ObjectSetClassSubclass").?;
    objc.registerClassPair(Subclass);
    defer objc.disposeClassPair(Subclass);

    const obj = Base.send(objc.Object, "alloc", .{})
        .send(objc.Object, "init", .{});
    defer obj.send(void, "release", .{});

    try std.testing.expect(obj.class().eql(Base));
    const old_cls = obj.setClass(Subclass);
    try std.testing.expect(old_cls.eql(Base));
    try std.testing.expect(obj.class().eql(Subclass));
    _ = obj.setClass(Base);
}

test "object: getIvar and setIvar" {
    const Base = objc.requireClass("NSObject");
    const Subclass = objc.allocateClassPair(Base, "ObjectIvarTestClass").?;
    _ = Subclass.addIvar("_child", @sizeOf(objc.raw.id), @truncate(std.math.log2(@alignOf(objc.raw.id))), "@");
    objc.registerClassPair(Subclass);
    defer objc.disposeClassPair(Subclass);

    const ivar = Subclass.instanceIvar("_child").?;
    const parent = Subclass.send(objc.Object, "alloc", .{})
        .send(objc.Object, "init", .{});
    defer parent.send(void, "release", .{});
    const child = Base.send(objc.Object, "alloc", .{})
        .send(objc.Object, "init", .{});
    defer child.send(void, "release", .{});

    try std.testing.expectEqual(@as(?objc.Object, null), parent.getIvar(ivar));
    parent.setIvar(ivar, child);
    try std.testing.expectEqual(child.ptr, parent.getIvar(ivar).?.ptr);
    parent.setIvar(ivar, null);
    try std.testing.expectEqual(@as(?objc.Object, null), parent.getIvar(ivar));
}

test "conversion: objc.Object fromRaw and toRaw roundtrip" {
    const cls = objc.requireClass("NSObject");
    const obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    defer obj.send(void, "release", .{});

    const raw_id = obj.toRaw();
    try std.testing.expect(raw_id != null);
    try std.testing.expect(obj.eql(objc.Object.fromRaw(raw_id).?));
    try std.testing.expect(obj.eql(objc.Object.fromRawNonNull(raw_id.?)));
    try std.testing.expectEqual(@as(?objc.Object, null), objc.Object.fromRaw(null));
}


// --- from src/runtime/property.zig ---
test "property: dynamic class property introspection" {
    const NSObject = objc.requireClass("NSObject");
    const Subclass = objc.allocateClassPair(NSObject, "PropertyTestClass").?;
    const attrs = [_]objc.PropertyAttribute{
        .{ .name = "T", .value = "@\"NSString\"" },
        .{ .name = "C", .value = "" },
        .{ .name = "N", .value = "" },
        .{ .name = "V", .value = "_title" },
    };
    try std.testing.expect(Subclass.addProperty("title", &attrs));
    objc.registerClassPair(Subclass);
    defer objc.disposeClassPair(Subclass);

    const prop = Subclass.property("title").?;
    try std.testing.expectEqualStrings("title", prop.name());
    try std.testing.expect(prop.attributes() != null);
    try std.testing.expect(prop.attributes().?.len > 0);

    if (prop.copyAttributeValue("V")) |val| {
        var owned = val;
        defer owned.deinit();
        try std.testing.expectEqualStrings("_title", owned.slice());
    } else return error.AttributeValueNotFound;
    try std.testing.expect(prop.eql(prop));
}

test "conversion: objc.Property fromRaw and toRaw roundtrip" {
    const NSObject = objc.requireClass("NSObject");
    const prop = NSObject.property("className") orelse NSObject.property("description").?;
    try std.testing.expect(prop.eql(objc.Property.fromRaw(prop.toRaw()).?));
    try std.testing.expectEqual(@as(?objc.Property, null), objc.Property.fromRaw(null));
}


// --- from src/runtime/protocol.zig ---
test "protocol: NSObject protocol introspection" {
    const proto = objc.getProtocol("NSObject") orelse return error.ProtocolNotFound;
    try std.testing.expectEqualStrings("NSObject", proto.name());
    try std.testing.expect(proto.eql(objc.getProtocol("NSObject").?));
    try std.testing.expect(proto.conformsTo(proto));

    const desc = proto.methodDescription(objc.sel("description"), .{
        .required = true,
        .instance = true,
    });
    try std.testing.expect(desc != null);
    try std.testing.expect(desc.?.selector != null);
    try std.testing.expect(desc.?.selector.?.eql(objc.sel("description")));

    try std.testing.expectEqual(
        @as(?objc.MethodDescription, null),
        proto.methodDescription(objc.sel("nonExistentSelector123"), .{}),
    );
}

test "protocol: requireProtocol succeeds on valid protocol" {
    const proto = objc.requireProtocol("NSObject");
    try std.testing.expectEqualStrings("NSObject", proto.name());
}

test "conversion: objc.Protocol fromRaw and toRaw roundtrip" {
    const proto = objc.getProtocol("NSObject").?;
    try std.testing.expect(proto.eql(objc.Protocol.fromRaw(proto.toRaw()).?));
    try std.testing.expectEqual(@as(?objc.Protocol, null), objc.Protocol.fromRaw(null));
}


// --- from src/runtime/replacement.zig ---
test "method replacement: replaceWith and conflict detection" {
    const env = try setupReplacementClass("ReplacementClass");
    defer {
        env.inst.send(void, "release", .{});
        objc.disposeClassPair(env.cls);
    }

    const method = env.cls.instanceMethod(objc.sel("methodA")).?;
    const custom_imp = struct {
        fn call(self: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) c_int {
            _ = self;
            _ = sel_val;
            return 999;
        }
    }.call;
    var replacement = objc.MethodReplacement.replace(method, objc.Imp.fromRawNonNull(@ptrCast(&custom_imp)));
    try std.testing.expectEqual(@as(c_int, 999), objc.send(c_int, env.inst, "methodA", .{}));
    try replacement.restore();
    try std.testing.expectEqual(@as(c_int, 100), objc.send(c_int, env.inst, "methodA", .{}));

    const second_imp = struct {
        fn call(self: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) c_int {
            _ = self;
            _ = sel_val;
            return 888;
        }
    }.call;
    var replacement_two = objc.MethodReplacement.replace(method, objc.Imp.fromRawNonNull(@ptrCast(&second_imp)));
    const intervening_imp = struct {
        fn call(self: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) c_int {
            _ = self;
            _ = sel_val;
            return 777;
        }
    }.call;
    _ = method.setImplementation(objc.Imp.fromRawNonNull(@ptrCast(&intervening_imp)));
    try std.testing.expectError(error.ImplementationChanged, replacement_two.restore());
}

test "method replacement: objc.BlockMethodReplacement" {
    const env = try setupReplacementClass("BlockReplacementClass");
    defer {
        env.inst.send(void, "release", .{});
        objc.disposeClassPair(env.cls);
    }

    const method = env.cls.instanceMethod(objc.sel("methodA")).?;
    var block_handle = try objc.OwnedBlock(fn (objc.Object) c_int).fromFunction(struct {
        fn blockImp(_: objc.Object) c_int {
            return 555;
        }
    }.blockImp);
    defer block_handle.deinit();

    var replacement = try objc.BlockMethodReplacement.replace(method, block_handle);
    try std.testing.expectEqual(@as(c_int, 555), objc.send(c_int, env.inst, "methodA", .{}));
    try replacement.restore();
    try std.testing.expectEqual(@as(c_int, 100), objc.send(c_int, env.inst, "methodA", .{}));
}

// --- from src/runtime/swizzle.zig ---
test "swizzle: basic swap and restore" {
    const env = try setupSwizzleClass("SwizzleBasicClass");
    defer {
        env.inst.send(void, "release", .{});
        objc.disposeClassPair(env.cls);
    }

    try std.testing.expectEqual(@as(c_int, 100), objc.send(c_int, env.inst, "methodA", .{}));
    try std.testing.expectEqual(@as(c_int, 200), objc.send(c_int, env.inst, "methodB", .{}));
    var swiz = objc.Swizzle.install(env.cls.instanceMethod(objc.sel("methodA")).?, env.cls.instanceMethod(objc.sel("methodB")).?);
    try std.testing.expectEqual(@as(c_int, 200), objc.send(c_int, env.inst, "methodA", .{}));
    try std.testing.expectEqual(@as(c_int, 100), objc.send(c_int, env.inst, "methodB", .{}));
    swiz.restore();
    try std.testing.expectEqual(@as(c_int, 100), objc.send(c_int, env.inst, "methodA", .{}));
    try std.testing.expectEqual(@as(c_int, 200), objc.send(c_int, env.inst, "methodB", .{}));
}

test "swizzle: scoped RAII swizzling" {
    const env = try setupSwizzleClass("SwizzleScopedClass");
    defer {
        env.inst.send(void, "release", .{});
        objc.disposeClassPair(env.cls);
    }

    const m_a = env.cls.instanceMethod(objc.sel("methodA")).?;
    const m_b = env.cls.instanceMethod(objc.sel("methodB")).?;
    {
        var scoped = objc.ScopedSwizzle.init(m_a, m_b);
        defer scoped.deinit();
        try std.testing.expectEqual(@as(c_int, 200), objc.send(c_int, env.inst, "methodA", .{}));
        try std.testing.expectEqual(@as(c_int, 100), objc.send(c_int, env.inst, "methodB", .{}));
    }
    try std.testing.expectEqual(@as(c_int, 100), objc.send(c_int, env.inst, "methodA", .{}));
    try std.testing.expectEqual(@as(c_int, 200), objc.send(c_int, env.inst, "methodB", .{}));
}

test "swizzle: installChecked signature validation" {
    const env = try setupSwizzleClass("SwizzleCheckedClass");
    defer {
        env.inst.send(void, "release", .{});
        objc.disposeClassPair(env.cls);
    }

    const m_a = env.cls.instanceMethod(objc.sel("methodA")).?;
    const m_b = env.cls.instanceMethod(objc.sel("methodB")).?;
    const mismatched = env.cls.instanceMethod(objc.sel("methodMismatched")).?;
    var swiz = try objc.Swizzle.installChecked(std.testing.allocator, m_a, m_b);
    defer swiz.restore();
    try std.testing.expectError(error.IncompatibleSignatures, objc.Swizzle.installChecked(std.testing.allocator, m_a, mismatched));
}

// --- from src/memory/autorelease_pool.zig ---
test "AutoreleasePool: drains autoreleased object" {
    const cls = getOrCreatePoolTestClass();
    const initial_count = g_pool_dealloc_count;
    var pool = objc.AutoreleasePool.init();
    const obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    _ = obj.send(objc.Object, "autorelease", .{});
    try std.testing.expectEqual(initial_count, g_pool_dealloc_count);
    pool.drain();
    try std.testing.expectEqual(initial_count + 1, g_pool_dealloc_count);
}

test "AutoreleasePool: nested pools follow LIFO drain ordering" {
    const cls = getOrCreatePoolTestClass();
    const initial_count = g_pool_dealloc_count;
    var outer_pool = objc.AutoreleasePool.init();
    defer outer_pool.deinit();
    const outer_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    _ = outer_obj.send(objc.Object, "autorelease", .{});

    {
        var inner_pool = objc.AutoreleasePool.init();
        const inner_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
        _ = inner_obj.send(objc.Object, "autorelease", .{});
        try std.testing.expectEqual(initial_count, g_pool_dealloc_count);
        inner_pool.drain();
        try std.testing.expectEqual(initial_count + 1, g_pool_dealloc_count);
    }
    outer_pool.drain();
    try std.testing.expectEqual(initial_count + 2, g_pool_dealloc_count);
}

// --- from src/memory/owned_c_string.zig ---
test "OwnedCString: method.copyReturnType" {
    const method = objc.requireClass("NSObject").instanceMethod(objc.sel("description")).?;
    var ret_type = method.copyReturnType().?;
    defer ret_type.deinit();
    try std.testing.expectEqualStrings("@", ret_type.slice());
    try std.testing.expectEqual(@as(usize, 1), ret_type.len());
    ret_type.deinit();
    try std.testing.expectEqual(@as(usize, 0), ret_type.len());
}

test "OwnedCString: method.copyArgumentType" {
    const method = objc.requireClass("NSObject").instanceMethod(objc.sel("isEqual:")).?;
    var arg0 = method.copyArgumentType(0).?;
    defer arg0.deinit();
    try std.testing.expectEqualStrings("@", arg0.slice());
    var arg1 = method.copyArgumentType(1).?;
    defer arg1.deinit();
    try std.testing.expectEqualStrings(":", arg1.slice());
    var arg2 = method.copyArgumentType(2).?;
    defer arg2.deinit();
    try std.testing.expectEqualStrings("@", arg2.slice());
    try std.testing.expect(method.copyArgumentType(99) == null);
}

test "OwnedCString: property.copyAttributeValue" {
    const NSObject = objc.requireClass("NSObject");
    if (NSObject.property("className")) |prop| {
        if (prop.copyAttributeValue("T")) |val| {
            var owned = val;
            defer owned.deinit();
            try std.testing.expect(owned.len() > 0);
        }
    }
}

test "OwnedCString: intoRaw relinquishes ownership" {
    const method = objc.requireClass("NSObject").instanceMethod(objc.sel("description")).?;
    var ret_type = method.copyReturnType().?;
    const raw_ptr = ret_type.intoRaw();
    try std.testing.expectEqual(@as(usize, 0), ret_type.len());
    ret_type.deinit();
    try std.testing.expectEqualStrings("@", std.mem.span(raw_ptr));
    std.c.free(@ptrCast(raw_ptr));
}


// --- from src/memory/owned_c_string_list.zig ---
test "OwnedCStringList: objc.runtime.imageNames and classNamesForImage" {
    var images = objc.runtime.imageNames();
    defer images.deinit();
    try std.testing.expect(!images.isEmpty());
    try std.testing.expect(images.count() > 0);
    try std.testing.expect(images.get(0).?.len > 0);

    var count: usize = 0;
    var iter = images.iterator();
    while (iter.next()) |_| count += 1;
    try std.testing.expectEqual(images.count(), count);

    var libobjc_image: ?[:0]const u8 = null;
    var img_iter = images.iterator();
    while (img_iter.next()) |img| {
        if (std.mem.indexOf(u8, img, "libobjc") != null) {
            libobjc_image = img;
            break;
        }
    }
    if (libobjc_image) |target_image| {
        var class_names = objc.runtime.classNamesForImage(target_image);
        defer class_names.deinit();
        try std.testing.expect(class_names.count() > 0);
        try std.testing.expect(class_names.get(0).?.len > 0);
    }
}


// --- from src/memory/owned_method_descriptions.zig ---
test "OwnedMethodDescriptions: protocol.methodDescriptions" {
    const proto = objc.getProtocol("NSObject").?;
    var req_methods = proto.methodDescriptions(.{ .required = true, .instance = true });
    defer req_methods.deinit();
    try std.testing.expect(!req_methods.isEmpty());
    try std.testing.expect(req_methods.count() > 0);
    try std.testing.expect(req_methods.get(0).?.selector.?.name().len > 0);

    var count: usize = 0;
    var iter = req_methods.iterator();
    while (iter.next()) |_| count += 1;
    try std.testing.expectEqual(req_methods.count(), count);
}


// --- from src/memory/owned_property_attributes.zig ---
test "OwnedPropertyAttributes: property.attributesList" {
    const NSObject = objc.requireClass("NSObject");
    const prop = NSObject.property("className") orelse NSObject.property("description").?;
    var attrs = prop.attributesList();
    defer attrs.deinit();
    try std.testing.expect(!attrs.isEmpty());
    try std.testing.expect(attrs.count() > 0);
    try std.testing.expect(std.mem.span(attrs.get(0).?.name).len > 0);

    var count: usize = 0;
    var iter = attrs.iterator();
    while (iter.next()) |_| count += 1;
    try std.testing.expectEqual(attrs.count(), count);
}


// --- from src/memory/owned_runtime_list.zig ---
test "OwnedRuntimeList: class.methods and dupe" {
    const NSObject = objc.requireClass("NSObject");
    var method_list = NSObject.methods();
    try std.testing.expect(!method_list.isEmpty());
    try std.testing.expect(method_list.count() > 0);
    const first_method = method_list.get(0).?;

    var iter = method_list.iterator();
    var iterated_count: usize = 0;
    while (iter.next()) |_| iterated_count += 1;
    try std.testing.expectEqual(method_list.count(), iterated_count);

    const duped = try method_list.dupe(std.testing.allocator);
    defer std.testing.allocator.free(duped);
    try std.testing.expectEqual(method_list.count(), duped.len);
    method_list.deinit();
    try std.testing.expect(method_list.isEmpty());
    try std.testing.expectEqual(first_method.toRaw(), duped[0].toRaw());
}

test "OwnedRuntimeList: class.classMethods" {
    var class_methods = objc.requireClass("NSObject").classMethods();
    defer class_methods.deinit();
    try std.testing.expect(!class_methods.isEmpty());
    try std.testing.expect(class_methods.count() > 0);
}

test "OwnedRuntimeList: class.properties" {
    var props = objc.requireClass("NSObject").properties();
    defer props.deinit();
    try std.testing.expect(!props.isEmpty());
    try std.testing.expect(props.count() > 0);
}

test "OwnedRuntimeList: class.protocols" {
    var protos = objc.requireClass("NSObject").protocols();
    defer protos.deinit();
    try std.testing.expect(protos.count() >= 0);
}

test "OwnedRuntimeList: class.ivars" {
    var ivars = objc.requireClass("NSObject").ivars();
    defer ivars.deinit();
    try std.testing.expect(ivars.count() >= 1);
    try std.testing.expectEqualStrings("isa", ivars.get(0).?.name().?);
}

test "OwnedRuntimeList: objc.classes" {
    var all_classes = objc.classes();
    defer all_classes.deinit();
    try std.testing.expect(all_classes.count() >= 5);

    var found_nsobject = false;
    var iter = all_classes.iterator();
    while (iter.next()) |cls| {
        if (std.mem.eql(u8, cls.name(), "NSObject")) {
            found_nsobject = true;
            break;
        }
    }
    try std.testing.expect(found_nsobject);
}

test "OwnedRuntimeList: objc.protocols" {
    var all_protocols = objc.protocols();
    defer all_protocols.deinit();
    try std.testing.expect(all_protocols.count() > 10);

    var found_nsobject_proto = false;
    var iter = all_protocols.iterator();
    while (iter.next()) |proto| {
        if (std.mem.eql(u8, proto.name(), "NSObject")) {
            found_nsobject_proto = true;
            break;
        }
    }
    try std.testing.expect(found_nsobject_proto);
}

test "OwnedRuntimeList: empty container behavior" {
    var empty_list = objc.memory.OwnedRuntimeList(objc.Method).empty();
    try std.testing.expect(empty_list.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), empty_list.count());
    try std.testing.expect(empty_list.get(0) == null);
    var iter = empty_list.iterator();
    try std.testing.expect(iter.next() == null);
    empty_list.deinit();
    try std.testing.expect(empty_list.isEmpty());
}

// --- from src/memory/retained.zig ---
test "Retained: compile-time retainable traits" {
    const traits_mod = objc.memory.traits;
    try std.testing.expect(traits_mod.isRetainable(objc.Object));
    try std.testing.expect(!traits_mod.isRetainable(objc.Class));
    try std.testing.expect(!traits_mod.isRetainable(i32));
}

test "Retained: adopt takes ownership and deinit releases" {
    const cls = getOrCreateTestClass();
    const initial_count = g_dealloc_count;
    const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var retained = objc.memory.Retained(objc.Object).adopt(raw_obj);
    try std.testing.expectEqual(initial_count, g_dealloc_count);
    try std.testing.expectEqual(raw_obj.toRaw(), retained.borrow().toRaw());
    retained.deinit();
    try std.testing.expectEqual(initial_count + 1, g_dealloc_count);
    retained.deinit();
}

test "Retained: retain increments retain count" {
    const cls = getOrCreateTestClass();
    const initial_count = g_dealloc_count;
    const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var r1 = objc.memory.Retained(objc.Object).adopt(raw_obj);
    var r2 = objc.memory.Retained(objc.Object).retain(r1.borrow());
    r1.deinit();
    try std.testing.expectEqual(initial_count, g_dealloc_count);
    r2.deinit();
    try std.testing.expectEqual(initial_count + 1, g_dealloc_count);
}

test "Retained: clone increments retain count" {
    const cls = getOrCreateTestClass();
    const initial_count = g_dealloc_count;
    const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var r1 = objc.memory.Retained(objc.Object).adopt(raw_obj);
    var r2 = r1.clone();
    r1.deinit();
    try std.testing.expectEqual(initial_count, g_dealloc_count);
    r2.deinit();
    try std.testing.expectEqual(initial_count + 1, g_dealloc_count);
}

test "Retained: intoUnmanaged relinquishes ownership without releasing" {
    const cls = getOrCreateTestClass();
    const initial_count = g_dealloc_count;
    const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var retained = objc.memory.Retained(objc.Object).adopt(raw_obj);
    const unmanaged = retained.intoUnmanaged();
    retained.deinit();
    try std.testing.expectEqual(initial_count, g_dealloc_count);
    _ = objc.raw.compiler_runtime.objc_release(unmanaged.toRaw());
    try std.testing.expectEqual(initial_count + 1, g_dealloc_count);
}

test "Retained: retainOptional and adoptOptional" {
    const cls = getOrCreateTestClass();
    const initial_count = g_dealloc_count;
    try std.testing.expect(objc.memory.Retained(objc.Object).adoptOptional(null) == null);
    try std.testing.expect(objc.memory.Retained(objc.Object).retainOptional(null) == null);

    const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    if (objc.memory.Retained(objc.Object).adoptOptional(raw_obj)) |*retained| {
        var mutable = retained.*;
        defer mutable.deinit();
        try std.testing.expectEqual(raw_obj.toRaw(), mutable.borrow().toRaw());
    } else return error.UnexpectedNull;
    try std.testing.expectEqual(initial_count + 1, g_dealloc_count);
}

test "Retained: createInstanceRetained on objc.Class" {
    const cls = getOrCreateTestClass();
    const initial_count = g_dealloc_count;
    var retained = cls.createInstanceRetained(0).?;
    _ = retained.borrow().send(objc.Object, "init", .{});
    retained.deinit();
    try std.testing.expectEqual(initial_count + 1, g_dealloc_count);
}

fn consumeThroughPointer(owner: *objc.memory.Retained(objc.Object)) void {
    // Recommended pattern: owners travel by pointer, never by value.
    owner.deinit();
}

test "Retained: pointer-passing invalidates owner without copying" {
    const cls = getOrCreateTestClass();
    const initial_count = g_dealloc_count;
    const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var retained = objc.memory.Retained(objc.Object).adopt(raw_obj);
    consumeThroughPointer(&retained);
    try std.testing.expectEqual(initial_count + 1, g_dealloc_count);
    // Second deinit on the same (now empty) value is a safe no-op.
    retained.deinit();
    try std.testing.expectEqual(initial_count + 1, g_dealloc_count);
}

// --- from src/memory/weak.zig ---
test "Weak: in-place initialization and loadRetained while alive" {
    const cls = getOrCreateWeakTestClass();
    const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var strong = objc.memory.Retained(objc.Object).adopt(raw_obj);
    defer strong.deinit();
    var weak: objc.memory.Weak(objc.Object) = .{};
    weak.init(strong.borrow());
    defer weak.deinit();

    if (weak.loadRetained()) |*loaded| {
        var mutable = loaded.*;
        defer mutable.deinit();
        try std.testing.expectEqual(strong.borrow().toRaw(), mutable.borrow().toRaw());
    } else return error.ExpectedNonNullWeak;
}

test "Weak: automatic zeroing when strong owner deallocates" {
    const cls = getOrCreateWeakTestClass();
    const initial_dealloc = g_weak_dealloc_count;
    var weak: objc.memory.Weak(objc.Object) = .{};
    defer weak.deinit();
    {
        const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
        var strong = objc.memory.Retained(objc.Object).adopt(raw_obj);
        weak.init(strong.borrow());
        if (weak.loadRetained()) |*loaded| {
            var mutable = loaded.*;
            mutable.deinit();
        } else return error.ExpectedNonNullWeak;
        try std.testing.expectEqual(initial_dealloc, g_weak_dealloc_count);
        strong.deinit();
        try std.testing.expectEqual(initial_dealloc + 1, g_weak_dealloc_count);
    }
    try std.testing.expect(weak.loadRetained() == null);
}

test "Weak: store and clear" {
    const cls = getOrCreateWeakTestClass();
    const raw_obj1 = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var strong1 = objc.memory.Retained(objc.Object).adopt(raw_obj1);
    defer strong1.deinit();
    const raw_obj2 = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var strong2 = objc.memory.Retained(objc.Object).adopt(raw_obj2);
    defer strong2.deinit();
    var weak: objc.memory.Weak(objc.Object) = .{};
    weak.init(strong1.borrow());
    defer weak.deinit();

    try std.testing.expect(weak.loadRetained() != null);
    if (weak.loadRetained()) |*loaded| {
        var mutable = loaded.*;
        mutable.deinit();
    }
    weak.store(strong2.borrow());
    if (weak.loadRetained()) |*loaded| {
        var mutable = loaded.*;
        defer mutable.deinit();
        try std.testing.expectEqual(strong2.borrow().toRaw(), mutable.borrow().toRaw());
    } else return error.ExpectedNonNull;
    weak.clear();
    try std.testing.expect(weak.loadRetained() == null);
}

test "Weak: copyFrom and moveFrom" {
    const cls = getOrCreateWeakTestClass();
    const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var strong = objc.memory.Retained(objc.Object).adopt(raw_obj);
    defer strong.deinit();
    var weak1: objc.memory.Weak(objc.Object) = .{};
    weak1.init(strong.borrow());
    defer weak1.deinit();
    var weak2: objc.memory.Weak(objc.Object) = .{};
    defer weak2.deinit();
    weak2.copyFrom(&weak1);
    try std.testing.expect(weak1.loadRetained() != null);
    if (weak1.loadRetained()) |*loaded| {
        var mutable = loaded.*;
        mutable.deinit();
    }
    var weak3: objc.memory.Weak(objc.Object) = .{};
    defer weak3.deinit();
    weak3.moveFrom(&weak2);
    try std.testing.expect(weak2.loadRetained() == null);
    try std.testing.expect(weak3.loadRetained() != null);
    if (weak3.loadRetained()) |*loaded| {
        var mutable = loaded.*;
        mutable.deinit();
    }
}

test "Weak: loadBorrowed with autorelease pool" {
    const cls = getOrCreateWeakTestClass();
    const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var strong = objc.memory.Retained(objc.Object).adopt(raw_obj);
    defer strong.deinit();
    var weak: objc.memory.Weak(objc.Object) = .{};
    weak.init(strong.borrow());
    defer weak.deinit();
    var pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    try std.testing.expectEqual(strong.borrow().toRaw(), weak.loadBorrowed().?.toRaw());
}

// --- helpers from src/runtime/replacement.zig ---
fn setupReplacementClass(name: [:0]const u8) !struct { cls: objc.Class, inst: objc.Object } {
    const super_cls = objc.requireClass("NSObject");
    const dyn_cls = objc.raw.runtime.objc_allocateClassPair(super_cls.toRaw(), name.ptr, 0) orelse
        return error.ClassAllocFailed;

    const original_imp = struct {
        fn call(self: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) c_int {
            _ = self;
            _ = sel_val;
            return 100;
        }
    }.call;
    _ = objc.raw.runtime.class_addMethod(dyn_cls, objc.sel("methodA").toRaw(), @ptrCast(&original_imp), "i@:");
    objc.raw.runtime.objc_registerClassPair(dyn_cls);

    const cls = objc.Class.fromRaw(dyn_cls).?;
    const inst = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    return .{ .cls = cls, .inst = inst };
}

// --- helpers from src/runtime/swizzle.zig ---
fn setupSwizzleClass(name: [:0]const u8) !struct { cls: objc.Class, inst: objc.Object } {
    const super_cls = objc.requireClass("NSObject");
    const dyn_cls = objc.raw.runtime.objc_allocateClassPair(super_cls.toRaw(), name.ptr, 0) orelse
        return error.ClassAllocFailed;

    const fn_a = struct {
        fn imp(self: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) c_int {
            _ = self;
            _ = sel_val;
            return 100;
        }
    }.imp;
    const fn_b = struct {
        fn imp(self: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) c_int {
            _ = self;
            _ = sel_val;
            return 200;
        }
    }.imp;
    const fn_mismatched = struct {
        fn imp(self: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) f32 {
            _ = self;
            _ = sel_val;
            return 1.5;
        }
    }.imp;

    _ = objc.raw.runtime.class_addMethod(dyn_cls, objc.sel("methodA").toRaw(), @ptrCast(&fn_a), "i@:");
    _ = objc.raw.runtime.class_addMethod(dyn_cls, objc.sel("methodB").toRaw(), @ptrCast(&fn_b), "i@:");
    _ = objc.raw.runtime.class_addMethod(dyn_cls, objc.sel("methodMismatched").toRaw(), @ptrCast(&fn_mismatched), "f@:");
    objc.raw.runtime.objc_registerClassPair(dyn_cls);

    const cls = objc.Class.fromRaw(dyn_cls).?;
    const inst = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    return .{ .cls = cls, .inst = inst };
}

// --- helpers from src/memory/retained.zig ---
var g_super_dealloc_fn: ?*const fn (objc.raw.id, objc.raw.SEL) callconv(.c) void = null;
fn customDealloc(self_id: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) void {
    g_dealloc_count += 1;
    if (g_super_dealloc_fn) |super_fn| super_fn(self_id, sel_val);
}
fn getOrCreateTestClass() objc.Class {
    const class_name = "RetainedLifecycleTestClass";
    if (objc.getClass(class_name)) |existing| return existing;

    const NSObject = objc.requireClass("NSObject");
    const cls = objc.allocateClassPair(NSObject, class_name).?;
    g_super_dealloc_fn = @ptrCast(NSObject.instanceMethod(objc.sel("dealloc")).?.implementation().toRaw());
    _ = cls.addMethod(objc.sel("dealloc"), objc.Imp.fromRawNonNull(@ptrCast(&customDealloc)), "v@:");
    objc.registerClassPair(cls);
    return cls;
}

// --- helpers from src/memory/weak.zig ---
var g_weak_super_dealloc_fn: ?*const fn (objc.raw.id, objc.raw.SEL) callconv(.c) void = null;
fn customWeakDealloc(self_id: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) void {
    g_weak_dealloc_count += 1;
    if (g_weak_super_dealloc_fn) |super_fn| super_fn(self_id, sel_val);
}
fn getOrCreateWeakTestClass() objc.Class {
    const class_name = "WeakLifecycleTestClass";
    if (objc.getClass(class_name)) |existing| return existing;

    const NSObject = objc.requireClass("NSObject");
    const cls = objc.allocateClassPair(NSObject, class_name).?;
    g_weak_super_dealloc_fn = @ptrCast(NSObject.instanceMethod(objc.sel("dealloc")).?.implementation().toRaw());
    _ = cls.addMethod(objc.sel("dealloc"), objc.Imp.fromRawNonNull(@ptrCast(&customWeakDealloc)), "v@:");
    objc.registerClassPair(cls);
    return cls;
}

// --- helpers from src/memory/autorelease_pool.zig ---
var g_pool_super_dealloc_fn: ?*const fn (objc.raw.id, objc.raw.SEL) callconv(.c) void = null;
fn customPoolDealloc(self_id: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) void {
    g_pool_dealloc_count += 1;
    if (g_pool_super_dealloc_fn) |super_fn| super_fn(self_id, sel_val);
}
fn getOrCreatePoolTestClass() objc.Class {
    const class_name = "AutoreleasePoolLifecycleTestClass";
    if (objc.getClass(class_name)) |existing| return existing;

    const NSObject = objc.requireClass("NSObject");
    const cls = objc.allocateClassPair(NSObject, class_name).?;
    g_pool_super_dealloc_fn = @ptrCast(NSObject.instanceMethod(objc.sel("dealloc")).?.implementation().toRaw());
    _ = cls.addMethod(objc.sel("dealloc"), objc.Imp.fromRawNonNull(@ptrCast(&customPoolDealloc)), "v@:");
    objc.registerClassPair(cls);
    return cls;
}

test "integration: custom object wrappers retain and weak-reference" {
    const Custom = struct {
        ptr: *objc.raw.objc_object,
        pub const objc_wrapper = true;
    };
    const cls = getOrCreateTestClass();
    const initial_count = g_dealloc_count;
    const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    const custom = Custom{ .ptr = raw_obj.toRaw().? };

    var retained = objc.memory.Retained(Custom).adopt(custom);
    try std.testing.expectEqual(custom.ptr, retained.borrow().ptr);

    var weak: objc.memory.Weak(Custom) = .{};
    weak.init(custom);
    defer weak.deinit();
    if (weak.loadRetained()) |*loaded| {
        var mutable = loaded.*;
        defer mutable.deinit();
        try std.testing.expectEqual(custom.ptr, mutable.borrow().ptr);
    } else return error.ExpectedNonNullWeak;

    retained.deinit();
    try std.testing.expectEqual(initial_count + 1, g_dealloc_count);
}

test "class enumeration: early stop" {
    if (!objc.runtime.hasClassEnumeration()) return;

    var count: usize = 0;
    try objc.block.enumerateClasses(.{}, &count, struct {
        fn cb(c_ptr: *usize, cls: objc.Class) bool {
            _ = cls;
            c_ptr.* += 1;
            return c_ptr.* < 2;
        }
    }.cb);
    try std.testing.expectEqual(@as(usize, 2), count);
}

test "class enumeration: prefix filter" {
    if (!objc.runtime.hasClassEnumeration()) return;

    var count: usize = 0;
    var all_start_with_dealloc = true;
    var ctx = struct {
        cnt: *usize,
        matched: *bool,
    }{ .cnt = &count, .matched = &all_start_with_dealloc };

    try objc.block.enumerateClasses(.{ .name_prefix = "Dealloc" }, &ctx, struct {
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

    try std.testing.expect(count > 0);
    try std.testing.expect(all_start_with_dealloc);
}
