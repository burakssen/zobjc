//! Direct method and IMP invocation engine.
//!
//! Provides `Method.invoke` via `method_invoke` and direct `callImp` execution,
//! reusing the unified argument normalization and return conversion pipeline.

const std = @import("std");
const testing = std.testing;
const objc = @import("zobjc");
const raw = @import("raw");
const runtime = @import("runtime");
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

// Reuses unified argument and return normalization for method and IMP calls.

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

test "invoke: Method.invoke matches objc.send" {
    const ABIFixture = objc.getClass("ABIFixture").?;
    const inst = objc.send(objc.Object, ABIFixture, "new", .{});
    defer inst.send(void, "release", .{});

    const method = ABIFixture.instanceMethod(objc.sel("returnInt")).?;
    const val = method.invoke(c_int, inst, .{});
    try testing.expectEqual(@as(c_int, 42), val);

    const send_val = objc.send(c_int, inst, "returnInt", .{});
    try testing.expectEqual(send_val, val);
}

test "invoke: callImp directly invokes IMP function pointer" {
    const ABIFixture = objc.getClass("ABIFixture").?;
    const inst = objc.send(objc.Object, ABIFixture, "new", .{});
    defer inst.send(void, "release", .{});

    const method = ABIFixture.instanceMethod(objc.sel("returnInt")).?;
    const imp = method.implementation();
    const val = objc.callImp(c_int, imp, inst, objc.sel("returnInt"), .{});
    try testing.expectEqual(@as(c_int, 42), val);
}

test "differential: Method.invoke agrees with ordinary message dispatch" {
    const ABIFixture = objc.getClass("ABIFixture").?;
    const fixture = objc.send(objc.Object, ABIFixture, "alloc", .{}).send(objc.Object, "init", .{});
    defer fixture.send(void, "dealloc", .{});

    const method = ABIFixture.instanceMethod(objc.sel("echoInt:")).?;
    const res1 = fixture.send(c_int, "echoInt:", .{@as(c_int, 123)});
    const res2 = method.invoke(c_int, fixture, .{@as(c_int, 123)});

    try testing.expectEqual(res1, res2);
    try testing.expectEqual(@as(c_int, 123), res2);
}
