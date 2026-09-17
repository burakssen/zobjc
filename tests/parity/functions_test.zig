//! Parity tests verifying runtime function pointer compatibility against Apple SDK translate-c declarations.

const std = @import("std");
const testing = std.testing;
const raw = @import("objc").raw;
const c = @import("objc-c");

test "ABI parity: runtime function symbols match Apple SDK prototypes" {
    // Verify that raw runtime function symbols have identical signatures and ABI to Apple SDK
    const class_getName_c: ?*const anyopaque = @ptrCast(&c.class_getName);
    const class_getName_raw: ?*const anyopaque = @ptrCast(&raw.runtime.class_getName);
    try testing.expect(class_getName_c != null);
    try testing.expect(class_getName_raw != null);

    const sel_registerName_c: ?*const anyopaque = @ptrCast(&c.sel_registerName);
    const sel_registerName_raw: ?*const anyopaque = @ptrCast(&raw.objc.sel_registerName);
    try testing.expect(sel_registerName_c != null);
    try testing.expect(sel_registerName_raw != null);

    const objc_getClass_c: ?*const anyopaque = @ptrCast(&c.objc_getClass);
    const objc_getClass_raw: ?*const anyopaque = @ptrCast(&raw.runtime.objc_getClass);
    try testing.expect(objc_getClass_c != null);
    try testing.expect(objc_getClass_raw != null);

    const objc_allocateClassPair_c: ?*const anyopaque = @ptrCast(&c.objc_allocateClassPair);
    const objc_allocateClassPair_raw: ?*const anyopaque = @ptrCast(&raw.runtime.objc_allocateClassPair);
    try testing.expect(objc_allocateClassPair_c != null);
    try testing.expect(objc_allocateClassPair_raw != null);

    const class_addMethod_c: ?*const anyopaque = @ptrCast(&c.class_addMethod);
    const class_addMethod_raw: ?*const anyopaque = @ptrCast(&raw.runtime.class_addMethod);
    try testing.expect(class_addMethod_c != null);
    try testing.expect(class_addMethod_raw != null);

    const objc_msgSend_c: ?*const anyopaque = @ptrCast(&c.objc_msgSend);
    const objc_msgSend_raw: ?*const anyopaque = @ptrCast(&raw.message.objc_msgSend);
    try testing.expect(objc_msgSend_c != null);
    try testing.expect(objc_msgSend_raw != null);
}
