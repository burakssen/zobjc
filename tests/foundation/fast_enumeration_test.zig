//! Unit tests for fast enumeration iterator and mutation detection.
// ponytail: minimalist tests for fast enumeration across NSArray, NSDictionary, and mutation checks.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");
const foundation = @import("objc_foundation");
const NSString = foundation.NSString;

test "fast enumeration: NSArray iteration" {
    var pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const NSMutableArray = objc.requireClass("NSMutableArray");
    const NSNumber = objc.requireClass("NSNumber");

    const array = NSMutableArray.msgSend(
        objc.Object,
        "arrayWithCapacity:",
        .{@as(c_ulong, 5)},
    );

    for (0..5) |i| {
        const num = NSNumber.msgSend(objc.Object, "numberWithInt:", .{@as(c_int, @intCast(i))});
        array.msgSend(void, "addObject:", .{num});
    }

    var sum: c_int = 0;
    var count: usize = 0;
    var iter = foundation.fastIterate(array);
    while (try iter.next()) |elem| {
        sum += elem.msgSend(c_int, "intValue", .{});
        count += 1;
    }

    try testing.expectEqual(@as(usize, 5), count);
    try testing.expectEqual(@as(c_int, 0 + 1 + 2 + 3 + 4), sum);
}

test "fast enumeration: NSDictionary keys iteration" {
    var pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const NSMutableDictionary = objc.requireClass("NSMutableDictionary");
    const NSNumber = objc.requireClass("NSNumber");

    const dict = NSMutableDictionary.msgSend(
        objc.Object,
        "dictionaryWithCapacity:",
        .{@as(c_ulong, 3)},
    );

    for (0..3) |i| {
        const num = NSNumber.msgSend(objc.Object, "numberWithInt:", .{@as(c_int, @intCast(i))});
        const key_obj = num.msgSend(objc.Object, "stringValue", .{});
        dict.msgSend(void, "setObject:forKey:", .{ num, key_obj });
    }

    var sum: c_int = 0;
    var count: usize = 0;
    var iter = foundation.fastIterate(dict);
    while (try iter.next()) |key| {
        const val = dict.msgSend(objc.Object, "objectForKey:", .{key});
        sum += val.msgSend(c_int, "intValue", .{});
        count += 1;
    }

    try testing.expectEqual(@as(usize, 3), count);
    try testing.expectEqual(@as(c_int, 0 + 1 + 2), sum);
}

test "fast enumeration: empty NSArray returns null immediately" {
    var pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const NSArray = objc.requireClass("NSArray");
    const empty_arr = NSArray.msgSend(objc.Object, "array", .{});

    var iter = foundation.fastIterate(empty_arr);
    const first = try iter.next();
    try testing.expect(first == null);
}

test "fast enumeration: mutation during iteration returns error.CollectionMutated" {
    var pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const NSMutableArray = objc.requireClass("NSMutableArray");
    const NSNumber = objc.requireClass("NSNumber");

    const array = NSMutableArray.msgSend(
        objc.Object,
        "arrayWithCapacity:",
        .{@as(c_ulong, 20)},
    );

    for (0..20) |i| {
        const num = NSNumber.msgSend(objc.Object, "numberWithInt:", .{@as(c_int, @intCast(i))});
        array.msgSend(void, "addObject:", .{num});
    }

    var iter = foundation.FastEnumerationIterator(4).init(array);

    // Consume first batch
    _ = try iter.next();

    // Mutate collection
    const extra = NSNumber.msgSend(objc.Object, "numberWithInt:", .{@as(c_int, 999)});
    array.msgSend(void, "addObject:", .{extra});

    // Next call MUST detect mutation immediately
    const res = iter.next();
    try testing.expectError(error.CollectionMutated, res);
}
