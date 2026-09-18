//! Direct method and IMP invocation engine.
//!
//! Provides `Method.invoke` via `method_invoke` and direct `callImp` execution,
//! reusing the unified argument normalization and return conversion pipeline.

const raw = @import("raw");
const wrapper = @import("internal").wrapper;
const receiver_mod = @import("receiver.zig");
const selector_mod = @import("selector.zig");
const arguments_mod = @import("arguments.zig");
const returns_mod = @import("returns.zig");
const validation = @import("validation.zig");
const function_type = @import("function_type.zig");
const dispatch = @import("dispatch.zig");
const call_mod = @import("internal/call.zig");

// Reuses unified argument and return normalization for method and IMP calls.

/// Normalizes a method value to a non-null `*raw.objc_method`: a raw handle
/// directly (null panics), or an explicit wrapper exposing
/// `toRaw() -> raw.Method` (e.g. runtime.Method, null panics).
/// Method metadata descriptors are intentionally not a `WrapperKind`.
fn methodToRaw(method: anytype) *raw.objc_method {
    const T = @TypeOf(method);
    if (T == raw.Method) return method orelse @panic("invoke() received null Method");
    if (T == *raw.objc_method) return method;
    // NOTE: explicit `comptime` below is load-bearing (see NOTE in abi/type.zig).
    // The toRaw shape check ignores calling convention (`inline` included):
    // single (self) parameter returning exactly raw.Method.
    if (comptime @typeInfo(T) == .@"struct" and @hasDecl(T, "toRaw")) {
        const FT = @typeInfo(@TypeOf(@field(T, "toRaw")));
        if (FT == .@"fn" and FT.@"fn".params.len == 1 and FT.@"fn".return_type == raw.Method) {
            return method.toRaw() orelse @panic("invoke() wrapper returned null Method");
        }
    }
    @compileError("invoke() requires a raw.Method or a wrapper exposing toRaw() -> raw.Method, found: " ++ @typeName(T));
}

/// Normalizes an IMP value to a non-null raw function pointer: a raw
/// handle directly (null panics), or a non-optional `.imp`-kind wrapper.
const RawImp = @typeInfo(raw.IMP).optional.child;

fn impToRaw(imp: anytype) RawImp {
    const T = @TypeOf(imp);
    if (T == raw.IMP) return imp orelse @panic("callImp() received null IMP");
    // NOTE: explicit `comptime` below is load-bearing (see NOTE in abi/type.zig).
    if (comptime wrapper.isObjCWrapper(T) and wrapper.wrapperKind(T) == .imp and @typeInfo(T) != .optional) return imp.ptr;
    @compileError("callImp() requires a raw.IMP or an .imp-kind wrapper, found: " ++ @typeName(T));
}

/// Directly invokes `method` on `receiver` with tuple `args`.
pub inline fn invoke(
    method: anytype,
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

    const call_args = .{ receiver_raw, methodToRaw(method) } ++ abi_args;
    const raw_result = call_mod.call(Fn, fn_ptr, call_args);

    return returns_mod.fromAbi(Return, raw_result);
}

/// Invokes a direct implementation function pointer (`Imp`) on `receiver` with `selector` and `args`.
pub inline fn callImp(
    comptime Return: type,
    imp: anytype,
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
    const fn_ptr: *const anyopaque = @ptrCast(impToRaw(imp));

    const call_args = .{ receiver_raw, selector_raw } ++ abi_args;
    const raw_result = call_mod.call(Fn, fn_ptr, call_args);

    return returns_mod.fromAbi(Return, raw_result);
}
