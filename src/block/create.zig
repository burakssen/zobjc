//! Block creation engine for Apple Blocks.
//!
//! Synthesizes stack literals and immediately promotes them to the heap via _Block_copy,
//! returning a safe OwnedBlock. Also provides zero-allocation global Blocks.

const std = @import("std");
const raw = @import("raw");
const abi = @import("abi.zig");
const block_mod = @import("block.zig");
const owned_mod = @import("owned.zig");
const capture_mod = @import("capture.zig");
const literal_mod = @import("internal/literal.zig");
const copy_dispose_mod = @import("internal/copy_dispose.zig");
const trampoline_mod = @import("internal/trampoline.zig");
const validation = @import("validation.zig");
const diagnostics = @import("diagnostics.zig");
const strong_mod = @import("strong.zig");
const block_ref_mod = @import("block_ref.zig");
const byref_mod = @import("byref.zig");
const byref_cell_mod = @import("byref_cell.zig");
const Object = @import("runtime").Object;
const getClass = @import("runtime").getClass;

const testing = std.testing;

/// Primary constructor: creates an OwnedBlock with captures.
pub fn createBlock(
    comptime Signature: type,
    comptime Captures: type,
    captures: Captures,
    comptime callback: anytype,
) !owned_mod.OwnedBlock(Signature) {
    validation.validateBlockSignature(Signature);
    validation.validateNotPtrauth();

    const Info = capture_mod.CaptureInfo(Captures);
    const fn_info = @typeInfo(Signature).@"fn";
    const RetType = fn_info.return_type orelse void;
    const uses_stret = abi.usesStret(RetType);

    const Lit = literal_mod.Literal(Captures);
    const helpers = copy_dispose_mod.CopyDisposeHelpers(Captures);

    const S = struct {
        const sig_str = abi.blockSignature(Signature);
        const trampoline = trampoline_mod.InvokeTrampoline(Signature, Captures, callback).Runner.trampoline;
        const layout_res = Info.computeLayout();
        const DescType = abi.Descriptor(Info.requires_helpers, true, layout_res.has_layout);
        const desc: DescType = if (Info.requires_helpers and layout_res.has_layout) .{
            .reserved = 0,
            .size = @sizeOf(Lit),
            .copy = &helpers.copy,
            .dispose = &helpers.dispose,
            .signature = sig_str,
            .layout = layout_res.rawPointer(),
        } else if (Info.requires_helpers and !layout_res.has_layout) .{
            .reserved = 0,
            .size = @sizeOf(Lit),
            .copy = &helpers.copy,
            .dispose = &helpers.dispose,
            .signature = sig_str,
        } else if (!Info.requires_helpers and layout_res.has_layout) .{
            .reserved = 0,
            .size = @sizeOf(Lit),
            .signature = sig_str,
            .layout = layout_res.rawPointer(),
        } else .{
            .reserved = 0,
            .size = @sizeOf(Lit),
            .signature = sig_str,
        };
    };

    const flags = (abi.BlockFlags{
        .copy_dispose = Info.requires_helpers,
        .stret = uses_stret,
        .signature = true,
        .extended_layout = S.layout_res.has_layout,
    }).bits();

    var lit: Lit = undefined;
    lit.header.isa = raw.blocks._NSConcreteStackBlock;
    lit.header.flags = flags;
    lit.header.reserved = 0;
    lit.header.invoke = @ptrCast(&S.trampoline);
    lit.header.descriptor = @ptrCast(&S.desc);

    if (@sizeOf(Captures) > 0) {
        lit.getCaptures().* = captures;
    }

    // promote stack literal to heap immediately via _Block_copy; stack literal never escapes
    const copied = raw.blocks._Block_copy(&lit) orelse return error.OutOfMemory;
    return owned_mod.OwnedBlock(Signature).fromRaw(@ptrCast(@alignCast(copied)));
}

/// Creates an OwnedBlock with captures, automatically inferring the capture type.
pub fn closure(
    comptime Signature: type,
    captures: anytype,
    comptime callback: anytype,
) !owned_mod.OwnedBlock(Signature) {
    return createBlock(Signature, @TypeOf(captures), captures, callback);
}

/// Creates a non-allocating, immortal Block handle from a free function without heap allocation.
pub fn fromFunction(
    comptime Signature: type,
    comptime callback: anytype,
) block_mod.Block(Signature) {
    return global(Signature, callback);
}

