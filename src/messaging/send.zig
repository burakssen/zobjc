//! Primary Objective-C message dispatch engine.
//!
//! Exposes `send(Return, receiver, selector, args)` with full compile-time validation,
//! ABI classification, and zero heap allocation.

const std = @import("std");
const testing = std.testing;
const objc = @import("zobjc");
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

test "send: class method invocation and object creation" {
    const ABIFixture = objc.getClass("ABIFixture").?;

    const sum = objc.send(c_int, ABIFixture, "addInt:to:", .{ @as(c_int, 20), @as(c_int, 22) });
    try testing.expectEqual(@as(c_int, 42), sum);

    const inst = objc.send(objc.Object, ABIFixture, "new", .{});
    defer inst.send(void, "release", .{});

    const val = objc.send(c_int, inst, "echoInt:", .{@as(c_int, 42)});
    try testing.expectEqual(@as(c_int, 42), val);
}

test "send: scalar arguments and returns" {
    const ABIFixture = objc.getClass("ABIFixture").?;

    const prod = objc.send(f64, ABIFixture, "multiplyDouble:by:", .{ @as(f64, 2.0), @as(f64, 3.14159) });
    try testing.expectApproxEqAbs(@as(f64, 6.28318), prod, 0.0001);

    const inst = objc.send(objc.Object, ABIFixture, "new", .{});
    defer inst.send(void, "release", .{});

    const val = objc.send(c_int, inst, "returnInt", .{});
    try testing.expectEqual(@as(c_int, 42), val);
}

test "send: aggregate argument and return (ABIPoint)" {
    const ABIFixture = objc.getClass("ABIFixture").?;
    const inst = objc.send(objc.Object, ABIFixture, "new", .{});
    defer inst.send(void, "release", .{});

    const SendPoint = extern struct {
        x: f64,
        y: f64,
    };

    const pt = objc.send(SendPoint, inst, "returnPoint", .{});
    try testing.expectEqual(@as(f64, 10.0), pt.x);
    try testing.expectEqual(@as(f64, 20.0), pt.y);
}

test "send: nil receiver semantics" {
    const nil_obj: ?objc.Object = null;

    const int_val = objc.send(c_int, nil_obj, "returnInt", .{});
    try testing.expectEqual(@as(c_int, 0), int_val);

    const obj_val = objc.send(?objc.Object, nil_obj, "description", .{});
    try testing.expectEqual(@as(?objc.Object, null), obj_val);
}

test "send: object and class convenience methods" {
    const ABIFixture = objc.getClass("ABIFixture").?;

    const sum = ABIFixture.send(c_int, "addInt:to:", .{ @as(c_int, 40), @as(c_int, 60) });
    try testing.expectEqual(@as(c_int, 100), sum);

    const inst = ABIFixture.send(objc.Object, "new", .{});
    defer inst.send(void, "release", .{});

    const val = inst.send(c_int, "echoInt:", .{@as(c_int, 100)});
    try testing.expectEqual(@as(c_int, 100), val);

    const sum2 = ABIFixture.send(c_int, "addInt:to:", .{ @as(c_int, 150), @as(c_int, 50) });
    try testing.expectEqual(@as(c_int, 200), sum2);

    const val2 = inst.send(c_int, "echoInt:", .{@as(c_int, 200)});
    try testing.expectEqual(@as(c_int, 200), val2);
}

const ABISize1 = extern struct { a: u8 };
const ABISize2 = extern struct { a: c_short };
const ABISize3 = extern struct { a: u8, b: c_short };
const ABISize4 = extern struct { a: i32 };
const ABISize7 = extern struct { a: c_int, b: u8, c: u8, d: u8 };
const ABISize8 = extern struct { a: i64 };
const ABISize8Mixed = extern struct { a: c_int, b: f32 };
const ABISize9 = extern struct { a: i64, b: u8 };
const ABISize12 = extern struct { a: c_int, b: c_int, c: c_int };
const ABISize16Int = extern struct { a: i64, b: i64 };
const ABISize16Float = extern struct { a: f64, b: f64 };
const ABISize16Mixed = extern struct { a: c_int, b: f64 };
const ABISize17 = extern struct { a: i64, b: i64, c: u8 };
const ABIPoint = extern struct { x: f64, y: f64 };
const ABISize = extern struct { width: f64, height: f64 };
const ABIRect = extern struct { origin: ABIPoint, size: ABISize };
const ABINested = extern struct { pt: ABIPoint, tag: c_int };
const ABIUnion8 = extern union { i: i64, d: f64 };
const ABIStructLongDouble = extern struct { x: c_longdouble };
const ABIStructMixedLongDouble = extern struct { a: c_int, b: c_longdouble };
const ABISize24 = extern struct { a: f64, b: f64, c: f64 };
const ABISize32 = extern struct { a: f64, b: f64, c: f64, d: f64 };

