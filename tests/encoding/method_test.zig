//! Tests for Objective-C method signature parsing and encoding.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

const Point = extern struct {
    x: f64,
    y: f64,
};

test "method: parse compact method encoding" {
    const allocator = testing.allocator;

    // "v@:i" -> void (Object, SEL, int)
    var sig = try objc.encoding.parseMethod(allocator, "v@:i");
    defer sig.deinit(allocator);

    try testing.expect(sig.return_type.type == .scalar);
    try testing.expectEqual(.void, sig.return_type.type.scalar);
    try testing.expectEqual(@as(?usize, null), sig.frame_size);
    try testing.expectEqual(@as(usize, 3), sig.arguments.len);

    // Receiver (@)
    try testing.expect(sig.arguments[0].type.type == .object);
    try testing.expectEqual(@as(?isize, null), sig.arguments[0].offset);

    // Selector (:)
    try testing.expect(sig.arguments[1].type.type == .selector);
    try testing.expectEqual(@as(?isize, null), sig.arguments[1].offset);

    // Argument (i)
    try testing.expect(sig.arguments[2].type.type == .scalar);
    try testing.expectEqual(.int, sig.arguments[2].type.type.scalar);
    try testing.expectEqual(@as(?isize, null), sig.arguments[2].offset);
}

test "method: parse annotated method encoding with stack offsets" {
    const allocator = testing.allocator;

    // "v24@0:8i16" on 64-bit: frame_size=24, receiver at 0, selector at 8, int at 16
    var sig = try objc.encoding.parseMethod(allocator, "v24@0:8i16");
    defer sig.deinit(allocator);

    try testing.expect(sig.return_type.type == .scalar);
    try testing.expectEqual(.void, sig.return_type.type.scalar);
    try testing.expectEqual(@as(?usize, 24), sig.frame_size);
    try testing.expectEqual(@as(usize, 3), sig.arguments.len);

    try testing.expect(sig.arguments[0].type.type == .object);
    try testing.expectEqual(@as(?isize, 0), sig.arguments[0].offset);

    try testing.expect(sig.arguments[1].type.type == .selector);
    try testing.expectEqual(@as(?isize, 8), sig.arguments[1].offset);

    try testing.expect(sig.arguments[2].type.type == .scalar);
    try testing.expectEqual(.int, sig.arguments[2].type.type.scalar);
    try testing.expectEqual(@as(?isize, 16), sig.arguments[2].offset);
}

test "method: parse complex arguments and aggregates" {
    const allocator = testing.allocator;

    // "{CGPoint=dd}32@0:8{CGPoint=dd}16"
    var sig = try objc.encoding.parseMethod(allocator, "{CGPoint=dd}32@0:8{CGPoint=dd}16");
    defer sig.deinit(allocator);

    try testing.expect(sig.return_type.type == .structure);
    try testing.expectEqualStrings("CGPoint", sig.return_type.type.structure.name);
    try testing.expectEqual(@as(?usize, 32), sig.frame_size);
    try testing.expectEqual(@as(usize, 3), sig.arguments.len);

    try testing.expect(sig.arguments[2].type.type == .structure);
    try testing.expectEqualStrings("CGPoint", sig.arguments[2].type.type.structure.name);
    try testing.expectEqual(@as(?isize, 16), sig.arguments[2].offset);
}

test "method: comptime methodEncoding from Zig function types" {
    const InstanceCallback = fn (objc.Object, objc.Selector, i32) callconv(.c) void;
    const enc1 = comptime objc.encoding.methodEncoding(InstanceCallback);
    try testing.expectEqualStrings("v@:i", &enc1);

    const ClassCallback = fn (objc.Class, objc.Selector, [4]f32) callconv(.c) i32;
    const enc2 = comptime objc.encoding.methodEncoding(ClassCallback);
    try testing.expectEqualStrings("i#:[4f]", &enc2);

    const StructReturnCallback = fn (objc.Object, objc.Selector) callconv(.c) Point;
    const enc3 = comptime objc.encoding.methodEncoding(StructReturnCallback);
    try testing.expectEqualStrings("{Point=dd}@:", &enc3);

    const RawHandleCallback = fn (objc.raw.id, objc.raw.SEL, ?*anyopaque) callconv(.c) objc.raw.id;
    const enc4 = comptime objc.encoding.methodEncoding(RawHandleCallback);
    try testing.expectEqualStrings("@@:^v", &enc4);
}

test "method: encodeMethod round trip" {
    const allocator = testing.allocator;

    const original = "v@:i";
    var sig = try objc.encoding.parseMethod(allocator, original);
    defer sig.deinit(allocator);

    const encoded = try objc.encoding.encodeMethod(allocator, sig, .{});
    defer allocator.free(encoded);

    try testing.expectEqualStrings(original, encoded);
}

test "method: validateMethodImplementation" {
    const ValidFn = fn (objc.Object, objc.Selector, f64) callconv(.c) bool;
    objc.encoding.validateMethodImplementation(ValidFn);

    const ValidClassFn = fn (objc.Class, objc.Selector) callconv(.c) void;
    objc.encoding.validateMethodImplementation(ValidClassFn);
}
