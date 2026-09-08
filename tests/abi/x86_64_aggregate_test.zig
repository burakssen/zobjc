//! Tests for x86_64 aggregate return convention classification.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");
const Target = objc.abi.Target;
const returnConventionFor = objc.abi.returnConventionFor;
const classifyReturn = objc.abi.classifyReturn;
const aggregate = objc.abi.x86_64.aggregate;
const Class = objc.abi.x86_64.class.Class;

const macos_x86_64 = Target.macos_x86_64;

test "x86_64 aggregate: small aggregates (<= 16 bytes) use normal" {
    const S1 = extern struct { a: u8 };
    const S2 = extern struct { a: u16 };
    const S4 = extern struct { a: u32 };
    const S8 = extern struct { a: u64 };
    const S8Mixed = extern struct { a: i32, b: f32 };
    const S12 = extern struct { a: i32, b: i32, c: i32 };
    const S16Int = extern struct { a: u64, b: u64 };
    const S16Float = extern struct { a: f64, b: f64 };
    const S16Mixed = extern struct { a: i64, b: f64 };

    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, S1));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, S2));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, S4));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, S8));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, S8Mixed));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, S12));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, S16Int));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, S16Float));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, S16Mixed));
}

test "x86_64 aggregate: same-size different-layout registers" {
    const A = extern struct { a: u64, b: u64 };
    const B = extern struct { a: f64, b: f64 };
    const C = extern struct { a: i64, b: f64 };
    const D = extern struct { a: f64, b: i64 };

    // All are 16 bytes and use normal objc_msgSend
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, A));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, B));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, C));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, D));

    // But their detailed eightbyte register classes differ!
    const class_a = aggregate.classifyAggregate(A);
    try testing.expectEqual(Class.integer, class_a.classes[0]);
    try testing.expectEqual(Class.integer, class_a.classes[1]);

    const class_b = aggregate.classifyAggregate(B);
    try testing.expectEqual(Class.sse, class_b.classes[0]);
    try testing.expectEqual(Class.sse, class_b.classes[1]);

    const class_c = aggregate.classifyAggregate(C);
    try testing.expectEqual(Class.integer, class_c.classes[0]);
    try testing.expectEqual(Class.sse, class_c.classes[1]);

    const class_d = aggregate.classifyAggregate(D);
    try testing.expectEqual(Class.sse, class_d.classes[0]);
    try testing.expectEqual(Class.integer, class_d.classes[1]);
}

test "x86_64 aggregate: large aggregates (> 16 bytes) use stret" {
    const S17 = extern struct { a: u64, b: u64, c: u8 };
    const S24 = extern struct { a: f64, b: f64, c: f64 };
    const S32 = extern struct { a: f64, b: f64, c: f64, d: f64 };

    try testing.expectEqual(.stret, returnConventionFor(macos_x86_64, S17));
    try testing.expectEqual(.stret, returnConventionFor(macos_x86_64, S24));
    try testing.expectEqual(.stret, returnConventionFor(macos_x86_64, S32));

    try testing.expectEqual(.indirect, classifyReturn(macos_x86_64, S17));
    try testing.expectEqual(.indirect, classifyReturn(macos_x86_64, S24));
    try testing.expectEqual(.indirect, classifyReturn(macos_x86_64, S32));
}

test "x86_64 aggregate: nested aggregates" {
    const Point = extern struct { x: f64, y: f64 };
    const Size = extern struct { width: f64, height: f64 };
    const Rect = extern struct { origin: Point, size: Size };
    const TaggedPoint = extern struct { pt: Point, tag: i32 };

    // Point and Size are 16 bytes -> normal
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, Point));
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, Size));

    // TaggedPoint is 24 bytes -> stret
    try testing.expectEqual(.stret, returnConventionFor(macos_x86_64, TaggedPoint));

    // Rect is 32 bytes -> stret
    try testing.expectEqual(.stret, returnConventionFor(macos_x86_64, Rect));
}

test "x86_64 aggregate: arrays in structs" {
    const Array16 = extern struct { vals: [2]f64 };
    const Array24 = extern struct { vals: [3]f64 };

    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, Array16));
    try testing.expectEqual(.stret, returnConventionFor(macos_x86_64, Array24));

    const class_arr = aggregate.classifyAggregate(Array16);
    try testing.expectEqual(Class.sse, class_arr.classes[0]);
    try testing.expectEqual(Class.sse, class_arr.classes[1]);
}

test "x86_64 aggregate: unions" {
    const Union8 = extern union {
        i: i64,
        d: f64,
    };
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, Union8));

    // Section 3.2.3: INTEGER + SSE at same offset merges to INTEGER
    const class_u = aggregate.classifyAggregate(Union8);
    try testing.expectEqual(Class.integer, class_u.classes[0]);
}

test "x86_64 aggregate: long double in aggregate" {
    const StructWithLongDouble = extern struct { x: c_longdouble };
    const StructMixedLongDouble = extern struct { a: i32, b: c_longdouble };

    // Single long double struct is size 16 -> normal (returned in ST0)
    try testing.expectEqual(.normal, returnConventionFor(macos_x86_64, StructWithLongDouble));

    // Struct with other fields + long double is size 32 -> stret
    try testing.expectEqual(.stret, returnConventionFor(macos_x86_64, StructMixedLongDouble));
}