fn newABIFixture() objc.Object {
    const fixture_class = objc.getClass("ABIFixture").?;
    return objc.send(objc.Object, fixture_class, "alloc", .{}).send(objc.Object, "init", .{});
}

test "differential: scalar methods on ABIFixture" {
    const fixture = newABIFixture();
    defer fixture.send(void, "dealloc", .{});

    const int_val = objc.send(c_int, fixture, "returnInt", .{});
    try testing.expectEqual(@as(c_int, 42), int_val);

    const float_val = fixture.send(f32, "returnFloat", .{});
    try testing.expectApproxEqAbs(@as(f32, 3.14), float_val, 0.001);

    const dbl_val = objc.send(f64, fixture, "returnDouble", .{});
    try testing.expectApproxEqAbs(@as(f64, 2.718281828), dbl_val, 0.00001);

    objc.send(void, fixture, "returnVoid", .{});
    const long_double_val = fixture.send(c_longdouble, "returnLongDouble", .{});
    try testing.expectApproxEqAbs(@as(c_longdouble, 1.41421356237309504880), long_double_val, 0.0000001);
}

test "differential: small structures (<= 16 bytes) on ABIFixture" {
    const fixture = newABIFixture();
    defer fixture.send(void, "dealloc", .{});

    const s1 = objc.send(ABISize1, fixture, "returnSize1", .{});
    try testing.expectEqual(@as(u8, 'A'), @as(u8, @intCast(s1.a)));

    const s2 = fixture.send(ABISize2, "returnSize2", .{});
    try testing.expectEqual(@as(c_short, 100), s2.a);

    const s3 = fixture.send(ABISize3, "returnSize3", .{});
    try testing.expectEqual(@as(u8, 'B'), s3.a);
    try testing.expectEqual(@as(c_short, 200), s3.b);

    const s4 = objc.send(ABISize4, fixture, "returnSize4", .{});
    try testing.expectEqual(@as(c_int, 1000), s4.a);

    const s7 = fixture.send(ABISize7, "returnSize7", .{});
    try testing.expectEqual(@as(c_int, 10), s7.a);
    try testing.expectEqual(@as(u8, 'x'), s7.b);
    try testing.expectEqual(@as(u8, 'y'), s7.c);
    try testing.expectEqual(@as(u8, 'z'), s7.d);

    const s8 = objc.send(ABISize8, fixture, "returnSize8", .{});
    try testing.expectEqual(@as(c_longlong, 1234567890123), s8.a);

    const s8_mixed = fixture.send(ABISize8Mixed, "returnSize8Mixed", .{});
    try testing.expectEqual(@as(c_int, 10), s8_mixed.a);
    try testing.expectEqual(@as(f32, 20.0), s8_mixed.b);

    const s9 = fixture.send(ABISize9, "returnSize9", .{});
    try testing.expectEqual(@as(i64, 123), s9.a);
    try testing.expectEqual(@as(u8, 'c'), s9.b);

    const s12 = fixture.send(ABISize12, "returnSize12", .{});
    try testing.expectEqual(@as(c_int, 1), s12.a);
    try testing.expectEqual(@as(c_int, 2), s12.b);
    try testing.expectEqual(@as(c_int, 3), s12.c);

    const s16i = objc.send(ABISize16Int, fixture, "returnSize16Int", .{});
    try testing.expectEqual(@as(c_longlong, 100), s16i.a);
    try testing.expectEqual(@as(c_longlong, 200), s16i.b);

    const s16f = objc.send(ABISize16Float, fixture, "returnSize16Float", .{});
    try testing.expectEqual(1.5, s16f.a);
    try testing.expectEqual(2.5, s16f.b);

    const s16_mixed = fixture.send(ABISize16Mixed, "returnSize16Mixed", .{});
    try testing.expectEqual(@as(c_int, 42), s16_mixed.a);
    try testing.expectEqual(@as(f64, 3.14), s16_mixed.b);

    const pt = objc.send(ABIPoint, fixture, "returnPoint", .{});
    try testing.expectEqual(10.0, pt.x);
    try testing.expectEqual(20.0, pt.y);

    const union_value = fixture.send(ABIUnion8, "returnUnion8", .{});
    try testing.expectEqual(@as(i64, 0x123456789ABCDEF0), union_value.i);
}

