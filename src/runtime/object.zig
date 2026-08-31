//! Objective-C instance (Object) handle.

const std = @import("std");
const raw = @import("../raw/root.zig");
const selector_pkg = @import("selector.zig");
const Selector = selector_pkg.Selector;
const sel_fn = selector_pkg.sel;
const class_pkg = @import("class.zig");
const Iterator = @import("iterator.zig").Iterator;
const MsgSend = @import("../messaging/msg_send.zig").MsgSend;

/// Object is an instance of a class.
pub const Object = struct {
    value: raw.id,

    // Implement msgSend and msgSendSuper
    const msg_send = MsgSend(Object, Object);
    pub const msgSend = msg_send.msgSend;
    pub const msgSendSuper = msg_send.msgSendSuper;

    /// Convert a raw "id" into an Object. id must fit the size of the
    /// normal C "id" type (i.e. a `usize`).
    pub fn fromId(id_val: anytype) Object {
        if (@sizeOf(@TypeOf(id_val)) != @sizeOf(raw.id)) {
            @compileError("invalid id type");
        }

        // Some pointers in Objective-C are "tagged pointers", which
        // may be used for small objects and literals (NSNumber, NSString).
        // It's an internal implementation detail that replaces heap
        // allocation with direct encoding within the pointer itself.
        // This may result in UNALIGNED POINTERS!
        const ptr: raw.id = blk: {
            @setRuntimeSafety(false);
            break :blk @ptrCast(@alignCast(id_val));
        };

        return .{ .value = ptr };
    }

    /// Returns the class of an object.
    pub fn getClass(self: Object) ?class_pkg.Class {
        const cls_ptr = raw.runtime.object_getClass(self.value) orelse return null;
        return class_pkg.Class{
            .value = cls_ptr,
        };
    }

    /// Returns the class name of a given object.
    pub fn getClassName(self: Object) [:0]const u8 {
        return std.mem.span(raw.objc.object_getClassName(self.value));
    }

    /// Set a property. This is a helper around getProperty and is
    /// strictly less performant than doing it manually. Consider doing
    /// this manually if performance is critical.
    pub fn setProperty(self: Object, comptime n: [:0]const u8, v: anytype) void {
        const cls = self.getClass().?;
        const setter = setter: {
            if (cls.getProperty(n)) |prop| {
                if (prop.copyAttributeValue("S")) |val| {
                    defer std.heap.c_allocator.free(val);
                    break :setter sel_fn(val);
                }
            }

            break :setter sel_fn(
                "set" ++
                    [1]u8{std.ascii.toUpper(n[0])} ++
                    n[1..n.len] ++
                    ":",
            );
        };

        self.msgSend(void, setter, .{v});
    }

    /// Get a property. This is a helper around Class.getProperty and is
    /// strictly less performant than doing it manually. Consider doing
    /// this manually if performance is critical.
    pub fn getProperty(self: Object, comptime T: type, comptime n: [:0]const u8) T {
        const cls = self.getClass().?;
        const getter = getter: {
            if (cls.getProperty(n)) |prop| {
                if (prop.copyAttributeValue("G")) |val| {
                    defer std.heap.c_allocator.free(val);
                    break :getter sel_fn(val);
                }
            }

            break :getter sel_fn(n);
        };

        return self.msgSend(T, getter, .{});
    }

    pub fn copy(self: Object, size: usize) Object {
        return fromId(raw.runtime.object_copy(self.value, size));
    }

    pub fn dispose(self: Object) void {
        _ = raw.runtime.object_dispose(self.value);
    }

    pub fn isClass(self: Object) bool {
        return raw.boolResult(raw.runtime.object_isClass(self.value));
    }

    pub fn getInstanceVariable(self: Object, name: [:0]const u8) Object {
        const ivar = raw.runtime.object_getInstanceVariable(self.value, name, null);
        return fromId(raw.runtime.object_getIvar(self.value, ivar));
    }

    pub fn setInstanceVariable(self: Object, name: [:0]const u8, val: Object) void {
        const ivar = raw.runtime.object_getInstanceVariable(self.value, name, null);
        raw.runtime.object_setIvar(self.value, ivar, val.value);
    }

    // TODO(phase-3): Integrate retain/release into Retained(T) ownership type.
    pub fn retain(self: Object) Object {
        return fromId(raw.compiler_runtime.objc_retain(self.value));
    }

    pub fn release(self: Object) void {
        raw.compiler_runtime.objc_release(self.value);
    }

    /// Return an iterator for this object. The object must implement the
    /// `NSFastEnumeration` protocol.
    pub fn iterate(self: Object) Iterator {
        return Iterator.init(self);
    }
};
