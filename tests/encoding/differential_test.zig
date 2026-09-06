//! Differential tests comparing zobjc encoding output against Apple Clang @encode fixtures.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

// External fixture prototypes from fixtures.h compiled with Clang
extern fn fixture_encode_char() [*:0]const u8;
extern fn fixture_encode_uchar() [*:0]const u8;
extern fn fixture_encode_short() [*:0]const u8;
extern fn fixture_encode_ushort() [*:0]const u8;
extern fn fixture_encode_int() [*:0]const u8;
extern fn fixture_encode_uint() [*:0]const u8;
extern fn fixture_encode_long() [*:0]const u8;
extern fn fixture_encode_ulong() [*:0]const u8;
extern fn fixture_encode_longlong() [*:0]const u8;
extern fn fixture_encode_ulonglong() [*:0]const u8;
extern fn fixture_encode_float() [*:0]const u8;
extern fn fixture_encode_double() [*:0]const u8;
extern fn fixture_encode_long_double() [*:0]const u8;
extern fn fixture_encode_bool() [*:0]const u8;
extern fn fixture_encode_c99_bool() [*:0]const u8;
extern fn fixture_encode_void() [*:0]const u8;
extern fn fixture_encode_char_ptr() [*:0]const u8;
extern fn fixture_encode_const_char_ptr() [*:0]const u8;
extern fn fixture_encode_void_ptr() [*:0]const u8;
extern fn fixture_encode_id() [*:0]const u8;
extern fn fixture_encode_class() [*:0]const u8;
extern fn fixture_encode_sel() [*:0]const u8;

extern fn fixture_encode_int_ptr() [*:0]const u8;
extern fn fixture_encode_int_ptr_ptr() [*:0]const u8;

extern fn fixture_encode_int_array_4() [*:0]const u8;
extern fn fixture_encode_float_array_16() [*:0]const u8;
extern fn fixture_encode_matrix_4_4() [*:0]const u8;

extern fn fixture_encode_struct_s1() [*:0]const u8;
extern fn fixture_encode_struct_cgpoint() [*:0]const u8;
extern fn fixture_encode_union_u1() [*:0]const u8;
extern fn fixture_encode_struct_nested() [*:0]const u8;
extern fn fixture_encode_struct_s1_ptr() [*:0]const u8;
extern fn fixture_encode_struct_s1_ptr_ptr() [*:0]const u8;

extern fn fixture_encode_block_void() [*:0]const u8;
extern fn fixture_encode_block_int() [*:0]const u8;
extern fn fixture_encode_atomic_int() [*:0]const u8;

const S1 = extern struct {
    x: c_int,
};

const CGPoint = extern struct {
    x: f64,
    y: f64,
};

const U1 = extern union {
    i: c_int,
    f: f32,
};

const Nested = extern struct {
    point: CGPoint,
    flags: c_int,
};

fn checkDifferential(comptime T: type, fixture_fn: *const fn () callconv(.c) [*:0]const u8) !void {
    const expected = std.mem.span(fixture_fn());
    const actual = comptime objc.encoding.comptimeEncode(T);
    try testing.expectEqualStrings(expected, &actual);
}

test "differential: scalars vs Clang @encode" {
    try checkDifferential(c_char, fixture_encode_char);
    try checkDifferential(u8, fixture_encode_uchar);
    try checkDifferential(c_short, fixture_encode_short);
    try checkDifferential(c_ushort, fixture_encode_ushort);
    try checkDifferential(c_int, fixture_encode_int);
    try checkDifferential(c_uint, fixture_encode_uint);
    try checkDifferential(c_long, fixture_encode_long);
    try checkDifferential(c_ulong, fixture_encode_ulong);
    try checkDifferential(c_longlong, fixture_encode_longlong);
    try checkDifferential(c_ulonglong, fixture_encode_ulonglong);
    try checkDifferential(f32, fixture_encode_float);
    try checkDifferential(f64, fixture_encode_double);
    try checkDifferential(c_longdouble, fixture_encode_long_double);
    try checkDifferential(objc.raw.BOOL, fixture_encode_bool);
    try checkDifferential(bool, fixture_encode_c99_bool);
    try checkDifferential(void, fixture_encode_void);
    try checkDifferential([*c]u8, fixture_encode_char_ptr);
    try checkDifferential([*c]const u8, fixture_encode_const_char_ptr);
    try checkDifferential(*anyopaque, fixture_encode_void_ptr);
    try checkDifferential(objc.Object, fixture_encode_id);
    try checkDifferential(objc.Class, fixture_encode_class);
    try checkDifferential(objc.Selector, fixture_encode_sel);
}

test "differential: pointers vs Clang @encode" {
    try checkDifferential(*c_int, fixture_encode_int_ptr);
    try checkDifferential(**c_int, fixture_encode_int_ptr_ptr);
}

test "differential: arrays vs Clang @encode" {
    try checkDifferential([4]c_int, fixture_encode_int_array_4);
    try checkDifferential([16]f32, fixture_encode_float_array_16);
    try checkDifferential([4][4]c_int, fixture_encode_matrix_4_4);
}

test "differential: aggregates vs Clang @encode" {
    try checkDifferential(S1, fixture_encode_struct_s1);
    try checkDifferential(CGPoint, fixture_encode_struct_cgpoint);
    try checkDifferential(U1, fixture_encode_union_u1);
    try checkDifferential(Nested, fixture_encode_struct_nested);
    try checkDifferential(*S1, fixture_encode_struct_s1_ptr);
    try checkDifferential(**S1, fixture_encode_struct_s1_ptr_ptr);
}

test "differential: parser round-trip against Clang output" {
    const allocator = testing.allocator;

    const fixtures = [_]*const fn () callconv(.c) [*:0]const u8{
        fixture_encode_char,
        fixture_encode_uchar,
        fixture_encode_short,
        fixture_encode_ushort,
        fixture_encode_int,
        fixture_encode_uint,
        fixture_encode_long,
        fixture_encode_ulong,
        fixture_encode_longlong,
        fixture_encode_ulonglong,
        fixture_encode_float,
        fixture_encode_double,
        fixture_encode_long_double,
        fixture_encode_bool,
        fixture_encode_c99_bool,
        fixture_encode_void,
        fixture_encode_char_ptr,
        fixture_encode_const_char_ptr,
        fixture_encode_void_ptr,
        fixture_encode_id,
        fixture_encode_class,
        fixture_encode_sel,
        fixture_encode_int_ptr,
        fixture_encode_int_ptr_ptr,
        fixture_encode_int_array_4,
        fixture_encode_float_array_16,
        fixture_encode_matrix_4_4,
        fixture_encode_struct_s1,
        fixture_encode_struct_cgpoint,
        fixture_encode_union_u1,
        fixture_encode_struct_nested,
        fixture_encode_struct_s1_ptr,
        fixture_encode_struct_s1_ptr_ptr,
        fixture_encode_block_void,
        fixture_encode_block_int,
        fixture_encode_atomic_int,
    };

    for (fixtures) |fix_fn| {
        const clang_str = std.mem.span(fix_fn());
        var parsed = try objc.encoding.parse(allocator, clang_str);
        defer parsed.deinit(allocator);

        const reencoded = try objc.encoding.encode(allocator, parsed);
        defer allocator.free(reencoded);

        try testing.expectEqualStrings(clang_str, reencoded);
    }
}
