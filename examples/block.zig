//! Example demonstrating modern Objective-C Block creation, captures, ByRef mutation, and execution.

const std = @import("std");
const objc = @import("objc");

pub fn main() !void {
    std.debug.print("=== Modern Objective-C Blocks in zobjc ===\n", .{});

    // 1. Zero-allocation global block
    const square = objc.block.global(fn (c_int) c_int, struct {
        fn run(x: c_int) c_int {
            return x * x;
        }
    }.run);
    const sq_res = square.call(.{7});
    std.debug.print("1. Global block square(7) = {} (expected 49)\n", .{sq_res});

    // 2. Heap-allocated Block with captured values
    const Captures = struct {
        base: c_int,
        multiplier: c_int,
    };
    var calc = try objc.OwnedBlock(fn (c_int) c_int).capture(
        Captures,
        .{ .base = 10, .multiplier = 3 },
        struct {
            fn run(caps: *const Captures, input: c_int) c_int {
                return (caps.base + input) * caps.multiplier;
            }
        }.run,
    );
    defer calc.deinit();

    const calc_res = calc.call(.{5});
    std.debug.print("2. Captured block calc(5) = {} (expected 45)\n", .{calc_res});

    // 3. Mutable __block / ByRef variable capture
    var counter: objc.block.ByRef(c_int) = undefined;
    counter.init(100);
    defer counter.deinit();

    const CounterCapture = struct { ctr: objc.block.ByRefCapture(c_int) };
    var incrementer = try objc.OwnedBlock(fn (c_int) void).capture(
        CounterCapture,
        .{ .ctr = counter.capture() },
        struct {
            fn run(caps: *const CounterCapture, step: c_int) void {
                caps.ctr.set(caps.ctr.get().* + step);
            }
        }.run,
    );
    defer incrementer.deinit();

    incrementer.call(.{25});
    incrementer.call(.{15});
    std.debug.print("3. ByRef counter after 2 calls = {} (expected 140)\n", .{counter.get().*});

    // 4. Block to IMP bridging
    var greet_blk = try objc.OwnedBlock(fn (objc.Object) c_int).fromFunction(struct {
        fn run(self: objc.Object) c_int {
            _ = self;
            return 42;
        }
    }.run);
    defer greet_blk.deinit();

    var greet_imp = try greet_blk.makeImp();
    defer greet_imp.deinit();

    const NSObject = objc.requireClass("NSObject");
    const obj = NSObject.msgSend(objc.Object, "alloc", .{}).msgSend(objc.Object, "init", .{});
    defer obj.msgSend(void, "dealloc", .{});

    const imp_res = objc.callImp(c_int, greet_imp.borrow(), obj, objc.sel("test"), .{});
    std.debug.print("4. Block-to-IMP invocation result = {} (expected 42)\n", .{imp_res});

    std.debug.print("All block examples executed successfully!\n", .{});
}
