//! Differential tests verifying Darwin ABI classification against Clang codegen.
//!
//! Asserts return convention rules across target architectures (arm64, x86_64).

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");
const Target = objc.abi.Target;
const ReturnConvention = objc.abi.ReturnConvention;
const returnConventionFor = objc.abi.returnConventionFor;

const macos_arm64 = Target.macos_arm64;
const macos_x86_64 = Target.macos_x86_64;

// --- Fixture Mirror Types ---
const ABISize1 = extern struct { a: u8 };
const ABISize2 = extern struct { a: i16 };
const ABISize3 = extern struct { a: u8, b: i16 };
const ABISize4 = extern struct { a: i32 };
const ABISize7 = extern struct { a: i32, b: u8, c: u8, d: u8 };
const ABISize8 = extern struct { a: i64 };
const ABISize8Mixed = extern struct { a: i32, b: f32 };
const ABISize9 = extern struct { a: i64, b: u8 };
const ABISize12 = extern struct { a: i32, b: i32, c: i32 };
const ABISize16Int = extern struct { a: i64, b: i64 };
const ABISize16Float = extern struct { a: f64, b: f64 };
const ABISize16Mixed = extern struct { a: i32, b: f64 };
const ABISize17 = extern struct { a: i64, b: i64, c: u8 };
const ABISize24 = extern struct { a: f64, b: f64, c: f64 };
const ABISize32 = extern struct { a: f64, b: f64, c: f64, d: f64 };
const ABIStructLongDouble = extern struct { x: c_longdouble };
const ABIStructMixedLongDouble = extern struct { a: i32, b: c_longdouble };
const ABIPoint = extern struct { x: f64, y: f64 };
const ABISize = extern struct { width: f64, height: f64 };
const ABIRect = extern struct { origin: ABIPoint, size: ABISize };
const ABINested = extern struct { pt: ABIPoint, tag: i32 };
const ABIArrayInStruct = extern struct { vals: [2]f64 };
const ABIUnion8 = extern union { i: i64, d: f64 };
const ComplexLongDouble = extern struct { real: c_longdouble, imag: c_longdouble };

// Same-size / different-layout cases (all exactly 16 bytes)
const LayoutIntInt = extern struct { a: u64, b: u64 };
const LayoutFloatFloat = extern struct { a: f64, b: f64 };
const LayoutFloatInt = extern struct { a: f64, b: u64 };
const LayoutFourFloats = extern struct { a: f32, b: f32, c: f32, d: f32 };

fn check(comptime T: type, arm64_expected: ReturnConvention, x86_64_expected: ReturnConvention) !void {
    try testing.expectEqual(arm64_expected, returnConventionFor(macos_arm64, T));
    try testing.expectEqual(x86_64_expected, returnConventionFor(macos_x86_64, T));
}

test "differential: scalar return conventions match Clang codegen" {
    try check(void, .normal, .normal);
    try check(c_int, .normal, .normal);
    try check(f32, .normal, .normal);
    try check(f64, .normal, .normal);
    try check(c_longdouble, .normal, .fpret);
    try check(ComplexLongDouble, .normal, .fp2ret);
}

test "differential: small structures (<= 16 bytes) match Clang codegen" {
    try check(ABISize1, .normal, .normal);
    try check(ABISize2, .normal, .normal);
    try check(ABISize3, .normal, .normal);
    try check(ABISize4, .normal, .normal);
    try check(ABISize7, .normal, .normal);
    try check(ABISize8, .normal, .normal);
    try check(ABISize8Mixed, .normal, .normal);
    try check(ABISize9, .normal, .normal);
    try check(ABISize12, .normal, .normal);
    try check(ABISize16Int, .normal, .normal);
    try check(ABISize16Float, .normal, .normal);
    try check(ABISize16Mixed, .normal, .normal);
    try check(ABIPoint, .normal, .normal);
    try check(ABISize, .normal, .normal);
    try check(ABIArrayInStruct, .normal, .normal);
    try check(ABIUnion8, .normal, .normal);
}

test "differential: large structures (> 16 bytes) match Clang codegen" {
    // Permanent regression gate: arm64 NEVER selects stret for ordinary messaging
    // On x86_64, structures larger than 16 bytes always use stret
    try check(ABISize17, .normal, .stret);
    try check(ABISize24, .normal, .stret);
    try check(ABISize32, .normal, .stret);
    try check(ABIRect, .normal, .stret);
    try check(ABINested, .normal, .stret);
}

test "differential: same-size different-layout 16-byte aggregates" {
    try testing.expectEqual(@sizeOf(LayoutIntInt), 16);
    try testing.expectEqual(@sizeOf(LayoutFloatFloat), 16);
    try testing.expectEqual(@sizeOf(LayoutFloatInt), 16);
    try testing.expectEqual(@sizeOf(LayoutFourFloats), 16);

    try check(LayoutIntInt, .normal, .normal);
    try check(LayoutFloatFloat, .normal, .normal);
    try check(LayoutFloatInt, .normal, .normal);
    try check(LayoutFourFloats, .normal, .normal);
}
