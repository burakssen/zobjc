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
    defer sub.send(void, "dealloc", .{});

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
    defer fixture.send(void, "dealloc", .{});

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
    defer fixture.send(void, "dealloc", .{});

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
    defer fixture.send(void, "dealloc", .{});

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
    defer fixture.send(void, "dealloc", .{});

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
    try integration_std.testing.expectEqual(@as(c_int, 55), sum);
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
    try integration_std.testing.expectEqual(@as(f64, 55.0), sum);
}

test "sendChecked: valid NSObject messages pass signature validation" {
    const NSObject = objc.requireClass("NSObject");

    const obj = sendChecked(objc.Object, NSObject, "alloc", .{});
    const init = sendChecked(objc.Object, obj, "init", .{});
    defer init.send(void, "dealloc", .{});

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
