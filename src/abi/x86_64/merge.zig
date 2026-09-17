//! System V AMD64 ABI Section 3.2.3 class merge rules.

const Class = @import("class.zig").Class;
const std = @import("std");

// Direct implementation of System V ABI 3.2.3 classification merge.
pub fn merge(lhs: Class, rhs: Class) Class {
    // (a) If both classes are equal, this is the resulting class.
    if (lhs == rhs) return lhs;

    // (b) If one of the classes is NO_CLASS, the resulting class is the other class.
    if (lhs == .no_class) return rhs;
    if (rhs == .no_class) return lhs;

    // (c) If one of the classes is MEMORY, the result is the MEMORY class.
    if (lhs == .memory or rhs == .memory) return .memory;

    // (d) If one of the classes is X87, X87UP, COMPLEX_X87 class, MEMORY is used.
    if (lhs == .x87 or rhs == .x87 or
        lhs == .x87up or rhs == .x87up or
        lhs == .complex_x87 or rhs == .complex_x87)
    {
        return .memory;
    }

    // (e) If one of the classes is INTEGER, the result is the INTEGER class.
    if (lhs == .integer or rhs == .integer) return .integer;

    // (f) Otherwise class SSE is used.
    return .sse;
}

test "x86_64 merge: identical classes return self" {
    const all_classes = [_]Class{ .no_class, .integer, .sse, .sseup, .x87, .x87up, .complex_x87, .memory };
    for (all_classes) |c| try std.testing.expectEqual(c, merge(c, c));
}

test "x86_64 merge: NO_CLASS yields the other class" {
    const classes = [_]Class{ .integer, .sse, .sseup, .x87, .x87up, .complex_x87, .memory };
    for (classes) |c| {
        try std.testing.expectEqual(c, merge(.no_class, c));
        try std.testing.expectEqual(c, merge(c, .no_class));
    }
}

test "x86_64 merge: MEMORY dominates anything" {
    const all_classes = [_]Class{ .no_class, .integer, .sse, .sseup, .x87, .x87up, .complex_x87, .memory };
    for (all_classes) |c| {
        try std.testing.expectEqual(Class.memory, merge(.memory, c));
        try std.testing.expectEqual(Class.memory, merge(c, .memory));
    }
}

test "x86_64 merge: INTEGER dominates SSE and SSEUP" {
    try std.testing.expectEqual(Class.integer, merge(.integer, .sse));
    try std.testing.expectEqual(Class.integer, merge(.sse, .integer));
    try std.testing.expectEqual(Class.integer, merge(.integer, .sseup));
    try std.testing.expectEqual(Class.integer, merge(.sseup, .integer));
}

test "x86_64 merge: X87, X87UP, and COMPLEX_X87 yield MEMORY" {
    const x87_classes = [_]Class{ .x87, .x87up, .complex_x87 };
    const other_classes = [_]Class{ .integer, .sse, .sseup };
    for (x87_classes) |x| {
        for (other_classes) |other| {
            try std.testing.expectEqual(Class.memory, merge(x, other));
            try std.testing.expectEqual(Class.memory, merge(other, x));
        }
    }
}

test "x86_64 merge: otherwise SSE is used" {
    try std.testing.expectEqual(Class.sse, merge(.sse, .sseup));
    try std.testing.expectEqual(Class.sse, merge(.sseup, .sse));
}
