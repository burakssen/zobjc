//! Canonical public entry point for zobjc.
//!
//! Provides type-safe Zig bindings and runtime abstractions for Apple's Objective-C runtime.

// Subsystem module boundaries
pub const raw = @import("raw");
pub const runtime = @import("runtime");
pub const messaging = @import("messaging");
pub const abi = @import("abi");
pub const encoding = @import("encoding");
pub const memory = @import("memory");
pub const block = @import("block");

// Core runtime handles
pub const Object = runtime.Object;
pub const Class = runtime.Class;
pub const Selector = runtime.Selector;
pub const Method = runtime.Method;
pub const Ivar = runtime.Ivar;
pub const Property = runtime.Property;
pub const Protocol = runtime.Protocol;
pub const Imp = runtime.Imp;

// Descriptors
pub const MethodDescription = runtime.MethodDescription;
pub const PropertyAttribute = runtime.PropertyAttribute;
pub const ProtocolMethodOptions = runtime.ProtocolMethodOptions;
pub const ProtocolPropertyOptions = runtime.ProtocolPropertyOptions;

// Global runtime lookups
pub const getClass = runtime.getClass;
pub const lookupClass = runtime.lookupClass;
pub const requireClass = runtime.requireClass;
pub const getMetaClass = runtime.getMetaClass;
pub const getProtocol = runtime.getProtocol;
pub const requireProtocol = runtime.requireProtocol;
pub const allocateClassPair = runtime.allocateClassPair;
pub const registerClassPair = runtime.registerClassPair;
pub const disposeClassPair = runtime.disposeClassPair;
pub const classes = runtime.classes;
pub const protocols = runtime.protocols;
pub const sel = runtime.sel;

// Messaging engine
pub const send = messaging.send;
pub const sendChecked = messaging.sendChecked;
pub const sendSuper = messaging.sendSuper;
pub const invoke = messaging.invoke;
pub const callImp = messaging.callImp;

// Memory and ownership
pub const Retained = memory.Retained;
pub const Weak = memory.Weak;
pub const AutoreleasePool = memory.AutoreleasePool;

// Objective-C Blocks
pub const Block = block.Block;
pub const OwnedBlock = block.OwnedBlock;

// Type Encoding
pub const Encoding = encoding.Encoding;
pub const comptimeEncode = encoding.comptimeEncode;
pub const methodEncoding = encoding.methodEncoding;
pub const StorageType = encoding.StorageType;

// Associated objects & Swizzling
pub const AssociationKey = runtime.AssociationKey;
pub const AssociationPolicy = runtime.AssociationPolicy;
pub const Swizzle = runtime.Swizzle;
pub const ScopedSwizzle = runtime.ScopedSwizzle;
pub const MethodReplacement = runtime.MethodReplacement;
pub const BlockMethodReplacement = runtime.BlockMethodReplacement;

test {
    @import("std").testing.refAllDecls(@This());
}

test "independent module compilation" {
    _ = @import("raw");
    _ = @import("abi");
    _ = @import("encoding");
    _ = @import("memory");
    _ = @import("messaging");
    _ = @import("runtime");
    _ = @import("block");
    _ = @import("internal");
}

test "raw can be accessed independently" {
    _ = raw;
    _ = raw.objc;
    _ = raw.runtime;
    _ = raw.message;
    _ = raw.blocks;
    _ = raw.compiler_runtime;
    _ = raw.availability;
}

test "abi can be accessed independently" {
    _ = abi;
}

test "encoding can be accessed independently" {
    _ = encoding;
}

test "memory can be accessed independently" {
    _ = memory;
}

test "messaging can be accessed independently" {
    _ = messaging;
}

test "runtime facade imports cleanly" {
    _ = runtime;
}

test "block can be accessed independently" {
    _ = block;
}

test "core architecture: Foundation is not loaded in core test process" {
    var image_list = runtime.images();
    defer image_list.deinit();

    var iter = image_list.iterator();
    while (iter.next()) |img| {
        try @import("std").testing.expect(@import("std").mem.indexOf(u8, img, "Foundation.framework") == null);
    }
}

