//! Example demonstrating Darwin Objective-C ABI classification and call conventions.
//!
//! Shows how zobjc decides the correct messenger (objc_msgSend vs stret vs fpret vs fp2ret)
//! at compile time across macOS arm64 and x86_64 targets.

const std = @import("std");
const objc = @import("zobjc");

const Target = objc.abi.Target;
const ReturnConvention = objc.abi.ReturnConvention;

const Point = extern struct {
    x: f64,
    y: f64,
};

const Size = extern struct {
    width: f64,
    height: f64,
};

const CGRect = extern struct {
    origin: Point,
    size: Size,
};

const ComplexLongDouble = extern struct {
    real: c_longdouble,
    imag: c_longdouble,
};

fn printConvention(comptime name: []const u8, comptime T: type) void {
    const arm64_conv = objc.abi.returnConventionFor(Target.macos_arm64, T);
    const x86_conv = objc.abi.returnConventionFor(Target.macos_x86_64, T);
    const arm64_abi = objc.abi.classifyReturn(Target.macos_arm64, T);
    const x86_abi = objc.abi.classifyReturn(Target.macos_x86_64, T);

    std.debug.print("  {s:<22} | {s:<14} ({s:<8}) | {s:<18} ({s:<11})\n", .{
        name,
        @tagName(arm64_conv),
        @tagName(arm64_abi),
        @tagName(x86_conv),
        @tagName(x86_abi),
    });
}

pub fn main() !void {
    std.debug.print("=== Objective-C ABI Return Convention Engine ===\n\n", .{});

    const native_target = Target.native();
    std.debug.print("Host Target: {s}-{s}\n\n", .{
        @tagName(native_target.arch),
        @tagName(native_target.os),
    });

    std.debug.print("Cross-Target Comparison (arm64 vs x86_64):\n", .{});
    std.debug.print("  {s:<22} | {s:<25} | {s:<32}\n", .{
        "Return Type",
        "macOS arm64",
        "macOS x86_64",
    });
    std.debug.print("  {s:-<22}-+-{s:-<25}-+-{s:-<32}\n", .{ "", "", "" });

    // Scalars
    printConvention("void", void);
    printConvention("i32", i32);
    printConvention("f64 (double)", f64);
    printConvention("objc.Object", objc.Object);
    printConvention("?objc.Object", ?objc.Object);

    // Floating-point edge cases
    printConvention("c_longdouble", c_longdouble);
    printConvention("ComplexLongDouble", ComplexLongDouble);

    // Aggregates
    printConvention("Point (16B)", Point);
    printConvention("CGRect (32B)", CGRect);

    std.debug.print("\nKey Darwin ABI Invariants:\n", .{});
    std.debug.print("  1. ARM64 never uses stret or fpret (messengers do not exist in ARM64 libobjc).\n", .{});
    std.debug.print("  2. x86_64 f32 and f64 use normal objc_msgSend, NOT fpret.\n", .{});
    std.debug.print("  3. x86_64 long double uses objc_msgSend_fpret (returns in ST0).\n", .{});
    // ponytail: Zig cannot spell C `_Complex long double`, so fp2ret is never
    // auto-selected; an ordinary 2x-long-double struct uses the aggregate path.
    std.debug.print("  4. _Complex long double unsupported: 2x-long-double structs use stret/normal, never fp2ret.\n", .{});
    std.debug.print("  5. x86_64 CGRect (>16B) uses objc_msgSend_stret; ARM64 uses objc_msgSend.\n", .{});
}
