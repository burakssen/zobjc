//! Comptime type predicates for ABI classification.

const std = @import("std");
const raw = @import("raw");
const runtime = @import("runtime");

// Use pure comptime @typeInfo inspection without external dependencies.

/// Returns true if T is an integer or bool type.
pub fn isInteger(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .int, .bool => true,
        .@"enum" => true,
        else => false,
    };
}

/// Returns true if T is a pointer type (single-item, C-pointer, or optional pointer).
pub fn isPointer(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .pointer => true,
        .optional => |opt| @typeInfo(opt.child) == .pointer,
        else => false,
    };
}

/// Returns true if T is an Objective-C object, class, or selector handle.
pub fn isObjCObjectHandle(comptime T: type) bool {
    if (T == runtime.Object or T == ?runtime.Object) return true;
    if (T == runtime.Class or T == ?runtime.Class) return true;
    if (T == runtime.Selector or T == ?runtime.Selector) return true;
    if (T == raw.id or T == raw.Class or T == raw.SEL) return true;
    if (T == ?*raw.objc_object or T == ?*raw.objc_class or T == ?*raw.objc_selector) return true;
    if (T == *raw.objc_object or T == *raw.objc_class or T == *raw.objc_selector) return true;
    switch (@typeInfo(T)) {
        .optional => |opt| return isObjCObjectHandle(opt.child),
        .@"struct" => |s| {
            if (@sizeOf(T) == @sizeOf(usize)) {
                if (s.fields.len == 1 and isPointer(s.fields[0].type)) return true;
            }
        },
        else => {},
    }
    return false;
}

/// Returns true if T is a standard IEEE floating-point type (f16, f32, f64).
pub fn isStandardFloat(comptime T: type) bool {
    return T == f16 or T == f32 or T == f64;
}

/// Returns true if T is C long double.
pub fn isLongDouble(comptime T: type) bool {
    return T == c_longdouble or T == f80;
}

/// Returns true if T represents a C `_Complex long double`.
/// ponytail: Zig has no complex type in @typeInfo, so there is no Zig spelling
/// of C `_Complex long double`. An `extern struct` of two long doubles is an
/// ordinary aggregate (SysV: MEMORY/stret when >16 bytes), NOT COMPLEX_X87,
/// so this deliberately returns false — `fp2ret` is never auto-selected.
pub fn isComplexLongDouble(comptime T: type) bool {
    _ = T;
    return false;
}
