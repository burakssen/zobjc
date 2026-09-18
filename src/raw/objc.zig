//! Fundamental Objective-C selector and object declarations.
//!
//! Corresponds to public declarations in <objc/objc.h>.

const types = @import("types.zig");
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime.zig");
const id = types.id;
const SEL = types.SEL;
const BOOL = types.BOOL;

/// Returns the name of the method specified by a given selector.
///
/// Mirrors `sel_getName` from <objc/objc.h>.
pub extern "c" fn sel_getName(
    sel: SEL,
) [*:0]const u8;

/// Registers a method name with the Objective-C runtime system.
///
/// Mirrors `sel_registerName` from <objc/objc.h>.
pub extern "c" fn sel_registerName(
    name: [*:0]const u8,
) SEL;

/// Registers a method name with the Objective-C runtime system (synonym for `sel_registerName`).
///
/// Mirrors `sel_getUid` from <objc/objc.h>.
pub extern "c" fn sel_getUid(
    name: [*:0]const u8,
) SEL;

/// Returns a boolean value indicating whether a selector is valid.
///
/// Mirrors `sel_isMapped` from <objc/objc.h>.
pub extern "c" fn sel_isMapped(
    sel: SEL,
) BOOL;

/// Returns the class name of a given object.
///
/// Mirrors `object_getClassName` from <objc/objc.h>.
pub extern "c" fn object_getClassName(
    obj: id,
) [*:0]const u8;

/// Returns a pointer to any extra bytes allocated with an instance.
///
/// Mirrors `object_getIndexedIvars` from <objc/objc.h>.
pub extern "c" fn object_getIndexedIvars(
    obj: id,
) ?*anyopaque;

test "raw.objc: sel_registerName and sel_getName round-trip" {
    const sel_desc = sel_registerName("description");
    try testing.expect(sel_desc != null);

    const name = sel_getName(sel_desc);
    try testing.expectEqualStrings("description", std.mem.span(name));
}

test "raw.objc: sel_getUid" {
    const sel1 = sel_registerName("init");
    const sel2 = sel_getUid("init");
    try testing.expectEqual(sel1, sel2);
}

test "raw.objc: sel_isMapped" {
    const sel_init = sel_registerName("init");
    try testing.expect(sel_isMapped(sel_init) == types.YES);
}

test "raw.objc: object_getClassName" {
    const cls = runtime.objc_getClass("NSObject");
    try testing.expect(cls != null);

    const name = object_getClassName(@ptrCast(cls));
    try testing.expectEqualStrings("NSObject", std.mem.span(name));
}
