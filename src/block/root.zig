//! Objective-C Blocks implementation.
//!
//! Provides the Block type constructor for stack-allocated and copied Objective-C blocks.

const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const raw = @import("../raw/root.zig");
const c = raw.c;
const comptimeEncode = @import("../encoding/root.zig").comptimeEncode;

// We have to use the raw C allocator for all heap allocation in here
// because the objc runtime expects `malloc` to be used. If you don't use
// malloc you'll get segfaults because the objc runtime will try to free
// the memory with `free`.
const alloc = std.heap.raw_c_allocator;

// TODO(phase-8): Replace legacy block capture handling and simplify Block ABI layout.

/// Creates a new block type with captured (closed over) values.
pub fn Block(
    comptime CapturesArg: type,
    comptime Args: anytype,
    comptime Return: type,
) type {
    return struct {
        const Self = @This();
        const captures_info = @typeInfo(Captures).@"struct";
        const InvokeFn = FnType(anyopaque);
        const descriptor: Descriptor = .{
            .reserved = 0,
            .size = @sizeOf(Context),
            .copy_helper = &descCopyHelper,
            .dispose_helper = &descDisposeHelper,
            .signature = &comptimeEncode(InvokeFn),
        };

        /// This is the function type that is called back.
        pub const Fn = FnType(Context);

        /// The captures type, so it can be easily referenced again.
        pub const Captures = CapturesArg;

        /// This is the block context sent as the first parameter to the function.
        pub const Context = BlockContext(Captures, InvokeFn);

        /// Create a new block context. The block context is what is passed
        /// (by reference) to functions that request a block.
        pub fn init(captures: Captures, func: *const Fn) Context {
            var ctx: Context = undefined;
            ctx.isa = NSConcreteStackBlock;
            ctx.flags = .{
                .copy_dispose = true,
                .stret = @typeInfo(Return) == .@"struct",
                .signature = true,
            };
            ctx.invoke = @ptrCast(func);
            ctx.descriptor = &descriptor;
            inline for (captures_info.fields) |field| {
                @field(ctx, field.name) = @field(captures, field.name);
            }

            return ctx;
        }

        /// Invoke the block with the given arguments.
        pub fn invoke(ctx: *const Context, args: anytype) Return {
            return @call(
                .auto,
                ctx.invoke,
                .{ctx} ++ args,
            );
        }

        /// Copies the given context by either literally copying it
        /// to the heap or increasing the reference count. This must be
        /// paired with a `release` call to release the block.
        pub fn copy(ctx: *const Context) Allocator.Error!*Context {
            const copied = _Block_copy(@ptrCast(@alignCast(ctx))) orelse
                return error.OutOfMemory;
            return @ptrCast(@alignCast(copied));
        }

        /// Release a copied block context. This must only be called on
        /// contexts returned by the `copy` function.
        pub fn release(ctx: *const Context) void {
            assert(@intFromPtr(ctx.isa) == @intFromPtr(NSConcreteMallocBlock));
            _Block_release(@ptrCast(@alignCast(ctx)));
        }

        fn descCopyHelper(dst: *anyopaque, src: *anyopaque) callconv(.c) void {
            const real_dst: *Context = @ptrCast(@alignCast(dst));
            const real_src: *Context = @ptrCast(@alignCast(src));
            inline for (captures_info.fields) |field| {
                if (field.type == c.id) {
                    _Block_object_assign(
                        @ptrCast(&@field(real_dst, field.name)),
                        @field(real_src, field.name),
                        .object,
                    );
                }
            }
        }

        fn descDisposeHelper(src: *anyopaque) callconv(.c) void {
            const real_src: *Context = @ptrCast(@alignCast(src));
            inline for (captures_info.fields) |field| {
                if (field.type == c.id) {
                    _Block_object_dispose(
                        @field(real_src, field.name),
                        .object,
                    );
                }
            }
        }

        fn FnType(comptime ContextArg: type) type {
            var param_types: [Args.len + 1]type = undefined;
            param_types[0] = *const ContextArg;
            for (Args, 1..) |Arg, i| param_types[i] = Arg;

            return @Fn(&param_types, &@splat(.{}), Return, .{ .@"callconv" = .c });
        }
    };
}

