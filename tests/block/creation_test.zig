//! Block creation, heap cloning, and lifecycle tests.

const std = @import("std");
const objc = @import("objc");
const testing = std.testing;

test "creation: fromFunction no-capture block" {
    var blk = try objc.OwnedBlock(fn (c_int) c_int).fromFunction(struct {
        fn double(x: c_int) c_int {
            return x * 2;
        }
    }.double);
    defer blk.deinit();

    const res = blk.call(.{21});
    try testing.expectEqual(@as(c_int, 42), res);
}

test "creation: global block" {
    const blk = objc.block.global(fn (c_int, c_int) c_int, struct {
        fn add(a: c_int, b: c_int) c_int {
            return a + b;
        }
    }.add);

    try testing.expect(objc.block.diagnostics.isGlobal(blk.toRaw()));
    const res = blk.call(.{ 15, 27 });
    try testing.expectEqual(@as(c_int, 42), res);
}

test "creation: clone creates independent ownership" {
    var original = try objc.OwnedBlock(fn (c_int) c_int).fromFunction(struct {
        fn triple(x: c_int) c_int {
            return x * 3;
        }
    }.triple);

    var copy = try original.clone();
    original.deinit(); // destroy original owner

    // copy must still be alive and callable
    const res = copy.call(.{10});
    try testing.expectEqual(@as(c_int, 30), res);
    copy.deinit();
}

test "creation: intoRaw relinquishes ownership" {
    var blk = try objc.OwnedBlock(fn () void).fromFunction(struct {
        fn nop() void {}
    }.nop);

    const raw_ptr = blk.intoRaw();
    try testing.expectEqual(@as(?*objc.raw.blocks.Block_layout, null), blk.ptr);

    // Manually release
    objc.raw.blocks._Block_release(raw_ptr);
}
