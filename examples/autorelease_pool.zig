//! Example demonstrating Objective-C AutoreleasePool lifecycle.

const std = @import("std");
const objc = @import("objc");

pub fn main() void {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const NSDate = objc.getClass("NSDate") orelse return;
    const now = NSDate.msgSend(objc.Object, "date", .{});
    const desc = now.msgSend(objc.Object, "description", .{});
    const utf8 = desc.getProperty([*c]const u8, "UTF8String");

    std.debug.print("Current date in autorelease pool: {s}\n", .{std.mem.span(utf8)});
}
