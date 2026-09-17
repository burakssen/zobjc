//! Compile-time traits for retainable Objective-C objects.

const std = @import("std");
const raw = @import("../raw/root.zig");
const Object = @import("../runtime/object.zig").Object;

/// Determines whether T is a retainable Objective-C object type.
///
/// Supported types are:
/// - `Object`
/// - Any custom wrapper providing `.asObject() Object` and `.fromObject(Object) T`.
pub fn isRetainable(comptime T: type) bool {
    if (T == Object) return true;
    switch (@typeInfo(T)) {
        .@"struct", .@"union", .@"enum", .@"opaque" => {
            if (@hasDecl(T, "asObject") and @hasDecl(T, "fromObject")) return true;
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
        return val.asObject().ptr;
    } else {
        @compileError(@typeName(T) ++ " is not an Objective-C retainable object type");
    }
}

/// Converts a non-null raw `*raw.objc_object` pointer into a retainable value T.
pub inline fn fromRawIdNonNull(comptime T: type, p: *raw.objc_object) T {
    if (comptime T == Object) {
        return Object.fromRawNonNull(p);
    } else if (comptime isRetainable(T)) {
        return T.fromObject(Object.fromRawNonNull(p));
    } else {
        @compileError(@typeName(T) ++ " is not an Objective-C retainable object type");
    }
}
