//! Objective-C Associated Object support.
//!
//! Provides type-safe associated object attachment, inspection, and clearing
//! with exact ABI policy values and address-stable keys.

const std = @import("std");
const testing = std.testing;
const objc = @import("zobjc");
const raw = @import("raw");
const Object = @import("object.zig").Object;
const memory = @import("memory");

/// Objective-C association policies matching Apple runtime values.
pub const AssociationPolicy = enum(usize) {
    assign = raw.runtime.OBJC_ASSOCIATION_ASSIGN,
    retain_nonatomic = raw.runtime.OBJC_ASSOCIATION_RETAIN_NONATOMIC,
    copy_nonatomic = raw.runtime.OBJC_ASSOCIATION_COPY_NONATOMIC,
    retain = raw.runtime.OBJC_ASSOCIATION_RETAIN,
    copy = raw.runtime.OBJC_ASSOCIATION_COPY,
};

/// Type-safe token providing pointer identity for an associated object key.
///
/// IMPORTANT: AssociationKey identity is its address. The key must remain at a
/// stable address (e.g., global/static storage) for as long as the association
/// is expected to be accessible.
pub const AssociationKey = struct {
    // // single-byte token prevents compiler zero-sized object alias anomalies
    token: u8 = 0,

    pub fn init() AssociationKey {
        return .{};
    }

    /// Returns the raw pointer identity for this key.
    pub inline fn raw(self: *const AssociationKey) *const anyopaque {
        return @ptrCast(self);
    }
};

/// Sets an associated value for a given object using a given key and association policy.
pub inline fn setAssociated(
    object: Object,
    key: *const AssociationKey,
    value: ?Object,
    policy: AssociationPolicy,
) void {
    const raw_val: raw.id = if (value) |v| v.ptr else null;
    raw.runtime.objc_setAssociatedObject(object.ptr, key.raw(), raw_val, @intFromEnum(policy));
}

/// Returns the value associated with a given object for a given key as a non-owning Object handle.
pub inline fn associated(
    object: Object,
    key: *const AssociationKey,
) ?Object {
    const raw_val = raw.runtime.objc_getAssociatedObject(object.ptr, key.raw());
    return Object.fromRaw(raw_val);
}

/// Clears an associated value for a given object and key.
pub inline fn clearAssociated(
    object: Object,
    key: *const AssociationKey,
) void {
    setAssociated(object, key, null, .assign);
}

/// Returns the value associated with a given object for a given key, retained into an owning `Retained(Object)`.
pub fn associatedRetained(
    object: Object,
    key: *const AssociationKey,
) ?memory.Retained(Object) {
    const obj = associated(object, key) orelse return null;
    return memory.Retained(Object).retain(obj);
}

extern "c" fn get_dealloc_count() c_int;
extern "c" fn reset_dealloc_count() void;

test "associated objects: assign policy" {
    const key = objc.AssociationKey.init();
    const host = objc.requireClass("NSObject").send(objc.Object, "alloc", .{})
        .send(objc.Object, "init", .{});
    defer host.send(void, "dealloc", .{});

    const target = objc.requireClass("NSObject").send(objc.Object, "alloc", .{})
        .send(objc.Object, "init", .{});
    defer target.send(void, "dealloc", .{});

    try testing.expect(host.associated(&key) == null);
    host.setAssociated(&key, target, .assign);
    const read = host.associated(&key);
    try testing.expect(read != null);
    try testing.expectEqual(target.ptr, read.?.ptr);
    host.clearAssociated(&key);
    try testing.expect(host.associated(&key) == null);
}

test "associated objects: retain policies and lifetime" {
    const key1 = objc.AssociationKey.init();
    const key2 = objc.AssociationKey.init();
    reset_dealloc_count();

    const host = objc.requireClass("NSObject").send(objc.Object, "alloc", .{})
        .send(objc.Object, "init", .{});
    const tracker1 = objc.requireClass("DeallocTracker").send(objc.Object, "alloc", .{})
        .send(objc.Object, "initWithIdentifier:", .{@as(c_int, 101)});
    const tracker2 = objc.requireClass("DeallocTracker").send(objc.Object, "alloc", .{})
        .send(objc.Object, "initWithIdentifier:", .{@as(c_int, 102)});

    host.setAssociated(&key1, tracker1, .retain_nonatomic);
    host.setAssociated(&key2, tracker2, .retain);
    tracker1.send(void, "release", .{});
    tracker2.send(void, "release", .{});

    try testing.expectEqual(@as(c_int, 0), get_dealloc_count());
    {
        var retained = host.associatedRetained(&key1);
        try testing.expect(retained != null);
        try testing.expectEqual(tracker1.ptr, retained.?.borrow().ptr);
        retained.?.deinit();
    }
    try testing.expectEqual(@as(c_int, 0), get_dealloc_count());

    host.clearAssociated(&key1);
    try testing.expectEqual(@as(c_int, 1), get_dealloc_count());
    try testing.expect(host.associated(&key1) == null);

    {
        var pool = objc.AutoreleasePool.init();
        try testing.expect(host.associated(&key2) != null);
        host.clearAssociated(&key2);
        pool.drain();
    }
    try testing.expectEqual(@as(c_int, 2), get_dealloc_count());
    try testing.expect(host.associated(&key2) == null);
    host.send(void, "release", .{});
}

test "associated objects: copy policies" {
    const key_non_atomic = objc.AssociationKey.init();
    const key_atomic = objc.AssociationKey.init();
    const host = objc.requireClass("NSObject").send(objc.Object, "alloc", .{})
        .send(objc.Object, "init", .{});
    defer host.send(void, "dealloc", .{});

    const original = objc.requireClass("CopyableTracker").send(objc.Object, "alloc", .{})
        .send(objc.Object, "initWithIdentifier:", .{@as(c_int, 200)});
    defer original.send(void, "release", .{});

    try testing.expectEqual(@as(c_int, 0), original.send(c_int, "copyCount", .{}));
    host.setAssociated(&key_non_atomic, original, .copy_nonatomic);
    const copied1 = host.associated(&key_non_atomic).?;
    try testing.expect(copied1.ptr != original.ptr);
    try testing.expectEqual(@as(c_int, 1), copied1.send(c_int, "copyCount", .{}));

    host.setAssociated(&key_atomic, original, .copy);
    const copied2 = host.associated(&key_atomic).?;
    try testing.expect(copied2.ptr != original.ptr);
    try testing.expectEqual(@as(c_int, 1), copied2.send(c_int, "copyCount", .{}));
}
