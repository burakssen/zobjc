const objc = @import("zobjc");
const std = @import("std");
const testing = std.testing;

// --- Encoding/runtime integration: live Clang differential gates. ---
// These need linked fixtures and libobjc, so they live at the facade
// while `src/encoding` stays free of runtime/facade imports.

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

const S1 = extern struct { x: c_int };
const CGPoint = extern struct { x: f64, y: f64 };
const U1 = extern union { i: c_int, f: f32 };
const Nested = extern struct { point: CGPoint, flags: c_int };

fn checkDifferential(comptime T: type, fixture_fn: *const fn () callconv(.c) [*:0]const u8) !void {
    const expected = std.mem.span(fixture_fn());
    const actual = comptime objc.encoding.comptimeEncode(T);
    try std.testing.expectEqualStrings(expected, &actual);
}

test "differential: encodings match Clang fixtures" {
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
    try checkDifferential(S1, fixture_encode_struct_s1);
    try checkDifferential(CGPoint, fixture_encode_struct_cgpoint);
    try checkDifferential(U1, fixture_encode_union_u1);
    try checkDifferential(Nested, fixture_encode_struct_nested);
}

test "differential: pointers and arrays match Clang fixtures" {
    try checkDifferential(*c_int, fixture_encode_int_ptr);
    try checkDifferential(**c_int, fixture_encode_int_ptr_ptr);
    try checkDifferential([4]c_int, fixture_encode_int_array_4);
    try checkDifferential([16]f32, fixture_encode_float_array_16);
    try checkDifferential([4][4]c_int, fixture_encode_matrix_4_4);
}

test "differential: aggregate pointers match Clang fixtures" {
    try checkDifferential(*S1, fixture_encode_struct_s1_ptr);
    try checkDifferential(**S1, fixture_encode_struct_s1_ptr_ptr);
}

test "parser: round-trip every Clang fixture encoding" {
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

    for (fixtures) |fixture| {
        const original = std.mem.span(fixture());
        var parsed = try objc.encoding.parse(std.testing.allocator, original);
        defer parsed.deinit(std.testing.allocator);
        const encoded = try objc.encoding.encode(std.testing.allocator, parsed);
        defer std.testing.allocator.free(encoded);
        try std.testing.expectEqualStrings(original, encoded);
    }
}

test "method: clang instance and class methods both hide self as @" {
    const cls = objc.raw.runtime.objc_getClass("ABIFixture") orelse return error.FixtureNotLinked;
    const inst_m = objc.raw.runtime.class_getInstanceMethod(
        cls,
        objc.raw.objc.sel_registerName("echoInt:"),
    ) orelse return error.MethodNotFound;
    const meta = objc.raw.runtime.objc_getMetaClass("ABIFixture") orelse return error.FixtureNotLinked;
    const class_m = objc.raw.runtime.class_getInstanceMethod(
        meta,
        objc.raw.objc.sel_registerName("addInt:to:"),
    ) orelse return error.MethodNotFound;
    for ([2]objc.raw.Method{ inst_m, class_m }) |m| {
        const enc = std.mem.span(objc.raw.runtime.method_getTypeEncoding(m) orelse return error.MethodNotFound);
        var sig = try objc.encoding.parseMethod(std.testing.allocator, enc);
        defer sig.deinit(std.testing.allocator);
        try sig.validateObjectiveCMethod();
        try std.testing.expect(sig.arguments[0].type.type == .object);
        try std.testing.expect(sig.arguments[1].type.type == .selector);
    }
}

test "corpus: parse runtime methods, properties, and ivars" {
    const allocator = std.testing.allocator;
    const class = objc.raw.runtime.objc_getClass("NSObject") orelse return error.ClassNotLoaded;

    var method_count: c_uint = 0;
    const methods = objc.raw.runtime.class_copyMethodList(class, &method_count);
    defer if (methods) |list| std.c.free(@ptrCast(list));

    var parsed_method_count: usize = 0;
    if (methods) |list| {
        for (0..method_count) |index| {
            const type_enc = objc.raw.runtime.method_getTypeEncoding(list[index]) orelse continue;
            if (type_enc[0] == 0) continue;
            var sig = try objc.encoding.parseMethod(allocator, std.mem.span(type_enc));
            defer sig.deinit(allocator);
            parsed_method_count += 1;
        }
    }
    try std.testing.expect(parsed_method_count > 10);

    var property_count: c_uint = 0;
    const properties = objc.raw.runtime.class_copyPropertyList(class, &property_count);
    defer if (properties) |list| std.c.free(@ptrCast(list));
    var parsed_property_count: usize = 0;
    if (properties) |list| {
        for (0..property_count) |index| {
            const attributes = objc.raw.runtime.property_getAttributes(list[index]) orelse continue;
            var parsed = try objc.encoding.property.parseProperty(allocator, std.mem.span(attributes));
            defer parsed.deinit(allocator);
            parsed_property_count += 1;
        }
    }
    try std.testing.expect(parsed_property_count > 0);
}

test "corpus: parse Foundation class metadata when available" {
    const allocator = std.testing.allocator;
    const class_names = [_][*:0]const u8{ "NSString", "NSArray", "NSDictionary" };

    for (class_names) |name| {
        const class = objc.raw.runtime.objc_getClass(name) orelse continue;

        var method_count: c_uint = 0;
        const methods = objc.raw.runtime.class_copyMethodList(class, &method_count);
        defer if (methods) |list| std.c.free(@ptrCast(list));
        if (methods) |list| {
            for (0..method_count) |index| {
                const type_enc = objc.raw.runtime.method_getTypeEncoding(list[index]) orelse continue;
                var parsed = try objc.encoding.parseMethod(allocator, std.mem.span(type_enc));
                defer parsed.deinit(allocator);
            }
        }

        var property_count: c_uint = 0;
        const properties = objc.raw.runtime.class_copyPropertyList(class, &property_count);
        defer if (properties) |list| std.c.free(@ptrCast(list));
        if (properties) |list| {
            for (0..property_count) |index| {
                const attributes = objc.raw.runtime.property_getAttributes(list[index]) orelse continue;
                var parsed = try objc.encoding.property.parseProperty(allocator, std.mem.span(attributes));
                defer parsed.deinit(allocator);
            }
        }

        var ivar_count: c_uint = 0;
        const ivars = objc.raw.runtime.class_copyIvarList(class, &ivar_count);
        defer if (ivars) |list| std.c.free(@ptrCast(list));
        if (ivars) |list| {
            for (0..ivar_count) |index| {
                const type_enc = objc.raw.runtime.ivar_getTypeEncoding(list[index]) orelse continue;
                var parsed = try objc.encoding.parser.parse(allocator, std.mem.span(type_enc));
                defer parsed.deinit(allocator);
            }
        }
    }
}

test "method: live runtime initializer encoding parses cleanly" {
    const class = objc.raw.runtime.objc_getClass("NSObject") orelse return error.ClassNotLoaded;
    const method = objc.raw.runtime.class_getInstanceMethod(class, objc.raw.objc.sel_registerName("init"));
    const type_enc = objc.raw.runtime.method_getTypeEncoding(method) orelse return error.MethodNotFound;
    var sig = try objc.encoding.parseMethod(std.testing.allocator, std.mem.span(type_enc));
    defer sig.deinit(std.testing.allocator);
    try std.testing.expect(sig.return_type.type == .object);
    try std.testing.expect(sig.arguments.len >= 2);
}