// --- Encoding/runtime integration: live Clang differential gates. ---
// These need linked fixtures and libobjc, so they live at the facade
// while `src/encoding` stays free of runtime/facade imports.
const integration_std = @import("std");

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
    const expected = integration_std.mem.span(fixture_fn());
    const actual = comptime encoding.comptimeEncode(T);
    try integration_std.testing.expectEqualStrings(expected, &actual);
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
    try checkDifferential(raw.BOOL, fixture_encode_bool);
    try checkDifferential(bool, fixture_encode_c99_bool);
    try checkDifferential(void, fixture_encode_void);
    try checkDifferential([*c]u8, fixture_encode_char_ptr);
    try checkDifferential([*c]const u8, fixture_encode_const_char_ptr);
    try checkDifferential(*anyopaque, fixture_encode_void_ptr);
    try checkDifferential(Object, fixture_encode_id);
    try checkDifferential(Class, fixture_encode_class);
    try checkDifferential(Selector, fixture_encode_sel);
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
        const original = integration_std.mem.span(fixture());
        var parsed = try encoding.parse(integration_std.testing.allocator, original);
        defer parsed.deinit(integration_std.testing.allocator);
        const encoded = try encoding.encode(integration_std.testing.allocator, parsed);
        defer integration_std.testing.allocator.free(encoded);
        try integration_std.testing.expectEqualStrings(original, encoded);
    }
}

test "method: clang instance and class methods both hide self as @" {
    const cls = raw.runtime.objc_getClass("ABIFixture") orelse return error.FixtureNotLinked;
    const inst_m = raw.runtime.class_getInstanceMethod(
        cls,
        raw.objc.sel_registerName("echoInt:"),
    ) orelse return error.MethodNotFound;
    const meta = raw.runtime.objc_getMetaClass("ABIFixture") orelse return error.FixtureNotLinked;
    const class_m = raw.runtime.class_getInstanceMethod(
        meta,
        raw.objc.sel_registerName("addInt:to:"),
    ) orelse return error.MethodNotFound;
    for ([2]raw.Method{ inst_m, class_m }) |m| {
        const enc = integration_std.mem.span(raw.runtime.method_getTypeEncoding(m) orelse return error.MethodNotFound);
        var sig = try encoding.parseMethod(integration_std.testing.allocator, enc);
        defer sig.deinit(integration_std.testing.allocator);
        try sig.validateObjectiveCMethod();
        try integration_std.testing.expect(sig.arguments[0].type.type == .object);
        try integration_std.testing.expect(sig.arguments[1].type.type == .selector);
    }
}

test "corpus: parse runtime methods, properties, and ivars" {
    const allocator = integration_std.testing.allocator;
    const class = raw.runtime.objc_getClass("NSObject") orelse return error.ClassNotLoaded;

    var method_count: c_uint = 0;
    const methods = raw.runtime.class_copyMethodList(class, &method_count);
    defer if (methods) |list| integration_std.c.free(@ptrCast(list));

    var parsed_method_count: usize = 0;
    if (methods) |list| {
        for (0..method_count) |index| {
            const type_enc = raw.runtime.method_getTypeEncoding(list[index]) orelse continue;
            if (type_enc[0] == 0) continue;
            var sig = try encoding.parseMethod(allocator, integration_std.mem.span(type_enc));
            defer sig.deinit(allocator);
            parsed_method_count += 1;
        }
    }
    try integration_std.testing.expect(parsed_method_count > 10);

    var property_count: c_uint = 0;
    const properties = raw.runtime.class_copyPropertyList(class, &property_count);
    defer if (properties) |list| integration_std.c.free(@ptrCast(list));
    var parsed_property_count: usize = 0;
    if (properties) |list| {
        for (0..property_count) |index| {
            const attributes = raw.runtime.property_getAttributes(list[index]) orelse continue;
            var parsed = try encoding.property.parseProperty(allocator, integration_std.mem.span(attributes));
            defer parsed.deinit(allocator);
            parsed_property_count += 1;
        }
    }
    try integration_std.testing.expect(parsed_property_count > 0);
}

test "corpus: parse Foundation class metadata when available" {
    const allocator = integration_std.testing.allocator;
    const class_names = [_][*:0]const u8{ "NSString", "NSArray", "NSDictionary" };

    for (class_names) |name| {
        const class = raw.runtime.objc_getClass(name) orelse continue;

        var method_count: c_uint = 0;
        const methods = raw.runtime.class_copyMethodList(class, &method_count);
        defer if (methods) |list| integration_std.c.free(@ptrCast(list));
        if (methods) |list| {
            for (0..method_count) |index| {
                const type_enc = raw.runtime.method_getTypeEncoding(list[index]) orelse continue;
                var parsed = try encoding.parseMethod(allocator, integration_std.mem.span(type_enc));
                defer parsed.deinit(allocator);
            }
        }

        var property_count: c_uint = 0;
        const properties = raw.runtime.class_copyPropertyList(class, &property_count);
        defer if (properties) |list| integration_std.c.free(@ptrCast(list));
        if (properties) |list| {
            for (0..property_count) |index| {
                const attributes = raw.runtime.property_getAttributes(list[index]) orelse continue;
                var parsed = try encoding.property.parseProperty(allocator, integration_std.mem.span(attributes));
                defer parsed.deinit(allocator);
            }
        }

        var ivar_count: c_uint = 0;
        const ivars = raw.runtime.class_copyIvarList(class, &ivar_count);
        defer if (ivars) |list| integration_std.c.free(@ptrCast(list));
        if (ivars) |list| {
            for (0..ivar_count) |index| {
                const type_enc = raw.runtime.ivar_getTypeEncoding(list[index]) orelse continue;
                var parsed = try encoding.parser.parse(allocator, integration_std.mem.span(type_enc));
                defer parsed.deinit(allocator);
            }
        }
    }
}

