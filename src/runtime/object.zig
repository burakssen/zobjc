//! Objective-C instance (Object) handle.
//!
//! A non-owning, non-null handle to an Objective-C object instance (`id`).

const std = @import("std");
const raw = @import("../raw/root.zig");
const conversion = @import("conversion.zig");
const Class = @import("class.zig").Class;
const Selector = @import("selector.zig").Selector;
const sel_fn = @import("selector.zig").sel;
const Ivar = @import("ivar.zig").Ivar;
const Iterator = @import("iterator.zig").Iterator;
const MsgSend = @import("../messaging/msg_send.zig").MsgSend;

/// A non-owning, non-null handle to an Objective-C object instance (`id`).
pub const Object = struct {
    ptr: *raw.objc_object,

    // Implement msgSend and msgSendSuper
    const msg_send = MsgSend(Object, Object);
    pub const msgSend = msg_send.msgSend;
    pub const msgSendSuper = msg_send.msgSendSuper;

    /// Converts a raw nullable `raw.id` into an optional `Object`.
    pub inline fn fromRaw(val: raw.id) ?Object {
        const p = val orelse return null;
        return .{ .ptr = p };
    }

    /// Converts this `Object` into its raw `raw.id` pointer.
    pub inline fn toRaw(self: Object) raw.id {
        return self.ptr;
    }

    /// Creates an `Object` from a known non-null raw object pointer.
    pub inline fn fromRawNonNull(p: *raw.objc_object) Object {
        return .{ .ptr = p };
    }

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
        const p: *raw.objc_object = blk: {
            @setRuntimeSafety(false);
            const raw_p: raw.id = @ptrCast(@alignCast(id_val));
            break :blk raw_p orelse @panic("attempted to create Object from null id");
        };

        return .{ .ptr = p };
    }

    /// Returns the class of the object.
    pub inline fn class(self: Object) Class {
        const cls_ptr = raw.runtime.object_getClass(self.ptr) orelse unreachable;
        return Class.fromRawNonNull(cls_ptr);
    }

    /// Legacy alias for class().
    pub inline fn getClass(self: Object) ?Class {
        return Class.fromRaw(raw.runtime.object_getClass(self.ptr));
    }

    /// Sets the class of the object, returning the previous class.
    pub inline fn setClass(self: Object, new_class: Class) Class {
        const old_cls = raw.runtime.object_setClass(self.ptr, new_class.ptr) orelse unreachable;
        return Class.fromRawNonNull(old_cls);
    }

    /// Returns the class name of the object.
    pub inline fn className(self: Object) [:0]const u8 {
        return conversion.spanCString(raw.objc.object_getClassName(self.ptr));
    }

    /// Legacy alias for className().
    pub inline fn getClassName(self: Object) [:0]const u8 {
        return self.className();
    }

    /// Returns whether this object is a class object.
    pub inline fn isClass(self: Object) bool {
        return raw.boolResult(raw.runtime.object_isClass(self.ptr));
    }

    /// Returns a pointer to any extra memory allocated with the instance (indexed ivars).
    pub inline fn indexedIvars(self: Object) ?*anyopaque {
        return raw.objc.object_getIndexedIvars(self.ptr);
    }

    /// Reads an instance variable value via an Ivar handle.
    pub inline fn getIvar(self: Object, ivar_val: Ivar) ?Object {
        return Object.fromRaw(raw.runtime.object_getIvar(self.ptr, ivar_val.ptr));
    }

    /// Writes an instance variable value via an Ivar handle.
    pub inline fn setIvar(self: Object, ivar_val: Ivar, val: ?Object) void {
        const raw_val = if (val) |v| v.ptr else null;
        raw.runtime.object_setIvar(self.ptr, ivar_val.ptr, raw_val);
    }

    /// Compares two Object handles for pointer identity.
    pub inline fn eql(self: Object, other: Object) bool {
        return self.ptr == other.ptr;
    }

    /// Set a property. This is a helper around getProperty and is
    /// strictly less performant than doing it manually.
    pub fn setProperty(self: Object, comptime n: [:0]const u8, v: anytype) void {
        const cls = self.class();
        const setter = setter: {
            if (cls.getProperty(n)) |prop| {
                if (prop.copyAttributeValue("S")) |val| {
                    var owned = val;
                    defer owned.deinit();
                    break :setter sel_fn(owned.slice());
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
    /// strictly less performant than doing it manually.
    pub fn getProperty(self: Object, comptime T: type, comptime n: [:0]const u8) T {
        const cls = self.class();
        const getter = getter: {
            if (cls.getProperty(n)) |prop| {
                if (prop.copyAttributeValue("G")) |val| {
                    var owned = val;
                    defer owned.deinit();
                    break :getter sel_fn(owned.slice());
                }
            }

            break :getter sel_fn(n);
        };

        return self.msgSend(T, getter, .{});
    }

    /// Creates a copy of an object.
    pub fn copy(self: Object, extra_bytes: usize) ?Object {
        return Object.fromRaw(raw.runtime.object_copy(self.ptr, extra_bytes));
    }

    /// Frees the memory occupied by an object.
    pub fn dispose(self: Object) void {
        _ = raw.runtime.object_dispose(self.ptr);
    }

    /// Reads an instance variable value by name.
    pub fn getInstanceVariable(self: Object, name_str: [:0]const u8) ?Object {
        const ivar = raw.runtime.object_getInstanceVariable(self.ptr, name_str.ptr, null);
        return Object.fromRaw(raw.runtime.object_getIvar(self.ptr, ivar));
    }

    /// Writes an instance variable value by name.
    pub fn setInstanceVariable(self: Object, name_str: [:0]const u8, val: Object) void {
        const ivar = raw.runtime.object_getInstanceVariable(self.ptr, name_str.ptr, null);
        raw.runtime.object_setIvar(self.ptr, ivar, val.ptr);
    }

    // TODO(phase-3): Integrate retain/release into Retained(T) ownership type.
    pub fn retain(self: Object) Object {
        return Object.fromRawNonNull(raw.compiler_runtime.objc_retain(self.ptr).?);
    }

    pub fn release(self: Object) void {
        raw.compiler_runtime.objc_release(self.ptr);
    }

    /// Return an iterator for this object. The object must implement the
    /// `NSFastEnumeration` protocol.
    pub fn iterate(self: Object) Iterator {
        return Iterator.init(self);
    }

    comptime {
        std.debug.assert(@sizeOf(@This()) == @sizeOf(raw.id));
        std.debug.assert(@alignOf(@This()) == @alignOf(raw.id));
    }
};
