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

// --- Messaging integration: live dispatch tests needing runtime/facade. ---
// Pure classifier/normalization unit tests stay inside `src/messaging`;
// anything touching live objects, fixtures, or the facade API lives here.
// `objc` below is this facade itself (@This()), keeping moved tests verbatim.
const objc = @This();

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

    try integration_std.testing.expectEqualStrings("Child", integration_std.mem.span(objc.send([*:0]const u8, child_obj, "identify", .{})));
    try integration_std.testing.expectEqualStrings("Grandchild", integration_std.mem.span(objc.send([*:0]const u8, grandchild_obj, "identify", .{})));

    const child_super = objc.send([*:0]const u8, child_obj, "superIdentify", .{});
    try integration_std.testing.expectEqualStrings("Base", integration_std.mem.span(child_super));

    const grandchild_super = objc.send([*:0]const u8, grandchild_obj, "superIdentify", .{});
    try integration_std.testing.expectEqualStrings("Child", integration_std.mem.span(grandchild_super));
}

test "differential: super dispatch matches native Objective-C super behavior" {
    const ABISubclass = objc.getClass("ABISubclass").?;
    const sub = objc.send(objc.Object, ABISubclass, "alloc", .{}).send(objc.Object, "init", .{});
    defer sub.send(void, "release", .{});

    const overridden = sub.send(c_int, "echoInt:", .{@as(c_int, 5)});
    try integration_std.testing.expectEqual(@as(c_int, 50), overridden);

    const native_super = sub.send(c_int, "callSuperEcho:", .{@as(c_int, 5)});
    try integration_std.testing.expectEqual(@as(c_int, 5), native_super);

    const zig_super = objc.sendSuper(c_int, sub, ABISubclass, "echoInt:", .{@as(c_int, 5)});
    try integration_std.testing.expectEqual(@as(c_int, 5), zig_super);
}

test "invoke: Method.invoke matches objc.send" {
    const ABIFixture = objc.getClass("ABIFixture").?;
    const inst = objc.send(objc.Object, ABIFixture, "new", .{});
    defer inst.send(void, "release", .{});

    const method = ABIFixture.instanceMethod(objc.sel("returnInt")).?;
    const val = method.invoke(c_int, inst, .{});
    try integration_std.testing.expectEqual(@as(c_int, 42), val);

    const send_val = objc.send(c_int, inst, "returnInt", .{});
    try integration_std.testing.expectEqual(send_val, val);
}

test "invoke: callImp directly invokes IMP function pointer" {
    const ABIFixture = objc.getClass("ABIFixture").?;
    const inst = objc.send(objc.Object, ABIFixture, "new", .{});
    defer inst.send(void, "release", .{});

    const method = ABIFixture.instanceMethod(objc.sel("returnInt")).?;
    const imp = method.implementation();
    const val = objc.callImp(c_int, imp, inst, objc.sel("returnInt"), .{});
    try integration_std.testing.expectEqual(@as(c_int, 42), val);
}

test "differential: Method.invoke agrees with ordinary message dispatch" {
    const ABIFixture = objc.getClass("ABIFixture").?;
    const fixture = objc.send(objc.Object, ABIFixture, "alloc", .{}).send(objc.Object, "init", .{});
    defer fixture.send(void, "release", .{});

    const method = ABIFixture.instanceMethod(objc.sel("echoInt:")).?;
    const res1 = fixture.send(c_int, "echoInt:", .{@as(c_int, 123)});
    const res2 = method.invoke(c_int, fixture, .{@as(c_int, 123)});

    try integration_std.testing.expectEqual(res1, res2);
    try integration_std.testing.expectEqual(@as(c_int, 123), res2);
}

test "send: class method invocation and object creation" {
    const ABIFixture = objc.getClass("ABIFixture").?;

    const sum = objc.send(c_int, ABIFixture, "addInt:to:", .{ @as(c_int, 20), @as(c_int, 22) });
    try integration_std.testing.expectEqual(@as(c_int, 42), sum);

    const inst = objc.send(objc.Object, ABIFixture, "new", .{});
    defer inst.send(void, "release", .{});

    const val = objc.send(c_int, inst, "echoInt:", .{@as(c_int, 42)});
    try integration_std.testing.expectEqual(@as(c_int, 42), val);
}

test "send: scalar arguments and returns" {
    const ABIFixture = objc.getClass("ABIFixture").?;

    const prod = objc.send(f64, ABIFixture, "multiplyDouble:by:", .{ @as(f64, 2.0), @as(f64, 3.14159) });
    try integration_std.testing.expectApproxEqAbs(@as(f64, 6.28318), prod, 0.0001);

    const inst = objc.send(objc.Object, ABIFixture, "new", .{});
    defer inst.send(void, "release", .{});

    const val = objc.send(c_int, inst, "returnInt", .{});
    try integration_std.testing.expectEqual(@as(c_int, 42), val);
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
    try integration_std.testing.expectEqual(@as(f64, 10.0), pt.x);
    try integration_std.testing.expectEqual(@as(f64, 20.0), pt.y);
}

test "send: nil receiver semantics" {
    const nil_obj: ?objc.Object = null;

    const int_val = objc.send(c_int, nil_obj, "returnInt", .{});
    try integration_std.testing.expectEqual(@as(c_int, 0), int_val);

    const obj_val = objc.send(?objc.Object, nil_obj, "description", .{});
    try integration_std.testing.expectEqual(@as(?objc.Object, null), obj_val);
}

test "send: object and class convenience methods" {
    const ABIFixture = objc.getClass("ABIFixture").?;

    const sum = ABIFixture.send(c_int, "addInt:to:", .{ @as(c_int, 40), @as(c_int, 60) });
    try integration_std.testing.expectEqual(@as(c_int, 100), sum);

    const inst = ABIFixture.send(objc.Object, "new", .{});
    defer inst.send(void, "release", .{});

    const val = inst.send(c_int, "echoInt:", .{@as(c_int, 100)});
    try integration_std.testing.expectEqual(@as(c_int, 100), val);

    const sum2 = ABIFixture.send(c_int, "addInt:to:", .{ @as(c_int, 150), @as(c_int, 50) });
    try integration_std.testing.expectEqual(@as(c_int, 200), sum2);

    const val2 = inst.send(c_int, "echoInt:", .{@as(c_int, 200)});
    try integration_std.testing.expectEqual(@as(c_int, 200), val2);
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
    defer fixture.send(void, "release", .{});

    const int_val = objc.send(c_int, fixture, "returnInt", .{});
    try integration_std.testing.expectEqual(@as(c_int, 42), int_val);

    const float_val = fixture.send(f32, "returnFloat", .{});
    try integration_std.testing.expectApproxEqAbs(@as(f32, 3.14), float_val, 0.001);

    const dbl_val = objc.send(f64, fixture, "returnDouble", .{});
    try integration_std.testing.expectApproxEqAbs(@as(f64, 2.718281828), dbl_val, 0.00001);

    objc.send(void, fixture, "returnVoid", .{});
    const long_double_val = fixture.send(c_longdouble, "returnLongDouble", .{});
    try integration_std.testing.expectApproxEqAbs(@as(c_longdouble, 1.41421356237309504880), long_double_val, 0.0000001);
}

test "differential: small structures (<= 16 bytes) on ABIFixture" {
    const fixture = newABIFixture();
    defer fixture.send(void, "release", .{});

    const s1 = objc.send(ABISize1, fixture, "returnSize1", .{});
    try integration_std.testing.expectEqual(@as(u8, 'A'), @as(u8, @intCast(s1.a)));

    const s2 = fixture.send(ABISize2, "returnSize2", .{});
    try integration_std.testing.expectEqual(@as(c_short, 100), s2.a);

    const s3 = fixture.send(ABISize3, "returnSize3", .{});
    try integration_std.testing.expectEqual(@as(u8, 'B'), s3.a);
    try integration_std.testing.expectEqual(@as(c_short, 200), s3.b);

    const s4 = objc.send(ABISize4, fixture, "returnSize4", .{});
    try integration_std.testing.expectEqual(@as(c_int, 1000), s4.a);

    const s7 = fixture.send(ABISize7, "returnSize7", .{});
    try integration_std.testing.expectEqual(@as(c_int, 10), s7.a);
    try integration_std.testing.expectEqual(@as(u8, 'x'), s7.b);
    try integration_std.testing.expectEqual(@as(u8, 'y'), s7.c);
    try integration_std.testing.expectEqual(@as(u8, 'z'), s7.d);

    const s8 = objc.send(ABISize8, fixture, "returnSize8", .{});
    try integration_std.testing.expectEqual(@as(c_longlong, 1234567890123), s8.a);

    const s8_mixed = fixture.send(ABISize8Mixed, "returnSize8Mixed", .{});
    try integration_std.testing.expectEqual(@as(c_int, 10), s8_mixed.a);
    try integration_std.testing.expectEqual(@as(f32, 20.0), s8_mixed.b);

    const s9 = fixture.send(ABISize9, "returnSize9", .{});
    try integration_std.testing.expectEqual(@as(i64, 123), s9.a);
    try integration_std.testing.expectEqual(@as(u8, 'c'), s9.b);

    const s12 = fixture.send(ABISize12, "returnSize12", .{});
    try integration_std.testing.expectEqual(@as(c_int, 1), s12.a);
    try integration_std.testing.expectEqual(@as(c_int, 2), s12.b);
    try integration_std.testing.expectEqual(@as(c_int, 3), s12.c);

    const s16i = objc.send(ABISize16Int, fixture, "returnSize16Int", .{});
    try integration_std.testing.expectEqual(@as(c_longlong, 100), s16i.a);
    try integration_std.testing.expectEqual(@as(c_longlong, 200), s16i.b);

    const s16f = objc.send(ABISize16Float, fixture, "returnSize16Float", .{});
    try integration_std.testing.expectEqual(1.5, s16f.a);
    try integration_std.testing.expectEqual(2.5, s16f.b);

    const s16_mixed = fixture.send(ABISize16Mixed, "returnSize16Mixed", .{});
    try integration_std.testing.expectEqual(@as(c_int, 42), s16_mixed.a);
    try integration_std.testing.expectEqual(@as(f64, 3.14), s16_mixed.b);

    const pt = objc.send(ABIPoint, fixture, "returnPoint", .{});
    try integration_std.testing.expectEqual(10.0, pt.x);
    try integration_std.testing.expectEqual(20.0, pt.y);

    const union_value = fixture.send(ABIUnion8, "returnUnion8", .{});
    try integration_std.testing.expectEqual(@as(i64, 0x123456789ABCDEF0), union_value.i);
}

