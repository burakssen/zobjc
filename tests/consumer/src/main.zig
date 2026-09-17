const std = @import("std");
const objc = @import("objc");

pub fn main() !void {
    const NSObject = objc.getClass("NSObject") orelse return error.ClassNotFound;
    const obj = objc.send(objc.Object, NSObject, "alloc", .{}).send(objc.Object, "init", .{});
    defer obj.send(void, "dealloc", .{});

    if (!std.mem.eql(u8, obj.getClassName(), "NSObject")) {
        return error.InvalidClassName;
    }
}
