//! System V AMD64 aggregate decomposition and classification engine.
//!
//! Decomposes structs, unions, and arrays into eightbyte chunks and classifies
//! them according to System V ABI Section 3.2.3 rules.

const std = @import("std");
const Class = @import("class.zig").Class;
const EightbyteClassification = @import("eightbyte.zig").EightbyteClassification;
const merge_mod = @import("merge.zig");
const merge = merge_mod.merge;
const layout = @import("../layout.zig");
const traits = @import("../internal/traits.zig");
const testing = std.testing;
const ReturnConvention = @import("../convention.zig").ReturnConvention;
const ABIResult = @import("../convention.zig").ABIResult;

fn aggregateReturnConvention(comptime T: type) ReturnConvention {
    return if (classifyAggregate(T).isMemory()) .stret else .normal;
}

fn aggregateClassifyReturn(comptime T: type) ABIResult {
    return if (classifyAggregate(T).isMemory()) .indirect else .direct;
}

// Pure compile-time recursive decomposition into up to 2 eightbytes.
pub fn classifyAggregate(comptime T: type) EightbyteClassification {
    const total_size = layout.sizeOf(T);

    // Rule: Empty struct in C/Darwin is size 0 or 1.
    if (total_size == 0) {
        return .{ .classes = .{ .no_class, .no_class } };
    }

    // Rule: If size > 16 bytes, the aggregate is returned in memory (stret).
    if (total_size > 16) {
        return .{ .classes = .{ .memory, .memory } };
    }

    var result: EightbyteClassification = .{};
    classifyTypeRecursive(T, 0, &result);

    // Post-classification cleanup rules (Section 3.2.3)
    cleanup(&result, total_size);

    return result;
}

fn classifyTypeRecursive(
    comptime T: type,
    comptime base_offset: usize,
    result: *EightbyteClassification,
) void {
    const info = @typeInfo(T);
    switch (info) {
        .@"struct" => |s| {
            // Check each field
            inline for (s.fields) |f| {
                const field_offset = base_offset + @offsetOf(T, f.name);
                const field_align = @alignOf(f.type);

                // Alignment check: unaligned fields force memory
                if (field_align > 0 and (field_offset % field_align) != 0) {
                    result.classes[0] = .memory;
                    result.classes[1] = .memory;
                    return;
                }

                classifyTypeRecursive(f.type, field_offset, result);
                if (result.isMemory()) return;
            }
        },

        .array => |a| {
            const elem_size = layout.sizeOf(a.child);
            inline for (0..a.len) |i| {
                const elem_offset = base_offset + i * elem_size;
                classifyTypeRecursive(a.child, elem_offset, result);
                if (result.isMemory()) return;
            }
        },

        .@"union" => |u| {
            // All union fields start at base_offset
            inline for (u.fields) |f| {
                classifyTypeRecursive(f.type, base_offset, result);
                if (result.isMemory()) return;
            }
        },

        else => {
            // Leaf types: integer, pointer, float, etc.
            classifyLeaf(T, base_offset, result);
        },
    }
}

fn classifyLeaf(
    comptime T: type,
    comptime offset: usize,
    result: *EightbyteClassification,
) void {
    const size = layout.sizeOf(T);
    if (size == 0) return;

    const leaf_class = getLeafClass(T);

    // Map byte range [offset, offset + size) to affected eightbytes
    if (offset < 8) {
        result.classes[0] = merge(result.classes[0], leaf_class);
    }
    if (offset + size > 8 and offset < 16) {
        // If leaf is 16-byte SSE vector or complex float, second eightbyte is sseup
        const second_class = if (leaf_class == .sse and size > 8)
            .sseup
        else if (leaf_class == .x87 and size > 8)
            .x87up
        else
            leaf_class;
        result.classes[1] = merge(result.classes[1], second_class);
    }
}

fn getLeafClass(comptime T: type) Class {
    if (traits.isPointer(T) or traits.isInteger(T) or traits.isSinglePointerStruct(T)) {
        return .integer;
    }
    if (T == f32 or T == f64) {
        return .sse;
    }
    if (traits.isLongDouble(T)) {
        return .x87;
    }
    if (@typeInfo(T) == .vector) {
        return .sse;
    }
    return .integer;
}