test "differential: large structures and aggregate arguments on ABIFixture" {
    const fixture = newABIFixture();
    defer fixture.send(void, "release", .{});

    const s24 = objc.send(ABISize24, fixture, "returnSize24", .{});
    try integration_std.testing.expectEqual(1.0, s24.a);
    try integration_std.testing.expectEqual(2.0, s24.b);
    try integration_std.testing.expectEqual(3.0, s24.c);

    const s32 = objc.send(ABISize32, fixture, "returnSize32", .{});
    try integration_std.testing.expectEqual(1.0, s32.a);
    try integration_std.testing.expectEqual(2.0, s32.b);
    try integration_std.testing.expectEqual(3.0, s32.c);
    try integration_std.testing.expectEqual(4.0, s32.d);

    const rect = objc.send(ABIRect, fixture, "returnRect", .{});
    try integration_std.testing.expectEqual(10.0, rect.origin.x);
    try integration_std.testing.expectEqual(20.0, rect.origin.y);
    try integration_std.testing.expectEqual(100.0, rect.size.width);
    try integration_std.testing.expectEqual(200.0, rect.size.height);

    const s17 = fixture.send(ABISize17, "returnSize17", .{});
    try integration_std.testing.expectEqual(@as(i64, 1), s17.a);
    try integration_std.testing.expectEqual(@as(i64, 2), s17.b);
    try integration_std.testing.expectEqual(@as(u8, 'z'), s17.c);

    const nested = fixture.send(ABINested, "returnNested", .{});
    try integration_std.testing.expectEqual(@as(f64, 1.0), nested.pt.x);
    try integration_std.testing.expectEqual(@as(f64, 2.0), nested.pt.y);
    try integration_std.testing.expectEqual(@as(c_int, 99), nested.tag);

    const struct_long_double = fixture.send(ABIStructLongDouble, "returnStructLongDouble", .{});
    try integration_std.testing.expectApproxEqAbs(@as(c_longdouble, 3.14), struct_long_double.x, 0.0000001);

    const struct_mixed_long_double = fixture.send(ABIStructMixedLongDouble, "returnStructMixedLongDouble", .{});
    try integration_std.testing.expectEqual(@as(c_int, 1), struct_mixed_long_double.a);
    try integration_std.testing.expectApproxEqAbs(@as(c_longdouble, 3.14), struct_mixed_long_double.b, 0.0000001);

    const input = ABISize32{ .a = 10.0, .b = 20.0, .c = 30.0, .d = 40.0 };
    const sum = fixture.send(f64, "passSize32:", .{input});
    try integration_std.testing.expectEqual(@as(f64, 100.0), sum);
}

test "differential: register pressure with 10 integers" {
    const fixture = newABIFixture();
    defer fixture.send(void, "release", .{});

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
    try integration_std.testing.expectEqual(@as(c_int, 55), sum);
}

test "differential: register pressure with 10 doubles" {
    const fixture = newABIFixture();
    defer fixture.send(void, "release", .{});

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
    try integration_std.testing.expectEqual(@as(f64, 55.0), sum);
}

test "sendChecked: valid NSObject messages pass signature validation" {
    const NSObject = objc.requireClass("NSObject");

    const obj = sendChecked(objc.Object, NSObject, "alloc", .{});
    const init = sendChecked(objc.Object, obj, "init", .{});
    defer init.send(void, "release", .{});

    // description -> @ ; hash -> NSUInteger ; isEqual: takes @, returns BOOL.
    const desc = sendChecked(?objc.Object, init, "description", .{});
    _ = desc;
    const hash = sendChecked(usize, init, "hash", .{});
    _ = hash;
    const eq = sendChecked(raw.BOOL, init, "isEqual:", .{init});
    try integration_std.testing.expect(raw.boolResult(eq));
}

test "sendChecked: nil receiver short-circuits without lookup" {
    const nil_obj: ?objc.Object = null;
    const result = sendChecked(?objc.Object, nil_obj, "description", .{});
    try integration_std.testing.expectEqual(@as(?objc.Object, null), result);
}

// --- Runtime/memory integration: live runtime and ownership tests. ---
extern "c" fn get_dealloc_count() c_int;
extern "c" fn reset_dealloc_count() void;
// Pure conversion/layout tests stay in their modules; anything using
// the facade API or fixtures lives here.


// --- globals from src/memory/retained.zig ---
var g_dealloc_count: usize = 0;

// --- globals from src/memory/weak.zig ---
var g_weak_dealloc_count: usize = 0;

// --- globals from src/memory/autorelease_pool.zig ---
var g_pool_dealloc_count: usize = 0;

// --- from src/runtime/association.zig ---
test "associated objects: assign policy" {
    const key = objc.AssociationKey.init();
    const host = objc.requireClass("NSObject").send(objc.Object, "alloc", .{})
        .send(objc.Object, "init", .{});
    defer host.send(void, "dealloc", .{});

    const target = objc.requireClass("NSObject").send(objc.Object, "alloc", .{})
        .send(objc.Object, "init", .{});
    defer target.send(void, "dealloc", .{});

    try integration_std.testing.expect(host.associated(&key) == null);
    host.setAssociated(&key, target, .assign);
    const read = host.associated(&key);
    try integration_std.testing.expect(read != null);
    try integration_std.testing.expectEqual(target.ptr, read.?.ptr);
    host.clearAssociated(&key);
    try integration_std.testing.expect(host.associated(&key) == null);
}

test "associated objects: retain policies and lifetime" {
    const key1 = objc.AssociationKey.init();
    const key2 = objc.AssociationKey.init();
    reset_dealloc_count();

    const host = objc.requireClass("NSObject").send(objc.Object, "alloc", .{})
        .send(objc.Object, "init", .{});
    const tracker1 = objc.requireClass("DeallocTracker").send(objc.Object, "alloc", .{})
        .send(objc.Object, "initWithIdentifier:", .{@as(c_int, 101)});
    const tracker2 = objc.requireClass("DeallocTracker").send(objc.Object, "alloc", .{})
        .send(objc.Object, "initWithIdentifier:", .{@as(c_int, 102)});

    host.setAssociated(&key1, tracker1, .retain_nonatomic);
    host.setAssociated(&key2, tracker2, .retain);
    tracker1.send(void, "release", .{});
    tracker2.send(void, "release", .{});

    try integration_std.testing.expectEqual(@as(c_int, 0), get_dealloc_count());
    {
        var retained = host.associatedRetained(&key1);
        try integration_std.testing.expect(retained != null);
        try integration_std.testing.expectEqual(tracker1.ptr, retained.?.borrow().ptr);
        retained.?.deinit();
    }
    try integration_std.testing.expectEqual(@as(c_int, 0), get_dealloc_count());

    host.clearAssociated(&key1);
    try integration_std.testing.expectEqual(@as(c_int, 1), get_dealloc_count());
    try integration_std.testing.expect(host.associated(&key1) == null);

    {
        var pool = objc.AutoreleasePool.init();
        try integration_std.testing.expect(host.associated(&key2) != null);
        host.clearAssociated(&key2);
        pool.drain();
    }
    try integration_std.testing.expectEqual(@as(c_int, 2), get_dealloc_count());
    try integration_std.testing.expect(host.associated(&key2) == null);
    host.send(void, "release", .{});
}

