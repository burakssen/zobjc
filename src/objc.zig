//! Canonical public entry point for zobjc.
//!
//! Provides Zig bindings and architectural abstractions for the Apple Objective-C runtime.

const std = @import("std");

// Subsystem module boundaries
pub const raw = @import("raw/root.zig");
pub const runtime = @import("runtime/root.zig");
pub const messaging = @import("messaging/root.zig");
pub const abi = @import("abi/root.zig");
pub const encoding = @import("encoding/root.zig");
pub const memory = @import("memory/root.zig");
pub const block = @import("block/root.zig");
pub const builder = @import("builder/root.zig");

// Low-level C bridge (preserved for backward compatibility)
pub const c = raw.c;

// Runtime handles
pub const Object = runtime.Object;
pub const Class = runtime.Class;
pub const Selector = runtime.Selector;
pub const Sel = runtime.Sel;
pub const Property = runtime.Property;
pub const Protocol = runtime.Protocol;
pub const Method = runtime.Method;
pub const Ivar = runtime.Ivar;
pub const Iterator = runtime.Iterator;

// Runtime lookup & manipulation functions
pub const getClass = runtime.getClass;
pub const getMetaClass = runtime.getMetaClass;
pub const allocateClassPair = runtime.allocateClassPair;
pub const registerClassPair = runtime.registerClassPair;
pub const disposeClassPair = runtime.disposeClassPair;
pub const getProtocol = runtime.getProtocol;
pub const sel = runtime.sel;

// Block & Memory subsystems
pub const Block = block.Block;
pub const AutoreleasePool = memory.AutoreleasePool;

// Encoding subsystem
pub const Encoding = encoding.Encoding;
pub const comptimeEncode = encoding.comptimeEncode;

/// Free memory allocated by the Objective-C runtime C allocator.
// TODO(phase-3): Deprecate manual free in favor of owned wrappers.
pub inline fn free(ptr: anytype) void {
    std.heap.c_allocator.free(ptr);
}

test {
    std.testing.refAllDecls(@This());
}

test "independent module compilation" {
    _ = @import("raw/root.zig");
    _ = @import("abi/root.zig");
    _ = @import("encoding/root.zig");
    _ = @import("memory/root.zig");
    _ = @import("messaging/root.zig");
    _ = @import("runtime/root.zig");
    _ = @import("block/root.zig");
    _ = @import("builder/root.zig");
    _ = @import("internal/root.zig");
}
