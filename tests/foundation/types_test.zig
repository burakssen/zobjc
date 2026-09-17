//! Unit tests for Foundation types and NSRange geometry.
// ponytail: minimalist tests for NSRange logic and ABI compatibility.

const std = @import("std");
const testing = std.testing;
const foundation = @import("objc_foundation");
const NSRange = foundation.NSRange;

test "types: NSRange basic operations" {
    const r = NSRange.init(5, 10);
    try testing.expectEqual(@as(usize, 5), r.location);
    try testing.expectEqual(@as(usize, 10), r.length);
    try testing.expectEqual(@as(usize, 15), r.max());
    try testing.expect(!r.isEmpty());

    try testing.expect(r.contains(5));
    try testing.expect(r.contains(14));
    try testing.expect(!r.contains(4));
    try testing.expect(!r.contains(15));

    const empty_r = NSRange.init(10, 0);
    try testing.expect(empty_r.isEmpty());
}

test "types: NSRange intersection" {
    const r1 = NSRange.init(0, 10);
    const r2 = NSRange.init(5, 10);

    const inter = r1.intersection(r2);
    try testing.expect(inter != null);
    try testing.expectEqual(@as(usize, 5), inter.?.location);
    try testing.expectEqual(@as(usize, 5), inter.?.length);

    const disjoint = NSRange.init(20, 5);
    try testing.expect(r1.intersection(disjoint) == null);
}

test "types: StringEncoding and NSComparisonResult" {
    try testing.expectEqual(@as(usize, 4), foundation.StringEncoding.UTF8);
    try testing.expectEqual(@as(isize, -1), @intFromEnum(foundation.NSComparisonResult.OrderedAscending));
    try testing.expectEqual(@as(isize, 0), @intFromEnum(foundation.NSComparisonResult.OrderedSame));
    try testing.expectEqual(@as(isize, 1), @intFromEnum(foundation.NSComparisonResult.OrderedDescending));
}
