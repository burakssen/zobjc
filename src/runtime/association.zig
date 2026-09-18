//! Objective-C Associated Object support.
//!
//! Provides type-safe associated object attachment, inspection, and clearing
//! with exact ABI policy values and address-stable keys.

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