/// Global Block optimization: returns a statically allocated non-capturing Block.
pub fn global(
    comptime Signature: type,
    comptime callback: anytype,
) block_mod.Block(Signature) {
    validation.validateBlockSignature(Signature);
    validation.validateNotPtrauth();

    const fn_info = @typeInfo(Signature).@"fn";
    const RetType = fn_info.return_type orelse void;
    const S = struct {
        const is_stret = abi.usesStret(RetType);
        const sig_str = abi.blockSignature(Signature);
        const trampoline = trampoline_mod.InvokeTrampoline(Signature, struct {}, callback).Runner.trampoline;
        const DescType = abi.Descriptor(false, true, false);
        const desc: DescType = .{
            .reserved = 0,
            .size = @sizeOf(raw.blocks.Block_layout),
            .signature = sig_str,
        };

        var lit: raw.blocks.Block_layout = .{
            .isa = raw.blocks._NSConcreteGlobalBlock,
            .flags = (abi.BlockFlags{
                .global = true,
                .stret = is_stret,
                .signature = true,
            }).bits(),
            .reserved = 0,
            .invoke = @ptrCast(&trampoline),
            .descriptor = @ptrCast(&desc),
        };
    };

    return block_mod.Block(Signature).fromRaw(&S.lit);
}

test "creation: fromFunction no-capture block" {
    var blk = try owned_mod.OwnedBlock(fn (c_int) c_int).fromFunction(struct {
        fn double(x: c_int) c_int {
            return x * 2;
        }
    }.double);
    defer blk.deinit();

    try testing.expectEqual(@as(c_int, 42), blk.call(.{21}));
}

test "creation: global block" {
    const blk = global(fn (c_int, c_int) c_int, struct {
        fn add(a: c_int, b: c_int) c_int {
            return a + b;
        }
    }.add);

    try testing.expect(diagnostics.isGlobal(blk.toRaw()));
    try testing.expectEqual(@as(c_int, 42), blk.call(.{ 15, 27 }));
}

test "creation: clone creates independent ownership" {
    var original = try owned_mod.OwnedBlock(fn (c_int) c_int).fromFunction(struct {
        fn triple(x: c_int) c_int {
            return x * 3;
        }
    }.triple);

    var copy = try original.clone();
    original.deinit();
    try testing.expectEqual(@as(c_int, 30), copy.call(.{10}));
    copy.deinit();
}

test "creation: intoRaw relinquishes ownership" {
    var blk = try owned_mod.OwnedBlock(fn () void).fromFunction(struct {
        fn nop() void {}
    }.nop);

    const raw_ptr = blk.intoRaw();
    try testing.expectEqual(@as(?*raw.blocks.Block_layout, null), blk.ptr);
    raw.blocks._Block_release(raw_ptr);
}

test "capture: trivial integer and float captures" {
    const Captures = struct {
        base: c_int,
        multiplier: f64,
    };

    var blk = try owned_mod.OwnedBlock(fn (c_int) f64).capture(
        Captures,
        .{ .base = 10, .multiplier = 2.5 },
        struct {
            fn compute(caps: *const Captures, input: c_int) f64 {
                return @as(f64, @floatFromInt(caps.base + input)) * caps.multiplier;
            }
        }.compute,
    );
    defer blk.deinit();
    try testing.expectEqual(@as(f64, 30.0), blk.call(.{2}));
}

test "capture: mixed alignment layout" {
    const MixedCaptures = struct {
        c: u8,
        pad: u64,
        s: u16,
    };

    var blk = try owned_mod.OwnedBlock(fn () u64).capture(
        MixedCaptures,
        .{ .c = 5, .pad = 1000, .s = 20 },
        struct {
            fn sum(caps: *const MixedCaptures) u64 {
                return @as(u64, caps.c) + caps.pad + @as(u64, caps.s);
            }
        }.sum,
    );
    defer blk.deinit();
    try testing.expectEqual(@as(u64, 1025), blk.call(.{}));
}

test "capture: trivial captures do not require copy/dispose helpers" {
    const TrivialCaptures = struct {
        x: c_int,
        y: f64,
        p: ?*anyopaque,
    };

    var blk = try owned_mod.OwnedBlock(fn () void).capture(
        TrivialCaptures,
        .{ .x = 1, .y = 2.0, .p = null },
        struct {
            fn run(_: *const TrivialCaptures) void {}
        }.run,
    );
    defer blk.deinit();
    try testing.expect(!diagnostics.hasCopyDispose(blk.borrow().toRaw()));
}

