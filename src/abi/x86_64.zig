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
const testing = std.testing;

// Clear separation between scalar rules and structural aggregate classification.
pub fn returnConvention(comptime target: Target, comptime T: type) ReturnConvention {
    _ = target;
    const cat = type_mod.categorize(T);

    return switch (cat) {
        .void,
        .integer,
        .pointer,
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

test "x86_64 scalar: void and integers use normal" {
    const target = Target.macos_x86_64;
    try testing.expectEqual(.normal, returnConvention(target, void));
    try testing.expectEqual(.normal, returnConvention(target, bool));
    try testing.expectEqual(.normal, returnConvention(target, i8));
    try testing.expectEqual(.normal, returnConvention(target, u8));
    try testing.expectEqual(.normal, returnConvention(target, i16));
    try testing.expectEqual(.normal, returnConvention(target, u16));
    try testing.expectEqual(.normal, returnConvention(target, i32));
    try testing.expectEqual(.normal, returnConvention(target, u32));
    try testing.expectEqual(.normal, returnConvention(target, i64));
    try testing.expectEqual(.normal, returnConvention(target, u64));
    try testing.expectEqual(.normal, returnConvention(target, isize));
    try testing.expectEqual(.normal, returnConvention(target, usize));
}

test "x86_64 scalar: pointers and pointer-like wrappers use normal" {
    const target = Target.macos_x86_64;
    try testing.expectEqual(.normal, returnConvention(target, *anyopaque));
    try testing.expectEqual(.normal, returnConvention(target, ?*anyopaque));
    try testing.expectEqual(.normal, returnConvention(target, [*:0]const u8));
    const PtrWrapper = struct { ptr: *anyopaque };
    try testing.expectEqual(.normal, returnConvention(target, PtrWrapper));
    try testing.expectEqual(.normal, returnConvention(target, ?PtrWrapper));
}

test "x86_64 scalar: f32 and f64 do NOT use fpret" {
    const target = Target.macos_x86_64;
    try testing.expectEqual(.normal, returnConvention(target, f32));
    try testing.expectEqual(.normal, returnConvention(target, f64));
    try testing.expectEqual(.direct, classifyReturn(target, f32));
    try testing.expectEqual(.direct, classifyReturn(target, f64));
}

test "x86_64 scalar: long double uses fpret" {
    const target = Target.macos_x86_64;
    try testing.expectEqual(.fpret, returnConvention(target, c_longdouble));
    try testing.expectEqual(.x87, classifyReturn(target, c_longdouble));
}

test "x86_64: ordinary 2x-long-double struct never uses fp2ret" {
    // ponytail: no ObjC fixture needed — the classifier is pure comptime, and
    // host @sizeOf(c_longdouble) differs per arch (8 on arm64, 16 on x86_64),
    // so assert the host-independent invariant: never fp2ret/complex_x87.
    // A true C `_Complex long double` has no Zig spelling; ordinary aggregates
    // go through the aggregate path (stret natively on x86_64 where size is 32).
    const Pair = extern struct { first: c_longdouble, second: c_longdouble };
    const target = Target.macos_x86_64;
    try testing.expect(returnConvention(target, Pair) != .fp2ret);
    try testing.expect(classifyReturn(target, Pair) != .complex_x87);
}
