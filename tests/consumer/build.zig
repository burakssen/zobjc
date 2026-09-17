const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zobjc_dep = b.dependency("zobjc", .{
        .target = target,
        .optimize = optimize,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("objc", zobjc_dep.module("objc"));

    const exe = b.addExecutable(.{
        .name = "consumer_app",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    const run_step = b.step("test-consumer", "Run consumer package test");
    run_step.dependOn(&run_cmd.step);
    b.default_step.dependOn(&run_cmd.step);
}
