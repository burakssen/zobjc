//! Direct method and IMP invocation engine.
//!
//! Provides `Method.invoke` via `method_invoke` and direct `callImp` execution,
//! reusing the unified argument normalization and return conversion pipeline.

const std = @import("std");
const raw = @import("../raw/root.zig");
const runtime = @import("../runtime/root.zig");
const Method = runtime.Method;
const Imp = runtime.Imp;
const receiver_mod = @import("receiver.zig");
const selector_mod = @import("selector.zig");
const arguments_mod = @import("arguments.zig");
const returns_mod = @import("returns.zig");
const validation = @import("validation.zig");
const function_type = @import("function_type.zig");
const dispatch = @import("dispatch.zig");
const call_mod = @import("internal/call.zig");

// ponytail: Reuses unified argument and return normalization for method and IMP calls.

/// Directly invokes `method` on `receiver` with tuple `args`.
pub inline fn invoke(
    method: Method,
    comptime Return: type,
    receiver: anytype,
    args: anytype,
) Return {
    validation.assertValidReturn(Return);
    validation.assertValidArguments(@TypeOf(args));
    receiver_mod.assertValidReceiver(@TypeOf(receiver));

    const receiver_raw = receiver_mod.toRaw(receiver);
    const abi_args = arguments_mod.normalizeTupleValues(args);

    const AbiReturn = returns_mod.AbiReturnType(Return);
    const AbiArgsTuple = @TypeOf(abi_args);

    const Fn = function_type.MethodInvokeFunctionType(AbiReturn, AbiArgsTuple);
    const fn_ptr = dispatch.methodInvokePointer(AbiReturn);

    const call_args = .{ receiver_raw, method.ptr } ++ abi_args;
    const raw_result = call_mod.call(Fn, fn_ptr, call_args);

    return returns_mod.fromAbi(Return, raw_result);
}

/// Invokes a direct implementation function pointer (`Imp`) on `receiver` with `selector` and `args`.
pub inline fn callImp(
    comptime Return: type,
    imp: Imp,
    receiver: anytype,
    selector: anytype,
    args: anytype,
) Return {
    validation.assertValidReturn(Return);
    validation.assertValidArguments(@TypeOf(args));
    receiver_mod.assertValidReceiver(@TypeOf(receiver));
    selector_mod.assertValidSelector(@TypeOf(selector));

    const receiver_raw = receiver_mod.toRaw(receiver);
    const selector_raw = selector_mod.toRaw(selector);
    const abi_args = arguments_mod.normalizeTupleValues(args);

    const AbiReturn = returns_mod.AbiReturnType(Return);
    const AbiArgsTuple = @TypeOf(abi_args);

    const Fn = function_type.ImpFunctionType(AbiReturn, AbiArgsTuple);
    const fn_ptr: *const anyopaque = @ptrCast(imp.ptr);

    const call_args = .{ receiver_raw, selector_raw } ++ abi_args;
    const raw_result = call_mod.call(Fn, fn_ptr, call_args);

    return returns_mod.fromAbi(Return, raw_result);
}
