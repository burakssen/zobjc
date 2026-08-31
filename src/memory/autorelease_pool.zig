//! Autorelease pool management.

const std = @import("std");
const raw = @import("../raw/root.zig");

pub const AutoreleasePool = opaque {
    /// Create a new autorelease pool. To clean it up, call deinit.
    pub inline fn init() *AutoreleasePool {
        return @ptrCast(raw.compiler_runtime.objc_autoreleasePoolPush().?);
    }

    pub inline fn deinit(self: *AutoreleasePool) void {
        raw.compiler_runtime.objc_autoreleasePoolPop(self);
    }
};
