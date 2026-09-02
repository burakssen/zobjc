//! Baseline behavioral tests for Foundation / Cocoa integration.

const std = @import("std");
const objc = @import("objc");
const testing = std.testing;

test "integration: NSArray iteration" {
    const NSMutableArray = objc.getClass("NSMutableArray").?;
    const NSNumber = objc.getClass("NSNumber").?;

    const array = NSMutableArray.msgSend(
        objc.Object,
        "arrayWithCapacity:",
        .{@as(c_ulong, 5)},
    );
    defer array.release();

    for (0..5) |i| {
        const num = NSNumber.msgSend(objc.Object, "numberWithInt:", .{@as(c_int, @intCast(i))});
        defer num.release();
        array.msgSend(void, "addObject:", .{num});
    }

    var sum: c_int = 0;
    var iter = array.iterate();
    while (iter.next()) |elem| {
        sum += elem.getProperty(c_int, "intValue");
    }
    try testing.expectEqual(@as(c_int, 0 + 1 + 2 + 3 + 4), sum);
}

test "integration: NSDictionary iteration" {
    const NSMutableDictionary = objc.getClass("NSMutableDictionary").?;
    const NSNumber = objc.getClass("NSNumber").?;

    const dict = NSMutableDictionary.msgSend(
        objc.Object,
        "dictionaryWithCapacity:",
        .{@as(c_ulong, 5)},
    );
    defer dict.release();

    for (0..5) |i| {
        const num = NSNumber.msgSend(objc.Object, "numberWithInt:", .{@as(c_int, @intCast(i))});
        defer num.release();
        dict.msgSend(void, "setValue:forKey:", .{
            num,
            num.getProperty(objc.Object, "stringValue"),
        });
    }

    var sum: c_int = 0;
    var iter = dict.iterate();
    while (iter.next()) |key| {
        const val = dict.msgSend(objc.Object, "valueForKey:", .{key});
        sum += val.getProperty(c_int, "intValue");
    }
    try testing.expectEqual(@as(c_int, 10), sum);
}

test "integration: tagged pointer unaligned cast" {
    // Tests that tagged pointer representations (like small NSNumbers) work properly with fromId.
    const NSNumber = objc.getClass("NSNumber").?;
    const num = NSNumber.msgSend(objc.Object, "numberWithChar:", .{@as(u8, 5)});

    // fromId on tagged pointer
    const obj = objc.Object.fromId(num.toRaw());
    try testing.expectEqual(num.toRaw(), obj.toRaw());
}
