//! Explicit Objective-C wrapper trait.
//!
//! A custom Zig type opts into Objective-C handle semantics by declaring BOTH:
//! 1. a `ptr` field whose type is one of `*raw.objc_object`, `*raw.objc_class`,
//!    `*raw.objc_selector`, `raw.IMP`, or `?raw.IMP`, and
//! 2. an explicit opt-in marker: either
//!    - `pub const objc_wrapper = true;`, or
//!    - `asObject()/fromObject()` (memory convention), or
//!    - `toObjC()/fromObjC()`.
//!
//! A struct that merely happens to contain a field named `ptr` is NOT a
//! wrapper. This replaces the old duck-typing rule that treated any struct
//! with a `ptr` field as an Objective-C handle.

const raw = @import("raw");

/// Which raw handle a wrapper struct carries in its `ptr` field.
pub const WrapperKind = enum {
    object,
    class,
    selector,
    imp,
    none,
};

fn ptrFieldKind(comptime T: type) WrapperKind {
    if (@typeInfo(T) != .@"struct") return .none;
    if (!@hasField(T, "ptr")) return .none;
    const FieldType = @TypeOf(@as(T, undefined).ptr);
    if (FieldType == *raw.objc_object) return .object;
    if (FieldType == *raw.objc_class) return .class;
    if (FieldType == *raw.objc_selector) return .selector;
    if (FieldType == raw.IMP or FieldType == ?raw.IMP) return .imp;
    // `Imp.ptr` stores the unwrapped function pointer (same ABI, non-optional).
    if (FieldType == @typeInfo(raw.IMP).optional.child) return .imp;
    return .none;
}

fn hasExplicitMarker(comptime T: type) bool {
    if (@hasDecl(T, "objc_wrapper")) {
        const marker = @field(T, "objc_wrapper");
        if (@TypeOf(marker) != bool) {
            @compileError("objc_wrapper must be a bool in '" ++ @typeName(T) ++ "'");
        }
        return marker;
    }
    if (@hasDecl(T, "asObject") and @hasDecl(T, "fromObject")) return true;
    if (@hasDecl(T, "toObjC") and @hasDecl(T, "fromObjC")) return true;
    return false;
}

/// Returns true for a struct that explicitly opts into wrapper semantics.
pub fn isObjCWrapper(comptime T: type) bool {
    if (@typeInfo(T) == .optional) return isObjCWrapper(@typeInfo(T).optional.child);
    if (@typeInfo(T) != .@"struct") return false;
    if (ptrFieldKind(T) == .none) return false;
    return hasExplicitMarker(T);
}

/// Classifies the wrapped handle, or `.none` for non-wrappers.
pub fn wrapperKind(comptime T: type) WrapperKind {
    if (@typeInfo(T) == .optional) return wrapperKind(@typeInfo(T).optional.child);
    if (!isObjCWrapper(T)) return .none;
    return ptrFieldKind(T);
}

/// Converts a wrapper value to its raw `ptr` contents.
pub inline fn toRawPtr(val: anytype) @TypeOf(@as(@TypeOf(val), undefined).ptr) {
    return val.ptr;
}

const testing = @import("std").testing;

const ExplicitObject = struct {
    ptr: *raw.objc_object,
    pub const objc_wrapper = true;
};

const AsObjectPair = struct {
    ptr: *raw.objc_object,
    pub fn asObject(self: @This()) @This() {
        return self;
    }
    pub fn fromObject(o: @This()) @This() {
        return o;
    }
};

const BarePtr = struct {
    ptr: *raw.objc_object,
};

const ExplicitFalse = struct {
    ptr: *raw.objc_object,
    pub const objc_wrapper = false;
};

const OtherPtr = struct {
    ptr: *u8,
    pub const objc_wrapper = true;
};

test "wrapper: explicit markers are recognized" {
    try testing.expect(isObjCWrapper(ExplicitObject));
    try testing.expect(isObjCWrapper(?ExplicitObject));
    try testing.expect(isObjCWrapper(AsObjectPair));
    try testing.expectEqual(WrapperKind.object, wrapperKind(ExplicitObject));
    try testing.expectEqual(WrapperKind.object, wrapperKind(?ExplicitObject));
}

test "wrapper: explicit false opts out" {
    try testing.expect(!isObjCWrapper(ExplicitFalse));
    try testing.expect(!isObjCWrapper(?ExplicitFalse));
    try testing.expectEqual(WrapperKind.none, wrapperKind(ExplicitFalse));
}

test "wrapper: bare ptr structs are rejected" {
    try testing.expect(!isObjCWrapper(BarePtr));
    try testing.expect(!isObjCWrapper(?BarePtr));
    try testing.expectEqual(WrapperKind.none, wrapperKind(BarePtr));
    try testing.expect(!isObjCWrapper(OtherPtr));
    try testing.expect(!isObjCWrapper(u8));
}
