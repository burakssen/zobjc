//! Tests for <objc/objc.h> functions exposed through raw.objc.

const std = @import("std");
const testing = std.testing;
const raw = @import("objc").raw;

test "raw.objc: sel_registerName and sel_getName round-trip" {
    const sel_desc = raw.objc.sel_registerName("description");
    try testing.expect(sel_desc != null);

    const name = raw.objc.sel_getName(sel_desc);
    try testing.expectEqualStrings("description", std.mem.span(name));
}

test "raw.objc: sel_getUid" {
    const sel1 = raw.objc.sel_registerName("init");
    const sel2 = raw.objc.sel_getUid("init");
    try testing.expectEqual(sel1, sel2);
}

test "raw.objc: sel_isMapped" {
    const sel_init = raw.objc.sel_registerName("init");
    try testing.expect(raw.boolResult(raw.objc.sel_isMapped(sel_init)));
}

test "raw.objc: object_getClassName" {
    const cls = raw.runtime.objc_getClass("NSObject");
    try testing.expect(cls != null);

    const name = raw.objc.object_getClassName(@ptrCast(cls));
    try testing.expectEqualStrings("NSObject", std.mem.span(name));
}
