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
    // Pure libobjc layer: links only libobjc and libc (NO Foundation framework).
    const objc_mod = b.addModule("objc", .{
        .root_source_file = b.path("src/objc.zig"),
        .target = target,
        .optimize = optimize,
    });
    if (add_paths) try addAppleSDK(b, objc_mod);
    objc_mod.linkSystemLibrary("objc", .{});

    const zobjc_mod = b.addModule("zobjc", .{
        .root_source_file = b.path("src/objc.zig"),
        .target = target,
        .optimize = optimize,
    });
    if (add_paths) try addAppleSDK(b, zobjc_mod);
    zobjc_mod.linkSystemLibrary("objc", .{});

    // Optional Foundation framework convenience layer
    const objc_foundation_mod = b.addModule("objc_foundation", .{
        .root_source_file = b.path("src/foundation/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    objc_foundation_mod.addImport("objc", objc_mod);
    if (add_paths) try addAppleSDK(b, objc_foundation_mod);
    objc_foundation_mod.linkSystemLibrary("objc", .{});
    objc_foundation_mod.linkFramework("Foundation", .{});

    // Core test suite (pure libobjc, no Foundation)
    const core_test = addObjcTest(b, target, optimize, "test-core", "tests/root_core.zig", objc_c, add_paths, false, false);
    const run_core_test = b.addRunArtifact(core_test);

    // Foundation test suite (links Foundation)
    const foundation_test = addObjcTest(b, target, optimize, "test-foundation", "tests/foundation/root.zig", objc_c, add_paths, true, false);
    const run_foundation_test = b.addRunArtifact(foundation_test);

    // Integration test suite (Foundation + AppKit)
    const integration_test = addObjcTest(b, target, optimize, "test-integration", "tests/integration/root.zig", objc_c, add_paths, true, true);
    const run_integration_test = b.addRunArtifact(integration_test);

    // Linkage verification: assert test-core does NOT link Foundation.framework
    const verify_step = b.step("verify-linkage", "Verify test-core does not link Foundation");
    const verify_cmd = b.addSystemCommand(&.{ "sh", "-c", "if otool -L \"$1\" | grep -q 'Foundation.framework'; then echo 'Error: test-core links Foundation.framework!' >&2; exit 1; else echo 'Verified: test-core does not link Foundation.framework'; fi", "--" });
    verify_cmd.addFileArg(core_test.getEmittedBin());
    verify_step.dependOn(&verify_cmd.step);

    // Step: test-core
    const test_core_step = b.step("test-core", "Run pure libobjc core runtime tests");
    test_core_step.dependOn(&run_core_test.step);
    test_core_step.dependOn(&verify_cmd.step);

    // Step: test-foundation
    const test_foundation_step = b.step("test-foundation", "Run Foundation convenience layer tests");
    test_foundation_step.dependOn(&run_foundation_test.step);

    // Step: test / test-all (runs core + foundation + integration)
    const test_step = b.step("test", "Run master test suite (core + foundation + integration)");
    test_step.dependOn(&run_core_test.step);
    test_step.dependOn(&verify_cmd.step);
    test_step.dependOn(&run_foundation_test.step);
    test_step.dependOn(&run_integration_test.step);

    // Step: test-parity (runs Apple SDK header parity tests)
    const parity_test = addObjcTest(b, target, optimize, "test-parity", "tests/parity/root.zig", objc_c, add_paths, false, false);
    const run_parity_test = b.addRunArtifact(parity_test);
    const test_parity_step = b.step("test-parity", "Run Apple SDK header parity tests");
    test_parity_step.dependOn(&run_parity_test.step);

    // Step: test-differential (runs Clang differential tests)
    const differential_test = addObjcTest(b, target, optimize, "test-differential", "tests/differential/root.zig", objc_c, add_paths, false, false);
    const run_differential_test = b.addRunArtifact(differential_test);
    const test_differential_step = b.step("test-differential", "Run Clang differential tests (encoding, ABI, messaging, blocks)");
    test_differential_step.dependOn(&run_differential_test.step);

    // Step: test-compat (runs backward compatibility tests)
    const compat_test = addObjcTest(b, target, optimize, "test-compat", "tests/compatibility/root.zig", objc_c, add_paths, false, false);
    const run_compat_test = b.addRunArtifact(compat_test);
    const test_compat_step = b.step("test-compat", "Run backward compatibility and upstream README tests");
    test_compat_step.dependOn(&run_compat_test.step);

    // Step: audit-runtime (runs runtime API completeness audit against SDK headers and manifest)
    const audit_step = b.step("audit-runtime", "Audit runtime API against SDK headers and manifest");
    const audit_cmd = b.addSystemCommand(&.{ "python3", "tools/audit-runtime-api.py" });
    audit_step.dependOn(&audit_cmd.step);

    // Step: test-consumer (builds and executes the external consumer package)
    const consumer_step = b.step("test-consumer", "Run standalone package consumer test");
    const consumer_cmd = b.addSystemCommand(&.{ b.graph.zig_exe, "build", "--build-file", "tests/consumer/build.zig" });
    consumer_step.dependOn(&consumer_cmd.step);

    // Step: test-cross (compiles the core library across all supported Apple target architectures)
    const test_cross_step = b.step("test-cross", "Cross-compile core library across Apple platforms");
    const cross_targets = [_]struct { name: []const u8, query: std.Target.Query }{
        .{ .name = "macos-x86_64", .query = .{ .cpu_arch = .x86_64, .os_tag = .macos } },
        .{ .name = "ios-aarch64", .query = .{ .cpu_arch = .aarch64, .os_tag = .ios } },
        .{ .name = "ios-simulator-aarch64", .query = .{ .cpu_arch = .aarch64, .os_tag = .ios, .abi = .simulator } },
        .{ .name = "tvos-aarch64", .query = .{ .cpu_arch = .aarch64, .os_tag = .tvos } },
        .{ .name = "watchos-aarch64", .query = .{ .cpu_arch = .aarch64, .os_tag = .watchos } },
        .{ .name = "visionos-aarch64", .query = .{ .cpu_arch = .aarch64, .os_tag = .visionos } },
    };

    for (cross_targets) |ct| {
        const resolved_tgt = b.resolveTargetQuery(ct.query);
        const cross_mod = b.createModule(.{
            .root_source_file = b.path("src/objc.zig"),
            .target = resolved_tgt,
            .optimize = optimize,
        });
        const cross_lib = b.addLibrary(.{
            .linkage = .static,
            .name = b.fmt("objc_{s}", .{ct.name}),
            .root_module = cross_mod,
        });
        test_cross_step.dependOn(&cross_lib.step);
    }

    // Step: test-compile-fail (verifies invalid types and constructs fail compilation)
    const compile_fail_step = b.step("test-compile-fail", "Run compile-fail rejection tests");
    const compile_fail_cmd = b.addSystemCommand(&.{ "python3", "tools/test-compile-fail.py", b.graph.zig_exe });
    compile_fail_step.dependOn(&compile_fail_cmd.step);

    // Release gate step: test-all
    const test_all_step = b.step("test-all", "Run full release verification matrix");
    test_all_step.dependOn(test_step);
    test_all_step.dependOn(&run_parity_test.step);
    test_all_step.dependOn(&run_differential_test.step);
    test_all_step.dependOn(&run_compat_test.step);
    test_all_step.dependOn(&audit_cmd.step);
    test_all_step.dependOn(&compile_fail_cmd.step);
    test_all_step.dependOn(&consumer_cmd.step);
    test_all_step.dependOn(test_cross_step);

    // Step: test-raw (runs raw ABI subsystem tests - pure libobjc)
    const raw_test = addObjcTest(b, target, optimize, "test-raw", "tests/raw/root.zig", objc_c, add_paths, false, false);
    const run_raw_test = b.addRunArtifact(raw_test);
    const test_raw_step = b.step("test-raw", "Run raw ABI subsystem tests");
    test_raw_step.dependOn(&run_raw_test.step);

    // Step: test-runtime (runs pure runtime tests - pure libobjc)
    const runtime_test = addObjcTest(b, target, optimize, "test-runtime", "tests/runtime/root.zig", objc_c, add_paths, false, false);
    const run_runtime_test = b.addRunArtifact(runtime_test);
    const test_runtime_step = b.step("test-runtime", "Run runtime subsystem tests");
    test_runtime_step.dependOn(&run_runtime_test.step);

    // Step: test-memory (runs ownership and memory tests - pure libobjc)
    const memory_test = addObjcTest(b, target, optimize, "test-memory", "tests/memory/root.zig", objc_c, add_paths, false, false);
    const run_memory_test = b.addRunArtifact(memory_test);
    const test_memory_step = b.step("test-memory", "Run memory and ownership subsystem tests");
    test_memory_step.dependOn(&run_memory_test.step);

    // Step: test-encoding (runs encoding subsystem tests - pure libobjc)
    const encoding_test = addObjcTest(b, target, optimize, "test-encoding", "tests/encoding/root.zig", objc_c, add_paths, false, false);
    const run_encoding_test = b.addRunArtifact(encoding_test);
    const test_encoding_step = b.step("test-encoding", "Run encoding and signature subsystem tests");
    test_encoding_step.dependOn(&run_encoding_test.step);

    // Step: test-abi (runs Darwin ABI classification tests - pure libobjc)
    const abi_test = addObjcTest(b, target, optimize, "test-abi", "tests/abi/root.zig", objc_c, add_paths, false, false);
    const run_abi_test = b.addRunArtifact(abi_test);
    const test_abi_step = b.step("test-abi", "Run Darwin ABI classification subsystem tests");
    test_abi_step.dependOn(&run_abi_test.step);

    // Step: test-messaging (runs unified messaging subsystem tests - pure libobjc)
    const messaging_test = addObjcTest(b, target, optimize, "test-messaging", "tests/messaging/root.zig", objc_c, add_paths, false, false);
    const run_messaging_test = b.addRunArtifact(messaging_test);
    const test_messaging_step = b.step("test-messaging", "Run unified messaging subsystem tests");
    test_messaging_step.dependOn(&run_messaging_test.step);

    // Step: test-builder (runs dynamic class and protocol builder tests - pure libobjc)
    const builder_test = addObjcTest(b, target, optimize, "test-builder", "tests/builder/root.zig", objc_c, add_paths, false, false);
    const run_builder_test = b.addRunArtifact(builder_test);
    const test_builder_step = b.step("test-builder", "Run dynamic class and protocol builder tests");
    test_builder_step.dependOn(&run_builder_test.step);

    // Step: test-block (runs Apple Block subsystem tests - pure libobjc)
    const block_test = addObjcTest(b, target, optimize, "test-block", "tests/block/root.zig", objc_c, add_paths, false, false);
    const run_block_test = b.addRunArtifact(block_test);
    const test_block_step = b.step("test-block", "Run Objective-C Block subsystem tests");
    test_block_step.dependOn(&run_block_test.step);

    // Step: test-integration (runs Foundation/AppKit integration tests)
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
        "runtime_introspection",
        "ownership_and_memory",
        "type_encodings",
        "abi_classification",
        "messaging",
        "dynamic_class",
        "runtime_inspector",
        "foundation_basics",
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

        const needs_foundation = std.mem.eql(u8, name, "process_info") or
            std.mem.eql(u8, name, "foundation_basics");
        if (needs_foundation) {
            exe_mod.addImport("objc_foundation", objc_foundation_mod);
            exe_mod.linkFramework("Foundation", .{});
        }

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
    link_foundation: bool,
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
    if (link_foundation) {
        const foundation_facade = b.createModule(.{
            .root_source_file = b.path("src/foundation/root.zig"),
            .target = target,
            .optimize = optimize,
        });
        foundation_facade.addImport("objc", objc_facade);
        mod.addImport("objc_foundation", foundation_facade);
        mod.linkFramework("Foundation", .{});
        if (add_paths) {
            addAppleSDK(b, foundation_facade) catch {};
        }
    }
    if (link_appkit) {
        mod.linkFramework("AppKit", .{});
    }

    if (add_paths) {
        addAppleSDK(b, mod) catch {};
        addAppleSDK(b, objc_facade) catch {};
    }

    mod.addCSourceFile(.{
        .file = b.path("tests/fixtures/encoding/fixtures.m"),
        .flags = &.{},
    });
    mod.addIncludePath(b.path("tests/fixtures/encoding"));

    mod.addCSourceFile(.{
        .file = b.path("tests/fixtures/abi/fixtures.m"),
        .flags = &.{},
    });
    mod.addIncludePath(b.path("tests/fixtures/abi"));

    mod.addCSourceFile(.{
        .file = b.path("tests/fixtures/blocks/fixtures.m"),
        .flags = &.{"-fblocks"},
    });
    mod.addIncludePath(b.path("tests/fixtures/blocks"));

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
