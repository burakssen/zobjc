//! Compile-time traits for retainable Objective-C objects.

const std = @import("std");
const raw = @import("raw");
const wrapper = @import("internal").wrapper;

/// Determines whether T is a retainable Objective-C object type.
///
/// Any explicit wrapper (`objc_wrapper`, `asObject`/`fromObject`, or
/// `toObjC`/`fromObjC`) whose kind is `.object`, including the shared
/// object handle itself.
pub fn isRetainable(comptime T: type) bool {
    // NOTE: explicit `comptime` is load-bearing (see NOTE in abi/type.zig).
    if (comptime !wrapper.isObjCWrapper(T)) return false;
    if (comptime wrapper.wrapperKind(T) != .object) return false;
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
    if (comptime isRetainable(T)) {
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

/// Reconstructs an object-kind wrapper from a non-null raw pointer without
/// naming concrete runtime types. Prefers an exact
/// `fromRawNonNull(*raw.objc_object) -> T`, then the `fromObject`/`fromObjC`
/// conventions (with a structurally built input), then direct `.ptr`
/// construction.
fn fromRawObjectNonNull(comptime T: type, p: *raw.objc_object) T {
    if (comptime @hasDecl(T, "fromRawNonNull")) {
        const FT = @typeInfo(@TypeOf(@field(T, "fromRawNonNull")));
        if (FT == .@"fn" and FT.@"fn".params.len == 1 and
            FT.@"fn".params[0].type != null and
            FT.@"fn".params[0].type.? == *raw.objc_object and
            FT.@"fn".return_type == T)
        {
            return @field(T, "fromRawNonNull")(p);
        }
    }
    inline for (.{ "fromObject", "fromObjC" }) |fname| {
        if (@hasDecl(T, fname)) {
            const FT = @typeInfo(@TypeOf(@field(T, fname)));
            if (FT != .@"fn" or FT.@"fn".params.len != 1 or FT.@"fn".params[0].type == null) {
                @compileError(@typeName(T) ++ "." ++ fname ++ " must take exactly one typed parameter");
            }
            const PT = FT.@"fn".params[0].type.?;
            return @field(T, fname)(coerceObjectParam(PT, p));
        }
    }
    return T{ .ptr = p };
}

/// Builds an object-kind wrapper input from a non-null raw pointer: via its
/// own exact `fromRawNonNull`, or by direct `.ptr` construction.
fn coerceObjectParam(comptime PT: type, p: *raw.objc_object) PT {
    if (@hasDecl(PT, "fromRawNonNull")) {
        const FT = @typeInfo(@TypeOf(@field(PT, "fromRawNonNull")));
        if (FT == .@"fn" and FT.@"fn".params.len == 1 and
            FT.@"fn".params[0].type != null and
            FT.@"fn".params[0].type.? == *raw.objc_object and
            (FT.@"fn".return_type == PT or FT.@"fn".return_type == ?PT))
        {
            const made = @field(PT, "fromRawNonNull")(p);
            if (FT.@"fn".return_type == PT) return made;
            return made orelse unreachable;
        }
    }
    // NOTE: explicit wrapper required here, not merely a `ptr` field: the
    // project no longer duck-types on field names for reconstruction.
    if (comptime wrapper.isObjCWrapper(PT) and wrapper.wrapperKind(PT) == .object) {
        return PT{ .ptr = p };
    }
    @compileError("cannot reconstruct " ++ @typeName(PT) ++ " from a raw object pointer: " ++
        "provide fromRawNonNull(*raw.objc_object) or make it an explicit .object wrapper");
}

/// Converts a non-null raw `*raw.objc_object` pointer into a retainable value T.
pub inline fn fromRawIdNonNull(comptime T: type, p: *raw.objc_object) T {
    if (comptime isRetainable(T)) {
        return fromRawObjectNonNull(T, p);
    } else {
        @compileError(@typeName(T) ++ " is not an Objective-C retainable object type");
    }
}

const testing = std.testing;

const FixtureObject = struct {
    ptr: *raw.objc_object,
    pub const objc_wrapper = true;

    pub fn fromRawNonNull(p: *raw.objc_object) FixtureObject {
        return .{ .ptr = p };
    }
};

const FixtureBare = struct {
    ptr: *raw.objc_object,
    pub const objc_wrapper = true;
};

const FixtureFromObject = struct {
    ptr: *raw.objc_object,
    pub const objc_wrapper = true;

    pub fn fromObject(o: FixtureObject) FixtureFromObject {
        return .{ .ptr = o.ptr };
    }
};

const FixtureFromObjC = struct {
    ptr: *raw.objc_object,
    pub const objc_wrapper = true;

    pub fn fromObjC(o: FixtureObject) FixtureFromObjC {
        return .{ .ptr = o.ptr };
    }
};

test "traits: retainable recognition without runtime types" {
    try testing.expect(isRetainable(FixtureObject));
    try testing.expect(isRetainable(FixtureBare));
    try testing.expect(isRetainable(FixtureFromObject));
    try testing.expect(isRetainable(FixtureFromObjC));
    try testing.expect(!isRetainable(i32));
}

test "traits: reconstruction paths without runtime types" {
    const p: *raw.objc_object = @ptrFromInt(0x1000);
    try testing.expectEqual(p, toRawId(FixtureObject{ .ptr = p }));
    try testing.expectEqual(p, fromRawIdNonNull(FixtureObject, p).ptr);
    try testing.expectEqual(p, fromRawIdNonNull(FixtureBare, p).ptr);
    try testing.expectEqual(p, fromRawIdNonNull(FixtureFromObject, p).ptr);
    try testing.expectEqual(p, fromRawIdNonNull(FixtureFromObjC, p).ptr);
}
