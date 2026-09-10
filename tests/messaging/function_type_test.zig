//! Unit tests for exact C function type synthesis.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");
const raw = objc.raw;
const function_type = objc.messaging.function_type;

test "function_type: message signature structure" {
    const AbiArgsTuple = struct { c_int, f64, [*:0]const u8 };
    const Fn = function_type.MessageFunctionType(raw.id, AbiArgsTuple);
    const info = @typeInfo(Fn).@"fn";

    try testing.expectEqual(std.builtin.CallingConvention.c, info.calling_convention);
    try testing.expectEqual(raw.id, info.return_type.?);
    try testing.expectEqual(@as(usize, 5), info.params.len);

    // Param 0: receiver (id)
    try testing.expectEqual(raw.id, info.params[0].type.?);
    // Param 1: selector (SEL)
    try testing.expectEqual(raw.SEL, info.params[1].type.?);
    // Param 2: c_int
    try testing.expectEqual(c_int, info.params[2].type.?);
    // Param 3: f64
    try testing.expectEqual(f64, info.params[3].type.?);
    // Param 4: [*:0]const u8
    try testing.expectEqual([*:0]const u8, info.params[4].type.?);
}

test "function_type: super signature structure" {
    const AbiArgsTuple = struct { usize };
    const Fn = function_type.SuperFunctionType(void, AbiArgsTuple);
    const info = @typeInfo(Fn).@"fn";

    try testing.expectEqual(std.builtin.CallingConvention.c, info.calling_convention);
    try testing.expectEqual(void, info.return_type.?);
    try testing.expectEqual(@as(usize, 3), info.params.len);

    // Param 0: *raw.objc_super
    try testing.expectEqual(*raw.objc_super, info.params[0].type.?);
    // Param 1: raw.SEL
    try testing.expectEqual(raw.SEL, info.params[1].type.?);
    // Param 2: usize
    try testing.expectEqual(usize, info.params[2].type.?);
}

test "function_type: method_invoke signature structure" {
    const AbiArgsTuple = struct { c_int };
    const Fn = function_type.MethodInvokeFunctionType(c_int, AbiArgsTuple);
    const info = @typeInfo(Fn).@"fn";

    try testing.expectEqual(std.builtin.CallingConvention.c, info.calling_convention);
    try testing.expectEqual(c_int, info.return_type.?);
    try testing.expectEqual(@as(usize, 3), info.params.len);

    // Param 0: raw.id
    try testing.expectEqual(raw.id, info.params[0].type.?);
    // Param 1: raw.Method
    try testing.expectEqual(raw.Method, info.params[1].type.?);
    // Param 2: c_int
    try testing.expectEqual(c_int, info.params[2].type.?);
}
