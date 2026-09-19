//! Argument normalization and value conversion for Objective-C message dispatch.
//!
//! Maps high-level Zig argument types and values to their low-level C ABI representations.

const std = @import("std");
const testing = std.testing;
const raw = @import("raw");
const wrapper = @import("internal").wrapper;

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
    // 1. Explicit wrappers (direct or optional) decay to their raw handle.
    // NOTE: explicit `comptime` is load-bearing (see NOTE in abi/type.zig).
    if (comptime wrapper.isObjCWrapper(T)) {
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

    if (comptime wrapper.isObjCWrapper(T)) {
        // Optional wrappers decay element-wise; the raw handle types are
        // already nullable at the C level.
        if (@typeInfo(T) == .optional) {
            if (val) |v| return @ptrCast(v.ptr);
            return null;
        }
        return @ptrCast(val.ptr);
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

/// Returns true if any argument in `Args` requires ABI normalization.
pub inline fn needsNormalization(comptime Args: type) bool {
    const fields = @typeInfo(Args).@"struct".fields;
    if (fields.len == 0) return false;
    inline for (fields) |f| {
        if (AbiArgumentType(f.type) != f.type) return true;
    }
    return false;
}

/// Converts a tuple of public argument values to a tuple of ABI values.
// if no arguments need ABI decay, return the tuple unchanged
pub inline fn normalizeTupleValues(args: anytype) if (!needsNormalization(@TypeOf(args))) @TypeOf(args) else NormalizeTupleTypes(@TypeOf(args)) {
    const Args = @TypeOf(args);
    if (comptime !needsNormalization(Args)) {
        return args;
    }

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

const FixtureObject = struct {
    ptr: *raw.objc_object,
    pub const objc_wrapper = true;
};

const FixtureClass = struct {
    ptr: *raw.objc_class,
    pub const objc_wrapper = true;
};

const FixtureSelector = struct {
    ptr: *raw.objc_selector,
    pub const objc_wrapper = true;
};

const FixtureImp = struct {
    ptr: *const fn () callconv(.c) void,
    pub const objc_wrapper = true;
};

const CustomObject = struct {
    ptr: *raw.objc_object,
    pub const objc_wrapper = true;
};

test "arguments: handle normalization to raw ABI types" {
    try testing.expectEqual(raw.id, AbiArgumentType(FixtureObject));
    try testing.expectEqual(raw.id, AbiArgumentType(?FixtureObject));
    try testing.expectEqual(raw.Class, AbiArgumentType(FixtureClass));
    try testing.expectEqual(raw.Class, AbiArgumentType(?FixtureClass));
    try testing.expectEqual(raw.SEL, AbiArgumentType(FixtureSelector));
    try testing.expectEqual(raw.SEL, AbiArgumentType(?FixtureSelector));
    try testing.expectEqual(raw.IMP, AbiArgumentType(FixtureImp));
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
        FixtureObject,
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
    try testing.expectEqual(@sizeOf(FixtureObject), @sizeOf(raw.id));
    try testing.expectEqual(@alignOf(FixtureObject), @alignOf(raw.id));

    try testing.expectEqual(@sizeOf(FixtureClass), @sizeOf(raw.Class));
    try testing.expectEqual(@alignOf(FixtureClass), @alignOf(raw.Class));

    try testing.expectEqual(@sizeOf(FixtureSelector), @sizeOf(raw.SEL));
    try testing.expectEqual(@alignOf(FixtureSelector), @alignOf(raw.SEL));
}

test "arguments: optional custom wrappers decay to raw handles" {
    try testing.expectEqual(raw.id, AbiArgumentType(?CustomObject));
    try testing.expectEqual(@as(raw.id, null), toAbi(@as(?CustomObject, null)));
    const w = CustomObject{ .ptr = @ptrFromInt(0x1000) };
    try testing.expectEqual(@as(raw.id, @ptrFromInt(0x1000)), toAbi(w));
    try testing.expectEqual(@as(raw.id, @ptrFromInt(0x1000)), toAbi(@as(?CustomObject, w)));
}

const FixtureBlock = struct {
    ptr: *raw.blocks.Block_layout,
};

const FixtureOwnedBlock = struct {
    ptr: ?*raw.blocks.Block_layout = null,
};

test "arguments: Block and OwnedBlock decay to raw.id" {
    try testing.expectEqual(raw.id, AbiArgumentType(FixtureBlock));
    try testing.expectEqual(raw.id, AbiArgumentType(?FixtureBlock));
    try testing.expectEqual(raw.id, AbiArgumentType(FixtureOwnedBlock));
    try testing.expectEqual(raw.id, AbiArgumentType(?FixtureOwnedBlock));

    const blk = FixtureBlock{ .ptr = @ptrFromInt(0x3000) };
    try testing.expectEqual(@as(raw.id, @ptrFromInt(0x3000)), toAbi(blk));

    const owned_blk = FixtureOwnedBlock{ .ptr = @ptrFromInt(0x4000) };
    try testing.expectEqual(@as(raw.id, @ptrFromInt(0x4000)), toAbi(owned_blk));
}
