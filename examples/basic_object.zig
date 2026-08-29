//! Example demonstrating basic object allocation, initialization, method calls, and memory cleanup.

const std = @import("std");
const objc = @import("objc");

pub fn main() void {
    const NSString = objc.getClass("NSString") orelse return;
    const str = NSString.msgSend(objc.Object, "stringWithUTF8String:", .{"Hello from zobjc!"});

    const length = str.msgSend(c_ulong, "length", .{});
    const utf8_ptr = str.getProperty([*c]const u8, "UTF8String");

    std.debug.print("Created NSString: \"{s}\" (length: {})\n", .{
        std.mem.span(utf8_ptr),
        length,
    });
}
