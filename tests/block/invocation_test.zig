//! Bidirectional invocation tests between Zig and Objective-C Clang blocks.

const std = @import("std");
const objc = @import("objc");
const raw = objc.raw;
const testing = std.testing;

extern "c" fn make_int_multiplier_block(multiplier: c_int) *anyopaque;
extern "c" fn make_object_holder_block(obj: raw.id) *anyopaque;
extern "c" fn make_byref_counter_block(initial: c_int) *anyopaque;

extern "c" fn invoke_int_block(block: *anyopaque, val: c_int) c_int;
extern "c" fn invoke_object_block(block: *anyopaque, val: raw.id) raw.id;
extern "c" fn invoke_two_arg_block(block: *anyopaque, x: c_int, y: c_int) c_int;

test "invocation: Zig calling Zig block" {
    var blk = try objc.OwnedBlock(fn (c_int, c_int) c_int).fromFunction(struct {
        fn multiply(a: c_int, b: c_int) c_int {
            return a * b;
        }
    }.multiply);
    defer blk.deinit();

    const res = blk.call(.{ 6, 7 });
    try testing.expectEqual(@as(c_int, 42), res);
}

test "invocation: Zig calling Clang blocks" {
    // 1. Int multiplier block
    const raw_int_blk = make_int_multiplier_block(4);
    defer raw.blocks._Block_release(raw_int_blk);

    const int_blk = objc.Block(fn (c_int) c_int).fromRaw(@ptrCast(@alignCast(raw_int_blk)));
    const int_res = int_blk.call(.{10});
    try testing.expectEqual(@as(c_int, 40), int_res);

    // 2. Object holder block
    const NSObject = objc.getClass("NSObject").?;
    const obj = NSObject.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    defer obj.msgSend(void, "release", .{});

    const raw_obj_blk = make_object_holder_block(obj.toRaw());
    defer raw.blocks._Block_release(raw_obj_blk);

    const obj_blk = objc.Block(fn () ?objc.Object).fromRaw(@ptrCast(@alignCast(raw_obj_blk)));
    const held_obj = obj_blk.call(.{});
    try testing.expect(held_obj != null);
    try testing.expectEqual(obj.toRaw(), held_obj.?.toRaw());

    // 3. ByRef counter block
    const raw_byref_blk = make_byref_counter_block(10);
    defer raw.blocks._Block_release(raw_byref_blk);

    const byref_blk = objc.Block(fn (c_int) c_int).fromRaw(@ptrCast(@alignCast(raw_byref_blk)));
    try testing.expectEqual(@as(c_int, 15), byref_blk.call(.{5}));
    try testing.expectEqual(@as(c_int, 25), byref_blk.call(.{10}));
}

test "invocation: Clang calling Zig blocks" {
    // 1. Single int argument
    var int_blk = try objc.OwnedBlock(fn (c_int) c_int).fromFunction(struct {
        fn square(x: c_int) c_int {
            return x * x;
        }
    }.square);
    defer int_blk.deinit();

    const int_res = invoke_int_block(@ptrCast(int_blk.borrow().toRaw()), 8);
    try testing.expectEqual(@as(c_int, 64), int_res);

    // 2. Two arguments
    var add_blk = try objc.OwnedBlock(fn (c_int, c_int) c_int).fromFunction(struct {
        fn add(x: c_int, y: c_int) c_int {
            return x + y;
        }
    }.add);
    defer add_blk.deinit();

    const add_res = invoke_two_arg_block(@ptrCast(add_blk.borrow().toRaw()), 100, 25);
    try testing.expectEqual(@as(c_int, 125), add_res);

    // 3. Object argument and return
    const NSObject = objc.getClass("NSObject").?;
    const obj = NSObject.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    defer obj.msgSend(void, "release", .{});

    var echo_blk = try objc.OwnedBlock(fn (?objc.Object) ?objc.Object).fromFunction(struct {
        fn echo(in_obj: ?objc.Object) ?objc.Object {
            return in_obj;
        }
    }.echo);
    defer echo_blk.deinit();

    const ret_id = invoke_object_block(@ptrCast(echo_blk.borrow().toRaw()), obj.toRaw());
    try testing.expectEqual(obj.toRaw(), ret_id);
}
