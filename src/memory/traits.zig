//! Compile-time traits for retainable Objective-C objects.

const std = @import("std");
const raw = @import("raw");
const Object = @import("runtime").Object;
const wrapper = @import("internal").wrapper;

/// Determines whether T is a retainable Objective-C object type.
///
/// Supported types are:
/// - `Object`
/// - Any explicit wrapper (`objc_wrapper`, `asObject`/`fromObject`, or
///   `toObjC`/`fromObjC`) whose `ptr` is `*raw.objc_object`.
pub fn isRetainable(comptime T: type) bool {
    if (T == Object) return true;
    if (!wrapper.isObjCWrapper(T)) return false;
    if (wrapper.wrapperKind(T) != .object) return false;
    switch (@typeInfo(T)) {
        .@"struct", .@"union", .@"enum", .@"opaque" => {
            // Explicit marker already verified by wrapper.isObjCWrapper.
            return true;
        },
        else => {},
    }
    return false;
}

/// Converts a retainable value into a raw `raw.id` pointer.
pub inline fn toRawId(val: anytype) raw.id {
    const T = @TypeOf(val);
    if (comptime T == Object) {
        return val.ptr;
    } else if (comptime isRetainable(T)) {
        if (comptime @hasDecl(T, "asObject")) {
            return val.asObject().ptr;
        } else if (comptime @hasDecl(T, "toObjC")) {
            return val.toObjC().ptr;
        } else {
            return @ptrCast(val.ptr);
        }
    } else {
        @compileError(@typeName(T) ++ " is not an Objective-C retainable object type");
    }
}

/// Converts a non-null raw `*raw.objc_object` pointer into a retainable value T.
pub inline fn fromRawIdNonNull(comptime T: type, p: *raw.objc_object) T {
    if (comptime T == Object) {
        return Object.fromRawNonNull(p);
    } else if (comptime isRetainable(T)) {
        if (comptime @hasDecl(T, "fromObject")) {
            return T.fromObject(Object.fromRawNonNull(p));
        } else if (comptime @hasDecl(T, "fromObjC")) {
            return T.fromObjC(Object.fromRawNonNull(p));
        } else {
            return T{ .ptr = p };
        }
    } else {
        @compileError(@typeName(T) ++ " is not an Objective-C retainable object type");
    }
}