test "associated objects: copy policies" {
    const key_non_atomic = objc.AssociationKey.init();
    const key_atomic = objc.AssociationKey.init();
    const host = objc.requireClass("NSObject").send(objc.Object, "alloc", .{})
        .send(objc.Object, "init", .{});
    defer host.send(void, "dealloc", .{});

    const original = objc.requireClass("CopyableTracker").send(objc.Object, "alloc", .{})
        .send(objc.Object, "initWithIdentifier:", .{@as(c_int, 200)});
    defer original.send(void, "release", .{});

    try integration_std.testing.expectEqual(@as(c_int, 0), original.send(c_int, "copyCount", .{}));
    host.setAssociated(&key_non_atomic, original, .copy_nonatomic);
    const copied1 = host.associated(&key_non_atomic).?;
    try integration_std.testing.expect(copied1.ptr != original.ptr);
    try integration_std.testing.expectEqual(@as(c_int, 1), copied1.send(c_int, "copyCount", .{}));

    host.setAssociated(&key_atomic, original, .copy);
    const copied2 = host.associated(&key_atomic).?;
    try integration_std.testing.expect(copied2.ptr != original.ptr);
    try integration_std.testing.expectEqual(@as(c_int, 1), copied2.send(c_int, "copyCount", .{}));
}

// --- from src/runtime/class.zig ---
test "class: NSObject introspection" {
    const cls = objc.requireClass("NSObject");

    try integration_std.testing.expectEqualStrings("NSObject", cls.name());
    try integration_std.testing.expect(!cls.isMetaClass());
    try integration_std.testing.expectEqual(@as(?objc.Class, null), cls.superclass());
    try integration_std.testing.expect(cls.instanceSize() >= @sizeOf(usize));

    const v = cls.version();
    cls.setVersion(v + 1);
    try integration_std.testing.expectEqual(v + 1, cls.version());
    cls.setVersion(v);

    const init_sel = objc.sel("init");
    try integration_std.testing.expect(cls.respondsTo(init_sel));
    try integration_std.testing.expect(cls.instanceMethod(init_sel) != null);
    try integration_std.testing.expect(cls.methodImplementation(init_sel) != null);
    try integration_std.testing.expect(cls.classMethod(objc.sel("alloc")) != null);

    if (objc.getProtocol("NSObject")) |proto| {
        try integration_std.testing.expect(cls.conformsTo(proto));
    }
    if (cls.imageName()) |img| {
        try integration_std.testing.expect(img.len > 0);
    }

    const cls_again = objc.getClass("NSObject").?;
    try integration_std.testing.expect(cls.eql(cls_again));
    try integration_std.testing.expect(cls.hash() == cls_again.hash());
}

test "class: subclass superclass hierarchy" {
    const fixture_cls = objc.requireClass("ABIFixture");
    const super_cls = fixture_cls.superclass();
    try integration_std.testing.expect(super_cls != null);
    try integration_std.testing.expectEqualStrings("NSObject", super_cls.?.name());
}

test "class: createInstance creates non-null object" {
    const cls = objc.requireClass("NSObject");
    const inst = cls.createInstance(0);
    try integration_std.testing.expect(inst != null);
    defer inst.?.disposeObjectMemory();

    try integration_std.testing.expect(inst.?.class().eql(cls));
}

test "hierarchy introspection: isSubclassOf and isStrictSubclassOf" {
    const NSObject = objc.requireClass("NSObject");
    const FixtureCls = objc.requireClass("ABIFixture");

    try integration_std.testing.expect(NSObject.isSubclassOf(NSObject));
    try integration_std.testing.expect(!NSObject.isStrictSubclassOf(NSObject));
    try integration_std.testing.expect(FixtureCls.isSubclassOf(NSObject));
    try integration_std.testing.expect(FixtureCls.isStrictSubclassOf(NSObject));
    try integration_std.testing.expect(!NSObject.isSubclassOf(FixtureCls));
    try integration_std.testing.expect(!NSObject.isStrictSubclassOf(FixtureCls));
}

test "runtime: property introspection" {
    const Tracker = objc.getClass("DeallocTracker").?;
    const prop = Tracker.property("identifier");
    try integration_std.testing.expect(prop != null);
    try integration_std.testing.expectEqualStrings("identifier", prop.?.name());

    try integration_std.testing.expect(Tracker.property("nonExistentPropertyXYZ") == null);

    var prop_list = Tracker.properties();
    defer prop_list.deinit();
    try integration_std.testing.expect(prop_list.count() > 0);
}

test "runtime: subclass creation, method replacement, and ivar addition" {
    const NSObject = objc.getClass("NSObject").?;
    var dynamic_class = objc.allocateClassPair(NSObject, "DynamicTestClass").?;
    try integration_std.testing.expect(dynamic_class.addIvar(
        "custom_ivar",
        @sizeOf(objc.raw.id),
        @truncate(integration_std.math.log2(@alignOf(objc.raw.id))),
        "@",
    ));

    _ = dynamic_class.replaceMethod(objc.sel("hash"), objc.Imp.fromRawNonNull(@ptrCast(&struct {
        fn inner(target: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) u64 {
            _ = target;
            _ = sel_val;
            return 42;
        }
    }.inner)), "Q@:");

    try integration_std.testing.expect(dynamic_class.addMethod(objc.sel("multiplyByTwo:"), objc.Imp.fromRawNonNull(@ptrCast(&struct {
        fn imp(target: objc.raw.id, sel_val: objc.raw.SEL, val: i32) callconv(.c) i32 {
            _ = target;
            _ = sel_val;
            return val * 2;
        }
    }.imp)), "i@:i"));

    objc.registerClassPair(dynamic_class);
    defer objc.disposeClassPair(dynamic_class);

    const instance = dynamic_class.send(objc.Object, "alloc", .{})
        .send(objc.Object, "init", .{});
    defer instance.send(void, "dealloc", .{});

    try integration_std.testing.expectEqual(@as(u64, 42), instance.send(u64, "hash", .{}));
    try integration_std.testing.expectEqual(@as(i32, 42), instance.send(i32, "multiplyByTwo:", .{@as(i32, 21)}));

    const val_obj = NSObject.send(objc.Object, "new", .{});
    defer val_obj.send(void, "release", .{});
    instance.setInstanceVariable("custom_ivar", val_obj);
    try integration_std.testing.expect(instance.getInstanceVariable("custom_ivar").?.eql(val_obj));
}

test "mutation: dynamic class creation, methods, ivars, protocols, and properties" {
    const NSObject = objc.requireClass("NSObject");
    const DynClass = objc.allocateClassPair(NSObject, "DynamicMutationFullTest").?;

    try integration_std.testing.expect(DynClass.addIvar(
        "counter",
        @sizeOf(i64),
        @truncate(integration_std.math.log2(@alignOf(i64))),
        "q",
    ));

    const add_fn = struct {
        fn add(target: objc.raw.id, sel_val: objc.raw.SEL, a: i32, b: i32) callconv(.c) i32 {
            _ = target;
            _ = sel_val;
            return a + b;
        }
    }.add;
    const add_sel = objc.sel("add:and:");
    try integration_std.testing.expect(DynClass.addMethod(add_sel, objc.Imp.fromRawNonNull(@ptrCast(&add_fn)), "i@:ii"));

    if (objc.getProtocol("NSObject")) |proto| {
        try integration_std.testing.expect(DynClass.addProtocol(proto));
    }

    const attrs = [_]objc.PropertyAttribute{
        .{ .name = "T", .value = "q" },
        .{ .name = "V", .value = "counter" },
    };
    try integration_std.testing.expect(DynClass.addProperty("counter", &attrs));

    objc.registerClassPair(DynClass);
    defer objc.disposeClassPair(DynClass);

    const new_add_fn = struct {
        fn new_add(target: objc.raw.id, sel_val: objc.raw.SEL, a: i32, b: i32) callconv(.c) i32 {
            _ = target;
            _ = sel_val;
            return (a + b) * 10;
        }
    }.new_add;
    try integration_std.testing.expect(DynClass.replaceMethod(add_sel, objc.Imp.fromRawNonNull(@ptrCast(&new_add_fn)), "i@:ii") != null);

    const inst = DynClass.send(objc.Object, "alloc", .{})
        .send(objc.Object, "init", .{});
    defer inst.send(void, "dealloc", .{});
    try integration_std.testing.expectEqual(@as(i32, 50), inst.send(i32, add_sel, .{ @as(i32, 2), @as(i32, 3) }));

    if (objc.getProtocol("NSObject")) |proto| {
        try integration_std.testing.expect(DynClass.conformsTo(proto));
    }
    const prop = DynClass.property("counter");
    try integration_std.testing.expect(prop != null);
    try integration_std.testing.expectEqualStrings("counter", prop.?.name());
}


