//! Optional runtime method signature validation and debug checked messaging.

const std = @import("std");
const raw = @import("../raw/root.zig");
const runtime = @import("../runtime/root.zig");
const receiver_mod = @import("receiver.zig");
const selector_mod = @import("selector.zig");
const send_mod = @import("send.zig");

// ponytail: Optional diagnostic layer that compiles away in fast release modes.

/// Checks whether `receiver` has an implementation for `selector`.
pub fn respondsToSelector(receiver: anytype, selector: anytype) bool {
    const raw_rec = receiver_mod.toRaw(receiver) orelse return false;
    const raw_sel = selector_mod.toRaw(selector);

    const cls = raw.runtime.object_getClass(raw_rec) orelse return false;
    return raw.runtime.class_respondsToSelector(cls, raw_sel) == raw.YES;
}

/// Dispatches an Objective-C message after validating that `receiver` responds to `selector`.
///
/// Panics in Debug/ReleaseSafe if `receiver` is non-nil and does not respond to `selector`.
pub inline fn sendChecked(
    comptime Return: type,
    receiver: anytype,
    selector: anytype,
    args: anytype,
) Return {
    if (std.debug.runtime_safety) {
        const raw_rec = receiver_mod.toRaw(receiver);
        if (raw_rec != null and !respondsToSelector(receiver, selector)) {
            @panic("Objective-C message target does not respond to selector");
        }
    }
    return send_mod.send(Return, receiver, selector, args);
}
