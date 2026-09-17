//! Example demonstrating the optional objc_foundation convenience module.
// ponytail: minimalist, zero overhead Foundation interop with NSString and fast enumeration.

const std = @import("std");
const objc = @import("objc");
const foundation = @import("objc_foundation");
const NSString = foundation.NSString;
const NSRange = foundation.NSRange;

pub fn main() !void {
    var pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    std.debug.print("--- NSString & UTF-8 Bridging ---\n", .{});

    // 1. Owned NSString using Retained(NSString)
    var owned_str = NSString.fromUTF8Owned("Hello, Apple Foundation from Zig!") orelse {
        std.debug.print("Failed to create NSString\n", .{});
        return;
    };
    defer owned_str.deinit();

    const borrowed = owned_str.borrow();
    std.debug.print("String UTF-16 length: {d}\n", .{borrowed.lengthUtf16()});
    std.debug.print("String UTF-8 content: {s}\n", .{borrowed.utf8CString().?});

    // 2. NSRange manipulation
    const r = borrowed.range();
    std.debug.print("NSRange: loc={d}, len={d}, max={d}\n", .{ r.location, r.length, r.max() });

    std.debug.print("\n--- Zero-Allocation Fast Enumeration ---\n", .{});

    // 3. Fast enumeration on NSArray
    const NSMutableArray = objc.requireClass("NSMutableArray");
    const NSNumber = objc.requireClass("NSNumber");

    const array = NSMutableArray.msgSend(
        objc.Object,
        "arrayWithCapacity:",
        .{@as(c_ulong, 5)},
    );

    const items = [_]c_int{ 10, 20, 30, 40, 50 };
    for (items) |val| {
        const num = NSNumber.msgSend(objc.Object, "numberWithInt:", .{val});
        array.msgSend(void, "addObject:", .{num});
    }

    // Fast enumeration with stack buffer
    var iter = foundation.fastIterate(array);
    var index: usize = 0;
    while (try iter.next()) |elem| {
        const val = elem.msgSend(c_int, "intValue", .{});
        std.debug.print("  array[{d}] = {d}\n", .{ index, val });
        index += 1;
    }

    std.debug.print("\n--- NSEnumerator ---\n", .{});

    // 4. NSEnumerator wrapper
    const raw_enum = array.msgSend(objc.Object, "objectEnumerator", .{});
    const enumerator = foundation.NSEnumerator.fromObject(raw_enum);
    var enum_it = enumerator.iterator();

    var count: usize = 0;
    while (enum_it.next()) |elem| {
        _ = elem;
        count += 1;
    }
    std.debug.print("Enumerated {d} elements via NSEnumerator\n", .{count});
}
