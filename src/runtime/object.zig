//! Objective-C instance (Object) handle.
//!
//! A non-owning, non-null handle to an Objective-C object instance (`id`).

const std = @import("std");
const testing = std.testing;
const objc = @import("zobjc");
const raw = @import("raw");
const conversion = @import("conversion.zig");
const Class = @import("class.zig").Class;
const Selector = @import("selector.zig").Selector;
const sel_fn = @import("selector.zig").sel;
const Ivar = @import("ivar.zig").Ivar;
const memory = @import("memory");
const association = @import("association.zig");
const AssociationKey = association.AssociationKey;
const AssociationPolicy = association.AssociationPolicy;

/// A non-owning, non-null handle to an Objective-C object instance (`id`).
pub const Object = struct {
    ptr: *raw.objc_object,

    /// Dispatches an Objective-C message to this object.
    pub inline fn send(
        self: Object,
        comptime Return: type,
        selector: anytype,
        args: anytype,
    ) Return {
        const messaging = @import("messaging");
        return messaging.send(Return, self, selector, args);
    }

    /// Dispatches an Objective-C message to this object's superclass (Super2 semantics).
    pub inline fn sendSuper(
        self: Object,
        comptime Return: type,
        current_class: anytype,
        selector: anytype,
        args: anytype,
    ) Return {
        const messaging = @import("messaging");
        return messaging.sendSuper(Return, self, current_class, selector, args);
    }

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

    /// Sets the class of the object, returning the previous class.
    pub inline fn setClass(self: Object, new_class: Class) Class {
        const old_cls = raw.runtime.object_setClass(self.ptr, new_class.ptr) orelse unreachable;
        return Class.fromRawNonNull(old_cls);
    }

    /// Returns the class name of the object.
    pub inline fn className(self: Object) [:0]const u8 {
        return conversion.spanCString(raw.objc.object_getClassName(self.ptr));
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

    /// Set a property. This is a helper around `Class.property` and is
    /// strictly less performant than doing it manually.
    pub fn setProperty(self: Object, comptime n: [:0]const u8, v: anytype) void {
        const cls = self.class();
        const setter = setter: {
            if (cls.property(n)) |prop| {
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

        self.send(void, setter, .{v});
    }

    /// Get a property. This is a helper around `Class.property` and is
    /// strictly less performant than doing it manually.
    pub fn getProperty(self: Object, comptime T: type, comptime n: [:0]const u8) T {
        const cls = self.class();
        const getter = getter: {
            if (cls.property(n)) |prop| {
                if (prop.copyAttributeValue("G")) |val| {
                    var owned = val;
                    defer owned.deinit();
                    break :getter sel_fn(owned.slice());
                }
            }

            break :getter sel_fn(n);
        };

        return self.send(T, getter, .{});
    }

    /// Sets an associated value for this object using a given key and association policy.
    pub inline fn setAssociated(
        self: Object,
        key: *const AssociationKey,
        value: ?Object,
        policy: AssociationPolicy,
    ) void {
        association.setAssociated(self, key, value, policy);
    }

    /// Returns the value associated with this object for a given key as a non-owning handle.
    pub inline fn associated(
        self: Object,
        key: *const AssociationKey,
    ) ?Object {
        return association.associated(self, key);
    }

    /// Clears the associated value for this object and key.
    pub inline fn clearAssociated(
        self: Object,
        key: *const AssociationKey,
    ) void {
        association.clearAssociated(self, key);
    }

    /// Returns the value associated with this object for a given key, retained into an owning `Retained(Object)`.
    pub inline fn associatedRetained(
        self: Object,
        key: *const AssociationKey,
    ) ?memory.Retained(Object) {
        return association.associatedRetained(self, key);
    }

    /// Copies object memory with extra bytes.
    ///
    /// Prefer the owned high-level runtime APIs for object memory management.
    pub inline fn copyObjectMemory(self: Object, extra_bytes: usize) ?Object {
        return Object.fromRaw(raw.runtime.object_copy(self.ptr, extra_bytes));
    }

    /// Disposes object memory directly via runtime without dealloc message dispatch.
    ///
    /// Releases the runtime-owned object memory.
    pub inline fn disposeObjectMemory(self: Object) void {
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

    comptime {
        std.debug.assert(@sizeOf(@This()) == @sizeOf(raw.id));
        std.debug.assert(@alignOf(@This()) == @alignOf(raw.id));
    }
};

test "object: instance class and identity" {
    const cls = objc.requireClass("NSObject");
    const obj1 = cls.send(Object, "alloc", .{})
        .send(Object, "init", .{});
    defer obj1.send(void, "dealloc", .{});

    const obj2 = cls.send(Object, "alloc", .{})
        .send(Object, "init", .{});
    defer obj2.send(void, "dealloc", .{});

    try testing.expect(obj1.class().eql(cls));
    try testing.expectEqualStrings("NSObject", obj1.className());
    try testing.expect(!obj1.isClass());
    try testing.expect(obj1.eql(obj1));
    try testing.expect(!obj1.eql(obj2));
}

test "object: setClass dynamic isa swizzling" {
    const Base = objc.requireClass("NSObject");
    const Subclass = objc.allocateClassPair(Base, "ObjectSetClassSubclass").?;
    objc.registerClassPair(Subclass);
    defer objc.disposeClassPair(Subclass);

    const obj = Base.send(Object, "alloc", .{})
        .send(Object, "init", .{});
    defer obj.send(void, "dealloc", .{});

    try testing.expect(obj.class().eql(Base));
    const old_cls = obj.setClass(Subclass);
    try testing.expect(old_cls.eql(Base));
    try testing.expect(obj.class().eql(Subclass));
    _ = obj.setClass(Base);
}

test "object: getIvar and setIvar" {
    const Base = objc.requireClass("NSObject");
    const Subclass = objc.allocateClassPair(Base, "ObjectIvarTestClass").?;
    _ = Subclass.addIvar("_child", @sizeOf(raw.id), @truncate(std.math.log2(@alignOf(raw.id))), "@");
    objc.registerClassPair(Subclass);
    defer objc.disposeClassPair(Subclass);

    const ivar = Subclass.instanceIvar("_child").?;
    const parent = Subclass.send(Object, "alloc", .{})
        .send(Object, "init", .{});
    defer parent.send(void, "dealloc", .{});
    const child = Base.send(Object, "alloc", .{})
        .send(Object, "init", .{});
    defer child.send(void, "dealloc", .{});

    try testing.expectEqual(@as(?Object, null), parent.getIvar(ivar));
    parent.setIvar(ivar, child);
    try testing.expectEqual(child.ptr, parent.getIvar(ivar).?.ptr);
    parent.setIvar(ivar, null);
    try testing.expectEqual(@as(?Object, null), parent.getIvar(ivar));
}

test "conversion: Object fromRaw and toRaw roundtrip" {
    const cls = objc.requireClass("NSObject");
    const obj = cls.send(Object, "alloc", .{}).send(Object, "init", .{});
    defer obj.send(void, "dealloc", .{});

    const raw_id = obj.toRaw();
    try testing.expect(raw_id != null);
    try testing.expect(obj.eql(Object.fromRaw(raw_id).?));
    try testing.expect(obj.eql(Object.fromRawNonNull(raw_id.?)));
    try testing.expectEqual(@as(?Object, null), Object.fromRaw(null));
}

test "handle: Object is pointer-sized and pointer-aligned" {
    try testing.expectEqual(@sizeOf(usize), @sizeOf(Object));
    try testing.expectEqual(@alignOf(usize), @alignOf(Object));
}
