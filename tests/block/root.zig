//! Baseline behavioral tests for the block subsystem.

const std = @import("std");
const objc = @import("objc");
const testing = std.testing;

test "block: creation, captures, and invocation" {
    const AddBlock = objc.Block(struct {
        x: i32,
        y: i32,
    }, .{}, i32);

    const captures: AddBlock.Captures = .{
        .x = 20,
        .y = 22,
    };

    var block = AddBlock.init(captures, (struct {
        fn add(ctx: *const AddBlock.Context) callconv(.c) i32 {
            return ctx.x + ctx.y;
        }
    }).add);

    const result = AddBlock.invoke(&block, .{});
    try testing.expectEqual(@as(i32, 42), result);
}

test "block: heap copy and release" {
    const SimpleBlock = objc.Block(struct {
        val: i32,
    }, .{i32}, i32);

    var block = SimpleBlock.init(.{ .val = 100 }, (struct {
        fn multiply(ctx: *const SimpleBlock.Context, factor: i32) callconv(.c) i32 {
            return ctx.val * factor;
        }
    }).multiply);

    const copied = try SimpleBlock.copy(&block);
    defer SimpleBlock.release(copied);

    const result = SimpleBlock.invoke(copied, .{@as(i32, 5)});
    try testing.expectEqual(@as(i32, 500), result);
}

test "block: captured objc object retains across copy" {
    const NSObject = objc.getClass("NSObject").?;
    const obj = NSObject.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    defer obj.msgSend(void, "dealloc", .{});

    const ObjectBlock = objc.Block(struct {
        id: objc.c.id,
    }, .{}, objc.c.id);

    var block = ObjectBlock.init(.{ .id = obj.toRaw() }, (struct {
        fn get(ctx: *const ObjectBlock.Context) callconv(.c) objc.c.id {
            return ctx.id;
        }
    }).get);

    const copied = try ObjectBlock.copy(&block);
    defer ObjectBlock.release(copied);

    const returned_id = ObjectBlock.invoke(copied, .{});
    try testing.expectEqual(obj.toRaw(), returned_id);
}
