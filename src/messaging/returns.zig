//! Return type normalization and conversion for Objective-C message dispatch.
//!
//! Maps high-level return types to raw C ABI types and safely converts raw returns
//! into user-requested types, enforcing non-null invariants.

const std = @import("std");
const testing = std.testing;
const raw = @import("raw");
const wrapper = @import("internal").wrapper;

// Explicit type mapping matching ABI classification requirements with zero allocation.

/// Maps a user-requested return type `T` to its low-level C ABI return type.
pub fn AbiReturnType(comptime T: type) type {
    if (T == void) return void;

    // 1. Explicit wrappers (direct or optional) decay to their raw handle.
    // NOTE: explicit `comptime` is load-bearing (see NOTE in abi/type.zig).
    if (comptime wrapper.isObjCWrapper(T)) {
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

    if (comptime @typeInfo(Return) == .optional and wrapper.isObjCWrapper(Return)) {
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

const FixtureObject = struct {
    ptr: *raw.objc_object,
    pub const objc_wrapper = true;
};

const FixtureClass = struct {
    ptr: *raw.objc_class,
    pub const objc_wrapper = true;
};

const FixtureSelector = struct {
    ptr: *raw.objc_selector,
    pub const objc_wrapper = true;
};

const FixtureImp = struct {
    ptr: *const fn () callconv(.c) void,
    pub const objc_wrapper = true;
};

const CustomObject = struct {
    ptr: *raw.objc_object,
    pub const objc_wrapper = true;
};

test "returns: normalization to raw ABI return types" {
    try testing.expectEqual(raw.id, AbiReturnType(FixtureObject));
    try testing.expectEqual(raw.id, AbiReturnType(?FixtureObject));
    try testing.expectEqual(raw.Class, AbiReturnType(FixtureClass));
    try testing.expectEqual(raw.Class, AbiReturnType(?FixtureClass));
    try testing.expectEqual(raw.SEL, AbiReturnType(FixtureSelector));
    try testing.expectEqual(raw.SEL, AbiReturnType(?FixtureSelector));
    try testing.expectEqual(raw.IMP, AbiReturnType(FixtureImp));
    try testing.expectEqual(raw.IMP, AbiReturnType(?FixtureImp));
    try testing.expectEqual(c_int, AbiReturnType(TestEnum));
    try testing.expectEqual(void, AbiReturnType(void));
    try testing.expectEqual(Rect, AbiReturnType(Rect));
    try testing.expectEqual([*]f32, AbiReturnType([*]f32));
    try testing.expectEqual(?[*]f32, AbiReturnType(?[*]f32));
}

test "returns: fromAbi value conversion" {
    const e = fromAbi(TestEnum, 2);
    try testing.expectEqual(TestEnum.beta, e);

    const v = fromAbi(void, {});
    try testing.expectEqual({}, v);

    const opt_obj = fromAbi(?FixtureObject, null);
    try testing.expectEqual(@as(?FixtureObject, null), opt_obj);

    const opt_cls = fromAbi(?FixtureClass, null);
    try testing.expectEqual(@as(?FixtureClass, null), opt_cls);
}

test "returns: optional custom wrappers convert element-wise" {
    try testing.expectEqual(@as(?CustomObject, null), fromAbi(?CustomObject, null));
    const w = fromAbi(?CustomObject, @as(raw.id, @ptrFromInt(0x2000)));
    try testing.expectEqual(@as(*raw.objc_object, @ptrFromInt(0x2000)), w.?.ptr);
}