fn BlockContext(comptime Captures: type, comptime InvokeFn: type) type {
    const captures_info = @typeInfo(Captures).@"struct";
    var fields: [captures_info.fields.len + 5]std.builtin.Type.StructField = undefined;
    fields[0] = .{
        .name = "isa",
        .type = ?*anyopaque,
        .default_value_ptr = null,
        .is_comptime = false,
        .alignment = @alignOf(*anyopaque),
    };
    fields[1] = .{
        .name = "flags",
        .type = BlockFlags,
        .default_value_ptr = null,
        .is_comptime = false,
        .alignment = @alignOf(c_int),
    };
    fields[2] = .{
        .name = "reserved",
        .type = c_int,
        .default_value_ptr = null,
        .is_comptime = false,
        .alignment = @alignOf(c_int),
    };
    fields[3] = .{
        .name = "invoke",
        .type = *const InvokeFn,
        .default_value_ptr = null,
        .is_comptime = false,
        .alignment = @typeInfo(*const InvokeFn).pointer.alignment,
    };
    fields[4] = .{
        .name = "descriptor",
        .type = *const Descriptor,
        .default_value_ptr = null,
        .is_comptime = false,
        .alignment = @alignOf(*Descriptor),
    };

    for (captures_info.fields, 5..) |capture, i| {
        switch (capture.type) {
            comptime_int => @compileError("capture should not be a comptime_int, try using @as"),
            comptime_float => @compileError("capture should not be a comptime_float, try using @as"),
            else => {},
        }
        fields[i] = .{ .name = capture.name, .type = capture.type, .default_value_ptr = null, .is_comptime = false, .alignment = capture.alignment };
    }

    var field_names: [fields.len][]const u8 = undefined;
    var field_types: [fields.len]type = undefined;
    var field_attrs: [fields.len]std.builtin.Type.StructField.Attributes = undefined;
    for (fields, 0..) |field, i| {
        field_names[i] = field.name;
        field_types[i] = field.type;
        field_attrs[i] = .{ .@"align" = field.alignment };
    }

    return @Struct(.@"extern", null, &field_names, &field_types, &field_attrs);
}

const NSConcreteStackBlock = @extern(*opaque {}, .{ .name = "_NSConcreteStackBlock" });
const NSConcreteMallocBlock = @extern(*opaque {}, .{ .name = "_NSConcreteMallocBlock" });

const BlockFieldFlags = enum(c_int) {
    object = 3,
    block = 7,
    byref = 8,
    weak = 16,
    byref_caller = 128,
};

extern "c" fn _Block_copy(src: *const anyopaque) callconv(.c) ?*anyopaque;
extern "c" fn _Block_release(src: *const anyopaque) callconv(.c) void;
extern "c" fn _Block_object_assign(dst: *anyopaque, src: *const anyopaque, flag: BlockFieldFlags) void;
extern "c" fn _Block_object_dispose(src: *const anyopaque, flag: BlockFieldFlags) void;

const Descriptor = extern struct {
    reserved: c_ulong = 0,
    size: c_ulong,
    copy_helper: *const fn (dst: *anyopaque, src: *anyopaque) callconv(.c) void,
    dispose_helper: *const fn (src: *anyopaque) callconv(.c) void,
    signature: ?[*:0]const u8,
};

const BlockFlags = packed struct(c_int) {
    _unused: u23 = 0,
    noescape: bool = false,
    _unused_2: u1 = 0,
    copy_dispose: bool = false,
    ctor: bool = false,
    _unused_3: u1 = 0,
    global: bool = false,
    stret: bool = false,
    signature: bool = false,
    _unused_4: u1 = 0,
};
