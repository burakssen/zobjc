//! Return type normalization and conversion for Objective-C message dispatch.
//!
//! Maps high-level return types to raw C ABI types and safely converts raw returns
//! into user-requested types, enforcing non-null invariants.

const std = @import("std");
const testing = std.testing;
const raw = @import("raw");
const runtime = @import("runtime");
const wrapper = @import("internal").wrapper;
const Object = runtime.Object;
const Class = runtime.Class;
const Selector = runtime.Selector;
const Imp = runtime.Imp;

// Explicit type mapping matching ABI classification requirements with zero allocation.

/// Maps a user-requested return type `T` to its low-level C ABI return type.
pub fn AbiReturnType(comptime T: type) type {
    if (T == void) return void;

    // 1. High-level runtime handles
    if (T == Object or T == ?Object) return raw.id;
    if (T == Class or T == ?Class) return raw.Class;
    if (T == Selector or T == ?Selector) return raw.SEL;
    if (T == Imp or T == ?Imp) return raw.IMP;

    if (@typeInfo(T) == .@"struct" and wrapper.isObjCWrapper(T)) {
        return switch (wrapper.wrapperKind(T)) {
            .object => raw.id,
            .class => raw.Class,
            .selector => raw.SEL,
            .imp => raw.IMP,
            .none => unreachable,
        };
    }
    if (@typeInfo(T) == .optional and wrapper.isObjCWrapper(T)) {
        return switch (wrapper.wrapperKind(T)) {
            .object => raw.id,
            .class => raw.Class,
            .selector => raw.SEL,
            .imp => raw.IMP,
            .none => unreachable,
        };
    }

    // 2. Raw handles
    if (T == raw.id or T == raw.Class or T == raw.SEL or T == raw.IMP) return T;

    // 3. Enums: map to tag type
    if (@typeInfo(T) == .@"enum") {
        return @typeInfo(T).@"enum".tag_type;
    }

    // 4. All other C-ABI compatible types (scalars, pointers, extern structs, unions)
    return T;
}

/// Converts a raw C ABI return value to the user-requested `Return` type.
pub inline fn fromAbi(comptime Return: type, raw_val: AbiReturnType(Return)) Return {
    if (comptime Return == void) return {};

    if (comptime Return == ?Object) {
        return Object.fromRaw(raw_val);
    } else if (comptime Return == Object) {
        return Object.fromRaw(raw_val) orelse @panic("Objective-C message returned nil for non-null Object return type");
    } else if (comptime Return == ?Class) {
        return Class.fromRaw(raw_val);
    } else if (comptime Return == Class) {
        return Class.fromRaw(raw_val) orelse @panic("Objective-C message returned nil for non-null Class return type");
    } else if (comptime Return == ?Selector) {
        return Selector.fromRaw(raw_val);
    } else if (comptime Return == Selector) {
        return Selector.fromRaw(raw_val) orelse @panic("Objective-C message returned nil for non-null Selector return type");
    } else if (comptime Return == ?Imp) {
        return Imp.fromRaw(raw_val);
    } else if (comptime Return == Imp) {
        return Imp.fromRaw(raw_val) orelse @panic("Objective-C message returned nil for non-null Imp return type");
    } else if (comptime @typeInfo(Return) == .optional and wrapper.isObjCWrapper(Return)) {
        const Child = @typeInfo(Return).optional.child;
        if (raw_val) |p| {
            return Child{ .ptr = @ptrCast(p) };
        }
        return null;
    } else if (comptime @typeInfo(Return) == .@"struct" and wrapper.isObjCWrapper(Return)) {
        const p = raw_val orelse @panic("Objective-C message returned nil for non-null return type");
        return Return{ .ptr = @ptrCast(p) };
    } else if (comptime @typeInfo(Return) == .@"enum") {
        return @enumFromInt(raw_val);
    } else {
        return raw_val;
    }
}

const TestEnum = enum(c_int) {
    alpha = 1,
    beta = 2,
};

const Rect = extern struct {
    x: f64,
    y: f64,
    w: f64,
    h: f64,
};

test "returns: normalization to raw ABI return types" {
    try testing.expectEqual(raw.id, AbiReturnType(Object));
    try testing.expectEqual(raw.id, AbiReturnType(?Object));
    try testing.expectEqual(raw.Class, AbiReturnType(Class));
    try testing.expectEqual(raw.Class, AbiReturnType(?Class));
    try testing.expectEqual(raw.SEL, AbiReturnType(Selector));
    try testing.expectEqual(raw.SEL, AbiReturnType(?Selector));
    try testing.expectEqual(raw.IMP, AbiReturnType(Imp));
    try testing.expectEqual(raw.IMP, AbiReturnType(?Imp));
    try testing.expectEqual(c_int, AbiReturnType(TestEnum));
    try testing.expectEqual(void, AbiReturnType(void));
    try testing.expectEqual(Rect, AbiReturnType(Rect));
}

test "returns: fromAbi value conversion" {
    const e = fromAbi(TestEnum, 2);
    try testing.expectEqual(TestEnum.beta, e);

    const v = fromAbi(void, {});
    try testing.expectEqual({}, v);

    const opt_obj = fromAbi(?Object, null);
    try testing.expectEqual(@as(?Object, null), opt_obj);

    const opt_cls = fromAbi(?Class, null);
    try testing.expectEqual(@as(?Class, null), opt_cls);
}
