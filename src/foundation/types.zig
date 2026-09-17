//! Foundation primitive scalar types and core geometry/range structs.
// ponytail: minimalist, zero overhead, mirrors Darwin 64-bit ABI directly.

const std = @import("std");

/// Signed integer type used by Foundation collections and indexing.
pub const NSInteger = isize;

/// Unsigned integer type used by Foundation collections, lengths, and sizes.
pub const NSUInteger = usize;

/// High-precision time interval in seconds (IEEE 754 64-bit float).
pub const NSTimeInterval = f64;

/// Result of ordering comparisons in Foundation.
pub const NSComparisonResult = enum(NSInteger) {
    OrderedAscending = -1,
    OrderedSame = 0,
    OrderedDescending = 1,
};

/// Common Foundation NSString encoding constants.
pub const StringEncoding = struct {
    pub const ASCII: NSUInteger = 1;
    pub const UTF8: NSUInteger = 4;
    pub const Unicode: NSUInteger = 10; // UTF-16
};

/// Represents a contiguous subrange within an ordered collection or string.
pub const NSRange = extern struct {
    location: NSUInteger,
    length: NSUInteger,

    /// Sentinel value indicating an item was not found.
    pub const not_found: NSUInteger = std.math.maxInt(NSUInteger);

    /// Constructs an NSRange with the specified location and length.
    pub inline fn init(loc: NSUInteger, len: NSUInteger) NSRange {
        return .{ .location = loc, .length = len };
    }

    /// Returns the upper bound of the range (exclusive).
    pub inline fn max(self: NSRange) NSUInteger {
        return self.location + self.length;
    }

    /// Tests whether the given index lies within the range.
    pub inline fn contains(self: NSRange, index: NSUInteger) bool {
        return index >= self.location and index < self.max();
    }

    /// Returns true if the range spans 0 elements.
    pub inline fn isEmpty(self: NSRange) bool {
        return self.length == 0;
    }

    /// Computes the intersection of this range with another range.
    /// Returns null if the ranges do not intersect.
    pub fn intersection(self: NSRange, other: NSRange) ?NSRange {
        const start = @max(self.location, other.location);
        const end = @min(self.max(), other.max());
        if (end <= start) return null;
        return NSRange{ .location = start, .length = end - start };
    }
};

comptime {
    std.debug.assert(@sizeOf(NSRange) == 16);
    std.debug.assert(@alignOf(NSRange) == 8);
}
