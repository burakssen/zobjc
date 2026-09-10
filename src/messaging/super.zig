//! Superclass message dispatch engine (Super2 semantics).
//!
//! Dispatches messages to a superclass starting lookup at `current_class->superclass`.

const std = @import("std");
const raw = @import("../raw/root.zig");
const runtime = @import("../runtime/root.zig");
const Class = runtime.Class;
const receiver_mod = @import("receiver.zig");
const selector_mod = @import("selector.zig");
const arguments_mod = @import("arguments.zig");
const returns_mod = @import("returns.zig");
const validation = @import("validation.zig");
const function_type = @import("function_type.zig");
const dispatch = @import("dispatch.zig");
const call_mod = @import("internal/call.zig");

// ponytail: Implements modern Super2 semantics without off-by-one superclass calculations.

/// Sends a message to the superclass implementation of `receiver`.
///
/// `current_class` defines the class where the current method is executing.
/// Lookup begins at `current_class.superclass()`.
pub inline fn sendSuper(
    comptime Return: type,
    receiver: anytype,
    current_class: anytype,
    selector: anytype,
    args: anytype,
) Return {
    // 1. Compile-time validations
    validation.assertValidReturn(Return);
    validation.assertValidArguments(@TypeOf(args));
    receiver_mod.assertValidReceiver(@TypeOf(receiver));
    selector_mod.assertValidSelector(@TypeOf(selector));

    const SelType = @TypeOf(selector);
    if (comptime (@typeInfo(SelType) == .pointer and @typeInfo(@typeInfo(SelType).pointer.child) == .array and @typeInfo(@typeInfo(SelType).pointer.child).array.child == u8)) {
        const arg_count = @typeInfo(@TypeOf(args)).@"struct".fields.len;
        selector_mod.validateColonCount(selector, arg_count);
    }

    // 2. Normalization
    const receiver_raw = receiver_mod.toRaw(receiver);
    const selector_raw = selector_mod.toRaw(selector);
    const abi_args = arguments_mod.normalizeTupleValues(args);

    // Normalize current_class to raw pointer
    const class_raw: ?*raw.objc_class = switch (@TypeOf(current_class)) {
        Class => current_class.ptr,
        ?Class => if (current_class) |c| c.ptr else null,
        raw.Class => current_class,
        *raw.objc_class => current_class,
        else => blk: {
            const CurT = @TypeOf(current_class);
            if (@typeInfo(CurT) == .@"struct" and @hasField(CurT, "ptr")) {
                break :blk @ptrCast(current_class.ptr);
            }
            @compileError("current_class must be of type objc.Class, found: " ++ @typeName(CurT));
        },
    };

    var super_struct: raw.objc_super = .{
        .receiver = receiver_raw,
        .super_class = @ptrCast(class_raw),
    };

    const AbiReturn = returns_mod.AbiReturnType(Return);
    const AbiArgsTuple = @TypeOf(abi_args);

    // 3. Exact C function type construction
    const Fn = function_type.SuperFunctionType(AbiReturn, AbiArgsTuple);

    // 4. Runtime messenger selection
    const fn_ptr = dispatch.superPointer(AbiReturn);

    // 5. Invocation
    const call_args = .{ &super_struct, selector_raw } ++ abi_args;
    const raw_result = call_mod.call(Fn, fn_ptr, call_args);

    // 6. Return conversion
    return returns_mod.fromAbi(Return, raw_result);
}

/// Sends a message using legacy objc_msgSendSuper semantics (lookup starts at superclass directly).
pub inline fn sendSuperV1(
    comptime Return: type,
    receiver: anytype,
    superclass: anytype,
    selector: anytype,
    args: anytype,
) Return {
    validation.assertValidReturn(Return);
    validation.assertValidArguments(@TypeOf(args));
    receiver_mod.assertValidReceiver(@TypeOf(receiver));
    selector_mod.assertValidSelector(@TypeOf(selector));

    const SelType = @TypeOf(selector);
    if (comptime (@typeInfo(SelType) == .pointer and @typeInfo(@typeInfo(SelType).pointer.child) == .array and @typeInfo(@typeInfo(SelType).pointer.child).array.child == u8)) {
        const arg_count = @typeInfo(@TypeOf(args)).@"struct".fields.len;
        selector_mod.validateColonCount(selector, arg_count);
    }

    const receiver_raw = receiver_mod.toRaw(receiver);
    const selector_raw = selector_mod.toRaw(selector);
    const abi_args = arguments_mod.normalizeTupleValues(args);

    const class_raw: ?*raw.objc_class = switch (@TypeOf(superclass)) {
        Class => superclass.ptr,
        ?Class => if (superclass) |c| c.ptr else null,
        raw.Class => superclass,
        *raw.objc_class => superclass,
        else => blk: {
            const CurT = @TypeOf(superclass);
            if (@typeInfo(CurT) == .@"struct" and @hasField(CurT, "ptr")) {
                break :blk @ptrCast(superclass.ptr);
            }
            @compileError("superclass must be of type objc.Class, found: " ++ @typeName(CurT));
        },
    };

    var super_struct: raw.objc_super = .{
        .receiver = receiver_raw,
        .super_class = @ptrCast(class_raw),
    };

    const AbiReturn = returns_mod.AbiReturnType(Return);
    const AbiArgsTuple = @TypeOf(abi_args);

    const Fn = function_type.SuperFunctionType(AbiReturn, AbiArgsTuple);
    const fn_ptr = dispatch.superV1Pointer(AbiReturn);

    const call_args = .{ &super_struct, selector_raw } ++ abi_args;
    const raw_result = call_mod.call(Fn, fn_ptr, call_args);

    return returns_mod.fromAbi(Return, raw_result);
}
