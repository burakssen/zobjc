//! Objective-C Class handle and class operations.

const std = @import("std");
const assert = std.debug.assert;
const raw = @import("../raw/root.zig");
const boolResult = raw.boolResult;
const selector_pkg = @import("selector.zig");
const Selector = selector_pkg.Selector;
const sel_fn = selector_pkg.sel;
const Property = @import("property.zig").Property;
const Protocol = @import("protocol.zig").Protocol;
const Object = @import("object.zig").Object;
const MsgSend = @import("../messaging/msg_send.zig").MsgSend;
const comptimeEncode = @import("../encoding/root.zig").comptimeEncode;

/// Class represents an Objective-C class handle (`Class`).
pub const Class = struct {
    value: raw.Class,

    // Implement msgSend and msgSendSuper
    const msg_send = MsgSend(Class, Object);
    pub const msgSend = msg_send.msgSend;
    pub const msgSendSuper = msg_send.msgSendSuper;

    /// Returns a property with a given name of a given class.
    pub fn getProperty(self: Class, name: [:0]const u8) ?Property {
        return Property{
            .value = raw.runtime.class_getProperty(self.value, name.ptr) orelse return null,
        };
    }

    /// Describes the properties declared by a class. This must be freed with objc.free.
    pub fn copyPropertyList(self: Class) []Property {
        var count: c_uint = undefined;
        const list = @as([*c]Property, @ptrCast(raw.runtime.class_copyPropertyList(self.value, &count)));
        if (count == 0) return list[0..0];
        return list[0..count];
    }

    /// Describes the protocols adopted by a class. This must be freed with objc.free.
    pub fn copyProtocolList(self: Class) []Protocol {
        var count: c_uint = undefined;
        const list = @as([*c]Protocol, @ptrCast(raw.runtime.class_copyProtocolList(self.value, &count)));
        if (count == 0) return list[0..0];
        return list[0..count];
    }

    pub fn isMetaClass(self: Class) bool {
        return boolResult(raw.runtime.class_isMetaClass(self.value));
    }

    pub fn getInstanceSize(self: Class) usize {
        return raw.runtime.class_getInstanceSize(self.value);
    }

    pub fn respondsToSelector(self: Class, sel_val: Selector) bool {
        return boolResult(raw.runtime.class_respondsToSelector(self.value, sel_val.value));
    }

    pub fn conformsToProtocol(self: Class, protocol: Protocol) bool {
        return boolResult(raw.runtime.class_conformsToProtocol(self.value, protocol.value));
    }

    /// Currently only allows for overriding methods previously defined, e.g. by a superclass.
    /// imp should be a function with C calling convention whose first two arguments are `raw.id` and `raw.SEL`.
    pub fn replaceMethod(self: Class, name: [:0]const u8, imp: anytype) void {
        const fn_info = @typeInfo(@TypeOf(imp)).@"fn";
        assert(std.meta.eql(fn_info.calling_convention, std.builtin.CallingConvention.c));
        assert(fn_info.is_var_args == false);
        assert(fn_info.params.len >= 2);
        assert(fn_info.params[0].type == raw.id);
        assert(fn_info.params[1].type == raw.SEL);
        _ = raw.runtime.class_replaceMethod(self.value, sel_fn(name).value, @ptrCast(&imp), null);
    }

    /// Allows adding new methods; returns true on success.
    /// imp should be a function with C calling convention whose first two arguments are `raw.id` and `raw.SEL`.
    pub fn addMethod(self: Class, name: [:0]const u8, imp: anytype) bool {
        const Fn = @TypeOf(imp);
        const fn_info = @typeInfo(Fn).@"fn";
        assert(std.meta.eql(fn_info.calling_convention, std.builtin.CallingConvention.c));
        assert(fn_info.is_var_args == false);
        assert(fn_info.params.len >= 2);
        assert(fn_info.params[0].type == raw.id);
        assert(fn_info.params[1].type == raw.SEL);
        const encoding = comptime comptimeEncode(Fn);
        return boolResult(raw.runtime.class_addMethod(
            self.value,
            sel_fn(name).value,
            @ptrCast(&imp),
            &encoding,
        ));
    }

    /// Only call this function between allocateClassPair and registerClassPair.
    /// This adds an Ivar of type `id`.
    pub fn addIvar(self: Class, name: [:0]const u8) bool {
        const result = raw.runtime.class_addIvar(self.value, name, @sizeOf(raw.id), @alignOf(raw.id), "@");
        return boolResult(result);
    }
};

/// Looks up a registered class by name. Returns null if not registered.
pub fn getClass(name: [:0]const u8) ?Class {
    return .{ .value = raw.runtime.objc_getClass(name.ptr) orelse return null };
}

/// Looks up the metaclass definition for a class by name.
pub fn getMetaClass(name: [:0]const u8) ?Class {
    return .{ .value = raw.runtime.objc_getMetaClass(name.ptr) orelse return null };
}

/// Allocates a new class pair (class and its metaclass).
/// Begin by calling this function, then call registerClassPair when configuration is complete.
pub fn allocateClassPair(superclass: ?Class, name: [:0]const u8) ?Class {
    return .{ .value = raw.runtime.objc_allocateClassPair(
        if (superclass) |cls| cls.value else null,
        name.ptr,
        0,
    ) orelse return null };
}

/// Registers a class that was allocated using allocateClassPair.
pub fn registerClassPair(class: Class) void {
    raw.runtime.objc_registerClassPair(class.value);
}

/// Destroys a class and its associated metaclass allocated using allocateClassPair.
pub fn disposeClassPair(class: Class) void {
    raw.runtime.objc_disposeClassPair(class.value);
}