// --- from src/runtime/enumeration.zig ---
test "class enumeration: protocol filter" {
    if (!runtime.hasClassEnumeration()) return;
    const NSCopying = objc.getProtocol("NSCopying") orelse return;

    var count: usize = 0;
    var all_conform = true;
    var ctx = struct {
        cnt: *usize,
        matched: *bool,
        proto: Protocol,
    }{ .cnt = &count, .matched = &all_conform, .proto = NSCopying };

    try runtime.enumerateClasses(.{ .conforming_to = NSCopying }, &ctx, struct {
        fn cb(c: anytype, cls: Class) bool {
            c.cnt.* += 1;
            if (!cls.conformsTo(c.proto)) {
                c.matched.* = false;
                return false;
            }
            return c.cnt.* < 15;
        }
    }.cb);

    try integration_std.testing.expect(count > 0);
    try integration_std.testing.expect(all_conform);
}

test "class enumeration: superclass filter" {
    if (!runtime.hasClassEnumeration()) return;
    const NSObject = objc.requireClass("NSObject");

    var count: usize = 0;
    var all_subclasses = true;
    var ctx = struct {
        cnt: *usize,
        matched: *bool,
        super_cls: Class,
    }{ .cnt = &count, .matched = &all_subclasses, .super_cls = NSObject };

    try runtime.enumerateClasses(.{ .subclassing = NSObject }, &ctx, struct {
        fn cb(c: anytype, cls: Class) bool {
            c.cnt.* += 1;
            if (!cls.isSubclassOf(c.super_cls)) {
                c.matched.* = false;
                return false;
            }
            return c.cnt.* < 20;
        }
    }.cb);

    try integration_std.testing.expect(count > 0);
    try integration_std.testing.expect(all_subclasses);
}

test "class enumeration: dynamic class filter" {
    if (!runtime.hasClassEnumeration()) return;

    const NSObject = objc.requireClass("NSObject");
    const dyn_cls = objc.allocateClassPair(NSObject, "EnumTestDynamicClass").?;
    objc.registerClassPair(dyn_cls);
    defer objc.disposeClassPair(dyn_cls);

    var found_dyn = false;
    try runtime.enumerateClasses(.{ .image = .dynamic }, &found_dyn, struct {
        fn cb(found: *bool, cls: Class) bool {
            if (integration_std.mem.eql(u8, cls.name(), "EnumTestDynamicClass")) {
                found.* = true;
                return false;
            }
            return true;
        }
    }.cb);
    try integration_std.testing.expect(found_dyn);
}

// --- from src/runtime/image.zig ---
test "image introspection: loaded images enumeration" {
    var image_list = objc.runtime.images();
    defer image_list.deinit();

    try integration_std.testing.expect(image_list.len > 0);
    var found_libobjc = false;
    var iter = image_list.iterator();
    while (iter.next()) |name| {
        if (integration_std.mem.indexOf(u8, name, "libobjc") != null) {
            found_libobjc = true;
            break;
        }
    }
    try integration_std.testing.expect(found_libobjc);
}

test "image introspection: class names for image" {
    const NSObject = objc.requireClass("NSObject");
    const nsobject_image = NSObject.imageName() orelse return;

    var class_names = objc.runtime.classNamesForImage(nsobject_image);
    defer class_names.deinit();
    try integration_std.testing.expect(class_names.len > 0);

    var found_nsobject = false;
    var name_iter = class_names.iterator();
    while (name_iter.next()) |cls_name| {
        if (integration_std.mem.eql(u8, cls_name, "NSObject")) {
            found_nsobject = true;
            break;
        }
    }
    try integration_std.testing.expect(found_nsobject);
}

test "image introspection: unknown image returns empty list" {
    var class_names = objc.runtime.classNamesForImage("/nonexistent/image/path.dylib");
    defer class_names.deinit();

    try integration_std.testing.expectEqual(@as(usize, 0), class_names.len);
    try integration_std.testing.expect(class_names.isEmpty());
}

test "image introspection: class.imageName" {
    const NSObject = objc.requireClass("NSObject");
    const image_name = NSObject.imageName();
    try integration_std.testing.expect(image_name != null);
    try integration_std.testing.expect(image_name.?.len > 0);
    try integration_std.testing.expect(integration_std.mem.indexOf(u8, image_name.?, "libobjc") != null or
        integration_std.mem.indexOf(u8, image_name.?, "Foundation") != null);
}

// --- from src/runtime/imp.zig ---
test "conversion: Imp fromRaw and toRaw roundtrip" {
    const imp = objc.requireClass("NSObject").methodImplementation(objc.sel("init")).?;
    try integration_std.testing.expect(imp.eql(Imp.fromRaw(imp.toRaw()).?));
    try integration_std.testing.expectEqual(@as(?Imp, null), Imp.fromRaw(null));
}


// --- from src/runtime/ivar.zig ---
test "ivar: dynamic class ivar introspection" {
    const NSObject = objc.requireClass("NSObject");
    const Subclass = objc.allocateClassPair(NSObject, "IvarTestClass").?;

    _ = Subclass.addIvar("test_int", @sizeOf(i32), @truncate(integration_std.math.log2(@alignOf(i32))), "i");
    _ = Subclass.addIvar("test_ptr", @sizeOf(objc.raw.id), @truncate(integration_std.math.log2(@alignOf(objc.raw.id))), "@");

    objc.registerClassPair(Subclass);
    defer objc.disposeClassPair(Subclass);

    const ivar_int = Subclass.instanceIvar("test_int").?;
    const ivar_ptr = Subclass.instanceIvar("test_ptr").?;
    try integration_std.testing.expectEqualStrings("test_int", ivar_int.name().?);
    try integration_std.testing.expectEqualStrings("test_ptr", ivar_ptr.name().?);
    try integration_std.testing.expectEqualStrings("i", ivar_int.typeEncoding().?);
    try integration_std.testing.expectEqualStrings("@", ivar_ptr.typeEncoding().?);

    const off_int = ivar_int.offset();
    const off_ptr = ivar_ptr.offset();
    try integration_std.testing.expect(off_int >= 0);
    try integration_std.testing.expect(off_ptr >= 0);
    try integration_std.testing.expect(off_int != off_ptr);
    try integration_std.testing.expect(ivar_int.eql(ivar_int));
    try integration_std.testing.expect(!ivar_int.eql(ivar_ptr));
}


// --- from src/runtime/method.zig ---
test "method: NSObject description method introspection" {
    const cls = objc.requireClass("NSObject");
    const desc_sel = objc.sel("description");
    const method = cls.instanceMethod(desc_sel).?;

    try integration_std.testing.expect(method.selector().eql(desc_sel));
    try integration_std.testing.expect(@intFromPtr(method.implementation().ptr) != 0);

    const enc = method.typeEncoding();
    try integration_std.testing.expect(enc != null);
    try integration_std.testing.expect(enc.?.len > 0);
    try integration_std.testing.expect(method.argumentCount() >= 2);

    var ret_buf: [128]u8 = undefined;
    method.returnType(&ret_buf);
    try integration_std.testing.expectEqualStrings("@", integration_std.mem.sliceTo(&ret_buf, 0));

    var arg0_buf: [128]u8 = undefined;
    method.argumentType(0, &arg0_buf);
    try integration_std.testing.expectEqualStrings("@", integration_std.mem.sliceTo(&arg0_buf, 0));

    var arg1_buf: [128]u8 = undefined;
    method.argumentType(1, &arg1_buf);
    try integration_std.testing.expectEqualStrings(":", integration_std.mem.sliceTo(&arg1_buf, 0));

    const desc_struct = method.description();
    try integration_std.testing.expect(desc_struct != null);
    try integration_std.testing.expect(desc_struct.?.selector.?.eql(desc_sel));
}

test "method: exchange implementations" {
    const NSObject = objc.requireClass("NSObject");
    const Subclass = objc.allocateClassPair(NSObject, "MethodExchangeTestClass").?;

    const Dummy = struct {
        fn m1(target: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) i32 {
            _ = target;
            _ = sel_val;
            return 100;
        }
        fn m2(target: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) i32 {
            _ = target;
            _ = sel_val;
            return 200;
        }
    };

    const sel1 = objc.sel("methodOne");
    const sel2 = objc.sel("methodTwo");
    _ = Subclass.addMethod(sel1, objc.Imp.fromRawNonNull(@ptrCast(&Dummy.m1)), "i@:");
    _ = Subclass.addMethod(sel2, objc.Imp.fromRawNonNull(@ptrCast(&Dummy.m2)), "i@:");
    objc.registerClassPair(Subclass);
    defer objc.disposeClassPair(Subclass);

    const method1 = Subclass.instanceMethod(sel1).?;
    const method2 = Subclass.instanceMethod(sel2).?;
    const inst = Subclass.send(objc.Object, "alloc", .{})
        .send(objc.Object, "init", .{});
    defer inst.send(void, "dealloc", .{});

    try integration_std.testing.expectEqual(@as(i32, 100), inst.send(i32, sel1, .{}));
    try integration_std.testing.expectEqual(@as(i32, 200), inst.send(i32, sel2, .{}));
    method1.exchange(method2);
    try integration_std.testing.expectEqual(@as(i32, 200), inst.send(i32, sel1, .{}));
    try integration_std.testing.expectEqual(@as(i32, 100), inst.send(i32, sel2, .{}));
}

