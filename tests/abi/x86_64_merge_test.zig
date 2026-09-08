//! Exhaustive unit tests for System V AMD64 ABI Section 3.2.3 class merge rules.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");
const Class = objc.abi.x86_64.class.Class;
const merge = objc.abi.x86_64.merge.merge;

test "x86_64 merge: identical classes return self" {
    const all_classes = [_]Class{
        .no_class,
        .integer,
        .sse,
        .sseup,
        .x87,
        .x87up,
        .complex_x87,
        .memory,
    };

    for (all_classes) |c| {
        try testing.expectEqual(c, merge(c, c));
    }
}

test "x86_64 merge: NO_CLASS yields the other class" {
    const classes = [_]Class{
        .integer,
        .sse,
        .sseup,
        .x87,
        .x87up,
        .complex_x87,
        .memory,
    };

    for (classes) |c| {
        try testing.expectEqual(c, merge(.no_class, c));
        try testing.expectEqual(c, merge(c, .no_class));
    }
}

test "x86_64 merge: MEMORY dominates anything" {
    const all_classes = [_]Class{
        .no_class,
        .integer,
        .sse,
        .sseup,
        .x87,
        .x87up,
        .complex_x87,
        .memory,
    };

    for (all_classes) |c| {
        try testing.expectEqual(Class.memory, merge(.memory, c));
        try testing.expectEqual(Class.memory, merge(c, .memory));
    }
}

test "x86_64 merge: INTEGER dominates SSE and SSEUP" {
    try testing.expectEqual(Class.integer, merge(.integer, .sse));
    try testing.expectEqual(Class.integer, merge(.sse, .integer));
    try testing.expectEqual(Class.integer, merge(.integer, .sseup));
    try testing.expectEqual(Class.integer, merge(.sseup, .integer));
}

test "x86_64 merge: X87, X87UP, and COMPLEX_X87 yield MEMORY" {
    const x87_classes = [_]Class{ .x87, .x87up, .complex_x87 };
    const other_classes = [_]Class{ .integer, .sse, .sseup };

    for (x87_classes) |x| {
        for (other_classes) |other| {
            try testing.expectEqual(Class.memory, merge(x, other));
            try testing.expectEqual(Class.memory, merge(other, x));
        }
    }
}

test "x86_64 merge: otherwise SSE is used" {
    try testing.expectEqual(Class.sse, merge(.sse, .sseup));
    try testing.expectEqual(Class.sse, merge(.sseup, .sse));
}
