//! Trivial value capture and alignment tests.

const std = @import("std");
const objc = @import("objc");
const testing = std.testing;

test "capture: trivial integer and float captures" {
    const Captures = struct {
        base: c_int,
        multiplier: f64,
    };

    var blk = try objc.OwnedBlock(fn (c_int) f64).capture(
        Captures,
        .{ .base = 10, .multiplier = 2.5 },
        struct {
            fn compute(caps: *const Captures, input: c_int) f64 {
                return @as(f64, @floatFromInt(caps.base + input)) * caps.multiplier;
            }
        }.compute,
    );
    defer blk.deinit();

    const res = blk.call(.{2});
    try testing.expectEqual(@as(f64, 30.0), res);
}

test "capture: mixed alignment layout" {
    const MixedCaptures = struct {
        c: u8,
        pad: u64,
        s: u16,
    };

    var blk = try objc.OwnedBlock(fn () u64).capture(
        MixedCaptures,
        .{ .c = 5, .pad = 1000, .s = 20 },
        struct {
            fn sum(caps: *const MixedCaptures) u64 {
                return @as(u64, caps.c) + caps.pad + @as(u64, caps.s);
            }
        }.sum,
    );
    defer blk.deinit();

    const res = blk.call(.{});
    try testing.expectEqual(@as(u64, 1025), res);
}

test "capture: trivial captures do not require copy/dispose helpers" {
    const TrivialCaptures = struct {
        x: c_int,
        y: f64,
        p: ?*anyopaque,
    };

    var blk = try objc.OwnedBlock(fn () void).capture(
        TrivialCaptures,
        .{ .x = 1, .y = 2.0, .p = null },
        struct {
            fn run(_: *const TrivialCaptures) void {}
        }.run,
    );
    defer blk.deinit();

    const raw_ptr = blk.borrow().toRaw();
    try testing.expect(!objc.block.diagnostics.hasCopyDispose(raw_ptr));
}
