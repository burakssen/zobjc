//! x86_64 Darwin Objective-C ABI return classification.
//!
//! Handles System V AMD64 ABI classification for Darwin x86_64, selecting between:
//! - objc_msgSend (.normal): integers, pointers, objects, floats (f32, f64), and register aggregates (<= 16 bytes)
//! - objc_msgSend_stret (.stret): memory-returned aggregates (> 16 bytes or unaligned)
//! - objc_msgSend_fpret (.fpret): long double (x87 80-bit float)
//! - objc_msgSend_fp2ret (.fp2ret): complex long double

const std = @import("std");
const Target = @import("target.zig").Target;
const convention = @import("convention.zig");
const ReturnConvention = convention.ReturnConvention;
const ABIResult = convention.ABIResult;
const type_mod = @import("type.zig");
pub const class = @import("x86_64/class.zig");
pub const eightbyte = @import("x86_64/eightbyte.zig");
pub const merge = @import("x86_64/merge.zig");
pub const aggregate = @import("x86_64/aggregate.zig");

// ponytail: Clear separation between scalar rules and structural aggregate classification.
pub fn returnConvention(comptime target: Target, comptime T: type) ReturnConvention {
    _ = target;
    const cat = type_mod.categorize(T);

    return switch (cat) {
        .void,
        .integer,
        .pointer,
        .objc_object,
        => .normal,

        // f32 and f64 are returned in XMM0 (SSE), so they use normal objc_msgSend!
        .floating => .normal,

        // x86_64 Darwin objc_msgSend_fpret specifically returns long double (x87).
        .long_double => .fpret,

        // x86_64 Darwin objc_msgSend_fp2ret returns complex long double (two x87 values).
        .complex_long_double => .fp2ret,

        .vector => .normal,

        .aggregate => {
            const eightbytes = aggregate.classifyAggregate(T);
            if (eightbytes.isMemory()) {
                return .stret;
            }
            return .normal;
        },
    };
}

/// Low-level x86_64 ABI return classification (direct, indirect, x87, complex_x87).
pub fn classifyReturn(comptime target: Target, comptime T: type) ABIResult {
    _ = target;
    const cat = type_mod.categorize(T);

    return switch (cat) {
        .void,
        .integer,
        .pointer,
        .objc_object,
        .floating,
        .vector,
        => .direct,

        .long_double => .x87,
        .complex_long_double => .complex_x87,

        .aggregate => {
            const eightbytes = aggregate.classifyAggregate(T);
            if (eightbytes.isMemory()) {
                return .indirect;
            }
            return .direct;
        },
    };
}