test "block layout: header size and offsets" {
    try testing.expectEqual(@as(usize, 32), @sizeOf(raw.blocks.Block_layout));
    try testing.expectEqual(@as(usize, 0), @offsetOf(raw.blocks.Block_layout, "isa"));
    try testing.expectEqual(@as(usize, 8), @offsetOf(raw.blocks.Block_layout, "flags"));
    try testing.expectEqual(@as(usize, 12), @offsetOf(raw.blocks.Block_layout, "reserved"));
    try testing.expectEqual(@as(usize, 16), @offsetOf(raw.blocks.Block_layout, "invoke"));
    try testing.expectEqual(@as(usize, 24), @offsetOf(raw.blocks.Block_layout, "descriptor"));
}

extern "c" fn get_clang_block_flags(block: *anyopaque) i32;
extern "c" fn get_clang_block_descriptor_size(block: *anyopaque) usize;
extern "c" fn get_clang_block_signature(block: *anyopaque) ?[*:0]const u8;
extern "c" fn make_int_multiplier_block(multiplier: c_int) *anyopaque;

test "block layout: Clang block comparison" {
    const clang_blk = make_int_multiplier_block(3);
    defer raw.blocks._Block_release(clang_blk);

    try testing.expect((get_clang_block_flags(clang_blk) & raw.blocks.BLOCK_HAS_SIGNATURE) != 0);
    try testing.expect(get_clang_block_descriptor_size(clang_blk) >= 36);
    try testing.expect(get_clang_block_signature(clang_blk) != null);
}

test "block layout: Zig block descriptor size covers captures" {
    const Captures = struct { a: c_int, b: f64 };
    var blk = try owned_mod.OwnedBlock(fn () void).capture(
        Captures,
        .{ .a = 1, .b = 2.0 },
        struct {
            fn run(_: *const Captures) void {}
        }.run,
    );
    defer blk.deinit();

    const raw_ptr = blk.borrow().toRaw();
    const Lit = literal_mod.Literal(Captures);
    try testing.expectEqual(@sizeOf(Lit), raw_ptr.descriptor.size);
    try testing.expect(raw_ptr.descriptor.size >= 48);
}

extern "c" fn get_dealloc_count() c_int;
extern "c" fn reset_dealloc_count() void;

test "lifecycle: Strong(Object) keeps object alive and deallocates on block destroy" {
    reset_dealloc_count();
    const TrackerClass = getClass("DeallocTracker").?;
    const tracker_raw = TrackerClass.send(Object, "alloc", .{})
        .send(Object, "initWithIdentifier:", .{@as(c_int, 42)});

    const Captures = struct { tracker: strong_mod.Strong(Object) };
    var blk = try owned_mod.OwnedBlock(fn () c_int).capture(
        Captures,
        .{ .tracker = strong_mod.Strong(Object).init(tracker_raw) },
        struct {
            fn run(caps: *const Captures) c_int {
                return caps.tracker.borrow().send(c_int, "identifier", .{});
            }
        }.run,
    );

    tracker_raw.send(void, "release", .{});
    try testing.expectEqual(@as(c_int, 0), get_dealloc_count());
    try testing.expectEqual(@as(c_int, 42), blk.call(.{}));
    try testing.expectEqual(@as(c_int, 0), get_dealloc_count());
    blk.deinit();
    try testing.expectEqual(@as(c_int, 1), get_dealloc_count());
}

test "lifecycle: nested BlockRef captures" {
    var inner_block = try owned_mod.OwnedBlock(fn (c_int) c_int).fromFunction(struct {
        fn double(x: c_int) c_int {
            return x * 2;
        }
    }.double);

    const OuterCaptures = struct { inner: block_ref_mod.BlockRef(fn (c_int) c_int) };
    var outer_block = try owned_mod.OwnedBlock(fn (c_int) c_int).capture(
        OuterCaptures,
        .{ .inner = block_ref_mod.BlockRef(fn (c_int) c_int).init(inner_block) },
        struct {
            fn run(caps: *const OuterCaptures, val: c_int) c_int {
                const inner = block_mod.Block(fn (c_int) c_int).fromRaw(caps.inner.rawPtr().?);
                return inner.call(.{val}) + 5;
            }
        }.run,
    );

    inner_block.deinit();
    try testing.expectEqual(@as(c_int, 25), outer_block.call(.{10}));
    outer_block.deinit();
}

test "differential: strong capture lifecycle verified by observable destruction" {
    reset_dealloc_count();
    const Tracker = getClass("DeallocTracker").?;

    {
        const tracker_obj = Tracker.send(Object, "alloc", .{})
            .send(Object, "initWithIdentifier:", .{@as(c_int, 100)});
        var retained = @import("memory").Retained(Object).adopt(tracker_obj);

        const Captures = struct { tracked: strong_mod.Strong(Object) };
        var blk = try owned_mod.OwnedBlock(fn () c_int).capture(
            Captures,
            .{ .tracked = strong_mod.Strong(Object).init(retained.borrow()) },
            struct {
                fn run(caps: *const Captures) c_int {
                    return caps.tracked.borrow().send(c_int, "identifier", .{});
                }
            }.run,
        );
        defer blk.deinit();

        retained.deinit();
        try testing.expectEqual(@as(c_int, 0), get_dealloc_count());
        try testing.expectEqual(@as(c_int, 100), blk.call(.{}));
    }

    try testing.expectEqual(@as(c_int, 1), get_dealloc_count());
}

