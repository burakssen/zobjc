//! Central architecture dispatch for Objective-C return ABI classification.

const std = @import("std");
const Target = @import("target.zig").Target;
const convention = @import("convention.zig");
const ReturnConvention = convention.ReturnConvention;
const ReturnInfo = convention.ReturnInfo;
const ABIResult = convention.ABIResult;
const aarch64 = @import("aarch64.zig");
const x86_64 = @import("x86_64.zig");
const layout = @import("layout.zig");
const diagnostics = @import("diagnostics.zig");
const testing = std.testing;
const Object = @import("runtime").Object;
const Class = @import("runtime").Class;
const Selector = @import("runtime").Selector;
const raw = @import("raw");

// Pure compile-time architecture dispatch.

/// Returns the Objective-C runtime return convention for type `T` on `target`.
pub fn returnConventionFor(comptime target: Target, comptime T: type) ReturnConvention {
    diagnostics.assertValidTarget(target);
    diagnostics.assertValidReturn(T);

    return switch (target.arch) {
        .aarch64 => aarch64.returnConvention(target, T),
        .x86_64 => x86_64.returnConvention(target, T),
        else => @compileError("Objective-C ABI classifier currently supports Darwin arm64 and x86_64."),
    };
}

/// Returns the Objective-C runtime return convention for type `T` on the native host target.
pub fn returnConvention(comptime T: type) ReturnConvention {
    return returnConventionFor(Target.native(), T);
}

/// Returns the low-level ABI return mechanism (direct vs indirect vs x87) for type `T` on `target`.
pub fn classifyReturn(comptime target: Target, comptime T: type) ABIResult {
    diagnostics.assertValidTarget(target);
    diagnostics.assertValidReturn(T);

    return switch (target.arch) {
        .aarch64 => aarch64.classifyReturn(target, T),
        .x86_64 => x86_64.classifyReturn(target, T),
        else => @compileError("Objective-C ABI classifier currently supports Darwin arm64 and x86_64."),
    };
}

/// Returns rich return metadata describing size, alignment, indirectness, and runtime convention.
pub fn returnInfo(comptime target: Target, comptime T: type) ReturnInfo {
    const conv = returnConventionFor(target, T);
    const result = classifyReturn(target, T);

    return .{
        .convention = conv,
        .indirect = (result == .indirect),
        .size = layout.sizeOf(T),
        .alignment = layout.alignOf(T),
        .arch = target.arch,
    };
}

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
const LayoutIntInt = extern struct { a: u64, b: u64 };
const LayoutFloatFloat = extern struct { a: f64, b: f64 };
const LayoutFloatInt = extern struct { a: f64, b: u64 };
const LayoutFourFloats = extern struct { a: f32, b: f32, c: f32, d: f32 };

fn checkDifferential(comptime T: type, arm64_expected: ReturnConvention, x86_64_expected: ReturnConvention) !void {
    try testing.expectEqual(arm64_expected, returnConventionFor(Target.macos_arm64, T));
    try testing.expectEqual(x86_64_expected, returnConventionFor(Target.macos_x86_64, T));
}

test "differential: scalars match Apple Clang" {
    try checkDifferential(void, .normal, .normal);
    try checkDifferential(c_int, .normal, .normal);
    try checkDifferential(f32, .normal, .normal);
    try checkDifferential(f64, .normal, .normal);
    try checkDifferential(c_longdouble, .normal, .fpret);
}

test "regression: ordinary 2x-long-double struct is not COMPLEX_X87" {
    // ponytail: C `_Complex long double` alone selects fp2ret per SysV/Clang;
    // an ordinary struct of two long doubles is an aggregate (MEMORY/stret
    // when >16 bytes). Zig cannot spell `_Complex`, so never auto-select fp2ret.
    try testing.expect(returnConventionFor(Target.macos_arm64, ComplexLongDouble) != .fp2ret);
    try testing.expect(returnConventionFor(Target.macos_x86_64, ComplexLongDouble) != .fp2ret);
    try testing.expect(classifyReturn(Target.macos_x86_64, ComplexLongDouble) != .complex_x87);
}

test "differential: small structures (<= 16 bytes) match Apple Clang" {
    try checkDifferential(ABISize1, .normal, .normal);
    try checkDifferential(ABISize2, .normal, .normal);
    try checkDifferential(ABISize3, .normal, .normal);
    try checkDifferential(ABISize4, .normal, .normal);
    try checkDifferential(ABISize7, .normal, .normal);
    try checkDifferential(ABISize8, .normal, .normal);
    try checkDifferential(ABISize8Mixed, .normal, .normal);
    try checkDifferential(ABISize9, .normal, .normal);
    try checkDifferential(ABISize12, .normal, .normal);
    try checkDifferential(ABISize16Int, .normal, .normal);
    try checkDifferential(ABISize16Float, .normal, .normal);
    try checkDifferential(ABISize16Mixed, .normal, .normal);
    try checkDifferential(ABIStructLongDouble, .normal, .normal);
    try checkDifferential(ABIPoint, .normal, .normal);
    try checkDifferential(ABISize, .normal, .normal);
    try checkDifferential(ABIArrayInStruct, .normal, .normal);
    try checkDifferential(ABIUnion8, .normal, .normal);
}

test "differential: large structures (> 16 bytes) match Apple Clang" {
    try checkDifferential(ABISize17, .normal, .stret);
    try checkDifferential(ABISize24, .normal, .stret);
    try checkDifferential(ABISize32, .normal, .stret);
    try checkDifferential(ABIStructMixedLongDouble, .normal, .stret);
    try checkDifferential(ABIRect, .normal, .stret);
    try checkDifferential(ABINested, .normal, .stret);
}

test "differential: same-size different-layout 16-byte aggregates" {
    try testing.expectEqual(@sizeOf(LayoutIntInt), 16);
    try testing.expectEqual(@sizeOf(LayoutFloatFloat), 16);
    try testing.expectEqual(@sizeOf(LayoutFloatInt), 16);
    try testing.expectEqual(@sizeOf(LayoutFourFloats), 16);

    try checkDifferential(LayoutIntInt, .normal, .normal);
    try checkDifferential(LayoutFloatFloat, .normal, .normal);
    try checkDifferential(LayoutFloatInt, .normal, .normal);
    try checkDifferential(LayoutFourFloats, .normal, .normal);
}

test "differential: representative handle returns use normal" {
    try checkDifferential(Object, .normal, .normal);
    try checkDifferential(Class, .normal, .normal);
    try checkDifferential(Selector, .normal, .normal);
    try checkDifferential(raw.id, .normal, .normal);
}
