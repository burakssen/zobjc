//! Canonical public entry point for zobjc.
//!
//! Provides type-safe Zig bindings and runtime abstractions for Apple's Objective-C runtime.

// Subsystem module boundaries
pub const raw = @import("raw");
pub const runtime = @import("runtime");
pub const messaging = @import("messaging");
pub const abi = @import("abi");
pub const encoding = @import("encoding");
pub const memory = @import("memory");
pub const block = @import("block");

// Core runtime handles
pub const Object = runtime.Object;
pub const Class = runtime.Class;
pub const Selector = runtime.Selector;
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
pub const sendChecked = messaging.sendChecked;
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

// Type Encoding
pub const Encoding = encoding.Encoding;
pub const comptimeEncode = encoding.comptimeEncode;
pub const methodEncoding = encoding.methodEncoding;
pub const StorageType = encoding.StorageType;

// Associated objects & Swizzling
pub const AssociationKey = runtime.AssociationKey;
pub const AssociationPolicy = runtime.AssociationPolicy;
pub const Swizzle = runtime.Swizzle;
pub const ScopedSwizzle = runtime.ScopedSwizzle;
pub const MethodReplacement = runtime.MethodReplacement;
pub const BlockMethodReplacement = block.BlockMethodReplacement;
pub const enumerateClasses = block.enumerateClasses;
pub const ClassEnumerationOptions = block.ClassEnumerationOptions;
pub const ImageFilter = block.ImageFilter;

test {
    @import("std").testing.refAllDecls(@This());
}

test "independent module compilation" {
    _ = @import("raw");
    _ = @import("abi");
    _ = @import("encoding");
    _ = @import("memory");
    _ = @import("messaging");
    _ = @import("runtime");
    _ = @import("block");
    _ = @import("internal");
}

test "raw can be accessed independently" {
    _ = raw;
    _ = raw.objc;
    _ = raw.runtime;
    _ = raw.message;
    _ = raw.blocks;
    _ = raw.compiler_runtime;
    _ = raw.availability;
}

test "abi can be accessed independently" {
    _ = abi;
}

test "encoding can be accessed independently" {
    _ = encoding;
}

test "memory can be accessed independently" {
    _ = memory;
}

test "messaging can be accessed independently" {
    _ = messaging;
}

test "runtime facade imports cleanly" {
    _ = runtime;
}

test "block can be accessed independently" {
    _ = block;
}
