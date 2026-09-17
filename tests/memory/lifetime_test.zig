//! Ownership and lifetime verification tests ensuring deterministic deallocation
//! without fragile retain-count inspection.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

// Tracking hooks from fixtures
extern fn reset_dealloc_count() void;
extern fn get_dealloc_count() c_int;

test "lifetime: Retained ownership lifecycle using destruction counter" {
    reset_dealloc_count();
    const Tracker = objc.getClass("DeallocTracker").?;

    {
        const raw_obj = objc.send(objc.Object, Tracker, "alloc", .{}).send(objc.Object, "initWithIdentifier:", .{@as(c_int, 42)});
        var retained = objc.memory.Retained(objc.Object).adopt(raw_obj);

        try testing.expectEqual(@as(c_int, 0), get_dealloc_count());
        try testing.expectEqual(@as(c_int, 42), retained.borrow().send(c_int, "identifier", .{}));

        {
            // Clone (increments reference count)
            var clone = retained.clone();
            try testing.expectEqual(@as(c_int, 0), get_dealloc_count());
            try testing.expectEqual(@as(c_int, 42), clone.borrow().send(c_int, "identifier", .{}));
            clone.deinit();
            // Still alive because 'retained' holds it
            try testing.expectEqual(@as(c_int, 0), get_dealloc_count());
        }

        retained.deinit();
    }

    // Must be deallocated now that all owners released
    try testing.expectEqual(@as(c_int, 1), get_dealloc_count());
}

test "lifetime: Weak zeroing upon target deallocation" {
    const Tracker = objc.getClass("DeallocTracker").?;

    var weak: objc.memory.Weak(objc.Object) = .{};
    defer weak.deinit();
    {
        var pool = objc.AutoreleasePool.init();
        defer pool.deinit();

        const raw_obj = objc.send(objc.Object, Tracker, "alloc", .{}).send(objc.Object, "initWithIdentifier:", .{@as(c_int, 99)});
        var strong = objc.memory.Retained(objc.Object).adopt(raw_obj);

        weak.init(strong.borrow());
        try testing.expect(weak.loadBorrowed() != null);
        try testing.expectEqual(@as(c_int, 99), weak.loadBorrowed().?.send(c_int, "identifier", .{}));

        strong.deinit();
    }

    // Referent was destroyed, weak must now return null (zeroed)
    try testing.expect(weak.loadBorrowed() == null);
}

test "lifetime: runtime list wrappers correctly release caller-freed memory" {
    const NSObject = objc.getClass("NSObject").?;

    // Copy method list and iterate
    {
        var methods = NSObject.methods();
        defer methods.deinit();
        try testing.expect(methods.len > 0);
    }

    // Copy property list
    {
        var props = NSObject.properties();
        defer props.deinit();
    }

    // Copy ivar list
    {
        var ivars = NSObject.ivars();
        defer ivars.deinit();
    }

    // Copy class list
    {
        var classes = objc.runtime.classes();
        defer classes.deinit();
        try testing.expect(classes.len > 0);
    }

    // Copy image names
    {
        var images = objc.runtime.images();
        defer images.deinit();
        try testing.expect(images.len > 0);
    }
}
