const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});
    const add_paths = b.option(
        bool,
        "add-paths",
        "add apple SDK paths from Xcode installation",
    ) orelse true;

    // Translate the Objective-C runtime headers once in the build so the Zig
    // code can import a stable generated module instead of invoking @cImport
    // from every compile.
    const objc_c = try translateCModule(b, target, optimize);

    // Canonical module: objc (also alias zobjc for package matching)
    const objc_mod = b.addModule("objc", .{
        .root_source_file = b.path("src/objc.zig"),
        .target = target,
        .optimize = optimize,
    });
    if (add_paths) try addAppleSDK(b, objc_mod);
    objc_mod.linkSystemLibrary("objc", .{});
    objc_mod.linkFramework("Foundation", .{});

    const zobjc_mod = b.addModule("zobjc", .{
        .root_source_file = b.path("src/objc.zig"),
        .target = target,
        .optimize = optimize,
    });
    if (add_paths) try addAppleSDK(b, zobjc_mod);
    zobjc_mod.linkSystemLibrary("objc", .{});
    zobjc_mod.linkFramework("Foundation", .{});

    // Master test suite
    const master_test = addObjcTest(b, target, optimize, "test-all", "tests/root.zig", objc_c, add_paths, true);
    const run_master_test = b.addRunArtifact(master_test);

    // Step: test (runs the entire test suite)
    const test_step = b.step("test", "Run master test suite");
    test_step.dependOn(&run_master_test.step);

    // Step: test-all (alias to test)
    const test_all_step = b.step("test-all", "Run all tests");
    test_all_step.dependOn(&run_master_test.step);

    // Step: test-raw (runs raw ABI subsystem tests)
    const raw_test = addObjcTest(b, target, optimize, "test-raw", "tests/raw/root.zig", objc_c, add_paths, false);
    const run_raw_test = b.addRunArtifact(raw_test);
    const test_raw_step = b.step("test-raw", "Run raw ABI subsystem tests");
    test_raw_step.dependOn(&run_raw_test.step);

    // Step: test-runtime (runs pure runtime tests)
    const runtime_test = addObjcTest(b, target, optimize, "test-runtime", "tests/runtime/root.zig", objc_c, add_paths, true);
    const run_runtime_test = b.addRunArtifact(runtime_test);
    const test_runtime_step = b.step("test-runtime", "Run runtime subsystem tests");
    test_runtime_step.dependOn(&run_runtime_test.step);

    // Step: test-integration (runs Foundation/AppKit integration tests)
    const integration_test = addObjcTest(b, target, optimize, "test-integration", "tests/integration/root.zig", objc_c, add_paths, true);
    const run_integration_test = b.addRunArtifact(integration_test);
    const test_integration_step = b.step("test-integration", "Run integration tests");
    test_integration_step.dependOn(&run_integration_test.step);

    // Step: examples (compiles all examples)
    const examples_step = b.step("examples", "Compile all examples");
    const example_names = [_][]const u8{
        "process_info",
        "basic_object",
        "subclass",
        "block",
        "autorelease_pool",
    };

    for (example_names) |name| {
        const file_path = b.fmt("examples/{s}.zig", .{name});
        const exe_mod = b.createModule(.{
            .root_source_file = b.path(file_path),
            .target = target,
            .optimize = optimize,
        });
        exe_mod.addImport("objc", objc_mod);
        if (add_paths) try addAppleSDK(b, exe_mod);
        exe_mod.linkSystemLibrary("objc", .{});
        exe_mod.linkFramework("Foundation", .{});

        const exe = b.addExecutable(.{
            .name = name,
            .root_module = exe_mod,
        });
        examples_step.dependOn(&b.addInstallArtifact(exe, .{}).step);
    }
}

