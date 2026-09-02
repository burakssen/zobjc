//! Handle fromRaw / toRaw conversion and null roundtrip tests.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");
const raw = objc.raw;

test "conversion: Class fromRaw and toRaw roundtrip" {
    const raw_cls = raw.runtime.objc_getClass("NSObject");
    try testing.expect(raw_cls != null);

    const cls = objc.Class.fromRaw(raw_cls).?;
    try testing.expectEqual(raw_cls, cls.toRaw());

    const cls_non_null = objc.Class.fromRawNonNull(raw_cls.?);
    try testing.expectEqual(raw_cls, cls_non_null.toRaw());

    try testing.expectEqual(@as(?objc.Class, null), objc.Class.fromRaw(null));
}

test "conversion: Selector fromRaw and toRaw roundtrip" {
    const raw_sel = raw.objc.sel_registerName("init");
    try testing.expect(raw_sel != null);

    const sel = objc.Selector.fromRaw(raw_sel).?;
    try testing.expectEqual(raw_sel, sel.toRaw());

    const sel_non_null = objc.Selector.fromRawNonNull(raw_sel.?);
    try testing.expectEqual(raw_sel, sel_non_null.toRaw());

    try testing.expectEqual(@as(?objc.Selector, null), objc.Selector.fromRaw(null));
}

test "conversion: Object fromRaw and toRaw roundtrip" {
    const cls = objc.requireClass("NSObject");
    const obj = cls.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    defer obj.msgSend(void, "dealloc", .{});

    const raw_id = obj.toRaw();
    try testing.expect(raw_id != null);

    const obj_roundtrip = objc.Object.fromRaw(raw_id).?;
    try testing.expect(obj.eql(obj_roundtrip));

    const obj_non_null = objc.Object.fromRawNonNull(raw_id.?);
    try testing.expect(obj.eql(obj_non_null));

    try testing.expectEqual(@as(?objc.Object, null), objc.Object.fromRaw(null));
}

test "conversion: Method fromRaw and toRaw roundtrip" {
    const cls = objc.requireClass("NSObject");
    const method = cls.instanceMethod(objc.sel("init")).?;
    const raw_method = method.toRaw();

    const roundtrip = objc.Method.fromRaw(raw_method).?;
    try testing.expect(method.eql(roundtrip));

    try testing.expectEqual(@as(?objc.Method, null), objc.Method.fromRaw(null));
}

test "conversion: Protocol fromRaw and toRaw roundtrip" {
    const proto = objc.getProtocol("NSObject").?;
    const raw_proto = proto.toRaw();

    const roundtrip = objc.Protocol.fromRaw(raw_proto).?;
    try testing.expect(proto.eql(roundtrip));

    try testing.expectEqual(@as(?objc.Protocol, null), objc.Protocol.fromRaw(null));
}

test "conversion: Imp fromRaw and toRaw roundtrip" {
    const cls = objc.requireClass("NSObject");
    const imp = cls.methodImplementation(objc.sel("init")).?;
    const raw_imp = imp.toRaw();

    const roundtrip = objc.Imp.fromRaw(raw_imp).?;
    try testing.expect(imp.eql(roundtrip));

    try testing.expectEqual(@as(?objc.Imp, null), objc.Imp.fromRaw(null));
}
