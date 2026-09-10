//! Argument normalization and value conversion for Objective-C message dispatch.
//!
//! Maps high-level Zig argument types and values to their low-level C ABI representations.

const std = @import("std");
const raw = @import("../raw/root.zig");
const runtime = @import("../runtime/root.zig");
const Object = runtime.Object;
const Class = runtime.Class;
const Selector = runtime.Selector;
const Imp = runtime.Imp;

// ponytail: Pure compile-time tuple and type mapping with zero runtime overhead.

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

    if (@typeInfo(T) == .@"struct" and @hasField(T, "ptr")) {
        const FieldType = @TypeOf(@as(T, undefined).ptr);
        if (FieldType == *raw.objc_object) return raw.id;
        if (FieldType == *raw.objc_class) return raw.Class;
        if (FieldType == *raw.objc_selector) return raw.SEL;
        if (FieldType == raw.IMP or FieldType == ?raw.IMP) return raw.IMP;
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
    } else if (comptime T == Imp) {
        return val.ptr;
    } else if (comptime T == ?Imp) {
        if (val) |i| return i.ptr;
        return null;
    } else if (comptime @typeInfo(T) == .@"struct" and @hasField(T, "ptr")) {
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
