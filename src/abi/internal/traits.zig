//! Comptime type predicates for ABI classification.

// Pure comptime @typeInfo inspection without external dependencies.

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

/// Returns true for a single-pointer-field struct of pointer size (after
/// peeling one optional layer): the machine-representation shape shared by
/// raw handles and small wrapper types. Lets the classifier reason about
/// representation instead of Objective-C identity.
pub fn isSinglePointerStruct(comptime T: type) bool {
    const U = if (@typeInfo(T) == .optional) @typeInfo(T).optional.child else T;
    if (@typeInfo(U) != .@"struct") return false;
    if (@sizeOf(U) != @sizeOf(usize)) return false;
    const fields = @typeInfo(U).@"struct".fields;
    if (fields.len != 1) return false;
    return isPointer(fields[0].type);
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