/// Helper function to create an Objective-C test artifact.
fn addObjcTest(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    name: []const u8,
    root_path: []const u8,
    objc_c: *std.Build.Module,
    add_paths: bool,
    link_appkit: bool,
) *std.Build.Step.Compile {
    const mod = b.createModule(.{
        .root_source_file = b.path(root_path),
        .target = target,
        .optimize = optimize,
    });
    const objc_facade = b.createModule(.{
        .root_source_file = b.path("src/objc.zig"),
        .target = target,
        .optimize = optimize,
    });
    mod.addImport("objc", objc_facade);
    mod.addImport("objc-c", objc_c);

    mod.linkSystemLibrary("objc", .{});
    mod.linkFramework("Foundation", .{});
    if (link_appkit) {
        mod.linkFramework("AppKit", .{});
    }

    if (add_paths) {
        addAppleSDK(b, mod) catch {};
        addAppleSDK(b, objc_facade) catch {};
    }

    const test_artifact = b.addTest(.{
        .name = name,
        .root_module = mod,
    });
    return test_artifact;
}

/// Returns a translated Objective-C header module built from the Apple SDK.
fn translateCModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) !*std.Build.Module {
    const sdk_path = try appleSDKPath(b, target);
    const include_path = b.pathJoin(&.{ sdk_path, "/usr/include" });
    const runtime_path = b.pathJoin(&.{ include_path, "/objc/runtime.h" });
    const runtime_h = try std.Io.Dir.cwd().readFileAlloc(
        b.graph.io,
        runtime_path,
        b.allocator,
        .limited(1024 * 1024),
    );

    const needle =
        \\objc_enumerateClasses(const void * _Nullable image,
        \\                      const char * _Nullable namePrefix,
        \\                      Protocol * _Nullable conformingTo,
        \\                      Class _Nullable subclassing,
        \\                      void (^ _Nonnull block)(Class _Nonnull aClass, BOOL * _Nonnull stop)
        \\                      OBJC_NOESCAPE)
    ;
    if (std.mem.indexOf(u8, runtime_h, needle) == null) {
        return error.ObjCRuntimeHeaderChanged;
    }

    const patched_runtime_h = try std.mem.replaceOwned(u8, b.allocator, runtime_h, needle,
        \\objc_enumerateClasses(const void * _Nullable image,
        \\                      const char * _Nullable namePrefix,
        \\                      Protocol * _Nullable conformingTo,
        \\                      Class _Nullable subclassing,
        \\                      void * _Nonnull block)
    );

    const wf = b.addWriteFiles();
    _ = wf.add("objc/runtime.h", patched_runtime_h);
    const import_h = wf.add("objc-import.h",
        \\#include <objc/runtime.h>
        \\#include <objc/message.h>
        \\
    );

    const c = b.addTranslateC(.{
        .root_source_file = import_h,
        .target = target,
        .optimize = optimize,
    });
    c.addIncludePath(wf.getDirectory());
    c.addSystemIncludePath(.{ .cwd_relative = include_path });
    return c.createModule();
}

/// Add the SDK framework, include, and library paths to the given module.
pub fn addAppleSDK(b: *std.Build, m: *std.Build.Module) !void {
    const path = try appleSDKPath(b, m.resolved_target.?);
    m.addSystemFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{ path, "/System/Library/Frameworks" }) });
    m.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ path, "/usr/include" }) });
    m.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ path, "/usr/lib" }) });
}

fn appleSDKPath(b: *std.Build, target: std.Build.ResolvedTarget) ![]const u8 {
    const Cache = struct {
        const Key = struct {
            arch: std.Target.Cpu.Arch,
            os: std.Target.Os.Tag,
            abi: std.Target.Abi,
        };
        var map: std.AutoHashMapUnmanaged(Key, ?[]const u8) = .{};
    };

    const gop = try Cache.map.getOrPut(b.allocator, .{
        .arch = target.result.cpu.arch,
        .os = target.result.os.tag,
        .abi = target.result.abi,
    });

    if (!gop.found_existing) {
        gop.value_ptr.* = std.zig.system.darwin.getSdk(
            b.allocator,
            b.graph.io,
            &target.result,
        );
    }

    return gop.value_ptr.* orelse switch (target.result.os.tag) {
        .macos => error.XcodeMacOSSDKNotFound,
        .ios => error.XcodeiOSSDKNotFound,
        .tvos => error.XcodeTVOSSDKNotFound,
        .watchos => error.XcodeWatchOSSDKNotFound,
        else => error.XcodeAppleSDKNotFound,
    };
}
