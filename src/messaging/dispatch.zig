//! Central runtime messenger entry point selection.
//!
//! Maps Phase 5 ABI classification decisions to the exact libobjc dispatch entry point:
//! - objc_msgSend
//! - objc_msgSend_stret
//! - objc_msgSend_fpret
//! - objc_msgSend_fp2ret
//! - objc_msgSendSuper2
//! - objc_msgSendSuper2_stret
//! - method_invoke
//! - method_invoke_stret

const std = @import("std");
const raw = @import("../raw/root.zig");
const abi = @import("../abi/root.zig");

// ponytail: Pure routing based strictly on Phase 5 ABI ReturnConvention.

/// Returns the untyped function pointer for an ordinary instance/class message send.
pub inline fn messagePointer(comptime AbiReturn: type) *const anyopaque {
    return comptime blk: {
        const conv = abi.returnConvention(AbiReturn);
        switch (conv) {
            .normal => break :blk &raw.message.objc_msgSend,
            .stret => {
                if (raw.availability.has_msgSendStret) {
                    break :blk &raw.message.objc_msgSend_stret;
                } else {
                    @compileError("stret is unavailable on this architecture");
                }
            },
            .fpret => {
                if (raw.availability.has_msgSendFpret) {
                    break :blk &raw.message.objc_msgSend_fpret;
                } else {
                    @compileError("fpret is unavailable on this architecture");
                }
            },
            .fp2ret => {
                if (raw.availability.has_msgSendFp2ret) {
                    break :blk &raw.message.objc_msgSend_fp2ret;
                } else {
                    @compileError("fp2ret is unavailable on this architecture");
                }
            },
        }
    };
}

/// Returns the untyped function pointer for a superclass message send (Super2 semantics).
pub inline fn superPointer(comptime AbiReturn: type) *const anyopaque {
    return comptime blk: {
        const conv = abi.returnConvention(AbiReturn);
        switch (conv) {
            .normal, .fpret, .fp2ret => break :blk &raw.message.objc_msgSendSuper2,
            .stret => {
                if (raw.availability.has_msgSendStret) {
                    break :blk &raw.message.objc_msgSendSuper2_stret;
                } else {
                    @compileError("stret is unavailable on this architecture");
                }
            },
        }
    };
}

/// Returns the untyped function pointer for a legacy superclass message send (objc_msgSendSuper v1).
pub inline fn superV1Pointer(comptime AbiReturn: type) *const anyopaque {
    return comptime blk: {
        const conv = abi.returnConvention(AbiReturn);
        switch (conv) {
            .normal, .fpret, .fp2ret => break :blk &raw.message.objc_msgSendSuper,
            .stret => {
                if (raw.availability.has_msgSendStret) {
                    break :blk &raw.message.objc_msgSendSuper_stret;
                } else {
                    @compileError("stret is unavailable on this architecture");
                }
            },
        }
    };
}

/// Returns the untyped function pointer for direct method invocation (`method_invoke`).
pub inline fn methodInvokePointer(comptime AbiReturn: type) *const anyopaque {
    return comptime blk: {
        const conv = abi.returnConvention(AbiReturn);
        switch (conv) {
            .normal, .fpret, .fp2ret => break :blk &raw.message.method_invoke,
            .stret => {
                if (raw.availability.has_msgSendStret) {
                    break :blk &raw.message.method_invoke_stret;
                } else {
                    @compileError("stret is unavailable on this architecture");
                }
            },
        }
    };
}
