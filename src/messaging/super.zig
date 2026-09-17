//! Superclass message dispatch engine (Super2 semantics).
//!
//! Dispatches messages to a superclass starting lookup at `current_class->superclass`.

const std = @import("std");
const testing = std.testing;
const objc = @import("zobjc");
const raw = @import("raw");
const runtime = @import("runtime");
const Class = runtime.Class;
const receiver_mod = @import("receiver.zig");
const selector_mod = @import("selector.zig");
const arguments_mod = @import("arguments.zig");
const returns_mod = @import("returns.zig");
const validation = @import("validation.zig");
const function_type = @import("function_type.zig");
const dispatch = @import("dispatch.zig");
const call_mod = @import("internal/call.zig");

// Implements modern Super2 semantics without off-by-one superclass calculations.

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

var g_base_class: objc.Class = undefined;
var g_child_class: objc.Class = undefined;
var g_grandchild_class: objc.Class = undefined;

fn baseIdentify(self: raw.id, _cmd: raw.SEL) callconv(.c) [*:0]const u8 {
    _ = self;
    _ = _cmd;
    return "Base";
}

fn childIdentify(self: raw.id, _cmd: raw.SEL) callconv(.c) [*:0]const u8 {
    _ = self;
    _ = _cmd;
    return "Child";
}

fn childSuperIdentify(self: raw.id, _cmd: raw.SEL) callconv(.c) [*:0]const u8 {
    _ = _cmd;
    const obj = objc.Object.fromRawNonNull(self.?);
    return objc.sendSuper([*:0]const u8, obj, g_child_class, "identify", .{});
}

fn grandchildIdentify(self: raw.id, _cmd: raw.SEL) callconv(.c) [*:0]const u8 {
    _ = self;
    _ = _cmd;
    return "Grandchild";
}

fn grandchildSuperIdentify(self: raw.id, _cmd: raw.SEL) callconv(.c) [*:0]const u8 {
    _ = _cmd;
    const obj = objc.Object.fromRawNonNull(self.?);
    return objc.sendSuper([*:0]const u8, obj, g_grandchild_class, "identify", .{});
}

test "super: 3-level class hierarchy with Super2 lookup" {
    const NSObject = objc.getClass("NSObject").?;

    const base_pair = objc.allocateClassPair(NSObject, "SuperTestBase").?;
    _ = raw.runtime.class_addMethod(
        base_pair.ptr,
        objc.sel("identify").toRaw(),
        @ptrCast(&baseIdentify),
        "r*@:",
    );
    g_base_class = base_pair;
    objc.registerClassPair(base_pair);
    defer objc.disposeClassPair(g_base_class);

    const child_pair = objc.allocateClassPair(g_base_class, "SuperTestChild").?;
    _ = raw.runtime.class_addMethod(
        child_pair.ptr,
        objc.sel("identify").toRaw(),
        @ptrCast(&childIdentify),
        "r*@:",
    );
    _ = raw.runtime.class_addMethod(
        child_pair.ptr,
        objc.sel("superIdentify").toRaw(),
        @ptrCast(&childSuperIdentify),
        "r*@:",
    );
    g_child_class = child_pair;
    objc.registerClassPair(child_pair);
    defer objc.disposeClassPair(g_child_class);

    const grandchild_pair = objc.allocateClassPair(g_child_class, "SuperTestGrandchild").?;
    _ = raw.runtime.class_addMethod(
        grandchild_pair.ptr,
        objc.sel("identify").toRaw(),
        @ptrCast(&grandchildIdentify),
        "r*@:",
    );
    _ = raw.runtime.class_addMethod(
        grandchild_pair.ptr,
        objc.sel("superIdentify").toRaw(),
        @ptrCast(&grandchildSuperIdentify),
        "r*@:",
    );
    g_grandchild_class = grandchild_pair;
    objc.registerClassPair(grandchild_pair);
    defer objc.disposeClassPair(g_grandchild_class);

    const child_obj = objc.send(objc.Object, g_child_class, "new", .{});
    defer child_obj.send(void, "release", .{});
    const grandchild_obj = objc.send(objc.Object, g_grandchild_class, "new", .{});
    defer grandchild_obj.send(void, "release", .{});

    try testing.expectEqualStrings("Child", std.mem.span(objc.send([*:0]const u8, child_obj, "identify", .{})));
    try testing.expectEqualStrings("Grandchild", std.mem.span(objc.send([*:0]const u8, grandchild_obj, "identify", .{})));

    const child_super = objc.send([*:0]const u8, child_obj, "superIdentify", .{});
    try testing.expectEqualStrings("Base", std.mem.span(child_super));

    const grandchild_super = objc.send([*:0]const u8, grandchild_obj, "superIdentify", .{});
    try testing.expectEqualStrings("Child", std.mem.span(grandchild_super));
}

test "differential: super dispatch matches native Objective-C super behavior" {
    const ABISubclass = objc.getClass("ABISubclass").?;
    const sub = objc.send(objc.Object, ABISubclass, "alloc", .{}).send(objc.Object, "init", .{});
    defer sub.send(void, "dealloc", .{});

    const overridden = sub.send(c_int, "echoInt:", .{@as(c_int, 5)});
    try testing.expectEqual(@as(c_int, 50), overridden);

    const native_super = sub.send(c_int, "callSuperEcho:", .{@as(c_int, 5)});
    try testing.expectEqual(@as(c_int, 5), native_super);

    const zig_super = objc.sendSuper(c_int, sub, ABISubclass, "echoInt:", .{@as(c_int, 5)});
    try testing.expectEqual(@as(c_int, 5), zig_super);
}