fn makeEscapedDifferentialBlock() !owned_mod.OwnedBlock(fn (c_int) c_int) {
    var count: byref_mod.ByRef(c_int) = .{};
    count.init(100);
    defer count.deinit();

    const Captures = struct { counter: byref_mod.ByRefCapture(c_int) };
    return try owned_mod.OwnedBlock(fn (c_int) c_int).capture(
        Captures,
        .{ .counter = count.capture() },
        struct {
            fn add(caps: *const Captures, delta: c_int) c_int {
                const cell: *byref_cell_mod.ByRefCell(c_int) = @ptrCast(@alignCast(caps.counter.cell_ptr));
                cell.forwarding.value += delta;
                return cell.forwarding.value;
            }
        }.add,
    );
}

test "differential: ByRef forwarding outlives original stack frame" {
    var escaped = try makeEscapedDifferentialBlock();
    defer escaped.deinit();
    try testing.expectEqual(@as(c_int, 105), escaped.call(.{5}));
    try testing.expectEqual(@as(c_int, 115), escaped.call(.{10}));
}

test "signature: generated block signatures" {
    try testing.expectEqualStrings("v@?", abi.blockSignature(fn () void));
    try testing.expectEqualStrings("v@?i", abi.blockSignature(fn (c_int) void));
    try testing.expectEqualStrings("i@?id", abi.blockSignature(fn (c_int, f64) c_int));
    try testing.expectEqualStrings("@@?@", abi.blockSignature(fn (Object) Object));
}

test "signature: validate against Clang block" {
    const clang_blk = make_int_multiplier_block(5);
    defer raw.blocks._Block_release(clang_blk);

    const sig_raw = get_clang_block_signature(clang_blk);
    try testing.expect(sig_raw != null);
    const sig_str = std.mem.span(sig_raw.?);
    try testing.expect(std.mem.startsWith(u8, sig_str, "i"));
    try testing.expect(std.mem.indexOf(u8, sig_str, "@?") != null);
    try testing.expect(std.mem.endsWith(u8, sig_str, "i") or std.mem.indexOf(u8, sig_str, "i8") != null);
}

test "signature: validateSignature on Zig block" {
    var blk = try owned_mod.OwnedBlock(fn (c_int) c_int).fromFunction(struct {
        fn run(x: c_int) c_int {
            return x * 2;
        }
    }.run);
    defer blk.deinit();

    try blk.borrow().validateSignature();
    const sig = blk.borrow().signature();
    try testing.expect(sig != null);
    try testing.expectEqualStrings("i@?i", std.mem.span(sig.?));
}

test "ergonomics: non-struct capture in closure" {
    var val: usize = 100;
    var blk = try closure(fn (usize) usize, &val, struct {
        fn run(ptr: *usize, delta: usize) usize {
            ptr.* += delta;
            return ptr.*;
        }
    }.run);
    defer blk.deinit();

    try testing.expectEqual(@as(usize, 125), blk.call(.{25}));
    try testing.expectEqual(@as(usize, 125), val);
}

test "ergonomics: closure with primitive capture by value" {
    const multiplier: c_int = 10;
    var blk = try closure(fn (c_int) c_int, multiplier, struct {
        fn run(mult: c_int, x: c_int) c_int {
            return mult * x;
        }
    }.run);
    defer blk.deinit();

    try testing.expectEqual(@as(c_int, 70), blk.call(.{7}));
}

test "ergonomics: arity adaptation ignoring block parameters" {
    var count: usize = 0;
    var blk = try closure(fn (c_int, f64) void, &count, struct {
        fn run(ptr: *usize) void {
            ptr.* += 1;
        }
    }.run);
    defer blk.deinit();

    blk.call(.{ 42, 3.14 });
    try testing.expectEqual(@as(usize, 1), count);
}

test "ergonomics: stateless fromFunction returns direct Block without error" {
    const blk = fromFunction(fn (c_int, c_int) c_int, struct {
        fn add(a: c_int, b: c_int) c_int {
            return a + b;
        }
    }.add);

    try testing.expectEqual(@as(c_int, 42), blk.call(.{ 20, 22 }));
}
