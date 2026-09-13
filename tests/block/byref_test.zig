//! ByRef (__block) variable forwarding and lifecycle tests.

const std = @import("std");
const objc = @import("objc");
const testing = std.testing;

test "byref: stack mutation via forwarding pointer" {
    var count: objc.block.ByRef(c_int) = .{};
    count.init(10);
    defer count.deinit();

    const Captures = struct {
        counter: objc.block.ByRefCapture(c_int),
    };

    var blk = try objc.OwnedBlock(fn (c_int) void).capture(
        Captures,
        .{ .counter = count.capture() },
        struct {
            fn step(caps: *const Captures, delta: c_int) void {
                const cell: *objc.block.ByRefCell(c_int) = @ptrCast(@alignCast(caps.counter.cell_ptr));
                cell.forwarding.value += delta;
            }
        }.step,
    );
    defer blk.deinit();

    blk.call(.{5});
    try testing.expectEqual(@as(c_int, 15), count.get().*);

    blk.call(.{10});
    try testing.expectEqual(@as(c_int, 25), count.get().*);
}

fn makeEscapedBlock() !objc.OwnedBlock(fn (c_int) c_int) {
    var count: objc.block.ByRef(c_int) = .{};
    count.init(100);
    defer count.deinit();

    const Captures = struct {
        counter: objc.block.ByRefCapture(c_int),
    };

    // When _Block_copy runs inside capture(), the stack ByRef cell is promoted to heap!
    return try objc.OwnedBlock(fn (c_int) c_int).capture(
        Captures,
        .{ .counter = count.capture() },
        struct {
            fn add(caps: *const Captures, delta: c_int) c_int {
                const cell: *objc.block.ByRefCell(c_int) = @ptrCast(@alignCast(caps.counter.cell_ptr));
                cell.forwarding.value += delta;
                return cell.forwarding.value;
            }
        }.add,
    );
}

test "byref: outlives original stack frame via heap promotion" {
    var escaped = try makeEscapedBlock();
    defer escaped.deinit();

    // The original stack frame of makeEscapedBlock is long gone.
    // The heap byref cell must remain valid and operational!
    const r1 = escaped.call(.{25});
    try testing.expectEqual(@as(c_int, 125), r1);

    const r2 = escaped.call(.{50});
    try testing.expectEqual(@as(c_int, 175), r2);
}
