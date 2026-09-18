//! Architecture regression guard: no subsystem source may import the facade.
//!
//! Textual rule (see docs/architecture.md): subsystem source files must not
//! contain `@import("zobjc")`, including in comments. Narrow on purpose:
//! `tests/`, `examples/`, and `src/root.zig` may reference the facade freely.

const std = @import("std");

const forbidden = "@import(\"zobjc\")";

const subsystem_dirs = [_][]const u8{
    "src/abi",
    "src/block",
    "src/encoding",
    "src/internal",
    "src/memory",
    "src/messaging",
    "src/raw",
    "src/runtime",
};

/// Returns true when `source` textually imports the zobjc facade.
pub fn containsForbiddenFacadeImport(source: []const u8) bool {
    return std.mem.indexOf(u8, source, forbidden) != null;
}

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var violations: usize = 0;
    for (subsystem_dirs) |dir_path| {
        var dir = std.Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true }) catch |err| {
            std.debug.print("architecture check could not walk {s}: {s}\n", .{ dir_path, @errorName(err) });
            return err;
        };
        defer dir.close(io);
        var walker = try std.Io.Dir.walk(dir, allocator);
        defer walker.deinit();
        while (try walker.next(io)) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.basename, ".zig")) continue;
            const display_path = try std.fs.path.join(allocator, &.{ dir_path, entry.path });
            defer allocator.free(display_path);
            const content = try entry.dir.readFileAlloc(io, entry.basename, allocator, .limited(1 << 20));
            defer allocator.free(content);
            var lines = std.mem.splitScalar(u8, content, '\n');
            var lineno: usize = 1;
            while (lines.next()) |line| : (lineno += 1) {
                if (containsForbiddenFacadeImport(line)) {
                    std.debug.print("architecture violation: {s}:{d} imports the zobjc facade\n", .{ display_path, lineno });
                    violations += 1;
                }
            }
        }
    }
    if (violations > 0) {
        std.debug.print("architecture check failed: {d} violation(s)\n", .{violations});
        std.process.exit(1);
    }
}

test "predicate accepts non-facade imports and plain mentions" {
    try std.testing.expect(!containsForbiddenFacadeImport("const raw = @import(\"raw\");\n"));
    try std.testing.expect(!containsForbiddenFacadeImport("const runtime = @import(\"runtime\");\n"));
    try std.testing.expect(!containsForbiddenFacadeImport("// mentions zobjc but imports nothing\n"));
    try std.testing.expect(!containsForbiddenFacadeImport("const std = @import(\"std\");\n"));
}

test "predicate rejects facade imports" {
    try std.testing.expect(containsForbiddenFacadeImport("const z = @import(\"zobjc\");\n"));
    try std.testing.expect(containsForbiddenFacadeImport("@import(\"zobjc\")\n"));
    try std.testing.expect(containsForbiddenFacadeImport("// @import(\"zobjc\") in a comment still counts\n"));
}