fn cleanup(result: *EightbyteClassification, total_size: usize) void {
    // 1. If any eightbyte is MEMORY, the entire aggregate is MEMORY.
    if (result.isMemory()) {
        result.classes[0] = .memory;
        result.classes[1] = .memory;
        return;
    }

    // 2. If X87/X87UP/COMPLEX_X87 appears anywhere other than pure x87 ([.x87, .x87up] or [.x87, .no_class]), it is MEMORY.
    if (result.classes[0] == .x87 or result.classes[0] == .x87up or result.classes[0] == .complex_x87 or
        result.classes[1] == .x87 or result.classes[1] == .x87up or result.classes[1] == .complex_x87)
    {
        const is_pure_x87 = (result.classes[0] == .x87 and (result.classes[1] == .x87up or result.classes[1] == .no_class));
        if (!is_pure_x87) {
            result.classes[0] = .memory;
            result.classes[1] = .memory;
            return;
        }
    }

    // 3. If SSEUP is not preceded by SSE, it is converted to SSE.
    if (result.classes[1] == .sseup and result.classes[0] != .sse) {
        result.classes[1] = .sse;
    }

    // 4. If size > 8 and eightbyte 0 is NO_CLASS while eightbyte 1 is classified, memory.
    if (total_size > 8 and result.classes[0] == .no_class and result.classes[1] != .no_class) {
        result.classes[0] = .memory;
        result.classes[1] = .memory;
    }
}

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

    try testing.expectEqual(.normal, aggregateReturnConvention(S1));
    try testing.expectEqual(.normal, aggregateReturnConvention(S2));
    try testing.expectEqual(.normal, aggregateReturnConvention(S4));
    try testing.expectEqual(.normal, aggregateReturnConvention(S8));
    try testing.expectEqual(.normal, aggregateReturnConvention(S8Mixed));
    try testing.expectEqual(.normal, aggregateReturnConvention(S12));
    try testing.expectEqual(.normal, aggregateReturnConvention(S16Int));
    try testing.expectEqual(.normal, aggregateReturnConvention(S16Float));
    try testing.expectEqual(.normal, aggregateReturnConvention(S16Mixed));
}

test "x86_64 aggregate: same-size different-layout registers" {
    const A = extern struct { a: u64, b: u64 };
    const B = extern struct { a: f64, b: f64 };
    const C = extern struct { a: i64, b: f64 };
    const D = extern struct { a: f64, b: i64 };

    try testing.expectEqual(.normal, aggregateReturnConvention(A));
    try testing.expectEqual(.normal, aggregateReturnConvention(B));
    try testing.expectEqual(.normal, aggregateReturnConvention(C));
    try testing.expectEqual(.normal, aggregateReturnConvention(D));

    const class_a = classifyAggregate(A);
    try testing.expectEqual(Class.integer, class_a.classes[0]);
    try testing.expectEqual(Class.integer, class_a.classes[1]);

    const class_b = classifyAggregate(B);
    try testing.expectEqual(Class.sse, class_b.classes[0]);
    try testing.expectEqual(Class.sse, class_b.classes[1]);

    const class_c = classifyAggregate(C);
    try testing.expectEqual(Class.integer, class_c.classes[0]);
    try testing.expectEqual(Class.sse, class_c.classes[1]);

    const class_d = classifyAggregate(D);
    try testing.expectEqual(Class.sse, class_d.classes[0]);
    try testing.expectEqual(Class.integer, class_d.classes[1]);
}

test "x86_64 aggregate: large aggregates (> 16 bytes) use stret" {
    const S17 = extern struct { a: u64, b: u64, c: u8 };
    const S24 = extern struct { a: f64, b: f64, c: f64 };
    const S32 = extern struct { a: f64, b: f64, c: f64, d: f64 };

    try testing.expectEqual(.stret, aggregateReturnConvention(S17));
    try testing.expectEqual(.stret, aggregateReturnConvention(S24));
    try testing.expectEqual(.stret, aggregateReturnConvention(S32));
    try testing.expectEqual(.indirect, aggregateClassifyReturn(S17));
    try testing.expectEqual(.indirect, aggregateClassifyReturn(S24));
    try testing.expectEqual(.indirect, aggregateClassifyReturn(S32));
}

test "x86_64 aggregate: nested aggregates" {
    const Point = extern struct { x: f64, y: f64 };
    const Size = extern struct { width: f64, height: f64 };
    const Rect = extern struct { origin: Point, size: Size };
    const TaggedPoint = extern struct { pt: Point, tag: i32 };

    try testing.expectEqual(.normal, aggregateReturnConvention(Point));
    try testing.expectEqual(.normal, aggregateReturnConvention(Size));
    try testing.expectEqual(.stret, aggregateReturnConvention(TaggedPoint));
    try testing.expectEqual(.stret, aggregateReturnConvention(Rect));
}

test "x86_64 aggregate: arrays in structs" {
    const Array16 = extern struct { vals: [2]f64 };
    const Array24 = extern struct { vals: [3]f64 };

    try testing.expectEqual(.normal, aggregateReturnConvention(Array16));
    try testing.expectEqual(.stret, aggregateReturnConvention(Array24));

    const class_arr = classifyAggregate(Array16);
    try testing.expectEqual(Class.sse, class_arr.classes[0]);
    try testing.expectEqual(Class.sse, class_arr.classes[1]);
}

test "x86_64 aggregate: unions" {
    const Union8 = extern union { i: i64, d: f64 };
    try testing.expectEqual(.normal, aggregateReturnConvention(Union8));

    const class_u = classifyAggregate(Union8);
    try testing.expectEqual(Class.integer, class_u.classes[0]);
}

test "x86_64 aggregate: long double in aggregate" {
    const StructWithLongDouble = extern struct { x: c_longdouble };
    const StructMixedLongDouble = extern struct { a: i32, b: c_longdouble };

    try testing.expectEqual(.normal, aggregateReturnConvention(StructWithLongDouble));
    try testing.expectEqual(.stret, aggregateReturnConvention(StructMixedLongDouble));
}
