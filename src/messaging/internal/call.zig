//! Low-level invocation and pointer casting boundary for Objective-C messaging.
//!
//! Isolates unsafe `@ptrCast` and `@call` operations in a single module.

const std = @import("std");

// ponytail: Confine all untyped pointer casts to this single file.

/// Casts untyped runtime messenger `fn_ptr` to exact typed function pointer `*const Fn` and invokes it.
pub inline fn call(comptime Fn: type, fn_ptr: *const anyopaque, call_args: anytype) @typeInfo(Fn).@"fn".return_type.? {
    const typed_fn: *const Fn = @ptrCast(@alignCast(fn_ptr));
    return @call(.auto, typed_fn, call_args);
}
