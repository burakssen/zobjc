//! Tests for x86_64 scalar return convention classification.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");
const Target = objc.abi.Target;
const returnConventionFor = objc.abi.returnConventionFor;
const classifyReturn = objc.abi.classifyReturn;

const macos_x86_64 = Target.macos_x86_64;

test "x86_64 scalar: void and integers use normal" {
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, void));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, bool));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, i8));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, u8));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, i16));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, u16));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, i32));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, u32));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, i64));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, u64));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, isize));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, usize));
}

test "x86_64 scalar: pointers and Objective-C handles use normal" {
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, *anyopaque));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, ?*anyopaque));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, [*:0]const u8));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, objc.Object));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, ?objc.Object));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, objc.Class));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, objc.Selector));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, objc.raw.id));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, objc.raw.Class));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, objc.raw.SEL));
}

test "x86_64 scalar: f32 and f64 do NOT use fpret (permanent regression guard)" {
    // Both f32 and f64 are returned in XMM0 (SSE) and use normal objc_msgSend.
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, f32));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, f64));
    try testing.expectEqual(.direct, classifyReturn(macos_x86_64, f32));
    try testing.expectEqual(.direct, classifyReturn(macos_x86_64, f64));
}

test "x86_64 scalar: long double uses fpret" {
    // Apple runtime declares objc_msgSend_fpret returning long double on x86_64.
    try testing.expectEqual(.fpret, returnConventionFor(macos_x86_64, c_longdouble));
    try testing.expectEqual(.x87, classifyReturn(macos_x86_64, c_longdouble));
}

test "x86_64 scalar: complex long double uses fp2ret" {
    const ComplexLongDouble = extern struct {
        real: c_longdouble,
        imag: c_longdouble,
    };
    try testing.expectEqual(.fp2ret, returnConventionFor(macos_x86_64, ComplexLongDouble));
    try testing.expectEqual(.complex_x87, classifyReturn(macos_x86_64, ComplexLongDouble));
}