test "conversion: Method fromRaw and toRaw roundtrip" {
    const cls = objc.requireClass("NSObject");
    const method = cls.instanceMethod(objc.sel("init")).?;
    const raw_method = method.toRaw();
    try integration_std.testing.expect(method.eql(Method.fromRaw(raw_method).?));
    try integration_std.testing.expectEqual(@as(?Method, null), Method.fromRaw(null));
}


// --- from src/runtime/object.zig ---
test "object: instance class and identity" {
    const cls = objc.requireClass("NSObject");
    const obj1 = cls.send(Object, "alloc", .{})
        .send(Object, "init", .{});
    defer obj1.send(void, "dealloc", .{});

    const obj2 = cls.send(Object, "alloc", .{})
        .send(Object, "init", .{});
    defer obj2.send(void, "dealloc", .{});

    try integration_std.testing.expect(obj1.class().eql(cls));
    try integration_std.testing.expectEqualStrings("NSObject", obj1.className());
    try integration_std.testing.expect(!obj1.isClass());
    try integration_std.testing.expect(obj1.eql(obj1));
    try integration_std.testing.expect(!obj1.eql(obj2));
}

test "object: setClass dynamic isa swizzling" {
    const Base = objc.requireClass("NSObject");
    const Subclass = objc.allocateClassPair(Base, "ObjectSetClassSubclass").?;
    objc.registerClassPair(Subclass);
    defer objc.disposeClassPair(Subclass);

    const obj = Base.send(Object, "alloc", .{})
        .send(Object, "init", .{});
    defer obj.send(void, "dealloc", .{});

    try integration_std.testing.expect(obj.class().eql(Base));
    const old_cls = obj.setClass(Subclass);
    try integration_std.testing.expect(old_cls.eql(Base));
    try integration_std.testing.expect(obj.class().eql(Subclass));
    _ = obj.setClass(Base);
}

test "object: getIvar and setIvar" {
    const Base = objc.requireClass("NSObject");
    const Subclass = objc.allocateClassPair(Base, "ObjectIvarTestClass").?;
    _ = Subclass.addIvar("_child", @sizeOf(raw.id), @truncate(integration_std.math.log2(@alignOf(raw.id))), "@");
    objc.registerClassPair(Subclass);
    defer objc.disposeClassPair(Subclass);

    const ivar = Subclass.instanceIvar("_child").?;
    const parent = Subclass.send(Object, "alloc", .{})
        .send(Object, "init", .{});
    defer parent.send(void, "dealloc", .{});
    const child = Base.send(Object, "alloc", .{})
        .send(Object, "init", .{});
    defer child.send(void, "dealloc", .{});

    try integration_std.testing.expectEqual(@as(?Object, null), parent.getIvar(ivar));
    parent.setIvar(ivar, child);
    try integration_std.testing.expectEqual(child.ptr, parent.getIvar(ivar).?.ptr);
    parent.setIvar(ivar, null);
    try integration_std.testing.expectEqual(@as(?Object, null), parent.getIvar(ivar));
}

test "conversion: Object fromRaw and toRaw roundtrip" {
    const cls = objc.requireClass("NSObject");
    const obj = cls.send(Object, "alloc", .{}).send(Object, "init", .{});
    defer obj.send(void, "dealloc", .{});

    const raw_id = obj.toRaw();
    try integration_std.testing.expect(raw_id != null);
    try integration_std.testing.expect(obj.eql(Object.fromRaw(raw_id).?));
    try integration_std.testing.expect(obj.eql(Object.fromRawNonNull(raw_id.?)));
    try integration_std.testing.expectEqual(@as(?Object, null), Object.fromRaw(null));
}


// --- from src/runtime/property.zig ---
test "property: dynamic class property introspection" {
    const NSObject = objc.requireClass("NSObject");
    const Subclass = objc.allocateClassPair(NSObject, "PropertyTestClass").?;
    const attrs = [_]objc.PropertyAttribute{
        .{ .name = "T", .value = "@\"NSString\"" },
        .{ .name = "C", .value = "" },
        .{ .name = "N", .value = "" },
        .{ .name = "V", .value = "_title" },
    };
    try integration_std.testing.expect(Subclass.addProperty("title", &attrs));
    objc.registerClassPair(Subclass);
    defer objc.disposeClassPair(Subclass);

    const prop = Subclass.property("title").?;
    try integration_std.testing.expectEqualStrings("title", prop.name());
    try integration_std.testing.expect(prop.attributes() != null);
    try integration_std.testing.expect(prop.attributes().?.len > 0);

    if (prop.copyAttributeValue("V")) |val| {
        var owned = val;
        defer owned.deinit();
        try integration_std.testing.expectEqualStrings("_title", owned.slice());
    } else return error.AttributeValueNotFound;
    try integration_std.testing.expect(prop.eql(prop));
}

test "conversion: Property fromRaw and toRaw roundtrip" {
    const NSObject = objc.requireClass("NSObject");
    const prop = NSObject.property("className") orelse NSObject.property("description").?;
    try integration_std.testing.expect(prop.eql(Property.fromRaw(prop.toRaw()).?));
    try integration_std.testing.expectEqual(@as(?Property, null), Property.fromRaw(null));
}


// --- from src/runtime/protocol.zig ---
test "protocol: NSObject protocol introspection" {
    const proto = objc.getProtocol("NSObject") orelse return error.ProtocolNotFound;
    try integration_std.testing.expectEqualStrings("NSObject", proto.name());
    try integration_std.testing.expect(proto.eql(objc.getProtocol("NSObject").?));
    try integration_std.testing.expect(proto.conformsTo(proto));

    const desc = proto.methodDescription(objc.sel("description"), .{
        .required = true,
        .instance = true,
    });
    try integration_std.testing.expect(desc != null);
    try integration_std.testing.expect(desc.?.selector != null);
    try integration_std.testing.expect(desc.?.selector.?.eql(objc.sel("description")));

    try integration_std.testing.expectEqual(
        @as(?objc.MethodDescription, null),
        proto.methodDescription(objc.sel("nonExistentSelector123"), .{}),
    );
}

test "protocol: requireProtocol succeeds on valid protocol" {
    const proto = objc.requireProtocol("NSObject");
    try integration_std.testing.expectEqualStrings("NSObject", proto.name());
}

test "conversion: Protocol fromRaw and toRaw roundtrip" {
    const proto = objc.getProtocol("NSObject").?;
    try integration_std.testing.expect(proto.eql(Protocol.fromRaw(proto.toRaw()).?));
    try integration_std.testing.expectEqual(@as(?Protocol, null), Protocol.fromRaw(null));
}


// --- from src/runtime/replacement.zig ---
test "method replacement: replaceWith and conflict detection" {
    const env = try setupReplacementClass("ReplacementClass");
    defer {
        env.inst.send(void, "dealloc", .{});
        objc.disposeClassPair(env.cls);
    }

    const method = env.cls.instanceMethod(objc.sel("methodA")).?;
    const custom_imp = struct {
        fn call(self: raw.id, sel_val: raw.SEL) callconv(.c) c_int {
            _ = self;
            _ = sel_val;
            return 999;
        }
    }.call;
    var replacement = MethodReplacement.replace(method, Imp.fromRawNonNull(@ptrCast(&custom_imp)));
    try integration_std.testing.expectEqual(@as(c_int, 999), objc.send(c_int, env.inst, "methodA", .{}));
    try replacement.restore();
    try integration_std.testing.expectEqual(@as(c_int, 100), objc.send(c_int, env.inst, "methodA", .{}));

    const second_imp = struct {
        fn call(self: raw.id, sel_val: raw.SEL) callconv(.c) c_int {
            _ = self;
            _ = sel_val;
            return 888;
        }
    }.call;
    var replacement_two = MethodReplacement.replace(method, Imp.fromRawNonNull(@ptrCast(&second_imp)));
    const intervening_imp = struct {
        fn call(self: raw.id, sel_val: raw.SEL) callconv(.c) c_int {
            _ = self;
            _ = sel_val;
            return 777;
        }
    }.call;
    _ = method.setImplementation(Imp.fromRawNonNull(@ptrCast(&intervening_imp)));
    try integration_std.testing.expectError(error.ImplementationChanged, replacement_two.restore());
}

