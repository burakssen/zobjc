//! Objective-C Block capture lifecycle tests.
//!
//! Uses DeallocTracker to prove exact deallocation points for Strong and BlockRef captures.

const std = @import("std");
const objc = @import("objc");
const raw = objc.raw;
const testing = std.testing;

extern "c" fn get_dealloc_count() c_int;
extern "c" fn reset_dealloc_count() void;

test "lifecycle: Strong(Object) keeps object alive and deallocates on block destroy" {
    reset_dealloc_count();

    const TrackerClass = objc.getClass("DeallocTracker").?;
    const tracker_raw = TrackerClass.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "initWithIdentifier:", .{@as(c_int, 42)});

    const Captures = struct {
        tracker: objc.block.Strong(objc.Object),
    };

    var blk = try objc.OwnedBlock(fn () c_int).capture(
        Captures,
        .{ .tracker = objc.block.Strong(objc.Object).init(tracker_raw) },
        struct {
            fn run(caps: *const Captures) c_int {
                return objc.send(c_int, caps.tracker.borrow(), "identifier", .{});
            }
        }.run,
    );

    // Release the original owner reference: block must now be the sole owner
    tracker_raw.msgSend(void, "release", .{});
    try testing.expectEqual(@as(c_int, 0), get_dealloc_count());

    // Block is invoked and accesses the object safely
    const ident = blk.call(.{});
    try testing.expectEqual(@as(c_int, 42), ident);
    try testing.expectEqual(@as(c_int, 0), get_dealloc_count());

    // Destroying the block releases the strong capture, causing deallocation
    blk.deinit();
    try testing.expectEqual(@as(c_int, 1), get_dealloc_count());
}

test "lifecycle: nested BlockRef captures" {
    var inner_block = try objc.OwnedBlock(fn (c_int) c_int).fromFunction(struct {
        fn double(x: c_int) c_int {
            return x * 2;
        }
    }.double);

    const OuterCaptures = struct {
        inner: objc.block.BlockRef(fn (c_int) c_int),
    };

    var outer_block = try objc.OwnedBlock(fn (c_int) c_int).capture(
        OuterCaptures,
        .{ .inner = objc.block.BlockRef(fn (c_int) c_int).init(inner_block) },
        struct {
            fn run(caps: *const OuterCaptures, val: c_int) c_int {
                // Borrow captured block and invoke it
                const inner = objc.Block(fn (c_int) c_int).fromRaw(caps.inner.rawPtr().?);
                return inner.call(.{val}) + 5;
            }
        }.run,
    );

    // Destroy original inner block owner: outer block holds an independent copy
    inner_block.deinit();

    const res = outer_block.call(.{10});
    try testing.expectEqual(@as(c_int, 25), res);

    outer_block.deinit();
}
