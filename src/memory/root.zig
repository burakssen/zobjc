//! Memory management, ownership, and runtime-allocated buffer facade.
//!
//! Exposes explicit ownership smart pointers and caller-freed container abstractions:
//! - `Retained(T)`: Strong ownership smart pointer (+1 reference).
//! - `Weak(T)`: Zeroing weak reference slot.
//! - `AutoreleasePool`: Scoped autorelease pool token manager.
//! - `OwnedCString`: Caller-freed C string from runtime copies.
//! - `OwnedRuntimeList(T)`: Caller-freed typed handle array from runtime copies.
//! - `OwnedMethodDescriptions`: Caller-freed method description array.
//! - `OwnedPropertyAttributes`: Caller-freed property attribute array.
//! - `OwnedCStringList`: Caller-freed array of C strings (image names, etc.).

pub const Retained = @import("retained.zig").Retained;
pub const Weak = @import("weak.zig").Weak;
pub const AutoreleasePool = @import("autorelease_pool.zig").AutoreleasePool;
pub const OwnedCString = @import("owned_c_string.zig").OwnedCString;
pub const OwnedRuntimeList = @import("owned_runtime_list.zig").OwnedRuntimeList;
pub const OwnedMethodDescriptions = @import("owned_method_descriptions.zig").OwnedMethodDescriptions;
pub const OwnedPropertyAttributes = @import("owned_property_attributes.zig").OwnedPropertyAttributes;
pub const OwnedCStringList = @import("owned_c_string_list.zig").OwnedCStringList;

pub const traits = @import("traits.zig");
pub const c_free = @import("c_free.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
