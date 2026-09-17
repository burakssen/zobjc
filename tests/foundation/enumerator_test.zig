//! Unit tests for NSEnumerator handle and iterator.
// ponytail: minimalist tests for NSEnumerator operations.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");
const foundation = @import("objc_foundation");
const NSEnumerator = foundation.NSEnumerator;

test "NSEnumerator: basic enumeration" {
    var pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const NSMutableArray = objc.requireClass("NSMutableArray");
    const NSNumber = objc.requireClass("NSNumber");

    const array = NSMutableArray.msgSend(
        objc.Object,
        "arrayWithCapacity:",
        .{@as(c_ulong, 3)},
    );

    for (0..3) |i| {
        const num = NSNumber.msgSend(objc.Object, "numberWithInt:", .{@as(c_int, @intCast(i * 10))});
        array.msgSend(void, "addObject:", .{num});
    }

    const raw_enum = array.msgSend(objc.Object, "objectEnumerator", .{});
    const enumerator = NSEnumerator.fromObject(raw_enum);

    var iter = enumerator.iterator();
    var sum: c_int = 0;
    var count: usize = 0;

    while (iter.next()) |elem| {
        sum += elem.msgSend(c_int, "intValue", .{});
        count += 1;
    }

    try testing.expectEqual(@as(usize, 3), count);
    try testing.expectEqual(@as(c_int, 0 + 10 + 20), sum);
}

test "NSEnumerator: allObjects" {
    var pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const NSMutableArray = objc.requireClass("NSMutableArray");
    const NSNumber = objc.requireClass("NSNumber");

    const array = NSMutableArray.msgSend(
        objc.Object,
        "arrayWithCapacity:",
        .{@as(c_ulong, 4)},
    );

    for (0..4) |i| {
        const num = NSNumber.msgSend(objc.Object, "numberWithInt:", .{@as(c_int, @intCast(i))});
        array.msgSend(void, "addObject:", .{num});
    }

    const raw_enum = array.msgSend(objc.Object, "objectEnumerator", .{});
    const enumerator = NSEnumerator.fromObject(raw_enum);

    // Consume first element
    const first = enumerator.nextObject();
    try testing.expect(first != null);

    // Get remaining objects
    const remaining = enumerator.allObjects();
    const rem_count = remaining.msgSend(usize, "count", .{});
    try testing.expectEqual(@as(usize, 3), rem_count);
}
