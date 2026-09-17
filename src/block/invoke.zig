//! Typed Block invocation engine.
//!
//! Invokes an Apple Block's function pointer directly using argument normalization
//! and return decoding.

const std = @import("std");
const raw = @import("raw");
const convert = @import("internal/convert.zig");
const validation = @import("validation.zig");
const owned_mod = @import("owned.zig");
const block_mod = @import("block.zig");
const Object = @import("runtime").Object;
const getClass = @import("runtime").getClass;

/// Invokes a Block pointer directly with typed arguments.
pub fn callBlock(
    comptime Signature: type,
    block_ptr: *raw.blocks.Block_layout,
    args: anytype,
) ReturnType(Signature) {
    const fn_info = @typeInfo(Signature).@"fn";
    const RetType = fn_info.return_type orelse void;

    const ArgsType = @TypeOf(args);
    const args_info = @typeInfo(ArgsType);
    if (args_info != .@"struct" or !args_info.@"struct".is_tuple) {
        @compileError("Block arguments must be passed as an anonymous tuple, e.g. .{arg1, arg2}");
    }
    if (args.len != fn_info.params.len) {
        @compileError(std.fmt.comptimePrint(
            "Block signature expects {d} arguments, but received {d}",
            .{ fn_info.params.len, args.len },
        ));
    }

    const InvokeFn = MakeInvokeFn(Signature);
    const invoke_ptr = block_ptr.invoke orelse @panic("attempted to call Block with null invoke pointer");
    const invoke_fn: *const InvokeFn = @ptrCast(@alignCast(invoke_ptr));

    // Normalize arguments to ABI representations
    const abi_args = normalizeArgs(Signature, args);

    if (RetType == void) {
        @call(.auto, invoke_fn, .{block_ptr} ++ abi_args);
        return;
    } else {
        const raw_res = @call(.auto, invoke_fn, .{block_ptr} ++ abi_args);
        return convert.fromAbi(RetType, raw_res);
    }
}

pub fn ReturnType(comptime Signature: type) type {
    const fn_info = @typeInfo(Signature).@"fn";
    return fn_info.return_type orelse void;
}

fn MakeInvokeFn(comptime Signature: type) type {
    const fn_info = @typeInfo(Signature).@"fn";
    const RetType = fn_info.return_type orelse void;
    const AbiRet = convert.AbiReturnType(RetType);

    var param_types: [fn_info.params.len + 1]type = undefined;
    param_types[0] = *anyopaque; // hidden block pointer

    for (fn_info.params, 1..) |param, i| {
        param_types[i] = convert.AbiArgumentType(param.type.?);
    }

    return @Fn(&param_types, &@splat(.{}), AbiRet, .{ .@"callconv" = .c });
}

fn normalizeArgs(comptime Signature: type, args: anytype) TupleOfAbiArgs(Signature) {
    const fn_info = @typeInfo(Signature).@"fn";
    var result: TupleOfAbiArgs(Signature) = undefined;

    inline for (fn_info.params, 0..) |param, i| {
        const PT = param.type.?;
        result[i] = convert.toAbi(args[i]);
        _ = PT;
    }

    return result;
}

fn TupleOfAbiArgs(comptime Signature: type) type {
    const fn_info = @typeInfo(Signature).@"fn";
    var types: [fn_info.params.len]type = undefined;
    for (fn_info.params, 0..) |param, i| {
        types[i] = convert.AbiArgumentType(param.type.?);
    }
    return std.meta.Tuple(&types);
}

extern "c" fn make_int_multiplier_block(multiplier: c_int) *anyopaque;
extern "c" fn make_object_holder_block(obj: raw.id) *anyopaque;
extern "c" fn make_byref_counter_block(initial: c_int) *anyopaque;
extern "c" fn invoke_int_block(block: *anyopaque, val: c_int) c_int;
extern "c" fn invoke_object_block(block: *anyopaque, val: raw.id) raw.id;
extern "c" fn invoke_two_arg_block(block: *anyopaque, x: c_int, y: c_int) c_int;

test "invocation: Zig calling Zig block" {
    var blk = try owned_mod.OwnedBlock(fn (c_int, c_int) c_int).fromFunction(struct {
        fn multiply(a: c_int, b: c_int) c_int {
            return a * b;
        }
    }.multiply);
    defer blk.deinit();

    try std.testing.expectEqual(@as(c_int, 42), blk.call(.{ 6, 7 }));
}

test "invocation: Zig calling Clang blocks" {
    const raw_int_blk = make_int_multiplier_block(4);
    defer raw.blocks._Block_release(raw_int_blk);

    const int_blk = block_mod.Block(fn (c_int) c_int).fromRaw(@ptrCast(@alignCast(raw_int_blk)));
    try std.testing.expectEqual(@as(c_int, 40), int_blk.call(.{10}));

    const NSObject = getClass("NSObject").?;
    const obj = NSObject.send(Object, "alloc", .{}).send(Object, "init", .{});
    defer obj.send(void, "release", .{});

    const raw_obj_blk = make_object_holder_block(obj.toRaw());
    defer raw.blocks._Block_release(raw_obj_blk);

    const obj_blk = block_mod.Block(fn () ?Object).fromRaw(@ptrCast(@alignCast(raw_obj_blk)));
    const held_obj = obj_blk.call(.{});
    try std.testing.expect(held_obj != null);
    try std.testing.expectEqual(obj.toRaw(), held_obj.?.toRaw());

    const raw_byref_blk = make_byref_counter_block(10);
    defer raw.blocks._Block_release(raw_byref_blk);

    const byref_blk = block_mod.Block(fn (c_int) c_int).fromRaw(@ptrCast(@alignCast(raw_byref_blk)));
    try std.testing.expectEqual(@as(c_int, 15), byref_blk.call(.{5}));
    try std.testing.expectEqual(@as(c_int, 25), byref_blk.call(.{10}));
}

test "invocation: Clang calling Zig blocks" {
    var int_blk = try owned_mod.OwnedBlock(fn (c_int) c_int).fromFunction(struct {
        fn square(x: c_int) c_int {
            return x * x;
        }
    }.square);
    defer int_blk.deinit();
    try std.testing.expectEqual(@as(c_int, 64), invoke_int_block(@ptrCast(int_blk.borrow().toRaw()), 8));

    var add_blk = try owned_mod.OwnedBlock(fn (c_int, c_int) c_int).fromFunction(struct {
        fn add(x: c_int, y: c_int) c_int {
            return x + y;
        }
    }.add);
    defer add_blk.deinit();
    try std.testing.expectEqual(@as(c_int, 125), invoke_two_arg_block(@ptrCast(add_blk.borrow().toRaw()), 100, 25));

    const NSObject = getClass("NSObject").?;
    const obj = NSObject.send(Object, "alloc", .{}).send(Object, "init", .{});
    defer obj.send(void, "release", .{});

    var echo_blk = try owned_mod.OwnedBlock(fn (?Object) ?Object).fromFunction(struct {
        fn echo(in_obj: ?Object) ?Object {
            return in_obj;
        }
    }.echo);
    defer echo_blk.deinit();

    const ret_id = invoke_object_block(@ptrCast(echo_blk.borrow().toRaw()), obj.toRaw());
    try std.testing.expectEqual(obj.toRaw(), ret_id);
}