test "differential: large structures and aggregate arguments on ABIFixture" {
    const fixture = newABIFixture();
    defer fixture.send(void, "dealloc", .{});

    const s24 = objc.send(ABISize24, fixture, "returnSize24", .{});
    try testing.expectEqual(1.0, s24.a);
    try testing.expectEqual(2.0, s24.b);
    try testing.expectEqual(3.0, s24.c);

    const s32 = objc.send(ABISize32, fixture, "returnSize32", .{});
    try testing.expectEqual(1.0, s32.a);
    try testing.expectEqual(2.0, s32.b);
    try testing.expectEqual(3.0, s32.c);
    try testing.expectEqual(4.0, s32.d);

    const rect = objc.send(ABIRect, fixture, "returnRect", .{});
    try testing.expectEqual(10.0, rect.origin.x);
    try testing.expectEqual(20.0, rect.origin.y);
    try testing.expectEqual(100.0, rect.size.width);
    try testing.expectEqual(200.0, rect.size.height);

    const s17 = fixture.send(ABISize17, "returnSize17", .{});
    try testing.expectEqual(@as(i64, 1), s17.a);
    try testing.expectEqual(@as(i64, 2), s17.b);
    try testing.expectEqual(@as(u8, 'z'), s17.c);

    const nested = fixture.send(ABINested, "returnNested", .{});
    try testing.expectEqual(@as(f64, 1.0), nested.pt.x);
    try testing.expectEqual(@as(f64, 2.0), nested.pt.y);
    try testing.expectEqual(@as(c_int, 99), nested.tag);

    const struct_long_double = fixture.send(ABIStructLongDouble, "returnStructLongDouble", .{});
    try testing.expectApproxEqAbs(@as(c_longdouble, 3.14), struct_long_double.x, 0.0000001);

    const struct_mixed_long_double = fixture.send(ABIStructMixedLongDouble, "returnStructMixedLongDouble", .{});
    try testing.expectEqual(@as(c_int, 1), struct_mixed_long_double.a);
    try testing.expectApproxEqAbs(@as(c_longdouble, 3.14), struct_mixed_long_double.b, 0.0000001);

    const input = ABISize32{ .a = 10.0, .b = 20.0, .c = 30.0, .d = 40.0 };
    const sum = fixture.send(f64, "passSize32:", .{input});
    try testing.expectEqual(@as(f64, 100.0), sum);
}

test "differential: register pressure with 10 integers" {
    const fixture = newABIFixture();
    defer fixture.send(void, "dealloc", .{});

    const sum = fixture.send(c_int, "sum10Ints:b:c:d:e:f:g:h:i:j:", .{
        @as(c_int, 1),
        @as(c_int, 2),
        @as(c_int, 3),
        @as(c_int, 4),
        @as(c_int, 5),
        @as(c_int, 6),
        @as(c_int, 7),
        @as(c_int, 8),
        @as(c_int, 9),
        @as(c_int, 10),
    });
    try testing.expectEqual(@as(c_int, 55), sum);
}

test "differential: register pressure with 10 doubles" {
    const fixture = newABIFixture();
    defer fixture.send(void, "dealloc", .{});

    const sum = fixture.send(f64, "sum10Doubles:b:c:d:e:f:g:h:i:j:", .{
        @as(f64, 1.0),
        @as(f64, 2.0),
        @as(f64, 3.0),
        @as(f64, 4.0),
        @as(f64, 5.0),
        @as(f64, 6.0),
        @as(f64, 7.0),
        @as(f64, 8.0),
        @as(f64, 9.0),
        @as(f64, 10.0),
    });
    try testing.expectEqual(@as(f64, 55.0), sum);
}
