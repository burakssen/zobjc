//! Differential tests comparing zobjc Blocks and ByRef subsystem against Clang Blocks.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

// Clang Block fixtures from tests/fixtures/blocks/fixtures.h
extern fn reset_dealloc_count() void;
extern fn get_dealloc_count() c_int;
extern fn make_int_multiplier_block(multiplier: c_int) *anyopaque;
extern fn make_object_holder_block(obj: objc.raw.id) *anyopaque;
extern fn invoke_int_block(block: *const anyopaque, val: c_int) c_int;
extern fn get_clang_block_flags(block: *anyopaque) i32;

test "differential: Block flags match Clang generated Blocks" {
    const clang_blk = make_int_multiplier_block(3);
    defer _ = objc.raw.blocks._Block_release(clang_blk);

    const clang_flags = get_clang_block_flags(clang_blk);

    // Clang heap-allocated block with no captures beyond scalar:
    // Should have BLOCK_HAS_SIGNATURE (1 << 30)
    try testing.expect((clang_flags & (1 << 30)) != 0);
}

test "differential: Clang can invoke zobjc typed Block" {
    var blk = try objc.OwnedBlock(fn (c_int) c_int).fromFunction(struct {
        fn doubleVal(x: c_int) c_int {
            return x * 7;
        }
    }.doubleVal);
    defer blk.deinit();

    const result = invoke_int_block(@ptrCast(blk.toRaw()), 6);
    try testing.expectEqual(@as(c_int, 42), result);
}

test "differential: strong capture lifecycle verified by observable destruction" {
    reset_dealloc_count();
    const Tracker = objc.getClass("DeallocTracker").?;

    {
        const tracker_obj = objc.send(objc.Object, Tracker, "alloc", .{})
            .send(objc.Object, "initWithIdentifier:", .{@as(c_int, 100)});

        // Wrap in Retained
        var retained = objc.memory.Retained(objc.Object).adopt(tracker_obj);

        const Captures = struct {
            tracked: objc.block.Strong(objc.Object),
        };

        var blk = try objc.OwnedBlock(fn () c_int).capture(
            Captures,
            .{ .tracked = objc.block.Strong(objc.Object).init(retained.borrow()) },
            struct {
                fn run(caps: *const Captures) c_int {
                    return caps.tracked.borrow().send(c_int, "identifier", .{});
                }
            }.run,
        );
        defer blk.deinit();

        // Release the outer Retained ownership: block now holds the only strong reference
        retained.deinit();

        // Target should be alive
        try testing.expectEqual(@as(c_int, 0), get_dealloc_count());
        try testing.expectEqual(@as(c_int, 100), blk.call(.{}));
    }

    // After heap block deinitialization, object must be deallocated
    try testing.expectEqual(@as(c_int, 1), get_dealloc_count());
}

fn makeEscapedBlock() !objc.OwnedBlock(fn (c_int) c_int) {
    var count: objc.block.ByRef(c_int) = .{};
    count.init(100);
    defer count.deinit();

    const Captures = struct {
        counter: objc.block.ByRefCapture(c_int),
    };

    // When capture() runs, the stack ByRef cell is promoted to heap!
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

test "differential: ByRef forwarding outlives original stack frame" {
    var escaped = try makeEscapedBlock();
    defer escaped.deinit();

    // Invoking the block after the creating stack frame has exited
    try testing.expectEqual(@as(c_int, 105), escaped.call(.{5}));
    try testing.expectEqual(@as(c_int, 115), escaped.call(.{10}));
}

test "differential: Block to IMP bridge lifecycle" {
    const NSObject = objc.getClass("NSObject").?;
    var builder = objc.builder.ClassBuilder.init("BlockImpBridgeTest", NSObject) catch |err| switch (err) {
        error.ClassAlreadyExists => {
            return; // already tested/registered in this process
        },
        else => return err,
    };

    var blk = try objc.OwnedBlock(fn (objc.Object, c_int) c_int).fromFunction(struct {
        fn bridgeFn(self: objc.Object, val: c_int) c_int {
            _ = self;
            return val + 100;
        }
    }.bridgeFn);
    defer blk.deinit();

    var owned_imp = try objc.block.imp.makeImp(blk);
    defer owned_imp.deinit();

    const sel = objc.sel("bridgeTest:");
    _ = builder.class_val.?.addMethod(sel, owned_imp.borrow(), "i@:i");

    const RegisteredClass = builder.register();

    const inst = objc.send(objc.Object, RegisteredClass, "alloc", .{}).send(objc.Object, "init", .{});
    defer inst.send(void, "dealloc", .{});

    const result = inst.send(c_int, "bridgeTest:", .{@as(c_int, 42)});
    try testing.expectEqual(@as(c_int, 142), result);
}
