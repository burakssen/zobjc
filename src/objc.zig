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
pub const Imp = runtime.Imp;
pub const Iterator = runtime.Iterator;

// Descriptors
pub const MethodDescription = runtime.MethodDescription;
pub const PropertyAttribute = runtime.PropertyAttribute;
pub const ProtocolMethodOptions = runtime.ProtocolMethodOptions;
pub const ProtocolPropertyOptions = runtime.ProtocolPropertyOptions;

// Runtime lookup & manipulation functions
pub const getClass = runtime.getClass;
pub const lookupClass = runtime.lookupClass;
pub const requireClass = runtime.requireClass;
pub const getMetaClass = runtime.getMetaClass;
pub const getProtocol = runtime.getProtocol;
pub const allocateClassPair = runtime.allocateClassPair;
pub const registerClassPair = runtime.registerClassPair;
pub const disposeClassPair = runtime.disposeClassPair;
pub const classes = runtime.classes;
pub const protocols = runtime.protocols;
pub const sel = runtime.sel;

// Memory subsystem
pub const Retained = memory.Retained;
pub const Weak = memory.Weak;
pub const OwnedCString = memory.OwnedCString;
pub const OwnedRuntimeList = memory.OwnedRuntimeList;
pub const OwnedMethodDescriptions = memory.OwnedMethodDescriptions;
pub const OwnedPropertyAttributes = memory.OwnedPropertyAttributes;
pub const OwnedCStringList = memory.OwnedCStringList;
pub const AutoreleasePool = memory.AutoreleasePool;

// Messaging subsystem
pub const send = messaging.send;
pub const sendSuper = messaging.sendSuper;
pub const invoke = messaging.invoke;
pub const callImp = messaging.callImp;
pub const sendChecked = messaging.sendChecked;

// Block subsystem
pub const Block = block.Block;

// Encoding subsystem
pub const Encoding = encoding.Encoding;
pub const comptimeEncode = encoding.comptimeEncode;
pub const methodEncoding = encoding.methodEncoding;

/// Free memory allocated by the Objective-C runtime C allocator.
///
/// NOTE: In Phase 3, preferred usage is the owned wrappers:
/// `OwnedCString`, `OwnedRuntimeList(T)`, `OwnedMethodDescriptions`, etc.
pub inline fn free(ptr: anytype) void {
    const T = @TypeOf(ptr);
    if (@typeInfo(T) == .pointer and @typeInfo(T).pointer.size == .slice) {
        if (ptr.len > 0) {
            std.c.free(@ptrCast(@constCast(ptr.ptr)));
        }
    } else if (@typeInfo(T) == .optional) {
        if (ptr) |unwrapped| {
            free(unwrapped);
        }
    } else {
        std.c.free(@ptrCast(@constCast(ptr)));
    }
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
