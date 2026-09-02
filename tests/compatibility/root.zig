//! Compatibility tests ensuring that 100% of the legacy zig-objc public API remains source compatible.

const std = @import("std");
const objc = @import("objc");
const testing = std.testing;

test "compatibility: getClass and getMetaClass" {
    const NSObject = objc.getClass("NSObject");
    try testing.expect(NSObject != null);
    try testing.expect(objc.getClass("NonExistentClass_XYZ") == null);

    const meta = objc.getMetaClass("NSObject");
    try testing.expect(meta != null);
}

test "compatibility: Sel alias and registerName" {
    const sel1: objc.Sel = objc.Sel.registerName("init");
    try testing.expectEqualStrings("init", sel1.getName());

    const sel2 = objc.sel("description");
    try testing.expectEqualStrings("description", sel2.getName());

    // New Selector type should be interchangeable with Sel
    const sel3: objc.Selector = sel1;
    try testing.expectEqualStrings("init", sel3.getName());
}

test "compatibility: Class.msgSend and Object.msgSend" {
    const NSObject = objc.getClass("NSObject").?;

    // Class msgSend
    const obj = NSObject.msgSend(objc.Object, "alloc", .{});
    try testing.expect(obj.toRaw() != null);

    // Object msgSend
    _ = obj.msgSend(objc.Object, "init", .{});
    defer obj.msgSend(void, "dealloc", .{});

    try testing.expectEqualStrings("NSObject", obj.getClassName());
}

test "compatibility: Object.msgSendSuper" {
    const Subclass = objc.allocateClassPair(objc.getClass("NSObject").?, "CompatSubclass").?;
    defer objc.disposeClassPair(Subclass);

    const str = struct {
        fn inner(target: objc.c.id, sel_val: objc.c.SEL) callconv(.c) objc.c.id {
            _ = sel_val;
            const self = objc.Object.fromId(target);
            self.msgSendSuper(objc.getClass("NSObject").?, void, "init", .{});
            return target;
        }
    };
    _ = Subclass.replaceMethod(objc.sel("init"), objc.Imp.fromRawNonNull(@ptrCast(&str.inner)), "@:@");
    objc.registerClassPair(Subclass);

    const instance = Subclass.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    defer instance.msgSend(void, "dealloc", .{});
}

test "compatibility: Block definition and invocation" {
    const AddBlock = objc.Block(struct {
        x: i32,
        y: i32,
    }, .{}, i32);

    var block_ctx = AddBlock.init(.{ .x = 10, .y = 20 }, (struct {
        fn run(ctx: *const AddBlock.Context) callconv(.c) i32 {
            return ctx.x + ctx.y;
        }
    }).run);

    const sum = AddBlock.invoke(&block_ctx, .{});
    try testing.expectEqual(@as(i32, 30), sum);
}

test "compatibility: AutoreleasePool" {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const NSObject = objc.getClass("NSObject").?;
    const obj = NSObject.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    obj.msgSend(void, "dealloc", .{});
}

test "compatibility: Property and copyPropertyList" {
    const NSObject = objc.getClass("NSObject").?;
    const list = NSObject.copyPropertyList();
    defer objc.free(list);
    try testing.expect(list.len > 0);

    const prop = NSObject.getProperty("className");
    try testing.expect(prop != null);
    try testing.expectEqualStrings("className", prop.?.getName());
}

test "compatibility: Protocol and getProtocol" {
    const proto = objc.getProtocol("NSObject");
    try testing.expect(proto != null);
    try testing.expectEqualStrings("NSObject", proto.?.getName());
}

test "compatibility: Encoding and comptimeEncode" {
    const enc = comptime objc.comptimeEncode(i32);
    try testing.expectEqualStrings("i", &enc);

    const enc_union = objc.Encoding.init(f64);
    try testing.expect(enc_union == .double);
}

test "compatibility: free function" {
    const slice = try std.heap.c_allocator.alloc(u8, 16);
    objc.free(slice);
}
