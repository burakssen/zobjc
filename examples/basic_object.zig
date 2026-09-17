//! Example demonstrating basic object allocation, initialization, method calls, and memory cleanup.

const std = @import("std");
const objc = @import("zobjc");

pub fn main() void {
    const NSObject = objc.requireClass("NSObject");
    const object = NSObject.send(objc.Object, "new", .{});
    defer object.send(void, "dealloc", .{});

    const object_class = object.send(objc.Class, "class", .{});
    std.debug.print("Created {s} instance via objc.send\n", .{object_class.name()});
}
