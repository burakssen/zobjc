//! Tests for advanced runtime facilities and memory operations.
// ponytail: minimalist, zero overhead, verify manual instance lifecycle, memory copying, and associations removal.

const std = @import("std");
const objc = @import("objc");
const raw = objc.raw;
const testing = std.testing;

test "advanced: constructInstance and destructInstance" {
    const NSObject = objc.requireClass("NSObject");
    const size = NSObject.instanceSize();

    const buffer = try testing.allocator.alignedAlloc(u8, .fromByteUnits(@alignOf(raw.id)), size);
    defer testing.allocator.free(buffer);
    @memset(buffer, 0);

    const inst = objc.advanced.constructInstance(NSObject, buffer.ptr);
    try testing.expect(inst != null);
    try testing.expectEqual(NSObject.ptr, inst.?.class().ptr);

    // Call init
    _ = inst.?.msgSend(objc.Object, "init", .{});

    // Destruct instance without freeing storage
    const returned_storage = objc.advanced.destructInstance(inst.?);
    try testing.expectEqual(@as(?*anyopaque, @ptrCast(buffer.ptr)), returned_storage);
}

test "advanced: ConstructedInstance wrapper" {
    const NSObject = objc.requireClass("NSObject");
    const size = NSObject.instanceSize();

    const buffer = try testing.allocator.alignedAlloc(u8, .fromByteUnits(@alignOf(raw.id)), size);
    defer testing.allocator.free(buffer);
    @memset(buffer, 0);

    const inst = objc.advanced.constructInstance(NSObject, buffer.ptr).?;
    var constructed = objc.advanced.ConstructedInstance.init(inst);

    try testing.expectEqual(NSObject.ptr, constructed.borrow().class().ptr);

    const storage = constructed.destruct();
    try testing.expectEqual(@as(?*anyopaque, @ptrCast(buffer.ptr)), storage);
    try testing.expect(constructed.object == null);
}

test "advanced: copyObjectMemory and disposeObjectMemory" {
    const NSObject = objc.requireClass("NSObject");
    const obj = NSObject.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    defer obj.msgSend(void, "dealloc", .{});

    const copied = objc.advanced.copyObjectMemory(obj, 0);
    try testing.expect(copied != null);
    try testing.expectEqual(NSObject.ptr, copied.?.class().ptr);

    objc.advanced.disposeObjectMemory(copied);
}

test "advanced: removeAllAssociatedObjects" {
    const NSObject = objc.requireClass("NSObject");
    const host = NSObject.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    defer host.msgSend(void, "dealloc", .{});

    const key1 = objc.AssociationKey.init();
    const key2 = objc.AssociationKey.init();

    host.setAssociated(&key1, host, .assign);
    host.setAssociated(&key2, host, .assign);

    try testing.expect(host.associated(&key1) != null);
    try testing.expect(host.associated(&key2) != null);

    objc.advanced.removeAllAssociatedObjects(host);

    try testing.expect(host.associated(&key1) == null);
    try testing.expect(host.associated(&key2) == null);
}

test "advanced: internal SPI resolution" {
    const handler = objc.raw.internal.getSetForwardHandler();
    // On macOS, objc_setForwardHandler is an internal symbol; dynamic resolution returns without crashing
    _ = handler;
}
