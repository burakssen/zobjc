//! Example demonstrating NSProcessInfo usage to query macOS operating system version.

const std = @import("std");
const objc = @import("objc");

const NSOperatingSystemVersion = extern struct {
    major: i64,
    minor: i64,
    patch: i64,
};

pub fn macosVersionAtLeast(major: i64, minor: i64, patch: i64) bool {
    const NSProcessInfo = objc.getClass("NSProcessInfo") orelse return false;
    const info = NSProcessInfo.msgSend(objc.Object, "processInfo", .{});
    return info.msgSend(bool, "isOperatingSystemAtLeastVersion:", .{
        NSOperatingSystemVersion{ .major = major, .minor = minor, .patch = patch },
    });
}

pub fn main() void {
    const is_at_least_11 = macosVersionAtLeast(11, 0, 0);
    std.debug.print("macOS version >= 11.0.0: {}\n", .{is_at_least_11});
}
