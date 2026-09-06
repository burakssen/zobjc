//! Type encoding parser tests.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

test "parser: primitives" {
    const allocator = testing.allocator;

    var int_type = try objc.encoding.parse(allocator, "i");
    defer int_type.deinit(allocator);
    try testing.expect(int_type.type == .scalar and int_type.type.scalar == .int);

    var dbl_type = try objc.encoding.parse(allocator, "d");
    defer dbl_type.deinit(allocator);
    try testing.expect(dbl_type.type == .scalar and dbl_type.type.scalar == .double);

    var void_type = try objc.encoding.parse(allocator, "v");
    defer void_type.deinit(allocator);
    try testing.expect(void_type.type == .scalar and void_type.type.scalar == .void);

    var sel_type = try objc.encoding.parse(allocator, ":");
    defer sel_type.deinit(allocator);
    try testing.expect(sel_type.type == .selector);

    var cls_type = try objc.encoding.parse(allocator, "#");
    defer cls_type.deinit(allocator);
    try testing.expect(cls_type.type == .class);
}

test "parser: qualifiers" {
    const allocator = testing.allocator;

    var const_ptr = try objc.encoding.parse(allocator, "r^i");
    defer const_ptr.deinit(allocator);
    try testing.expect(const_ptr.qualifiers.const_);
    try testing.expect(const_ptr.type == .pointer);

    var inout_obj = try objc.encoding.parse(allocator, "N@");
    defer inout_obj.deinit(allocator);
    try testing.expect(inout_obj.qualifiers.inout);
    try testing.expect(inout_obj.type == .object);

    var oneway_void = try objc.encoding.parse(allocator, "Vv");
    defer oneway_void.deinit(allocator);
    try testing.expect(oneway_void.qualifiers.oneway);
    try testing.expect(oneway_void.type == .scalar and oneway_void.type.scalar == .void);
}

test "parser: object variants" {
    const allocator = testing.allocator;

    // Plain object
    var plain_obj = try objc.encoding.parse(allocator, "@");
    defer plain_obj.deinit(allocator);
    try testing.expect(plain_obj.type == .object);
    try testing.expect(plain_obj.type.object.class_name == null);

    // Block pointer
    var block_obj = try objc.encoding.parse(allocator, "@?");
    defer block_obj.deinit(allocator);
    try testing.expect(block_obj.type == .block);

    // Typed object
    var str_obj = try objc.encoding.parse(allocator, "@\"NSString\"");
    defer str_obj.deinit(allocator);
    try testing.expect(str_obj.type == .object);
    try testing.expectEqualStrings("NSString", str_obj.type.object.class_name.?);

    // Protocol-qualified object
    var proto_obj = try objc.encoding.parse(allocator, "@\"<NSCopying>\"");
    defer proto_obj.deinit(allocator);
    try testing.expect(proto_obj.type == .object);
    try testing.expect(proto_obj.type.object.class_name == null);
    try testing.expectEqual(@as(usize, 1), proto_obj.type.object.protocols.len);
    try testing.expectEqualStrings("NSCopying", proto_obj.type.object.protocols[0]);

    // Class + multi-protocol
    var multi_obj = try objc.encoding.parse(allocator, "@\"NSString<NSCopying><NSSecureCoding>\"");
    defer multi_obj.deinit(allocator);
    try testing.expect(multi_obj.type == .object);
    try testing.expectEqualStrings("NSString", multi_obj.type.object.class_name.?);
    try testing.expectEqual(@as(usize, 2), multi_obj.type.object.protocols.len);
    try testing.expectEqualStrings("NSCopying", multi_obj.type.object.protocols[0]);
    try testing.expectEqualStrings("NSSecureCoding", multi_obj.type.object.protocols[1]);
}

test "parser: pointers and function pointers" {
    const allocator = testing.allocator;

    var ptr = try objc.encoding.parse(allocator, "^i");
    defer ptr.deinit(allocator);
    try testing.expect(ptr.type == .pointer);
    try testing.expect(ptr.type.pointer.child.type == .scalar and ptr.type.pointer.child.type.scalar == .int);

    var fn_ptr = try objc.encoding.parse(allocator, "^?");
    defer fn_ptr.deinit(allocator);
    try testing.expect(fn_ptr.type == .function_pointer);
}

