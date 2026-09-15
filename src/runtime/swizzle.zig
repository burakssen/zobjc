//! Structured Objective-C method swizzling.
//!
//! Provides reversible method implementation swapping with explicit restoration,
//! signature compatibility checks, and test-scoped RAII helpers.

const std = @import("std");
const raw = @import("../raw/root.zig");
const Method = @import("method.zig").Method;
const encoding = @import("../encoding/root.zig");

/// Structured representation of an active or restorable method swizzle.
///
/// WARNING: Swizzling mutates global process runtime state. Automatic restoration
/// on deinit is provided only by `ScopedSwizzle` for isolated unit tests.
pub const Swizzle = struct {
    first: Method,
    second: Method,
    active: bool,

    const Self = @This();

    /// Exchanges the implementations of `first` and `second`.
    pub fn install(first: Method, second: Method) Swizzle {
        first.exchange(second);
        return .{
            .first = first,
            .second = second,
            .active = true,
        };
    }

    /// Validates signature compatibility before exchanging method implementations.
    pub fn installChecked(
        allocator: std.mem.Allocator,
        first: Method,
        second: Method,
    ) !Swizzle {
        var sig1 = try first.parsedSignature(allocator);
        defer sig1.deinit(allocator);
        var sig2 = try second.parsedSignature(allocator);
        defer sig2.deinit(allocator);

        // Verify receiver kind and parameter/return types
        if (!sig1.eql(sig2)) {
            return error.IncompatibleSignatures;
        }

        return install(first, second);
    }

    /// Restores the original implementations.
    pub fn restore(self: *Self) void {
        if (self.active) {
            self.first.exchange(self.second);
            self.active = false;
        }
    }
};

/// Scoped RAII wrapper for method swizzling in controlled test environments.
///
/// Automatically restores original method implementations upon `deinit()`.
pub const ScopedSwizzle = struct {
    swizzle: Swizzle,

    const Self = @This();

    pub fn init(first: Method, second: Method) Self {
        return .{ .swizzle = Swizzle.install(first, second) };
    }

    pub fn initChecked(allocator: std.mem.Allocator, first: Method, second: Method) !Self {
        return .{ .swizzle = try Swizzle.installChecked(allocator, first, second) };
    }

    pub fn deinit(self: *Self) void {
        self.swizzle.restore();
    }
};