test "method replacement: BlockMethodReplacement" {
    const env = try setupReplacementClass("BlockReplacementClass");
    defer {
        env.inst.send(void, "dealloc", .{});
        objc.disposeClassPair(env.cls);
    }

    const method = env.cls.instanceMethod(objc.sel("methodA")).?;
    var block_handle = try objc.OwnedBlock(fn (objc.Object) c_int).fromFunction(struct {
        fn blockImp(_: objc.Object) c_int {
            return 555;
        }
    }.blockImp);
    defer block_handle.deinit();

    var replacement = try BlockMethodReplacement.replace(method, block_handle);
    try integration_std.testing.expectEqual(@as(c_int, 555), objc.send(c_int, env.inst, "methodA", .{}));
    try replacement.restore();
    try integration_std.testing.expectEqual(@as(c_int, 100), objc.send(c_int, env.inst, "methodA", .{}));
}

// --- from src/runtime/swizzle.zig ---
test "swizzle: basic swap and restore" {
    const env = try setupSwizzleClass("SwizzleBasicClass");
    defer {
        env.inst.send(void, "dealloc", .{});
        objc.disposeClassPair(env.cls);
    }

    try integration_std.testing.expectEqual(@as(c_int, 100), objc.send(c_int, env.inst, "methodA", .{}));
    try integration_std.testing.expectEqual(@as(c_int, 200), objc.send(c_int, env.inst, "methodB", .{}));
    var swiz = Swizzle.install(env.cls.instanceMethod(objc.sel("methodA")).?, env.cls.instanceMethod(objc.sel("methodB")).?);
    try integration_std.testing.expectEqual(@as(c_int, 200), objc.send(c_int, env.inst, "methodA", .{}));
    try integration_std.testing.expectEqual(@as(c_int, 100), objc.send(c_int, env.inst, "methodB", .{}));
    swiz.restore();
    try integration_std.testing.expectEqual(@as(c_int, 100), objc.send(c_int, env.inst, "methodA", .{}));
    try integration_std.testing.expectEqual(@as(c_int, 200), objc.send(c_int, env.inst, "methodB", .{}));
}

test "swizzle: scoped RAII swizzling" {
    const env = try setupSwizzleClass("SwizzleScopedClass");
    defer {
        env.inst.send(void, "dealloc", .{});
        objc.disposeClassPair(env.cls);
    }

    const m_a = env.cls.instanceMethod(objc.sel("methodA")).?;
    const m_b = env.cls.instanceMethod(objc.sel("methodB")).?;
    {
        var scoped = ScopedSwizzle.init(m_a, m_b);
        defer scoped.deinit();
        try integration_std.testing.expectEqual(@as(c_int, 200), objc.send(c_int, env.inst, "methodA", .{}));
        try integration_std.testing.expectEqual(@as(c_int, 100), objc.send(c_int, env.inst, "methodB", .{}));
    }
    try integration_std.testing.expectEqual(@as(c_int, 100), objc.send(c_int, env.inst, "methodA", .{}));
    try integration_std.testing.expectEqual(@as(c_int, 200), objc.send(c_int, env.inst, "methodB", .{}));
}

test "swizzle: installChecked signature validation" {
    const env = try setupSwizzleClass("SwizzleCheckedClass");
    defer {
        env.inst.send(void, "dealloc", .{});
        objc.disposeClassPair(env.cls);
    }

    const m_a = env.cls.instanceMethod(objc.sel("methodA")).?;
    const m_b = env.cls.instanceMethod(objc.sel("methodB")).?;
    const mismatched = env.cls.instanceMethod(objc.sel("methodMismatched")).?;
    var swiz = try Swizzle.installChecked(integration_std.testing.allocator, m_a, m_b);
    defer swiz.restore();
    try integration_std.testing.expectError(error.IncompatibleSignatures, Swizzle.installChecked(integration_std.testing.allocator, m_a, mismatched));
}

// --- from src/memory/autorelease_pool.zig ---
test "AutoreleasePool: drains autoreleased object" {
    const cls = getOrCreatePoolTestClass();
    const initial_count = g_pool_dealloc_count;
    var pool = AutoreleasePool.init();
    const obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    _ = obj.send(objc.Object, "autorelease", .{});
    try integration_std.testing.expectEqual(initial_count, g_pool_dealloc_count);
    pool.drain();
    try integration_std.testing.expectEqual(initial_count + 1, g_pool_dealloc_count);
}

test "AutoreleasePool: nested pools follow LIFO drain ordering" {
    const cls = getOrCreatePoolTestClass();
    const initial_count = g_pool_dealloc_count;
    var outer_pool = AutoreleasePool.init();
    defer outer_pool.deinit();
    const outer_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    _ = outer_obj.send(objc.Object, "autorelease", .{});

    {
        var inner_pool = AutoreleasePool.init();
        const inner_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
        _ = inner_obj.send(objc.Object, "autorelease", .{});
        try integration_std.testing.expectEqual(initial_count, g_pool_dealloc_count);
        inner_pool.drain();
        try integration_std.testing.expectEqual(initial_count + 1, g_pool_dealloc_count);
    }
    outer_pool.drain();
    try integration_std.testing.expectEqual(initial_count + 2, g_pool_dealloc_count);
}

// --- from src/memory/owned_c_string.zig ---
test "OwnedCString: method.copyReturnType" {
    const method = objc.requireClass("NSObject").instanceMethod(objc.sel("description")).?;
    var ret_type = method.copyReturnType().?;
    defer ret_type.deinit();
    try integration_std.testing.expectEqualStrings("@", ret_type.slice());
    try integration_std.testing.expectEqual(@as(usize, 1), ret_type.len());
    ret_type.deinit();
    try integration_std.testing.expectEqual(@as(usize, 0), ret_type.len());
}

test "OwnedCString: method.copyArgumentType" {
    const method = objc.requireClass("NSObject").instanceMethod(objc.sel("isEqual:")).?;
    var arg0 = method.copyArgumentType(0).?;
    defer arg0.deinit();
    try integration_std.testing.expectEqualStrings("@", arg0.slice());
    var arg1 = method.copyArgumentType(1).?;
    defer arg1.deinit();
    try integration_std.testing.expectEqualStrings(":", arg1.slice());
    var arg2 = method.copyArgumentType(2).?;
    defer arg2.deinit();
    try integration_std.testing.expectEqualStrings("@", arg2.slice());
    try integration_std.testing.expect(method.copyArgumentType(99) == null);
}

test "OwnedCString: property.copyAttributeValue" {
    const NSObject = objc.requireClass("NSObject");
    if (NSObject.property("className")) |prop| {
        if (prop.copyAttributeValue("T")) |val| {
            var owned = val;
            defer owned.deinit();
            try integration_std.testing.expect(owned.len() > 0);
        }
    }
}

test "OwnedCString: intoRaw relinquishes ownership" {
    const method = objc.requireClass("NSObject").instanceMethod(objc.sel("description")).?;
    var ret_type = method.copyReturnType().?;
    const raw_ptr = ret_type.intoRaw();
    try integration_std.testing.expectEqual(@as(usize, 0), ret_type.len());
    ret_type.deinit();
    try integration_std.testing.expectEqualStrings("@", integration_std.mem.span(raw_ptr));
    integration_std.c.free(@ptrCast(raw_ptr));
}


// --- from src/memory/owned_c_string_list.zig ---
test "OwnedCStringList: runtime.imageNames and classNamesForImage" {
    var images = objc.runtime.imageNames();
    defer images.deinit();
    try integration_std.testing.expect(!images.isEmpty());
    try integration_std.testing.expect(images.count() > 0);
    try integration_std.testing.expect(images.get(0).?.len > 0);

    var count: usize = 0;
    var iter = images.iterator();
    while (iter.next()) |_| count += 1;
    try integration_std.testing.expectEqual(images.count(), count);

    var libobjc_image: ?[:0]const u8 = null;
    var img_iter = images.iterator();
    while (img_iter.next()) |img| {
        if (integration_std.mem.indexOf(u8, img, "libobjc") != null) {
            libobjc_image = img;
            break;
        }
    }
    if (libobjc_image) |target_image| {
        var class_names = objc.runtime.classNamesForImage(target_image);
        defer class_names.deinit();
        try integration_std.testing.expect(class_names.count() > 0);
        try integration_std.testing.expect(class_names.get(0).?.len > 0);
    }
}


// --- from src/memory/owned_method_descriptions.zig ---
test "OwnedMethodDescriptions: protocol.methodDescriptions" {
    const proto = objc.getProtocol("NSObject").?;
    var req_methods = proto.methodDescriptions(.{ .required = true, .instance = true });
    defer req_methods.deinit();
    try integration_std.testing.expect(!req_methods.isEmpty());
    try integration_std.testing.expect(req_methods.count() > 0);
    try integration_std.testing.expect(req_methods.get(0).?.selector.?.name().len > 0);

    var count: usize = 0;
    var iter = req_methods.iterator();
    while (iter.next()) |_| count += 1;
    try integration_std.testing.expectEqual(req_methods.count(), count);
}


