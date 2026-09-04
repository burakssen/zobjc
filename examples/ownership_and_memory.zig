//! Example demonstrating Phase 3 Ownership and Lifetime Abstractions.
//!
//! Covers:
//! - Retained(T): explicit strong reference ownership
//! - Weak(T): zeroing weak references
//! - AutoreleasePool: scoped autorelease pools
//! - OwnedRuntimeList(T): runtime-allocated metadata lists
//! - OwnedCString: runtime-allocated C strings

const std = @import("std");
const objc = @import("objc");

pub fn main() void {
    // 1. Scoped Autorelease Pool
    var pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const NSObject = objc.requireClass("NSObject");

    // 2. Strong Ownership with Retained(T)
    std.debug.print("--- Retained(T) Demo ---\n", .{});
    {
        const raw_obj = NSObject.msgSend(objc.Object, "alloc", .{})
            .msgSend(objc.Object, "init", .{});

        // Adopt newly allocated object into Retained
        var strong = objc.Retained(objc.Object).adopt(raw_obj);
        defer strong.deinit();

        std.debug.print("Created and adopted object: ptr=0x{x}\n", .{@intFromPtr(strong.borrow().toRaw())});

        // Clone increments reference count
        var strong_copy = strong.clone();
        defer strong_copy.deinit();
        std.debug.print("Cloned strong reference: ptr=0x{x}\n", .{@intFromPtr(strong_copy.borrow().toRaw())});
    }

    // 3. Weak Reference Storage with Weak(T)
    std.debug.print("\n--- Weak(T) Demo ---\n", .{});
    {
        var weak: objc.Weak(objc.Object) = .{};
        defer weak.deinit();

        {
            const inner_raw = NSObject.msgSend(objc.Object, "alloc", .{})
                .msgSend(objc.Object, "init", .{});
            var inner_strong = objc.Retained(objc.Object).adopt(inner_raw);

            // Initialize weak reference in-place
            weak.init(inner_strong.borrow());

            if (weak.loadRetained()) |*loaded| {
                var m = loaded.*;
                defer m.deinit();
                std.debug.print("Weak loaded while strong alive: ptr=0x{x}\n", .{@intFromPtr(m.borrow().toRaw())});
            }

            inner_strong.deinit();
            // inner_strong has deallocated here
        }

        // Weak slot is now zeroed
        if (weak.loadRetained()) |_| {
            std.debug.print("ERROR: weak should be nil!\n", .{});
        } else {
            std.debug.print("Weak reference automatically zeroed after deallocation: null\n", .{});
        }
    }

    // 4. Runtime-Allocated Metadata Lists with OwnedRuntimeList(T)
    std.debug.print("\n--- OwnedRuntimeList(T) Demo ---\n", .{});
    {
        var methods = NSObject.methods();
        defer methods.deinit();

        std.debug.print("NSObject has {d} instance methods.\n", .{methods.count()});
        if (methods.get(0)) |first_method| {
            std.debug.print("First method selector: {s}\n", .{first_method.getName().getName()});

            // 5. Runtime-Allocated C String with OwnedCString
            if (first_method.copyReturnType()) |ret_type| {
                var mut_ret = ret_type;
                defer mut_ret.deinit();
                std.debug.print("First method return type encoding: {s}\n", .{mut_ret.slice()});
            }
        }
    }

    std.debug.print("\nOwnership and lifetime demo completed successfully.\n", .{});
}
