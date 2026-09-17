//! Example demonstrating Objective-C AutoreleasePool lifecycle.

const std = @import("std");
const objc = @import("zobjc");

pub fn main() void {
    var pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const NSDate = objc.getClass("NSDate") orelse return;
    const now = NSDate.send(objc.Object, "date", .{});
    const desc = now.send(objc.Object, "description", .{});
    const utf8 = desc.getProperty([*c]const u8, "UTF8String");

    std.debug.print("Current date in autorelease pool: {s}\n", .{std.mem.span(utf8)});
}
