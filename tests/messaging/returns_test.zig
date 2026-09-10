//! Unit tests for return type normalization and value conversion.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");
const raw = objc.raw;
const returns = objc.messaging.returns;

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
    try testing.expectEqual(raw.id, returns.AbiReturnType(objc.Object));
    try testing.expectEqual(raw.id, returns.AbiReturnType(?objc.Object));
    try testing.expectEqual(raw.Class, returns.AbiReturnType(objc.Class));
    try testing.expectEqual(raw.Class, returns.AbiReturnType(?objc.Class));
    try testing.expectEqual(raw.SEL, returns.AbiReturnType(objc.Selector));
    try testing.expectEqual(raw.SEL, returns.AbiReturnType(?objc.Selector));
    try testing.expectEqual(raw.IMP, returns.AbiReturnType(objc.Imp));
    try testing.expectEqual(raw.IMP, returns.AbiReturnType(?objc.Imp));
    try testing.expectEqual(c_int, returns.AbiReturnType(TestEnum));
    try testing.expectEqual(void, returns.AbiReturnType(void));
    try testing.expectEqual(Rect, returns.AbiReturnType(Rect));
}

test "returns: fromAbi value conversion" {
    // Enum
    const e = returns.fromAbi(TestEnum, 2);
    try testing.expectEqual(TestEnum.beta, e);

    // Void
    const v = returns.fromAbi(void, {});
    try testing.expectEqual({}, v);

    // Nullable object
    const opt_obj = returns.fromAbi(?objc.Object, null);
    try testing.expectEqual(@as(?objc.Object, null), opt_obj);

    // Nullable class
    const opt_cls = returns.fromAbi(?objc.Class, null);
    try testing.expectEqual(@as(?objc.Class, null), opt_cls);
}
