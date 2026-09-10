//! Diagnostic formatting for Objective-C messaging compile errors.

const std = @import("std");

/// Returns a string literal representing the 0-indexed argument number formatted as "#N".
pub fn argIndexStr(comptime index: usize) []const u8 {
    return std.fmt.comptimePrint("#{d}", .{index});
}
