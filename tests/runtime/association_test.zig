//! Tests for associated objects facility.
// ponytail: minimalist, zero overhead, verify all 5 policies and lifecycle.

const std = @import("std");
const objc = @import("objc");
const testing = std.testing;

extern "c" fn get_dealloc_count() c_int;
extern "c" fn reset_dealloc_count() void;

test "associated objects: assign policy" {
    const key = objc.AssociationKey.init();
    const host = objc.requireClass("NSObject").msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    defer host.msgSend(void, "dealloc", .{});

    const target = objc.requireClass("NSObject").msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    defer target.msgSend(void, "dealloc", .{});

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

    const host = objc.requireClass("NSObject").msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});

    const tracker1 = objc.requireClass("DeallocTracker").msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "initWithIdentifier:", .{@as(c_int, 101)});
    const tracker2 = objc.requireClass("DeallocTracker").msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "initWithIdentifier:", .{@as(c_int, 102)});

    // Associate tracker1 with retain_nonatomic
    host.setAssociated(&key1, tracker1, .retain_nonatomic);
    // Associate tracker2 with retain (atomic)
    host.setAssociated(&key2, tracker2, .retain);

    // Release local ownership of trackers
    tracker1.msgSend(void, "release", .{});
    tracker2.msgSend(void, "release", .{});

    // Both should still be alive because host retains them
    try testing.expectEqual(@as(c_int, 0), get_dealloc_count());

    // Test associatedRetained
    {
        var retained = host.associatedRetained(&key1);
        try testing.expect(retained != null);
        try testing.expectEqual(tracker1.ptr, retained.?.borrow().ptr);
        retained.?.deinit();
    }
    try testing.expectEqual(@as(c_int, 0), get_dealloc_count());

    // Clearing key1 should dealloc tracker1 (nonatomic policy does not autorelease on get)
    host.clearAssociated(&key1);
    try testing.expectEqual(@as(c_int, 1), get_dealloc_count());
    try testing.expect(host.associated(&key1) == null);

    // Note: atomic policy (retain) causes objc_getAssociatedObject to autorelease the returned value.
    // Draining an autorelease pool cleans up the autoreleased reference.
    {
        var pool = objc.AutoreleasePool.init();
        try testing.expect(host.associated(&key2) != null);
        host.clearAssociated(&key2);
        pool.drain();
    }
    try testing.expectEqual(@as(c_int, 2), get_dealloc_count());
    try testing.expect(host.associated(&key2) == null);

    host.release();
}

test "associated objects: copy policies" {
    const key_non_atomic = objc.AssociationKey.init();
    const key_atomic = objc.AssociationKey.init();

    const host = objc.requireClass("NSObject").msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    defer host.msgSend(void, "dealloc", .{});

    const original = objc.requireClass("CopyableTracker").msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "initWithIdentifier:", .{@as(c_int, 200)});
    defer original.msgSend(void, "release", .{});

    // Check initial copy count
    const initial_copies = original.msgSend(c_int, "copyCount", .{});
    try testing.expectEqual(@as(c_int, 0), initial_copies);

    // Set with copy_nonatomic
    host.setAssociated(&key_non_atomic, original, .copy_nonatomic);
    const copied1 = host.associated(&key_non_atomic).?;
    // Copied object pointer should differ from original
    try testing.expect(copied1.ptr != original.ptr);
    const count1 = copied1.msgSend(c_int, "copyCount", .{});
    try testing.expectEqual(@as(c_int, 1), count1);

    // Set with copy (atomic)
    host.setAssociated(&key_atomic, original, .copy);
    const copied2 = host.associated(&key_atomic).?;
    try testing.expect(copied2.ptr != original.ptr);
    const count2 = copied2.msgSend(c_int, "copyCount", .{});
    try testing.expectEqual(@as(c_int, 1), count2);
}
