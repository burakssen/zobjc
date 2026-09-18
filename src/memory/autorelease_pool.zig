//! Scoped autorelease pool token management.
//!
//! Autorelease pools are thread-local and must be created and popped in strict
//! LIFO (stack) order.

const std = @import("std");
const testing = std.testing;
const raw = @import("raw");

/// A scoped autorelease pool that pops its boundary on `deinit()`.
///
/// AutoreleasePool is an owning value and MUST NOT be copied.
pub const AutoreleasePool = struct {
    token: ?*anyopaque,

    /// Pushes a new autorelease pool context.
    pub fn init() AutoreleasePool {
        return .{
            .token = raw.compiler_runtime.objc_autoreleasePoolPush(),
        };
    }

    /// Drains and pops the autorelease pool (alias for deinit).
    pub inline fn drain(self: *AutoreleasePool) void {
        self.deinit();
    }

    /// Pops the autorelease pool token via `objc_autoreleasePoolPop`.
    /// Idempotent: safe to call multiple times.
    pub fn deinit(self: *AutoreleasePool) void {
        if (self.token) |tok| {
            raw.compiler_runtime.objc_autoreleasePoolPop(tok);
            self.token = null;
        }
    }
};




test "AutoreleasePool: basic creation and idempotent drain" {
    var pool = AutoreleasePool.init();
    try testing.expect(pool.token != null);
    pool.drain();
    try testing.expect(pool.token == null);
    pool.drain();
    pool.deinit();
    try testing.expect(pool.token == null);
}

