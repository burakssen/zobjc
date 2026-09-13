//! Compile-time validation tests for Block signatures.

const std = @import("std");
const objc = @import("objc");
const testing = std.testing;

test "validation: valid signatures" {
    objc.block.validation.validateBlockSignature(fn () void);
    objc.block.validation.validateBlockSignature(fn (c_int) void);
    objc.block.validation.validateBlockSignature(fn (c_int, f64) c_int);
    objc.block.validation.validateBlockSignature(fn (objc.Object) ?objc.Object);
}

test "validation: ptrauth detection" {
    // Non-aarch64 target is not ptrauth
    const x86_target: std.Target = .{
        .cpu = .{
            .arch = .x86_64,
            .model = &std.Target.x86.cpu.generic,
            .features = std.Target.x86.featureSet(&.{}),
        },
        .os = .{ .tag = .macos, .version_range = .{ .semver = .{ .min = .{ .major = 14, .minor = 0, .patch = 0 }, .max = .{ .major = 14, .minor = 0, .patch = 0 } } } },
        .abi = .none,
        .ofmt = .macho,
    };
    try testing.expect(!objc.block.validation.isPtrauthTarget(x86_target));
}
