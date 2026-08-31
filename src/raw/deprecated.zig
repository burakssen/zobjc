//! Deprecated and obsolete Objective-C runtime declarations.
//!
//! These symbols are preserved for ABI completeness but are formally deprecated
//! or obsolete in modern Apple platforms.

const types = @import("types.zig");
const id = types.id;
const Class = types.Class;
const SEL = types.SEL;
const IMP = types.IMP;
const BOOL = types.BOOL;

/// Sets the superclass of a given class. (Deprecated by Apple: not recommended).
pub extern "c" fn class_setSuperclass(cls: Class, newSuper: Class) Class;

/// Obsolete ARC conversion helper.
pub extern "c" fn objc_retainedObject(obj: id) id;

/// Obsolete ARC conversion helper.
pub extern "c" fn objc_unretainedObject(obj: id) id;

/// Obsolete ARC conversion helper.
pub extern "c" fn objc_unretainedPointer(obj: id) ?*anyopaque;

/// Legacy method lookup.
pub extern "c" fn class_lookupMethod(cls: Class, sel: SEL) IMP;

/// Legacy responds-to-method check.
pub extern "c" fn class_respondsToMethod(cls: Class, sel: SEL) BOOL;

/// Legacy zone-based instance creation.
pub extern "c" fn class_createInstanceFromZone(cls: Class, extraBytes: usize, zone: ?*anyopaque) id;

/// Legacy zone-based object copy.
pub extern "c" fn object_copyFromZone(obj: id, size: usize, zone: ?*anyopaque) id;

/// Flushes the method cache for a class. Deprecated.
pub extern "c" fn _objc_flush_caches(cls: Class) void;
