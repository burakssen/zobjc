//! Canonical public entry point for zobjc.
//!
//! Provides type-safe Zig bindings and runtime abstractions for Apple's Objective-C runtime.

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
pub const advanced = @import("advanced/root.zig");

// Low-level C bridge (preserved for backward compatibility)
pub const c = raw.c;

// Core runtime handles
pub const Object = runtime.Object;
pub const Class = runtime.Class;
pub const Selector = runtime.Selector;
pub const Sel = runtime.Sel; // Backward compatibility alias
pub const Method = runtime.Method;
pub const Ivar = runtime.Ivar;
pub const Property = runtime.Property;
pub const Protocol = runtime.Protocol;
pub const Imp = runtime.Imp;

// Descriptors
pub const MethodDescription = runtime.MethodDescription;
pub const PropertyAttribute = runtime.PropertyAttribute;
pub const ProtocolMethodOptions = runtime.ProtocolMethodOptions;
pub const ProtocolPropertyOptions = runtime.ProtocolPropertyOptions;

// Global runtime lookups
pub const getClass = runtime.getClass;
pub const lookupClass = runtime.lookupClass;
pub const requireClass = runtime.requireClass;
pub const getMetaClass = runtime.getMetaClass;
pub const getProtocol = runtime.getProtocol;
pub const requireProtocol = runtime.requireProtocol;
pub const allocateClassPair = runtime.allocateClassPair;
pub const registerClassPair = runtime.registerClassPair;
pub const disposeClassPair = runtime.disposeClassPair;
pub const classes = runtime.classes;
pub const protocols = runtime.protocols;
pub const sel = runtime.sel;

// Messaging engine
pub const send = messaging.send;
pub const sendSuper = messaging.sendSuper;
pub const invoke = messaging.invoke;
pub const callImp = messaging.callImp;

// Memory and ownership
pub const Retained = memory.Retained;
pub const Weak = memory.Weak;
pub const AutoreleasePool = memory.AutoreleasePool;

// Objective-C Blocks
pub const Block = block.Block;
pub const OwnedBlock = block.OwnedBlock;
pub const LegacyBlock = block.LegacyBlock; // Backward compatibility alias

// Type Encoding
pub const Encoding = encoding.Encoding;
pub const comptimeEncode = encoding.comptimeEncode;
pub const methodEncoding = encoding.methodEncoding;
pub const StorageType = encoding.StorageType;

// Dynamic class and protocol builders
pub const ClassBuilder = builder.ClassBuilder;
pub const ProtocolBuilder = builder.ProtocolBuilder;
pub const PropertyOptions = builder.PropertyOptions;

// Associated objects & Swizzling
pub const AssociationKey = runtime.AssociationKey;
pub const AssociationPolicy = runtime.AssociationPolicy;
pub const Swizzle = runtime.Swizzle;
pub const ScopedSwizzle = runtime.ScopedSwizzle;
pub const MethodReplacement = runtime.MethodReplacement;
pub const BlockMethodReplacement = runtime.BlockMethodReplacement;

/// Free memory allocated by the Objective-C runtime C allocator.
///
/// DEPRECATED: Non-owning handles should not manually invoke free().
/// Prefer RAII owned container wrappers (`cls.methods()`, `cls.properties()`,
/// `cls.ivars()`, `objc.runtime.classes()`, etc.) or call `objc.raw.runtime.free(ptr)`.
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
    _ = @import("advanced/root.zig");
    _ = @import("internal/root.zig");
}