// --- from src/memory/owned_property_attributes.zig ---
test "OwnedPropertyAttributes: property.attributesList" {
    const NSObject = objc.requireClass("NSObject");
    const prop = NSObject.property("className") orelse NSObject.property("description").?;
    var attrs = prop.attributesList();
    defer attrs.deinit();
    try integration_std.testing.expect(!attrs.isEmpty());
    try integration_std.testing.expect(attrs.count() > 0);
    try integration_std.testing.expect(integration_std.mem.span(attrs.get(0).?.name).len > 0);

    var count: usize = 0;
    var iter = attrs.iterator();
    while (iter.next()) |_| count += 1;
    try integration_std.testing.expectEqual(attrs.count(), count);
}


// --- from src/memory/owned_runtime_list.zig ---
test "OwnedRuntimeList: class.methods and dupe" {
    const NSObject = objc.requireClass("NSObject");
    var method_list = NSObject.methods();
    try integration_std.testing.expect(!method_list.isEmpty());
    try integration_std.testing.expect(method_list.count() > 0);
    const first_method = method_list.get(0).?;

    var iter = method_list.iterator();
    var iterated_count: usize = 0;
    while (iter.next()) |_| iterated_count += 1;
    try integration_std.testing.expectEqual(method_list.count(), iterated_count);

    const duped = try method_list.dupe(integration_std.testing.allocator);
    defer integration_std.testing.allocator.free(duped);
    try integration_std.testing.expectEqual(method_list.count(), duped.len);
    method_list.deinit();
    try integration_std.testing.expect(method_list.isEmpty());
    try integration_std.testing.expectEqual(first_method.toRaw(), duped[0].toRaw());
}

test "OwnedRuntimeList: class.classMethods" {
    var class_methods = objc.requireClass("NSObject").classMethods();
    defer class_methods.deinit();
    try integration_std.testing.expect(!class_methods.isEmpty());
    try integration_std.testing.expect(class_methods.count() > 0);
}

test "OwnedRuntimeList: class.properties" {
    var props = objc.requireClass("NSObject").properties();
    defer props.deinit();
    try integration_std.testing.expect(!props.isEmpty());
    try integration_std.testing.expect(props.count() > 0);
}

test "OwnedRuntimeList: class.protocols" {
    var protos = objc.requireClass("NSObject").protocols();
    defer protos.deinit();
    try integration_std.testing.expect(protos.count() >= 0);
}

test "OwnedRuntimeList: class.ivars" {
    var ivars = objc.requireClass("NSObject").ivars();
    defer ivars.deinit();
    try integration_std.testing.expect(ivars.count() >= 1);
    try integration_std.testing.expectEqualStrings("isa", ivars.get(0).?.name().?);
}

test "OwnedRuntimeList: objc.classes" {
    var all_classes = objc.classes();
    defer all_classes.deinit();
    try integration_std.testing.expect(all_classes.count() >= 5);

    var found_nsobject = false;
    var iter = all_classes.iterator();
    while (iter.next()) |cls| {
        if (integration_std.mem.eql(u8, cls.name(), "NSObject")) {
            found_nsobject = true;
            break;
        }
    }
    try integration_std.testing.expect(found_nsobject);
}

test "OwnedRuntimeList: objc.protocols" {
    var all_protocols = objc.protocols();
    defer all_protocols.deinit();
    try integration_std.testing.expect(all_protocols.count() > 10);

    var found_nsobject_proto = false;
    var iter = all_protocols.iterator();
    while (iter.next()) |proto| {
        if (integration_std.mem.eql(u8, proto.name(), "NSObject")) {
            found_nsobject_proto = true;
            break;
        }
    }
    try integration_std.testing.expect(found_nsobject_proto);
}

test "OwnedRuntimeList: empty container behavior" {
    var empty_list = objc.memory.OwnedRuntimeList(objc.Method).empty();
    try integration_std.testing.expect(empty_list.isEmpty());
    try integration_std.testing.expectEqual(@as(usize, 0), empty_list.count());
    try integration_std.testing.expect(empty_list.get(0) == null);
    var iter = empty_list.iterator();
    try integration_std.testing.expect(iter.next() == null);
    empty_list.deinit();
    try integration_std.testing.expect(empty_list.isEmpty());
}

// --- from src/memory/retained.zig ---
test "Retained: compile-time retainable traits" {
    const traits_mod = objc.memory.traits;
    try integration_std.testing.expect(traits_mod.isRetainable(objc.Object));
    try integration_std.testing.expect(!traits_mod.isRetainable(objc.Class));
    try integration_std.testing.expect(!traits_mod.isRetainable(i32));
}

test "Retained: adopt takes ownership and deinit releases" {
    const cls = getOrCreateTestClass();
    const initial_count = g_dealloc_count;
    const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var retained = memory.Retained(objc.Object).adopt(raw_obj);
    try integration_std.testing.expectEqual(initial_count, g_dealloc_count);
    try integration_std.testing.expectEqual(raw_obj.toRaw(), retained.borrow().toRaw());
    retained.deinit();
    try integration_std.testing.expectEqual(initial_count + 1, g_dealloc_count);
    retained.deinit();
}

test "Retained: retain increments retain count" {
    const cls = getOrCreateTestClass();
    const initial_count = g_dealloc_count;
    const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var r1 = memory.Retained(objc.Object).adopt(raw_obj);
    var r2 = memory.Retained(objc.Object).retain(r1.borrow());
    r1.deinit();
    try integration_std.testing.expectEqual(initial_count, g_dealloc_count);
    r2.deinit();
    try integration_std.testing.expectEqual(initial_count + 1, g_dealloc_count);
}

test "Retained: clone increments retain count" {
    const cls = getOrCreateTestClass();
    const initial_count = g_dealloc_count;
    const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var r1 = memory.Retained(objc.Object).adopt(raw_obj);
    var r2 = r1.clone();
    r1.deinit();
    try integration_std.testing.expectEqual(initial_count, g_dealloc_count);
    r2.deinit();
    try integration_std.testing.expectEqual(initial_count + 1, g_dealloc_count);
}

test "Retained: intoUnmanaged relinquishes ownership without releasing" {
    const cls = getOrCreateTestClass();
    const initial_count = g_dealloc_count;
    const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var retained = memory.Retained(objc.Object).adopt(raw_obj);
    const unmanaged = retained.intoUnmanaged();
    retained.deinit();
    try integration_std.testing.expectEqual(initial_count, g_dealloc_count);
    _ = objc.raw.compiler_runtime.objc_release(unmanaged.toRaw());
    try integration_std.testing.expectEqual(initial_count + 1, g_dealloc_count);
}

test "Retained: retainOptional and adoptOptional" {
    const cls = getOrCreateTestClass();
    const initial_count = g_dealloc_count;
    try integration_std.testing.expect(memory.Retained(objc.Object).adoptOptional(null) == null);
    try integration_std.testing.expect(memory.Retained(objc.Object).retainOptional(null) == null);

    const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    if (memory.Retained(objc.Object).adoptOptional(raw_obj)) |*retained| {
        var mutable = retained.*;
        defer mutable.deinit();
        try integration_std.testing.expectEqual(raw_obj.toRaw(), mutable.borrow().toRaw());
    } else return error.UnexpectedNull;
    try integration_std.testing.expectEqual(initial_count + 1, g_dealloc_count);
}

test "Retained: createInstanceRetained on Class" {
    const cls = getOrCreateTestClass();
    const initial_count = g_dealloc_count;
    var retained = cls.createInstanceRetained(0).?;
    _ = retained.borrow().send(objc.Object, "init", .{});
    retained.deinit();
    try integration_std.testing.expectEqual(initial_count + 1, g_dealloc_count);
}

fn consumeThroughPointer(owner: *memory.Retained(objc.Object)) void {
    // Recommended pattern: owners travel by pointer, never by value.
    owner.deinit();
}

test "Retained: pointer-passing invalidates owner without copying" {
    const cls = getOrCreateTestClass();
    const initial_count = g_dealloc_count;
    const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var retained = memory.Retained(objc.Object).adopt(raw_obj);
    consumeThroughPointer(&retained);
    try integration_std.testing.expectEqual(initial_count + 1, g_dealloc_count);
    // Second deinit on the same (now empty) value is a safe no-op.
    retained.deinit();
    try integration_std.testing.expectEqual(initial_count + 1, g_dealloc_count);
}

// --- from src/memory/weak.zig ---
test "Weak: in-place initialization and loadRetained while alive" {
    const cls = getOrCreateWeakTestClass();
    const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var strong = memory.Retained(objc.Object).adopt(raw_obj);
    defer strong.deinit();
    var weak: memory.Weak(objc.Object) = .{};
    weak.init(strong.borrow());
    defer weak.deinit();

    if (weak.loadRetained()) |*loaded| {
        var mutable = loaded.*;
        defer mutable.deinit();
        try integration_std.testing.expectEqual(strong.borrow().toRaw(), mutable.borrow().toRaw());
    } else return error.ExpectedNonNullWeak;
}

