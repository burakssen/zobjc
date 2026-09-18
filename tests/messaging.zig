const objc = @import("zobjc");
const std = @import("std");
const testing = std.testing;

// --- Messaging integration: live dispatch tests needing runtime/facade. ---
// Pure classifier/normalization unit tests stay inside `src/messaging`;
// anything touching live objects, fixtures, or the facade API lives here.

var g_base_class: objc.Class = undefined;
var g_child_class: objc.Class = undefined;
var g_grandchild_class: objc.Class = undefined;

fn baseIdentify(self: objc.raw.id, _cmd: objc.raw.SEL) callconv(.c) [*:0]const u8 {
    _ = self;
    _ = _cmd;
    return "Base";
}

fn childIdentify(self: objc.raw.id, _cmd: objc.raw.SEL) callconv(.c) [*:0]const u8 {
    _ = self;
    _ = _cmd;
    return "Child";
}

fn childSuperIdentify(self: objc.raw.id, _cmd: objc.raw.SEL) callconv(.c) [*:0]const u8 {
    _ = _cmd;
    const obj = objc.Object.fromRawNonNull(self.?);
    return objc.sendSuper([*:0]const u8, obj, g_child_class, "identify", .{});
}

fn grandchildIdentify(self: objc.raw.id, _cmd: objc.raw.SEL) callconv(.c) [*:0]const u8 {
    _ = self;
    _ = _cmd;
    return "Grandchild";
}

fn grandchildSuperIdentify(self: objc.raw.id, _cmd: objc.raw.SEL) callconv(.c) [*:0]const u8 {
    _ = _cmd;
    const obj = objc.Object.fromRawNonNull(self.?);
    return objc.sendSuper([*:0]const u8, obj, g_grandchild_class, "identify", .{});
}

