//! Target representation for Objective-C ABI classification.
//!
//! Encapsulates architecture, operating system, and ABI tag to enable
//! cross-target ABI classification at compile time without cross-compiling.

const std = @import("std");
const builtin = @import("builtin");

// Minimal target descriptor matching std.Target fields needed for ABI decisions.
pub const Target = struct {
    arch: std.Target.Cpu.Arch,
    os: std.Target.Os.Tag,
    abi: std.Target.Abi = .none,

    /// Native compilation target.
    pub fn native() Target {
        return .{
            .arch = builtin.target.cpu.arch,
            .os = builtin.target.os.tag,
            .abi = builtin.target.abi,
        };
    }

    /// Converts a standard library `std.Target` into an ABI `Target`.
    pub fn fromStdTarget(target: std.Target) Target {
        return .{
            .arch = target.cpu.arch,
            .os = target.os.tag,
            .abi = target.abi,
        };
    }

    /// Returns true if this target is a supported Apple Darwin Objective-C ABI target.
    pub fn isSupported(self: Target) bool {
        const is_darwin = switch (self.os) {
            .macos, .ios, .tvos, .watchos, .visionos => true,
            else => false,
        };
        if (!is_darwin) return false;

        return switch (self.arch) {
            .aarch64, .x86_64 => true,
            else => false,
        };
    }

    /// Asserts at compile time that the target is a supported Darwin Objective-C target.
    pub fn assertSupported(comptime self: Target) void {
        comptime {
            if (!self.isSupported()) {
                @compileError("Objective-C ABI classifier currently supports Darwin arm64 and x86_64.");
            }
        }
    }

    // Common Darwin test targets
    pub const macos_arm64: Target = .{ .arch = .aarch64, .os = .macos, .abi = .none };
    pub const macos_x86_64: Target = .{ .arch = .x86_64, .os = .macos, .abi = .none };
    pub const ios_arm64: Target = .{ .arch = .aarch64, .os = .ios, .abi = .none };
    pub const ios_sim_x86_64: Target = .{ .arch = .x86_64, .os = .ios, .abi = .none };
};

test "target: native target detection" {
    try std.testing.expect(Target.native().isSupported());
}

test "target: explicit Darwin targets are supported" {
    try std.testing.expect(Target.macos_arm64.isSupported());
    try std.testing.expect(Target.macos_x86_64.isSupported());
    try std.testing.expect(Target.ios_arm64.isSupported());
    try std.testing.expect(Target.ios_sim_x86_64.isSupported());
}

test "target: non-Darwin targets are rejected" {
    const linux_x86_64: Target = .{ .arch = .x86_64, .os = .linux, .abi = .gnu };
    try std.testing.expect(!linux_x86_64.isSupported());

    const windows_x86_64: Target = .{ .arch = .x86_64, .os = .windows, .abi = .msvc };
    try std.testing.expect(!windows_x86_64.isSupported());

    const darwin_riscv: Target = .{ .arch = .riscv64, .os = .macos, .abi = .none };
    try std.testing.expect(!darwin_riscv.isSupported());
}
