//! Low-level manual Objective-C instance construction and object memory manipulation.
//!
//! WARNING: These APIs require manual participation in Objective-C object storage
//! management and are marked unavailable under ARC. Callers are strictly responsible
//! for memory allocation, zero-filling, alignment, and eventual reclamation.

const std = @import("std");
const raw = @import("../raw/root.zig");
const Class = @import("../runtime/class.zig").Class;
const Object = @import("../runtime/object.zig").Object;

/// Constructs an Objective-C instance of `class` at `storage`.
///
/// REQUIREMENTS:
/// - `storage` must point to at least `class.instanceSize()` bytes.
/// - The memory must be appropriately aligned.
/// - The memory MUST be zero-filled prior to construction.
pub inline fn constructInstance(
    class: Class,
    storage: *anyopaque,
) ?Object {
    const raw_obj = raw.runtime.objc_constructInstance(class.ptr, storage);
    return Object.fromRaw(raw_obj);
}

/// Destroys an instance of a class without freeing its memory.
///
/// Returns the pointer to the backing storage. After destruction, the object
/// handle is invalid and must not be used.
pub inline fn destructInstance(object: Object) ?*anyopaque {
    return raw.runtime.objc_destructInstance(object.ptr);
}

/// Handle representing a manually constructed Objective-C instance.
///
/// IMPORTANT: `ConstructedInstance` does NOT own the backing bytes. Calling
/// `destruct()` invalidates the runtime object and clears internal handle,
/// returning the storage pointer for caller-controlled reclamation.
pub const ConstructedInstance = struct {
    object: ?Object,

    const Self = @This();

    /// Initializes a handle with an active constructed instance.
    pub fn init(obj: Object) Self {
        return .{ .object = obj };
    }

    /// Borrows the active Object handle. Panics if already destructed.
    pub fn borrow(self: Self) Object {
        return self.object orelse @panic("attempted to borrow destructed ConstructedInstance");
    }

    /// Destroys the Objective-C instance without freeing storage, invalidating this handle.
    /// Returns the backing storage pointer.
    pub fn destruct(self: *Self) ?*anyopaque {
        if (self.object) |obj| {
            const storage = destructInstance(obj);
            self.object = null;
            return storage;
        }
        return null;
    }
};

/// Copies an object's memory with extra bytes allocated.
///
/// Low-level wrapper around `object_copy`. Caller must free or dispose the returned object.
pub inline fn copyObjectMemory(
    object: Object,
    size: usize,
) ?Object {
    return Object.fromRaw(raw.runtime.object_copy(object.ptr, size));
}

/// Disposes an object's memory directly via the runtime without sending `-dealloc`.
///
/// Low-level wrapper around `object_dispose`.
pub inline fn disposeObjectMemory(object: ?Object) void {
    if (object) |obj| {
        _ = raw.runtime.object_dispose(obj.ptr);
    }
}

/// Removes all associations for a given object, including those installed by unrelated clients.
///
/// CAUTION: Apple explicitly discourages using this function as routine cleanup because
/// it removes other clients' associations too. Clear individual keys via `Object.clearAssociated`
/// instead.
pub inline fn removeAllAssociatedObjects(object: Object) void {
    raw.runtime.objc_removeAssociatedObjects(object.ptr);
}
