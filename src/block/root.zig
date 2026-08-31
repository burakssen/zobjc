//! Objective-C Blocks implementation.
//!
//! Provides the Block type constructor for stack-allocated and copied Objective-C blocks.

const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const raw = @import("../raw/root.zig");
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
        const descriptor: raw.blocks.BlockDescriptor = .{
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
            ctx.isa = raw.blocks._NSConcreteStackBlock;
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
            const copied = raw.blocks._Block_copy(@ptrCast(@alignCast(ctx))) orelse
                return error.OutOfMemory;
            return @ptrCast(@alignCast(copied));
        }

        /// Release a copied block context. This must only be called on
        /// contexts returned by the `copy` function.
        pub fn release(ctx: *const Context) void {
            assert(@intFromPtr(ctx.isa) == @intFromPtr(raw.blocks._NSConcreteMallocBlock));
            raw.blocks._Block_release(@ptrCast(@alignCast(ctx)));
        }

        fn descCopyHelper(dst: *anyopaque, src: *anyopaque) callconv(.c) void {
            const real_dst: *Context = @ptrCast(@alignCast(dst));
            const real_src: *Context = @ptrCast(@alignCast(src));
            inline for (captures_info.fields) |field| {
                if (field.type == raw.id) {
                    raw.blocks._Block_object_assign(
                        @ptrCast(&@field(real_dst, field.name)),
                        @ptrCast(@field(real_src, field.name)),
                        .object,
                    );
                }
            }
        }

        fn descDisposeHelper(src: *anyopaque) callconv(.c) void {
            const real_src: *Context = @ptrCast(@alignCast(src));
            inline for (captures_info.fields) |field| {
                if (field.type == raw.id) {
                    raw.blocks._Block_object_dispose(
                        @ptrCast(@field(real_src, field.name)),
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
        .type = raw.blocks.BlockFlags,
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
        .type = *const raw.blocks.BlockDescriptor,
        .default_value_ptr = null,
        .is_comptime = false,
        .alignment = @alignOf(*raw.blocks.BlockDescriptor),
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
