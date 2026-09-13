//! Objective-C Block ↔ IMP bridging.
//!
//! Bridges Apple Blocks into callable method IMPs via `imp_implementationWithBlock`
//! and ensures cleanup via `imp_removeBlock`.
//!
//! IMPORTANT: Per Apple documentation, the Block passed to `imp_implementationWithBlock`
//! omits the `_cmd` selector argument: its signature is `^(self, args...)`.

const std = @import("std");
const raw = @import("../raw/root.zig");
const Object = @import("../runtime/object.zig").Object;
const Imp = @import("../runtime/imp.zig").Imp;

/// Owning handle for an Objective-C IMP created via `imp_implementationWithBlock`.
pub const OwnedImp = struct {
    raw_imp: ?Imp = null,

    const Self = @This();

    /// Borrow the underlying typed Imp handle.
    pub fn borrow(self: Self) Imp {
        return self.raw_imp orelse @panic("attempted to borrow deinitialized OwnedImp");
    }

    /// Retrieves the Objective-C Block associated with this IMP via `imp_getBlock`.
    pub fn block(self: Self) ?Object {
        if (self.raw_imp) |i| {
            if (raw.runtime.imp_getBlock(i.toRaw())) |blk| {
                return Object.fromRaw(blk);
            }
        }
        return null;
    }

    /// Releases the IMP and its associated Block copy via `imp_removeBlock`.
    pub fn deinit(self: *Self) void {
        if (self.raw_imp) |i| {
            _ = raw.runtime.imp_removeBlock(i.toRaw());
            self.raw_imp = null;
        }
    }
};

/// Bridges an Objective-C Block into an OwnedImp using `imp_implementationWithBlock`.
pub fn makeImp(block_handle: anytype) !OwnedImp {
    const raw_imp = raw.runtime.imp_implementationWithBlock(@ptrCast(block_handle.toRaw())) orelse
        return error.ImpCreationFailed;
    return OwnedImp{ .raw_imp = Imp.fromRaw(raw_imp) };
}

/// Helper function transforming an Objective-C method signature `fn (self, _cmd, args...) Ret`
/// into the corresponding Block signature `fn (self, args...) Ret` (omitting `_cmd`).
pub fn MethodBlock(comptime MethodFn: type) type {
    const info = @typeInfo(MethodFn).@"fn";
    if (info.params.len < 2) {
        @compileError("Method signature must have at least receiver and selector arguments");
    }
    const Ret = info.return_type orelse void;
    var new_params: [info.params.len - 1]type = undefined;
    new_params[0] = info.params[0].type.?; // Receiver
    for (info.params[2..], 1..) |p, i| {
        new_params[i] = p.type.?; // Explicit method arguments
    }
    return @Fn(&new_params, &@splat(.{}), Ret, .{});
}

test "MethodBlock signature transformation" {
    const Selector = @import("../runtime/selector.zig").Selector;
    const MethodSig = fn (Object, Selector, c_int, f64) c_int;
    const ExpectedBlockSig = fn (Object, c_int, f64) c_int;

    try std.testing.expectEqual(ExpectedBlockSig, MethodBlock(MethodSig));
}