test "Weak: automatic zeroing when strong owner deallocates" {
    const cls = getOrCreateWeakTestClass();
    const initial_dealloc = g_weak_dealloc_count;
    var weak: memory.Weak(objc.Object) = .{};
    defer weak.deinit();
    {
        const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
        var strong = memory.Retained(objc.Object).adopt(raw_obj);
        weak.init(strong.borrow());
        if (weak.loadRetained()) |*loaded| {
            var mutable = loaded.*;
            mutable.deinit();
        } else return error.ExpectedNonNullWeak;
        try integration_std.testing.expectEqual(initial_dealloc, g_weak_dealloc_count);
        strong.deinit();
        try integration_std.testing.expectEqual(initial_dealloc + 1, g_weak_dealloc_count);
    }
    try integration_std.testing.expect(weak.loadRetained() == null);
}

test "Weak: store and clear" {
    const cls = getOrCreateWeakTestClass();
    const raw_obj1 = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var strong1 = memory.Retained(objc.Object).adopt(raw_obj1);
    defer strong1.deinit();
    const raw_obj2 = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var strong2 = memory.Retained(objc.Object).adopt(raw_obj2);
    defer strong2.deinit();
    var weak: memory.Weak(objc.Object) = .{};
    weak.init(strong1.borrow());
    defer weak.deinit();

    try integration_std.testing.expect(weak.loadRetained() != null);
    if (weak.loadRetained()) |*loaded| {
        var mutable = loaded.*;
        mutable.deinit();
    }
    weak.store(strong2.borrow());
    if (weak.loadRetained()) |*loaded| {
        var mutable = loaded.*;
        defer mutable.deinit();
        try integration_std.testing.expectEqual(strong2.borrow().toRaw(), mutable.borrow().toRaw());
    } else return error.ExpectedNonNull;
    weak.clear();
    try integration_std.testing.expect(weak.loadRetained() == null);
}

test "Weak: copyFrom and moveFrom" {
    const cls = getOrCreateWeakTestClass();
    const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var strong = memory.Retained(objc.Object).adopt(raw_obj);
    defer strong.deinit();
    var weak1: memory.Weak(objc.Object) = .{};
    weak1.init(strong.borrow());
    defer weak1.deinit();
    var weak2: memory.Weak(objc.Object) = .{};
    defer weak2.deinit();
    weak2.copyFrom(&weak1);
    try integration_std.testing.expect(weak1.loadRetained() != null);
    if (weak1.loadRetained()) |*loaded| {
        var mutable = loaded.*;
        mutable.deinit();
    }
    var weak3: memory.Weak(objc.Object) = .{};
    defer weak3.deinit();
    weak3.moveFrom(&weak2);
    try integration_std.testing.expect(weak2.loadRetained() == null);
    try integration_std.testing.expect(weak3.loadRetained() != null);
    if (weak3.loadRetained()) |*loaded| {
        var mutable = loaded.*;
        mutable.deinit();
    }
}

test "Weak: loadBorrowed with autorelease pool" {
    const cls = getOrCreateWeakTestClass();
    const raw_obj = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    var strong = memory.Retained(objc.Object).adopt(raw_obj);
    defer strong.deinit();
    var weak: memory.Weak(objc.Object) = .{};
    weak.init(strong.borrow());
    defer weak.deinit();
    var pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    try integration_std.testing.expectEqual(strong.borrow().toRaw(), weak.loadBorrowed().?.toRaw());
}

// --- helpers from src/runtime/replacement.zig ---
fn setupReplacementClass(name: [:0]const u8) !struct { cls: objc.Class, inst: objc.Object } {
    const super_cls = objc.requireClass("NSObject");
    const dyn_cls = raw.runtime.objc_allocateClassPair(super_cls.toRaw(), name.ptr, 0) orelse
        return error.ClassAllocFailed;

    const original_imp = struct {
        fn call(self: raw.id, sel_val: raw.SEL) callconv(.c) c_int {
            _ = self;
            _ = sel_val;
            return 100;
        }
    }.call;
    _ = raw.runtime.class_addMethod(dyn_cls, objc.sel("methodA").toRaw(), @ptrCast(&original_imp), "i@:");
    raw.runtime.objc_registerClassPair(dyn_cls);

    const cls = objc.Class.fromRaw(dyn_cls).?;
    const inst = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    return .{ .cls = cls, .inst = inst };
}

// --- helpers from src/runtime/swizzle.zig ---
fn setupSwizzleClass(name: [:0]const u8) !struct { cls: objc.Class, inst: objc.Object } {
    const super_cls = objc.requireClass("NSObject");
    const dyn_cls = raw.runtime.objc_allocateClassPair(super_cls.toRaw(), name.ptr, 0) orelse
        return error.ClassAllocFailed;

    const fn_a = struct {
        fn imp(self: raw.id, sel_val: raw.SEL) callconv(.c) c_int {
            _ = self;
            _ = sel_val;
            return 100;
        }
    }.imp;
    const fn_b = struct {
        fn imp(self: raw.id, sel_val: raw.SEL) callconv(.c) c_int {
            _ = self;
            _ = sel_val;
            return 200;
        }
    }.imp;
    const fn_mismatched = struct {
        fn imp(self: raw.id, sel_val: raw.SEL) callconv(.c) f32 {
            _ = self;
            _ = sel_val;
            return 1.5;
        }
    }.imp;

    _ = raw.runtime.class_addMethod(dyn_cls, objc.sel("methodA").toRaw(), @ptrCast(&fn_a), "i@:");
    _ = raw.runtime.class_addMethod(dyn_cls, objc.sel("methodB").toRaw(), @ptrCast(&fn_b), "i@:");
    _ = raw.runtime.class_addMethod(dyn_cls, objc.sel("methodMismatched").toRaw(), @ptrCast(&fn_mismatched), "f@:");
    raw.runtime.objc_registerClassPair(dyn_cls);

    const cls = objc.Class.fromRaw(dyn_cls).?;
    const inst = cls.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{});
    return .{ .cls = cls, .inst = inst };
}

// --- helpers from src/memory/retained.zig ---
var g_super_dealloc_fn: ?*const fn (objc.raw.id, objc.raw.SEL) callconv(.c) void = null;
fn customDealloc(self_id: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) void {
    g_dealloc_count += 1;
    if (g_super_dealloc_fn) |super_fn| super_fn(self_id, sel_val);
}
fn getOrCreateTestClass() objc.Class {
    const class_name = "RetainedLifecycleTestClass";
    if (objc.getClass(class_name)) |existing| return existing;

    const NSObject = objc.requireClass("NSObject");
    const cls = objc.allocateClassPair(NSObject, class_name).?;
    g_super_dealloc_fn = @ptrCast(NSObject.instanceMethod(objc.sel("dealloc")).?.implementation().toRaw());
    _ = cls.addMethod(objc.sel("dealloc"), objc.Imp.fromRawNonNull(@ptrCast(&customDealloc)), "v@:");
    objc.registerClassPair(cls);
    return cls;
}

// --- helpers from src/memory/weak.zig ---
var g_weak_super_dealloc_fn: ?*const fn (objc.raw.id, objc.raw.SEL) callconv(.c) void = null;
fn customWeakDealloc(self_id: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) void {
    g_weak_dealloc_count += 1;
    if (g_weak_super_dealloc_fn) |super_fn| super_fn(self_id, sel_val);
}
fn getOrCreateWeakTestClass() objc.Class {
    const class_name = "WeakLifecycleTestClass";
    if (objc.getClass(class_name)) |existing| return existing;

    const NSObject = objc.requireClass("NSObject");
    const cls = objc.allocateClassPair(NSObject, class_name).?;
    g_weak_super_dealloc_fn = @ptrCast(NSObject.instanceMethod(objc.sel("dealloc")).?.implementation().toRaw());
    _ = cls.addMethod(objc.sel("dealloc"), objc.Imp.fromRawNonNull(@ptrCast(&customWeakDealloc)), "v@:");
    objc.registerClassPair(cls);
    return cls;
}

// --- helpers from src/memory/autorelease_pool.zig ---
var g_pool_super_dealloc_fn: ?*const fn (objc.raw.id, objc.raw.SEL) callconv(.c) void = null;
fn customPoolDealloc(self_id: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) void {
    g_pool_dealloc_count += 1;
    if (g_pool_super_dealloc_fn) |super_fn| super_fn(self_id, sel_val);
}
fn getOrCreatePoolTestClass() objc.Class {
    const class_name = "AutoreleasePoolLifecycleTestClass";
    if (objc.getClass(class_name)) |existing| return existing;

    const NSObject = objc.requireClass("NSObject");
    const cls = objc.allocateClassPair(NSObject, class_name).?;
    g_pool_super_dealloc_fn = @ptrCast(NSObject.instanceMethod(objc.sel("dealloc")).?.implementation().toRaw());
    _ = cls.addMethod(objc.sel("dealloc"), objc.Imp.fromRawNonNull(@ptrCast(&customPoolDealloc)), "v@:");
    objc.registerClassPair(cls);
    return cls;
}
