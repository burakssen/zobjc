//! Advanced, dangerous, and manual Objective-C runtime operations.
//!
//! Facilities in this module require manual memory management or global state
//! manipulation. They are separated from standard `objc.runtime` to highlight their
//! manual or destructive nature.

const std = @import("std");

pub const instance = @import("instance.zig");

pub const constructInstance = instance.constructInstance;
pub const destructInstance = instance.destructInstance;
pub const ConstructedInstance = instance.ConstructedInstance;
pub const copyObjectMemory = instance.copyObjectMemory;
pub const disposeObjectMemory = instance.disposeObjectMemory;
pub const removeAllAssociatedObjects = instance.removeAllAssociatedObjects;

test {
    std.testing.refAllDecls(@This());
}
