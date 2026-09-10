//! Return type normalization and conversion for Objective-C message dispatch.
//!
//! Maps high-level return types to raw C ABI types and safely converts raw returns
//! into user-requested types, enforcing non-null invariants.

const std = @import("std");
const raw = @import("../raw/root.zig");
const runtime = @import("../runtime/root.zig");
const Object = runtime.Object;
const Class = runtime.Class;
const Selector = runtime.Selector;
const Imp = runtime.Imp;

// ponytail: Explicit type mapping matching ABI classification requirements with zero allocation.

/// Maps a user-requested return type `T` to its low-level C ABI return type.
pub fn AbiReturnType(comptime T: type) type {
    if (T == void) return void;

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
    if (@typeInfo(T) == .optional and @typeInfo(@typeInfo(T).optional.child) == .@"struct" and @hasField(@typeInfo(T).optional.child, "ptr")) {
        const Child = @typeInfo(T).optional.child;
        const FieldType = @TypeOf(@as(Child, undefined).ptr);
        if (FieldType == *raw.objc_object) return raw.id;
        if (FieldType == *raw.objc_class) return raw.Class;
        if (FieldType == *raw.objc_selector) return raw.SEL;
        if (FieldType == raw.IMP or FieldType == ?raw.IMP) return raw.IMP;
    }

    // 2. Raw handles
    if (T == raw.id or T == raw.Class or T == raw.SEL or T == raw.IMP) return T;

    // 3. Enums: map to tag type
    if (@typeInfo(T) == .@"enum") {
        return @typeInfo(T).@"enum".tag_type;
    }

    // 4. All other C-ABI compatible types (scalars, pointers, extern structs, unions)
    return T;
}

/// Converts a raw C ABI return value to the user-requested `Return` type.
pub inline fn fromAbi(comptime Return: type, raw_val: AbiReturnType(Return)) Return {
    if (comptime Return == void) return {};

    if (comptime Return == ?Object) {
        return Object.fromRaw(raw_val);
    } else if (comptime Return == Object) {
        return Object.fromRaw(raw_val) orelse @panic("Objective-C message returned nil for non-null Object return type");
    } else if (comptime Return == ?Class) {
        return Class.fromRaw(raw_val);
    } else if (comptime Return == Class) {
        return Class.fromRaw(raw_val) orelse @panic("Objective-C message returned nil for non-null Class return type");
    } else if (comptime Return == ?Selector) {
        return Selector.fromRaw(raw_val);
    } else if (comptime Return == Selector) {
        return Selector.fromRaw(raw_val) orelse @panic("Objective-C message returned nil for non-null Selector return type");
    } else if (comptime Return == ?Imp) {
        return Imp.fromRaw(raw_val);
    } else if (comptime Return == Imp) {
        return Imp.fromRaw(raw_val) orelse @panic("Objective-C message returned nil for non-null Imp return type");
    } else if (comptime @typeInfo(Return) == .optional and @typeInfo(@typeInfo(Return).optional.child) == .@"struct" and @hasField(@typeInfo(Return).optional.child, "ptr")) {
        const Child = @typeInfo(Return).optional.child;
        if (raw_val) |p| {
            return Child{ .ptr = @ptrCast(p) };
        }
        return null;
    } else if (comptime @typeInfo(Return) == .@"struct" and @hasField(Return, "ptr")) {
        const p = raw_val orelse @panic("Objective-C message returned nil for non-null return type");
        return Return{ .ptr = @ptrCast(p) };
    } else if (comptime @typeInfo(Return) == .@"enum") {
        return @enumFromInt(raw_val);
    } else {
        return raw_val;
    }
}
