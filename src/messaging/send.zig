//! Primary Objective-C message dispatch engine.
//!
//! Exposes `send(Return, receiver, selector, args)` with full compile-time validation,
//! ABI classification, and zero heap allocation.

const receiver_mod = @import("receiver.zig");
const selector_mod = @import("selector.zig");
const arguments_mod = @import("arguments.zig");
const returns_mod = @import("returns.zig");
const validation = @import("validation.zig");
const function_type = @import("function_type.zig");
const dispatch = @import("dispatch.zig");
const call_mod = @import("internal/call.zig");

comptime {
    @setEvalBranchQuota(10000);
}

// Lean single-flow message dispatch pipeline.

/// Sends an Objective-C message to `receiver` with selector `selector` and tuple `args`.
///
/// Example:
/// ```zig
/// const count = objc.send(usize, array, "count", .{});
/// const obj = objc.send(?objc.Object, array, "objectAtIndex:", .{@as(usize, 0)});
/// ```
pub inline fn send(
    comptime Return: type,
    receiver: anytype,
    selector: anytype,
    args: anytype,
) Return {
    @setEvalBranchQuota(10000);

    // 1. Compile-time validations
    validation.assertValidReturn(Return);
    validation.assertValidArguments(@TypeOf(args));
    receiver_mod.assertValidReceiver(@TypeOf(receiver));
    selector_mod.assertValidSelector(@TypeOf(selector));

    // Colon count verification for comptime string literals
    const SelType = @TypeOf(selector);
    if (comptime (@typeInfo(SelType) == .pointer and @typeInfo(@typeInfo(SelType).pointer.child) == .array and @typeInfo(@typeInfo(SelType).pointer.child).array.child == u8)) {
        const arg_count = @typeInfo(@TypeOf(args)).@"struct".fields.len;
        selector_mod.validateColonCount(selector, arg_count);
    }

    // 2. Normalization
    const receiver_raw = receiver_mod.toRaw(receiver);
    const selector_raw = selector_mod.toRaw(selector);
    const abi_args = arguments_mod.normalizeTupleValues(args);

    const AbiReturn = returns_mod.AbiReturnType(Return);
    const AbiArgsTuple = @TypeOf(abi_args);

    // 3. Exact C function type construction
    const Fn = function_type.MessageFunctionType(AbiReturn, AbiArgsTuple);

    // 4. Runtime messenger selection
    const fn_ptr = dispatch.messagePointer(AbiReturn);

    // 5. Invocation
    const call_args = .{ receiver_raw, selector_raw } ++ abi_args;
    const raw_result = call_mod.call(Fn, fn_ptr, call_args);

    // 6. Return conversion
    return returns_mod.fromAbi(Return, raw_result);
}
