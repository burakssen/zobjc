//! Example demonstrating Objective-C Block definition, closure capture, and execution.

const std = @import("std");
const objc = @import("objc");

pub fn main() !void {
    const ComputeBlock = objc.Block(struct {
        base: i32,
        multiplier: i32,
    }, .{i32}, i32);

    const captures: ComputeBlock.Captures = .{
        .base = 10,
        .multiplier = 3,
    };

    var block = ComputeBlock.init(captures, (struct {
        fn run(ctx: *const ComputeBlock.Context, input: i32) callconv(.c) i32 {
            return (ctx.base + input) * ctx.multiplier;
        }
    }).run);

    const result = ComputeBlock.invoke(&block, .{@as(i32, 5)});
    std.debug.print("Block invocation result: {} (expected: 45)\n", .{result});
}
