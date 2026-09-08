//! Tests for target modeling and support validation.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");
const Target = objc.abi.Target;

test "target: native target detection" {
    const native = Target.native();
    try testing.expect(native.isSupported());
}

test "target: explicit Darwin targets are supported" {
    try testing.expect(Target.macos_arm64.isSupported());
    try testing.expect(Target.macos_x86_64.isSupported());
    try testing.expect(Target.ios_arm64.isSupported());
    try testing.expect(Target.ios_sim_x86_64.isSupported());
}

test "target: non-Darwin targets are rejected" {
    const linux_x86_64: Target = .{ .arch = .x86_64, .os = .linux, .abi = .gnu };
    try testing.expect(!linux_x86_64.isSupported());

    const windows_x86_64: Target = .{ .arch = .x86_64, .os = .windows, .abi = .msvc };
    try testing.expect(!windows_x86_64.isSupported());

    const darwin_riscv: Target = .{ .arch = .riscv64, .os = .macos, .abi = .none };
    try testing.expect(!darwin_riscv.isSupported());
}
