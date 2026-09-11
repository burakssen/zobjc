//! Example demonstrating dynamic class creation using ClassBuilder.

const std = @import("std");
const objc = @import("objc");

pub fn main() !void {
    std.debug.print("=== Dynamic Class Creation with ClassBuilder ===\n\n", .{});

    const NSObject = objc.requireClass("NSObject");

    // 1. Initialize ClassBuilder
    var builder = try objc.ClassBuilder.init("ExampleCounter", NSObject);
    errdefer builder.abort();

    // 2. Add an instance variable for count storage
    try builder.addIvar(c_int, "_count");

    // 3. Add instance methods using ergonomic Zig callbacks
    const getCount = struct {
        fn run(self: objc.Object, _: objc.Selector) c_int {
            const cls = self.class();
            const ivar = cls.instanceIvar("_count").?;
            const base: [*]u8 = @ptrCast(self.ptr);
            const off: usize = @intCast(ivar.offset());
            const ptr: *const c_int = @ptrCast(@alignCast(&base[off]));
            return ptr.*;
        }
    }.run;

    const setCount = struct {
        fn run(self: objc.Object, _: objc.Selector, new_val: c_int) void {
            const cls = self.class();
            const ivar = cls.instanceIvar("_count").?;
            const base: [*]u8 = @ptrCast(self.ptr);
            const off: usize = @intCast(ivar.offset());
            const ptr: *c_int = @ptrCast(@alignCast(&base[off]));
            ptr.* = new_val;
        }
    }.run;

    const addDelta = struct {
        fn run(self: objc.Object, _: objc.Selector, delta: c_int) c_int {
            const cls = self.class();
            const ivar = cls.instanceIvar("_count").?;
            const base: [*]u8 = @ptrCast(self.ptr);
            const off: usize = @intCast(ivar.offset());
            const ptr: *c_int = @ptrCast(@alignCast(&base[off]));
            ptr.* += delta;
            return ptr.*;
        }
    }.run;

    const classInfo = struct {
        fn run(cls: objc.Class, _: objc.Selector) [*:0]const u8 {
            _ = cls;
            return "ExampleCounter - A dynamically constructed Objective-C class from Zig!";
        }
    }.run;

    try builder.addMethod("count", getCount);
    try builder.addMethod("setCount:", setCount);
    try builder.addMethod("add:", addDelta);
    try builder.addClassMethod("info", classInfo);

    // 4. Register the class
    const CounterClass = builder.register();
    std.debug.print("Successfully registered class: {s}\n", .{CounterClass.name()});

    // 5. Invoke class method
    const info_str = CounterClass.send([*:0]const u8, "info", .{});
    std.debug.print("Class info: {s}\n\n", .{std.mem.span(info_str)});

    // 6. Instantiate the dynamic class and message it
    const counter = CounterClass.send(objc.Object, "new", .{});
    std.debug.print("Initial count: {d}\n", .{counter.send(c_int, "count", .{})});

    counter.send(void, "setCount:", .{@as(c_int, 50)});
    std.debug.print("After setCount(50): {d}\n", .{counter.send(c_int, "count", .{})});

    const new_count = counter.send(c_int, "add:", .{@as(c_int, 25)});
    std.debug.print("After add(25): {d}\n", .{new_count});
    std.debug.print("Final count: {d}\n", .{counter.send(c_int, "count", .{})});
}
