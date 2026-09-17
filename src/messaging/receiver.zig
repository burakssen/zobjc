//! Receiver normalization for Objective-C message dispatch.
//!
//! Converts high-level runtime entities (Object, Class, optionals) and raw handles
//! into the standard C ABI receiver pointer (`raw.id`).

const std = @import("std");
const raw = @import("raw");
const runtime = @import("runtime");
const Object = runtime.Object;
const Class = runtime.Class;

// Pure compile-time type validation with zero-cost pointer cast.

/// Returns true if `T` is a valid Objective-C message receiver type.
pub fn isValidReceiver(comptime T: type) bool {
    if (T == Object or T == ?Object) return true;
    if (T == Class or T == ?Class) return true;
    if (T == raw.id or T == raw.Class) return true;
    if (T == *raw.objc_object or T == *raw.objc_class) return true;
    if (@typeInfo(T) == .optional) {
        return isValidReceiver(@typeInfo(T).optional.child);
    }
    if (@typeInfo(T) == .@"struct" and @hasField(T, "ptr")) {
        const FieldType = @TypeOf(@as(T, undefined).ptr);
        if (FieldType == *raw.objc_object or FieldType == *raw.objc_class) return true;
    }
    return false;
}

/// Asserts at compile time that `T` is a valid receiver type.
pub fn assertValidReceiver(comptime T: type) void {
    if (comptime !isValidReceiver(T)) {
        @compileError("Invalid Objective-C message receiver type: '" ++ @typeName(T) ++ "'. " ++
            "Expected Object, ?Object, Class, ?Class, or raw handle.");
    }
}

/// Normalizes any valid receiver instance into a raw Objective-C `raw.id`.
pub inline fn toRaw(receiver: anytype) raw.id {
    const T = @TypeOf(receiver);
    assertValidReceiver(T);

    if (comptime T == Object) {
        return receiver.ptr;
    } else if (comptime T == ?Object) {
        if (receiver) |obj| return obj.ptr;
        return null;
    } else if (comptime T == Class) {
        return @ptrCast(receiver.ptr);
    } else if (comptime T == ?Class) {
        if (receiver) |cls| return @ptrCast(cls.ptr);
        return null;
    } else if (comptime T == raw.id) {
        return receiver;
    } else if (comptime T == raw.Class) {
        if (receiver) |cls| return @ptrCast(cls);
        return null;
    } else if (comptime T == *raw.objc_object) {
        return receiver;
    } else if (comptime T == *raw.objc_class) {
        return @ptrCast(receiver);
    } else if (comptime @typeInfo(T) == .optional) {
        if (receiver) |val| return toRaw(val);
        return null;
    } else if (comptime @typeInfo(T) == .@"struct" and @hasField(T, "ptr")) {
        return @ptrCast(receiver.ptr);
    } else {
        unreachable;
    }
}
