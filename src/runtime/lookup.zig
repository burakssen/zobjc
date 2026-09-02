//! Global Objective-C class and protocol lookup functions.
//!
//! Provides type-safe lookups returning `Class` and `Protocol` handles.

const std = @import("std");
const raw = @import("../raw/root.zig");
const Class = @import("class.zig").Class;
const Protocol = @import("protocol.zig").Protocol;

/// Looks up a class by name, returning null if not found.
pub inline fn getClass(name: [:0]const u8) ?Class {
    return Class.fromRaw(raw.runtime.objc_getClass(name.ptr));
}

/// Looks up a class by name, returning null if not found.
/// Similar to getClass, but specifically intended for runtime lookups.
pub inline fn lookupClass(name: [:0]const u8) ?Class {
    return Class.fromRaw(raw.runtime.objc_lookUpClass(name.ptr));
}

/// Looks up a class by name, aborting the process if not found.
/// Corresponds to `objc_getRequiredClass`.
pub inline fn requireClass(name: [:0]const u8) Class {
    const raw_cls = raw.runtime.objc_getRequiredClass(name.ptr);
    return Class.fromRaw(raw_cls) orelse unreachable;
}

/// Looks up the metaclass for a class by name, returning null if not found.
pub inline fn getMetaClass(name: [:0]const u8) ?Class {
    return Class.fromRaw(raw.runtime.objc_getMetaClass(name.ptr));
}

/// Looks up a protocol by name, returning null if not found.
pub inline fn getProtocol(name: [:0]const u8) ?Protocol {
    return Protocol.fromRaw(raw.runtime.objc_getProtocol(name.ptr));
}

// --- Dynamic Class Pair Management ---

/// Allocates a new class and metaclass pair.
/// The class must be populated and registered with `registerClassPair` before use.
pub fn allocateClassPair(superclass: ?Class, name: [:0]const u8) ?Class {
    const raw_super = if (superclass) |s| s.ptr else null;
    return Class.fromRaw(raw.runtime.objc_allocateClassPair(raw_super, name.ptr, 0));
}

/// Registers a class pair allocated with `allocateClassPair`.
pub fn registerClassPair(cls: Class) void {
    raw.runtime.objc_registerClassPair(cls.ptr);
}

/// Disposes a class pair registered with `allocateClassPair`.
pub fn disposeClassPair(cls: Class) void {
    raw.runtime.objc_disposeClassPair(cls.ptr);
}