test "parser: arrays" {
    const allocator = testing.allocator;

    var arr = try objc.encoding.parse(allocator, "[8i]");
    defer arr.deinit(allocator);
    try testing.expect(arr.type == .array);
    try testing.expectEqual(@as(usize, 8), arr.type.array.len);
    try testing.expect(arr.type.array.child.type == .scalar and arr.type.array.child.type.scalar == .int);

    var nested_arr = try objc.encoding.parse(allocator, "[2[3f]]");
    defer nested_arr.deinit(allocator);
    try testing.expect(nested_arr.type == .array);
    try testing.expectEqual(@as(usize, 2), nested_arr.type.array.len);
    try testing.expect(nested_arr.type.array.child.type == .array);
    try testing.expectEqual(@as(usize, 3), nested_arr.type.array.child.type.array.len);
}

test "parser: structures and unions" {
    const allocator = testing.allocator;

    // Standard structure
    var point = try objc.encoding.parse(allocator, "{CGPoint=dd}");
    defer point.deinit(allocator);
    try testing.expect(point.type == .structure);
    try testing.expectEqualStrings("CGPoint", point.type.structure.name);
    try testing.expectEqual(@as(usize, 2), point.type.structure.fields.len);

    // Opaque structure
    var opaque_st = try objc.encoding.parse(allocator, "{OpaqueType}");
    defer opaque_st.deinit(allocator);
    try testing.expect(opaque_st.type == .structure);
    try testing.expectEqualStrings("OpaqueType", opaque_st.type.structure.name);
    try testing.expect(opaque_st.type.structure.@"opaque");

    // Anonymous structure
    var anon_st = try objc.encoding.parse(allocator, "{?=dd}");
    defer anon_st.deinit(allocator);
    try testing.expect(anon_st.type == .structure);
    try testing.expectEqualStrings("?", anon_st.type.structure.name);

    // Quoted field names
    var quoted_st = try objc.encoding.parse(allocator, "{CGPoint=\"x\"d\"y\"d}");
    defer quoted_st.deinit(allocator);
    try testing.expect(quoted_st.type == .structure);
    try testing.expectEqualStrings("x", quoted_st.type.structure.fields[0].name.?);
    try testing.expectEqualStrings("y", quoted_st.type.structure.fields[1].name.?);

    // Union
    var union_val = try objc.encoding.parse(allocator, "(U1=if)");
    defer union_val.deinit(allocator);
    try testing.expect(union_val.type == .union_);
    try testing.expectEqualStrings("U1", union_val.type.union_.name);
    try testing.expectEqual(@as(usize, 2), union_val.type.union_.fields.len);
}

test "parser: bitfields and atomics" {
    const allocator = testing.allocator;

    var bf = try objc.encoding.parse(allocator, "b5");
    defer bf.deinit(allocator);
    try testing.expect(bf.type == .bitfield);
    try testing.expectEqual(@as(u32, 5), bf.type.bitfield.bits);

    var at = try objc.encoding.parse(allocator, "Ai");
    defer at.deinit(allocator);
    try testing.expect(at.type == .atomic);
    try testing.expect(at.type.atomic.child.type == .scalar and at.type.atomic.child.type.scalar == .int);
}

test "parser: round-trip parse -> encode -> parse" {
    const allocator = testing.allocator;
    const test_encodings = [_][]const u8{
        "i",
        "d",
        "B",
        "^i",
        "[4f]",
        "{CGPoint=dd}",
        "(U1=if)",
        "@\"NSString\"",
        "@?",
        "^?",
        "b7",
        "Ai",
    };

    for (test_encodings) |original| {
        var parsed1 = try objc.encoding.parse(allocator, original);
        defer parsed1.deinit(allocator);

        const encoded_str = try objc.encoding.encode(allocator, parsed1);
        defer allocator.free(encoded_str);

        var parsed2 = try objc.encoding.parse(allocator, encoded_str);
        defer parsed2.deinit(allocator);

        try testing.expect(parsed1.eql(parsed2));
    }
}

test "parser: deterministic error handling on invalid input" {
    const allocator = testing.allocator;

    try testing.expectError(error.UnexpectedEnd, objc.encoding.parse(allocator, ""));
    try testing.expectError(error.MissingStructTerminator, objc.encoding.parse(allocator, "{CGPoint=dd"));
    try testing.expectError(error.MissingArrayTerminator, objc.encoding.parse(allocator, "[4i"));
    try testing.expectError(error.MissingAggregateName, objc.encoding.parse(allocator, "{}"));
    try testing.expectError(error.InvalidNumber, objc.encoding.parse(allocator, "[i]"));
    try testing.expectError(error.InvalidNumber, objc.encoding.parse(allocator, "b"));
    try testing.expectError(error.TrailingInput, objc.encoding.parse(allocator, "i extra"));
}
