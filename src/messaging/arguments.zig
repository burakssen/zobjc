//! Argument normalization and value conversion for Objective-C message dispatch.
//!
//! Maps high-level Zig argument types and values to their low-level C ABI representations.

const std = @import("std");
const testing = std.testing;
const raw = @import("raw");
const runtime = @import("runtime");
const wrapper = @import("internal").wrapper;
const Object = runtime.Object;
const Class = runtime.Class;
const Selector = runtime.Selector;
const Imp = runtime.Imp;

// Pure compile-time tuple and type mapping with zero runtime overhead.

/// Determines whether `T` is a sentinel-terminated string literal or slice.
pub fn isSentinelString(comptime T: type) bool {
    switch (@typeInfo(T)) {
        .pointer => |ptr| {
            if (ptr.child == u8 and ptr.sentinel_ptr != null) return true;
            if (@typeInfo(ptr.child) == .array and @typeInfo(ptr.child).array.child == u8) {
                if (ptr.sentinel_ptr != null or @typeInfo(ptr.child).array.sentinel_ptr != null) return true;
            }
        },
        else => {},
    }
    return false;
}

/// Normalizes a high-level Zig type `T` into its raw C ABI parameter type.
pub fn AbiArgumentType(comptime T: type) type {
    // 1. High-level runtime handles
    if (T == Object or T == ?Object) return raw.id;
    if (T == Class or T == ?Class) return raw.Class;
    if (T == Selector or T == ?Selector) return raw.SEL;
    if (T == Imp or T == ?Imp) return raw.IMP;

    if (@typeInfo(T) == .@"struct" and wrapper.isObjCWrapper(T)) {
        return switch (wrapper.wrapperKind(T)) {
            .object => raw.id,
            .class => raw.Class,
            .selector => raw.SEL,
            .imp => raw.IMP,
            .none => unreachable,
        };
    }

    // 2. Raw ABI handles
    if (T == raw.id or T == raw.Class or T == raw.SEL or T == raw.IMP) return T;
    if (T == *raw.objc_object or T == *raw.objc_class or T == *raw.objc_selector) return T;

    // 3. C-string literal normalization: map to [*:0]const u8
    if (isSentinelString(T)) return [*:0]const u8;

    // 4. Enums: map to their underlying integer tag type
    if (@typeInfo(T) == .@"enum") {
        return @typeInfo(T).@"enum".tag_type;
    }

    // 5. Pointers and optionals
    switch (@typeInfo(T)) {
        .pointer => return T,
        .optional => |opt| {
            if (@typeInfo(opt.child) == .pointer) return T;
        },
        .@"struct" => |s| {
            if (s.layout == .@"extern") return T;
        },
        .@"union" => |u| {
            if (u.layout == .@"extern") return T;
        },
        else => {},
    }

    return T;
}

/// Converts a high-level argument value to its corresponding raw ABI representation.
pub inline fn toAbi(val: anytype) AbiArgumentType(@TypeOf(val)) {
    const T = @TypeOf(val);

    if (comptime T == Object) {
        return val.ptr;
    } else if (comptime T == ?Object) {
        if (val) |o| return o.ptr;
        return null;
    } else if (comptime T == Class) {
        return val.ptr;
    } else if (comptime T == ?Class) {
        if (val) |c| return c.ptr;
        return null;
    } else if (comptime T == Selector) {
        return val.ptr;
    } else if (comptime T == ?Selector) {
        if (val) |s| return s.ptr;
        return null;
    } else     if (comptime T == Imp) {
        return val.ptr;
    } else if (comptime T == ?Imp) {
        if (val) |i| return i.ptr;
        return null;
    } else if (comptime wrapper.isObjCWrapper(T)) {
        return val.ptr;
    } else if (comptime isSentinelString(T)) {
        return @as([*:0]const u8, @ptrCast(val));
    } else if (comptime @typeInfo(T) == .@"enum") {
        return @intFromEnum(val);
    } else {
        return val;
    }
}

/// Maps a tuple of public argument types to a tuple of ABI argument types.
pub fn NormalizeTupleTypes(comptime Args: type) type {
    const fields = @typeInfo(Args).@"struct".fields;
    var abi_types: [fields.len]type = undefined;
    inline for (fields, 0..) |f, i| {
        abi_types[i] = AbiArgumentType(f.type);
    }
    return @Tuple(&abi_types);
}

/// Converts a tuple of public argument values to a tuple of ABI values.
pub inline fn normalizeTupleValues(args: anytype) NormalizeTupleTypes(@TypeOf(args)) {
    const Args = @TypeOf(args);
    const fields = @typeInfo(Args).@"struct".fields;
    var result: NormalizeTupleTypes(Args) = undefined;

    inline for (fields, 0..) |_, i| {
        result[i] = toAbi(args[i]);
    }
    return result;
}

const TestEnum = enum(c_int) {
    first = 10,
    second = 20,
};

const Point = extern struct {
    x: f64,
    y: f64,
};

test "arguments: handle normalization to raw ABI types" {
    try testing.expectEqual(raw.id, AbiArgumentType(Object));
    try testing.expectEqual(raw.id, AbiArgumentType(?Object));
    try testing.expectEqual(raw.Class, AbiArgumentType(Class));
    try testing.expectEqual(raw.Class, AbiArgumentType(?Class));
    try testing.expectEqual(raw.SEL, AbiArgumentType(Selector));
    try testing.expectEqual(raw.SEL, AbiArgumentType(?Selector));
    try testing.expectEqual(raw.IMP, AbiArgumentType(Imp));
}

test "arguments: enum normalization to tag type" {
    try testing.expectEqual(c_int, AbiArgumentType(TestEnum));
    try testing.expectEqual(@as(c_int, 20), toAbi(TestEnum.second));
}

test "arguments: string literal normalization to [*:0]const u8" {
    const literal = "hello world";
    try testing.expectEqual([*:0]const u8, AbiArgumentType(@TypeOf(literal)));

    const raw_ptr = toAbi(literal);
    try testing.expectEqualStrings("hello world", std.mem.span(raw_ptr));
}

test "arguments: extern struct remains unchanged" {
    try testing.expectEqual(Point, AbiArgumentType(Point));
    const pt = Point{ .x = 1.5, .y = 2.5 };
    const abi_pt = toAbi(pt);
    try testing.expectEqual(1.5, abi_pt.x);
    try testing.expectEqual(2.5, abi_pt.y);
}

test "arguments: tuple normalization" {
    const ArgsTuple = struct {
        Object,
        TestEnum,
        *const [5:0]u8,
        Point,
    };
    const Normalized = NormalizeTupleTypes(ArgsTuple);
    const fields = @typeInfo(Normalized).@"struct".fields;

    try testing.expectEqual(raw.id, fields[0].type);
    try testing.expectEqual(c_int, fields[1].type);
    try testing.expectEqual([*:0]const u8, fields[2].type);
    try testing.expectEqual(Point, fields[3].type);
}

test "arguments: wrapper ABI decay" {
    try testing.expectEqual(@sizeOf(Object), @sizeOf(raw.id));
    try testing.expectEqual(@alignOf(Object), @alignOf(raw.id));

    try testing.expectEqual(@sizeOf(Class), @sizeOf(raw.Class));
    try testing.expectEqual(@alignOf(Class), @alignOf(raw.Class));

    try testing.expectEqual(@sizeOf(Selector), @sizeOf(raw.SEL));
    try testing.expectEqual(@alignOf(Selector), @alignOf(raw.SEL));
}