test "super: 3-level class hierarchy with Super2 lookup" {
    const NSObject = objc.getClass("NSObject").?;

    const base_pair = objc.allocateClassPair(NSObject, "SuperTestBase").?;
    _ = objc.raw.runtime.class_addMethod(
        base_pair.ptr,
        objc.sel("identify").toRaw(),
        @ptrCast(&baseIdentify),
        "r*@:",
    );
    g_base_class = base_pair;
    objc.registerClassPair(base_pair);
    defer objc.disposeClassPair(g_base_class);

    const child_pair = objc.allocateClassPair(g_base_class, "SuperTestChild").?;
    _ = objc.raw.runtime.class_addMethod(
        child_pair.ptr,
        objc.sel("identify").toRaw(),
        @ptrCast(&childIdentify),
        "r*@:",
    );
    _ = objc.raw.runtime.class_addMethod(
        child_pair.ptr,
        objc.sel("superIdentify").toRaw(),
        @ptrCast(&childSuperIdentify),
        "r*@:",
    );
    g_child_class = child_pair;
    objc.registerClassPair(child_pair);
    defer objc.disposeClassPair(g_child_class);

    const grandchild_pair = objc.allocateClassPair(g_child_class, "SuperTestGrandchild").?;
    _ = objc.raw.runtime.class_addMethod(
        grandchild_pair.ptr,
        objc.sel("identify").toRaw(),
        @ptrCast(&grandchildIdentify),
        "r*@:",
    );
    _ = objc.raw.runtime.class_addMethod(
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

    try std.testing.expectEqualStrings("Child", std.mem.span(objc.send([*:0]const u8, child_obj, "identify", .{})));
    try std.testing.expectEqualStrings("Grandchild", std.mem.span(objc.send([*:0]const u8, grandchild_obj, "identify", .{})));

    const child_super = objc.send([*:0]const u8, child_obj, "superIdentify", .{});
    try std.testing.expectEqualStrings("Base", std.mem.span(child_super));

    const grandchild_super = objc.send([*:0]const u8, grandchild_obj, "superIdentify", .{});
    try std.testing.expectEqualStrings("Child", std.mem.span(grandchild_super));
}

test "differential: super dispatch matches native Objective-C super behavior" {
    const ABISubclass = objc.getClass("ABISubclass").?;
    const sub = objc.send(objc.Object, ABISubclass, "alloc", .{}).send(objc.Object, "init", .{});
    defer sub.send(void, "release", .{});

    const overridden = sub.send(c_int, "echoInt:", .{@as(c_int, 5)});
    try std.testing.expectEqual(@as(c_int, 50), overridden);

    const native_super = sub.send(c_int, "callSuperEcho:", .{@as(c_int, 5)});
    try std.testing.expectEqual(@as(c_int, 5), native_super);

    const zig_super = objc.sendSuper(c_int, sub, ABISubclass, "echoInt:", .{@as(c_int, 5)});
    try std.testing.expectEqual(@as(c_int, 5), zig_super);
}

test "invoke: objc.Method.invoke matches objc.send" {
    const ABIFixture = objc.getClass("ABIFixture").?;
    const inst = objc.send(objc.Object, ABIFixture, "new", .{});
    defer inst.send(void, "release", .{});

    const method = ABIFixture.instanceMethod(objc.sel("returnInt")).?;
    const val = method.invoke(c_int, inst, .{});
    try std.testing.expectEqual(@as(c_int, 42), val);

    const send_val = objc.send(c_int, inst, "returnInt", .{});
    try std.testing.expectEqual(send_val, val);
}

test "invoke: callImp directly invokes IMP function pointer" {
    const ABIFixture = objc.getClass("ABIFixture").?;
    const inst = objc.send(objc.Object, ABIFixture, "new", .{});
    defer inst.send(void, "release", .{});

    const method = ABIFixture.instanceMethod(objc.sel("returnInt")).?;
    const imp = method.implementation();
    const val = objc.callImp(c_int, imp, inst, objc.sel("returnInt"), .{});
    try std.testing.expectEqual(@as(c_int, 42), val);
}

test "differential: objc.Method.invoke agrees with ordinary message dispatch" {
    const ABIFixture = objc.getClass("ABIFixture").?;
    const fixture = objc.send(objc.Object, ABIFixture, "alloc", .{}).send(objc.Object, "init", .{});
    defer fixture.send(void, "release", .{});

    const method = ABIFixture.instanceMethod(objc.sel("echoInt:")).?;
    const res1 = fixture.send(c_int, "echoInt:", .{@as(c_int, 123)});
    const res2 = method.invoke(c_int, fixture, .{@as(c_int, 123)});

    try std.testing.expectEqual(res1, res2);
    try std.testing.expectEqual(@as(c_int, 123), res2);
}

test "send: class method invocation and object creation" {
    const ABIFixture = objc.getClass("ABIFixture").?;

    const sum = objc.send(c_int, ABIFixture, "addInt:to:", .{ @as(c_int, 20), @as(c_int, 22) });
    try std.testing.expectEqual(@as(c_int, 42), sum);

    const inst = objc.send(objc.Object, ABIFixture, "new", .{});
    defer inst.send(void, "release", .{});

    const val = objc.send(c_int, inst, "echoInt:", .{@as(c_int, 42)});
    try std.testing.expectEqual(@as(c_int, 42), val);
}

test "send: scalar arguments and returns" {
    const ABIFixture = objc.getClass("ABIFixture").?;

    const prod = objc.send(f64, ABIFixture, "multiplyDouble:by:", .{ @as(f64, 2.0), @as(f64, 3.14159) });
    try std.testing.expectApproxEqAbs(@as(f64, 6.28318), prod, 0.0001);

    const inst = objc.send(objc.Object, ABIFixture, "new", .{});
    defer inst.send(void, "release", .{});

    const val = objc.send(c_int, inst, "returnInt", .{});
    try std.testing.expectEqual(@as(c_int, 42), val);
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
    try std.testing.expectEqual(@as(f64, 10.0), pt.x);
    try std.testing.expectEqual(@as(f64, 20.0), pt.y);
}

test "send: nil receiver semantics" {
    const nil_obj: ?objc.Object = null;

    const int_val = objc.send(c_int, nil_obj, "returnInt", .{});
    try std.testing.expectEqual(@as(c_int, 0), int_val);

    const obj_val = objc.send(?objc.Object, nil_obj, "description", .{});
    try std.testing.expectEqual(@as(?objc.Object, null), obj_val);
}

test "send: object and class convenience methods" {
    const ABIFixture = objc.getClass("ABIFixture").?;

    const sum = ABIFixture.send(c_int, "addInt:to:", .{ @as(c_int, 40), @as(c_int, 60) });
    try std.testing.expectEqual(@as(c_int, 100), sum);

    const inst = ABIFixture.send(objc.Object, "new", .{});
    defer inst.send(void, "release", .{});

    const val = inst.send(c_int, "echoInt:", .{@as(c_int, 100)});
    try std.testing.expectEqual(@as(c_int, 100), val);

    const sum2 = ABIFixture.send(c_int, "addInt:to:", .{ @as(c_int, 150), @as(c_int, 50) });
    try std.testing.expectEqual(@as(c_int, 200), sum2);

    const val2 = inst.send(c_int, "echoInt:", .{@as(c_int, 200)});
    try std.testing.expectEqual(@as(c_int, 200), val2);
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
    try std.testing.expectEqual(@as(c_int, 42), int_val);

    const float_val = fixture.send(f32, "returnFloat", .{});
    try std.testing.expectApproxEqAbs(@as(f32, 3.14), float_val, 0.001);

    const dbl_val = objc.send(f64, fixture, "returnDouble", .{});
    try std.testing.expectApproxEqAbs(@as(f64, 2.718281828), dbl_val, 0.00001);

    objc.send(void, fixture, "returnVoid", .{});
    const long_double_val = fixture.send(c_longdouble, "returnLongDouble", .{});
    try std.testing.expectApproxEqAbs(@as(c_longdouble, 1.41421356237309504880), long_double_val, 0.0000001);
}

test "differential: small structures (<= 16 bytes) on ABIFixture" {
    const fixture = newABIFixture();
    defer fixture.send(void, "release", .{});

    const s1 = objc.send(ABISize1, fixture, "returnSize1", .{});
    try std.testing.expectEqual(@as(u8, 'A'), @as(u8, @intCast(s1.a)));

    const s2 = fixture.send(ABISize2, "returnSize2", .{});
    try std.testing.expectEqual(@as(c_short, 100), s2.a);

    const s3 = fixture.send(ABISize3, "returnSize3", .{});
    try std.testing.expectEqual(@as(u8, 'B'), s3.a);
    try std.testing.expectEqual(@as(c_short, 200), s3.b);

    const s4 = objc.send(ABISize4, fixture, "returnSize4", .{});
    try std.testing.expectEqual(@as(c_int, 1000), s4.a);

    const s7 = fixture.send(ABISize7, "returnSize7", .{});
    try std.testing.expectEqual(@as(c_int, 10), s7.a);
    try std.testing.expectEqual(@as(u8, 'x'), s7.b);
    try std.testing.expectEqual(@as(u8, 'y'), s7.c);
    try std.testing.expectEqual(@as(u8, 'z'), s7.d);

    const s8 = objc.send(ABISize8, fixture, "returnSize8", .{});
    try std.testing.expectEqual(@as(c_longlong, 1234567890123), s8.a);

    const s8_mixed = fixture.send(ABISize8Mixed, "returnSize8Mixed", .{});
    try std.testing.expectEqual(@as(c_int, 10), s8_mixed.a);
    try std.testing.expectEqual(@as(f32, 20.0), s8_mixed.b);

    const s9 = fixture.send(ABISize9, "returnSize9", .{});
    try std.testing.expectEqual(@as(i64, 123), s9.a);
    try std.testing.expectEqual(@as(u8, 'c'), s9.b);

    const s12 = fixture.send(ABISize12, "returnSize12", .{});
    try std.testing.expectEqual(@as(c_int, 1), s12.a);
    try std.testing.expectEqual(@as(c_int, 2), s12.b);
    try std.testing.expectEqual(@as(c_int, 3), s12.c);

    const s16i = objc.send(ABISize16Int, fixture, "returnSize16Int", .{});
    try std.testing.expectEqual(@as(c_longlong, 100), s16i.a);
    try std.testing.expectEqual(@as(c_longlong, 200), s16i.b);

    const s16f = objc.send(ABISize16Float, fixture, "returnSize16Float", .{});
    try std.testing.expectEqual(1.5, s16f.a);
    try std.testing.expectEqual(2.5, s16f.b);

    const s16_mixed = fixture.send(ABISize16Mixed, "returnSize16Mixed", .{});
    try std.testing.expectEqual(@as(c_int, 42), s16_mixed.a);
    try std.testing.expectEqual(@as(f64, 3.14), s16_mixed.b);

    const pt = objc.send(ABIPoint, fixture, "returnPoint", .{});
    try std.testing.expectEqual(10.0, pt.x);
    try std.testing.expectEqual(20.0, pt.y);

    const union_value = fixture.send(ABIUnion8, "returnUnion8", .{});
    try std.testing.expectEqual(@as(i64, 0x123456789ABCDEF0), union_value.i);
}

test "differential: large structures and aggregate arguments on ABIFixture" {
    const fixture = newABIFixture();
    defer fixture.send(void, "release", .{});

    const s24 = objc.send(ABISize24, fixture, "returnSize24", .{});
    try std.testing.expectEqual(1.0, s24.a);
    try std.testing.expectEqual(2.0, s24.b);
    try std.testing.expectEqual(3.0, s24.c);

    const s32 = objc.send(ABISize32, fixture, "returnSize32", .{});
    try std.testing.expectEqual(1.0, s32.a);
    try std.testing.expectEqual(2.0, s32.b);
    try std.testing.expectEqual(3.0, s32.c);
    try std.testing.expectEqual(4.0, s32.d);

    const rect = objc.send(ABIRect, fixture, "returnRect", .{});
    try std.testing.expectEqual(10.0, rect.origin.x);
    try std.testing.expectEqual(20.0, rect.origin.y);
    try std.testing.expectEqual(100.0, rect.size.width);
    try std.testing.expectEqual(200.0, rect.size.height);

    const s17 = fixture.send(ABISize17, "returnSize17", .{});
    try std.testing.expectEqual(@as(i64, 1), s17.a);
    try std.testing.expectEqual(@as(i64, 2), s17.b);
    try std.testing.expectEqual(@as(u8, 'z'), s17.c);

    const nested = fixture.send(ABINested, "returnNested", .{});
    try std.testing.expectEqual(@as(f64, 1.0), nested.pt.x);
    try std.testing.expectEqual(@as(f64, 2.0), nested.pt.y);
    try std.testing.expectEqual(@as(c_int, 99), nested.tag);

    const struct_long_double = fixture.send(ABIStructLongDouble, "returnStructLongDouble", .{});
    try std.testing.expectApproxEqAbs(@as(c_longdouble, 3.14), struct_long_double.x, 0.0000001);

    const struct_mixed_long_double = fixture.send(ABIStructMixedLongDouble, "returnStructMixedLongDouble", .{});
    try std.testing.expectEqual(@as(c_int, 1), struct_mixed_long_double.a);
    try std.testing.expectApproxEqAbs(@as(c_longdouble, 3.14), struct_mixed_long_double.b, 0.0000001);

    const input = ABISize32{ .a = 10.0, .b = 20.0, .c = 30.0, .d = 40.0 };
    const sum = fixture.send(f64, "passSize32:", .{input});
    try std.testing.expectEqual(@as(f64, 100.0), sum);
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
    try std.testing.expectEqual(@as(c_int, 55), sum);
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
    try std.testing.expectEqual(@as(f64, 55.0), sum);
}

test "sendChecked: valid NSObject messages pass signature validation" {
    const NSObject = objc.requireClass("NSObject");

    const obj = objc.sendChecked(objc.Object, NSObject, "alloc", .{});
    const init = objc.sendChecked(objc.Object, obj, "init", .{});
    defer init.send(void, "release", .{});

    // description -> @ ; hash -> NSUInteger ; isEqual: takes @, returns BOOL.
    const desc = objc.sendChecked(?objc.Object, init, "description", .{});
    _ = desc;
    const hash = objc.sendChecked(usize, init, "hash", .{});
    _ = hash;
    const eq = objc.sendChecked(objc.raw.BOOL, init, "isEqual:", .{init});
    try std.testing.expect(objc.raw.boolResult(eq));
}

test "sendChecked: nil receiver short-circuits without lookup" {
    const nil_obj: ?objc.Object = null;
    const result = objc.sendChecked(?objc.Object, nil_obj, "description", .{});
    try std.testing.expectEqual(@as(?objc.Object, null), result);
}
