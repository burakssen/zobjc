//! Modern Objective-C class enumeration (`objc_enumerateClasses`).
//!
//! Provides filtered runtime enumeration by image, name prefix, protocol conformance,
//! and superclass relationship with early stopping and runtime availability detection.

const std = @import("std");
const testing = std.testing;
const raw = @import("raw");
const Class = @import("class.zig").Class;
const Protocol = @import("protocol.zig").Protocol;

pub const EnumerateClassesFn = *const fn (
    image: ?*const anyopaque,
    namePrefix: ?[*:0]const u8,
    conformingTo: raw.Protocol,
    subclassing: raw.Class,
    block_handle: raw.id,
) callconv(.c) void;

// Darwin dlfcn.h: #define RTLD_DEFAULT ((void *) -2)
const RTLD_DEFAULT: ?*anyopaque = @ptrFromInt(@as(usize, @bitCast(@as(isize, -2))));

/// Dynamically resolves `objc_enumerateClasses` via dlsym if available on this platform.
pub fn getEnumerateClassesFn() ?EnumerateClassesFn {
    const sym = std.c.dlsym(RTLD_DEFAULT, "objc_enumerateClasses");
    if (sym) |s| return @ptrCast(@alignCast(s));
    return null;
}

/// Returns whether modern class enumeration (`objc_enumerateClasses`) is supported by the host OS.
pub inline fn hasClassEnumeration() bool {
    return getEnumerateClassesFn() != null;
}
