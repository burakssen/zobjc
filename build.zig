const std = @import("std");

const ModuleSet = struct {
    zobjc: *std.Build.Module,
    abi: *std.Build.Module,
    block: *std.Build.Module,
    encoding: *std.Build.Module,
    internal: *std.Build.Module,
    memory: *std.Build.Module,
    messaging: *std.Build.Module,
    raw: *std.Build.Module,
    runtime: *std.Build.Module,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zobjc = b.addModule("zobjc", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const abi = b.addModule("abi", .{
        .root_source_file = b.path("src/abi/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const block = b.addModule("block", .{
        .root_source_file = b.path("src/block/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const encoding = b.addModule("encoding", .{
        .root_source_file = b.path("src/encoding/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const internal = b.addModule("internal", .{
        .root_source_file = b.path("src/internal/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const memory = b.addModule("memory", .{
        .root_source_file = b.path("src/memory/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const messaging = b.addModule("messaging", .{
        .root_source_file = b.path("src/messaging/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const raw = b.addModule("raw", .{
        .root_source_file = b.path("src/raw/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const runtime = b.addModule("runtime", .{
        .root_source_file = b.path("src/runtime/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const modules = ModuleSet{
        .zobjc = zobjc,
        .abi = abi,
        .block = block,
        .encoding = encoding,
        .internal = internal,
        .memory = memory,
        .messaging = messaging,
        .raw = raw,
        .runtime = runtime,
    };
    wireModules(modules);

    zobjc.linkSystemLibrary("objc", .{});

    const lib = b.addLibrary(.{
        .name = "zobjc",
        .linkage = .static,
        .root_module = modules.zobjc,
    });
    b.installArtifact(lib);

    const test_modules = createTestModules(b, target, optimize);

    const integration_tests = b.createModule(.{
        .root_source_file = b.path("tests/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    integration_tests.addImport("zobjc", zobjc);
    addIntegrationFixtures(integration_tests, b);
    // raw tests call libobjc directly; link it explicitly now that raw no
    // longer imports the facade (which previously provided it transitively).
    test_modules.raw.linkSystemLibrary("objc", .{});
    // Standalone messaging tests exercise raw runtime helpers directly now
    // that the facade edge is gone (same treatment as raw above).
    test_modules.messaging.linkSystemLibrary("objc", .{});
    // Same for runtime/memory: their remaining unit tests call libobjc
    // directly (conversion/layout/size checks stay in-module).
    test_modules.runtime.linkSystemLibrary("objc", .{});
    test_modules.memory.linkSystemLibrary("objc", .{});
    addBlockTestFixture(test_modules.block, b);
    const test_targets = [_]struct {
        name: []const u8,
        module: *std.Build.Module,
    }{
        .{ .name = "zobjc", .module = test_modules.zobjc },
        .{ .name = "abi", .module = test_modules.abi },
        .{ .name = "block", .module = test_modules.block },
        .{ .name = "encoding", .module = test_modules.encoding },
        .{ .name = "memory", .module = test_modules.memory },
        .{ .name = "messaging", .module = test_modules.messaging },
        .{ .name = "raw", .module = test_modules.raw },
        .{ .name = "runtime", .module = test_modules.runtime },
    };
    const test_step = b.step("test", "Run all zobjc tests");
    // NOTE: test-zobjc covers facade smoke tests only (no fixtures); the
    // integration target below owns encoding.m/abi.m/common.m explicitly.
    const integration_test_artifact = b.addTest(.{
        .name = "test-integration",
        .root_module = integration_tests,
    });
    test_step.dependOn(&b.addRunArtifact(integration_test_artifact).step);
    for (test_targets) |test_target| {
        const tests = b.addTest(.{
            .name = b.fmt("test-{s}", .{test_target.name}),
            .root_module = test_target.module,
        });
        const run_tests = b.addRunArtifact(tests);
        test_step.dependOn(&run_tests.step);
    }
    const raw_internal_module = b.createModule(.{
        .root_source_file = b.path("src/raw/internal.zig"),
        .target = target,
        .optimize = optimize,
    });
    const raw_internal_tests = b.addTest(.{
        .name = "test-raw-internal",
        .root_module = raw_internal_module,
    });
    test_step.dependOn(&b.addRunArtifact(raw_internal_tests).step);

    const example_names = [_][]const u8{
        "basic_object",
        "subclass",
        "block",
        "autorelease_pool",
        "runtime_introspection",
        "ownership_and_memory",
        "type_encodings",
        "abi_classification",
        "messaging",
    };
    for (example_names) |name| {
        const example_module = b.createModule(.{
            .root_source_file = b.path(b.fmt("examples/{s}.zig", .{name})),
            .target = target,
            .optimize = optimize,
        });
        example_module.addImport("zobjc", zobjc);
        example_module.linkSystemLibrary("objc", .{});

        const executable = b.addExecutable(.{
            .name = name,
            .root_module = example_module,
        });
        const run = b.addRunArtifact(executable);
        b.step(b.fmt("run-{s}", .{name}), b.fmt("Run {s} example", .{name})).dependOn(&run.step);
    }
}

fn createTestModules(b: *std.Build, target: anytype, optimize: anytype) ModuleSet {
    const modules = ModuleSet{
        .zobjc = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .abi = b.createModule(.{
            .root_source_file = b.path("src/abi/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .block = b.createModule(.{
            .root_source_file = b.path("src/block/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .encoding = b.createModule(.{
            .root_source_file = b.path("src/encoding/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .internal = b.createModule(.{
            .root_source_file = b.path("src/internal/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .memory = b.createModule(.{
            .root_source_file = b.path("src/memory/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .messaging = b.createModule(.{
            .root_source_file = b.path("src/messaging/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .raw = b.createModule(.{
            .root_source_file = b.path("src/raw/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .runtime = b.createModule(.{
            .root_source_file = b.path("src/runtime/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    };
    wireModules(modules);
    return modules;
}

fn wireModules(modules: ModuleSet) void {
    const subsystems = [_]struct {
        name: []const u8,
        module: *std.Build.Module,
    }{
        .{ .name = "abi", .module = modules.abi },
        .{ .name = "block", .module = modules.block },
        .{ .name = "encoding", .module = modules.encoding },
        .{ .name = "internal", .module = modules.internal },
        .{ .name = "memory", .module = modules.memory },
        .{ .name = "messaging", .module = modules.messaging },
        .{ .name = "raw", .module = modules.raw },
        .{ .name = "runtime", .module = modules.runtime },
    };
    for (subsystems) |subsystem| {
        modules.zobjc.addImport(subsystem.name, subsystem.module);
    }
    // Subsystems must never import the zobjc facade.
    // All edges below point strictly downward.


    modules.internal.addImport("raw", modules.raw);

    modules.block.addImport("abi", modules.abi);
    modules.block.addImport("encoding", modules.encoding);
    modules.block.addImport("memory", modules.memory);
    modules.block.addImport("messaging", modules.messaging);
    modules.block.addImport("raw", modules.raw);
    modules.block.addImport("runtime", modules.runtime);

    modules.encoding.addImport("raw", modules.raw);
    modules.encoding.addImport("internal", modules.internal);

    modules.memory.addImport("raw", modules.raw);
    modules.memory.addImport("internal", modules.internal);

    modules.messaging.addImport("abi", modules.abi);
    modules.messaging.addImport("encoding", modules.encoding);
    modules.messaging.addImport("raw", modules.raw);
    modules.messaging.addImport("internal", modules.internal);

    modules.runtime.addImport("encoding", modules.encoding);
    modules.runtime.addImport("memory", modules.memory);
    modules.runtime.addImport("messaging", modules.messaging);
    modules.runtime.addImport("raw", modules.raw);
    modules.runtime.addImport("internal", modules.internal);
}

fn addBlockTestFixture(module: *std.Build.Module, b: *std.Build) void {
    module.linkSystemLibrary("objc", .{});
    module.addCSourceFile(.{
        .file = b.path("fixtures/common.m"),
        .flags = &.{},
    });
    module.addCSourceFile(.{
        .file = b.path("fixtures/block.m"),
        .flags = &.{"-fblocks"},
    });
}

fn addIntegrationFixtures(module: *std.Build.Module, b: *std.Build) void {
    module.linkSystemLibrary("objc", .{});
    module.addCSourceFile(.{
        .file = b.path("fixtures/encoding.m"),
        .flags = &.{},
    });
    module.addCSourceFile(.{
        .file = b.path("fixtures/abi.m"),
        .flags = &.{},
    });
    module.addCSourceFile(.{
        .file = b.path("fixtures/common.m"),
        .flags = &.{},
    });
}
