//! Typed Block invocation engine.
//!
//! Invokes an Apple Block's function pointer directly using Phase 6 argument normalization
//! and return decoding.

const std = @import("std");
const raw = @import("../raw/root.zig");
const convert = @import("internal/convert.zig");
const validation = @import("validation.zig");

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