test "method: live runtime initializer encoding parses cleanly" {
    const class = raw.runtime.objc_getClass("NSObject") orelse return error.ClassNotLoaded;
    const method = raw.runtime.class_getInstanceMethod(class, raw.objc.sel_registerName("init"));
    const type_enc = raw.runtime.method_getTypeEncoding(method) orelse return error.MethodNotFound;
    var sig = try encoding.parseMethod(integration_std.testing.allocator, integration_std.mem.span(type_enc));
    defer sig.deinit(integration_std.testing.allocator);
    try integration_std.testing.expect(sig.return_type.type == .object);
    try integration_std.testing.expect(sig.arguments.len >= 2);
}

test "integration: handles classify like raw handles on both macos targets" {
    const HandlePair = struct { handle: type, raw_handle: type };
    const pairs = [_]HandlePair{
        .{ .handle = Object, .raw_handle = raw.id },
        .{ .handle = ?Object, .raw_handle = raw.id },
        .{ .handle = Class, .raw_handle = raw.Class },
        .{ .handle = ?Class, .raw_handle = raw.Class },
        .{ .handle = Selector, .raw_handle = raw.SEL },
        .{ .handle = ?Selector, .raw_handle = raw.SEL },
        .{ .handle = Imp, .raw_handle = raw.IMP },
        .{ .handle = ?Imp, .raw_handle = raw.IMP },
        .{ .handle = Protocol, .raw_handle = raw.id },
        .{ .handle = ?Protocol, .raw_handle = raw.id },
    };
    inline for ([_]abi.Target{ abi.Target.macos_arm64, abi.Target.macos_x86_64 }) |target| {
        inline for (pairs) |pair| {
            try integration_std.testing.expectEqual(
                abi.returnConventionFor(target, pair.raw_handle),
                abi.returnConventionFor(target, pair.handle),
            );
            try integration_std.testing.expectEqual(
                .normal,
                abi.returnConventionFor(target, pair.handle),
            );
            try integration_std.testing.expectEqual(
                abi.classifyReturn(target, pair.raw_handle),
                abi.classifyReturn(target, pair.handle),
            );
        }
    }
}

test "integration: real handle encodings match wrapper-trait semantics" {
    const check = struct {
        fn enc(comptime T: type, expected: []const u8) !void {
            const actual = comptime encoding.comptimeEncode(T);
            try integration_std.testing.expectEqualStrings(expected, &actual);
        }
    }.enc;
    try check(Object, "@");
    try check(?Object, "@");
    try check(Class, "#");
    try check(?Class, "#");
    try check(Selector, ":");
    try check(?Selector, ":");
    try check(Imp, "^?");
    try check(Protocol, "@");
    try integration_std.testing.expect(encoding.zig_type.isObjCEncodable(Protocol));
    try integration_std.testing.expect(encoding.zig_type.isObjCEncodable(Imp));
    try integration_std.testing.expectEqual(raw.id, encoding.StorageType(Object));
    try integration_std.testing.expectEqual(raw.Class, encoding.StorageType(Class));
    try integration_std.testing.expectEqual(raw.SEL, encoding.StorageType(Selector));
    try integration_std.testing.expectEqual(raw.IMP, encoding.StorageType(Imp));
    try integration_std.testing.expectEqual(raw.Protocol, encoding.StorageType(Protocol));
    const InstanceCallback = fn (Object, Selector, i32) callconv(.c) void;
    const ClassCallback = fn (Class, Selector, i32) callconv(.c) void;
    try integration_std.testing.expectEqualStrings("v@:i", &encoding.methodEncoding(InstanceCallback));
    try integration_std.testing.expectEqualStrings("v@:i", &encoding.methodEncoding(ClassCallback));
}
