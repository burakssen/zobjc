//! Compile-time tuple manipulation utilities.
//!
//! Provides pure compile-time tuple concatenation, length inspection, and type mapping.

const std = @import("std");

// ponytail: Lean compile-time tuple helpers without allocations.

/// Returns the number of fields in tuple type `T`.
pub inline fn tupleLen(comptime T: type) usize {
    return @typeInfo(T).@"struct".fields.len;
}

/// Returns the type of field `index` in tuple type `T`.
pub inline fn tupleFieldType(comptime T: type, comptime index: usize) type {
    return @typeInfo(T).@"struct".fields[index].type;
}

/// Concatenates two tuple types into a single tuple type.
pub fn TupleConcat(comptime A: type, comptime B: type) type {
    const a_fields = @typeInfo(A).@"struct".fields;
    const b_fields = @typeInfo(B).@"struct".fields;
    const total_len = a_fields.len + b_fields.len;

    var types: [total_len]type = undefined;
    inline for (a_fields, 0..) |f, i| {
        types[i] = f.type;
    }
    inline for (b_fields, 0..) |f, i| {
        types[a_fields.len + i] = f.type;
    }

    return @Tuple(&types);
}

/// Concatenates two tuple values into a single tuple value.
pub inline fn concat(a: anytype, b: anytype) TupleConcat(@TypeOf(a), @TypeOf(b)) {
    const A = @TypeOf(a);
    const B = @TypeOf(b);
    const Res = TupleConcat(A, B);
    const a_len = @typeInfo(A).@"struct".fields.len;
    const b_len = @typeInfo(B).@"struct".fields.len;

    var result: Res = undefined;
    inline for (0..a_len) |i| {
        result[i] = a[i];
    }
    inline for (0..b_len) |i| {
        result[a_len + i] = b[i];
    }
    return result;
}
