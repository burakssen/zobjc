//! Modern Objective-C class enumeration (`objc_enumerateClasses`).
//!
//! Provides filtered runtime enumeration by image, name prefix, protocol conformance,
//! and superclass relationship with early stopping and runtime availability detection.

const std = @import("std");
const testing = std.testing;
const raw = @import("raw");
const Class = @import("class.zig").Class;
const Protocol = @import("protocol.zig").Protocol;
const block = @import("block");

pub const EnumerateClassesFn = *const fn (
    image: ?*const anyopaque,
    namePrefix: ?[*:0]const u8,
    conformingTo: raw.Protocol,
    subclassing: raw.Class,
    block_handle: raw.id,
) callconv(.c) void;

// Darwin dlfcn.h: #define RTLD_DEFAULT ((void *) -2)
const RTLD_DEFAULT: ?*anyopaque = @ptrFromInt(@as(usize, @bitCast(@as(isize, -2))));

/// Dynamically resolves `objc_enumerateClasses` via dlsym if available on this platform.
pub fn getEnumerateClassesFn() ?EnumerateClassesFn {
    const sym = std.c.dlsym(RTLD_DEFAULT, "objc_enumerateClasses");
    if (sym) |s| return @ptrCast(@alignCast(s));
    return null;
}

/// Returns whether modern class enumeration (`objc_enumerateClasses`) is supported by the host OS.
pub inline fn hasClassEnumeration() bool {
    return getEnumerateClassesFn() != null;
}

/// Scope of images to filter during class enumeration.
pub const ImageFilter = union(enum) {
    caller,
    dynamic,
    handle: *const anyopaque,

    pub fn toRaw(self: ImageFilter) ?*const anyopaque {
        return switch (self) {
            .caller => null,
            .dynamic => raw.runtime.OBJC_DYNAMIC_CLASSES,
            .handle => |h| h,
        };
    }
};

/// Options for filtering classes during runtime enumeration.
pub const ClassEnumerationOptions = struct {
    image: ImageFilter = .caller,
    name_prefix: ?[:0]const u8 = null,
    conforming_to: ?Protocol = null,
    subclassing: ?Class = null,
};

/// Enumerates Objective-C classes matching the given options.
///
/// Callback signature:
/// `fn (context: *Context, cls: Class) bool`
/// Return `true` to continue enumeration, or `false` to stop immediately.
pub fn enumerateClasses(
    options: ClassEnumerationOptions,
    context: anytype,
    comptime callback: anytype,
) !void {
    const enum_fn = getEnumerateClassesFn() orelse return error.UnsupportedRuntime;

    const ContextType = @TypeOf(context);
    const Captures = struct {
        ctx: ContextType,
    };

    const RawBlockSig = fn (raw.Class, *raw.BOOL) void;

    // // bridge through createBlock with stack-to-heap promotion
    var closure_block = try block.createBlock(
        RawBlockSig,
        Captures,
        .{ .ctx = context },
        struct {
            fn run(caps: *Captures, raw_cls: raw.Class, stop: *raw.BOOL) void {
                const cls = Class.fromRaw(raw_cls) orelse return;
                const should_continue = callback(caps.ctx, cls);

                if (!should_continue) {
                    stop.* = raw.YES;
                }
            }
        }.run,
    );
    defer closure_block.deinit();

    const raw_image = options.image.toRaw();
    const raw_prefix: ?[*:0]const u8 = if (options.name_prefix) |p| p.ptr else null;
    const raw_proto: raw.Protocol = if (options.conforming_to) |p| p.ptr else null;
    const raw_super: raw.Class = if (options.subclassing) |s| s.ptr else null;

    enum_fn(
        raw_image,
        raw_prefix,
        raw_proto,
        raw_super,
        closure_block.borrow().asObject().toRaw(),
    );
}

test "class enumeration: early stop" {
    if (!hasClassEnumeration()) return;

    var count: usize = 0;
    try enumerateClasses(.{}, &count, struct {
        fn cb(c_ptr: *usize, cls: Class) bool {
            _ = cls;
            c_ptr.* += 1;
            return c_ptr.* < 2;
        }
    }.cb);
    try testing.expectEqual(@as(usize, 2), count);
}

test "class enumeration: prefix filter" {
    if (!hasClassEnumeration()) return;

    var count: usize = 0;
    var all_start_with_dealloc = true;
    var ctx = struct {
        cnt: *usize,
        matched: *bool,
    }{ .cnt = &count, .matched = &all_start_with_dealloc };

    try enumerateClasses(.{ .name_prefix = "Dealloc" }, &ctx, struct {
        fn cb(c: anytype, cls: Class) bool {
            c.cnt.* += 1;
            const cls_name = cls.name();
            if (!std.mem.startsWith(u8, cls_name, "Dealloc")) {
                c.matched.* = false;
                return false;
            }
            return true;
        }
    }.cb);

    try testing.expect(count > 0);
    try testing.expect(all_start_with_dealloc);
}

