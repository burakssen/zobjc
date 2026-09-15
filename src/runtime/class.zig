//! Objective-C Class handle and class operations.
//!
//! A non-owning, non-null handle to an Objective-C class (`Class`).

const std = @import("std");
const raw = @import("../raw/root.zig");
const conversion = @import("conversion.zig");
const Selector = @import("selector.zig").Selector;
const sel_fn = @import("selector.zig").sel;
const Method = @import("method.zig").Method;
const Ivar = @import("ivar.zig").Ivar;
const Property = @import("property.zig").Property;
const PropertyAttribute = @import("property_attribute.zig").PropertyAttribute;
const Protocol = @import("protocol.zig").Protocol;
const Imp = @import("imp.zig").Imp;
const Object = @import("object.zig").Object;
const memory = @import("../memory/root.zig");

pub const Class = struct {
    ptr: *raw.objc_class,

    /// Dispatches an Objective-C class message to this class.
    pub inline fn send(
        self: Class,
        comptime Return: type,
        selector: anytype,
        args: anytype,
    ) Return {
        const messaging = @import("../messaging/root.zig");
        return messaging.send(Return, self, selector, args);
    }

    /// Dispatches an Objective-C class message to this class (backward compatibility alias).
    pub inline fn msgSend(
        self: Class,
        comptime Return: type,
        selector: anytype,
        args: anytype,
    ) Return {
        return self.send(Return, selector, args);
    }

    /// Converts a raw nullable `raw.Class` into an optional `Class`.
    pub inline fn fromRaw(val: raw.Class) ?Class {
        const p = val orelse return null;
        return .{ .ptr = p };
    }

    /// Converts this `Class` into its raw `raw.Class` pointer.
    pub inline fn toRaw(self: Class) raw.Class {
        return self.ptr;
    }

    /// Creates a `Class` from a known non-null raw class pointer.
    pub inline fn fromRawNonNull(p: *raw.objc_class) Class {
        return .{ .ptr = p };
    }

    /// Returns the name of the class.
    pub inline fn name(self: Class) [:0]const u8 {
        return conversion.spanCString(raw.runtime.class_getName(self.ptr));
    }

    /// Alias for name() to match Method, Ivar, Property, Protocol parity.
    pub inline fn getName(self: Class) [:0]const u8 {
        return self.name();
    }

    /// Returns whether this class is a metaclass.
    pub inline fn isMetaClass(self: Class) bool {
        return raw.boolResult(raw.runtime.class_isMetaClass(self.ptr));
    }

    /// Returns the metaclass corresponding to this class.
    pub inline fn metaClass(self: Class) Class {
        const raw_meta = raw.runtime.object_getClass(@ptrCast(self.ptr));
        return Class.fromRawNonNull(raw_meta.?);
    }

    /// Returns the superclass of this class, or null if root class (e.g. NSObject).
    pub inline fn superclass(self: Class) ?Class {
        return Class.fromRaw(raw.runtime.class_getSuperclass(self.ptr));
    }

    /// Returns true if this class equals target or is a subclass of target in the class hierarchy.
    ///
    /// Implemented via pure libobjc superclass traversal (zero Foundation messaging).
    pub fn isSubclassOf(self: Class, target: Class) bool {
        var current: ?Class = self;
        while (current) |cls| {
            if (cls.eql(target)) return true;
            current = cls.superclass();
        }
        return false;
    }

    /// Returns true if this class is a strict subclass of target (excludes self == target).
    pub inline fn isStrictSubclassOf(self: Class, target: Class) bool {
        return !self.eql(target) and self.isSubclassOf(target);
    }

    /// Returns the version number of this class definition.
    pub inline fn version(self: Class) i32 {
        return raw.runtime.class_getVersion(self.ptr);
    }

    /// Sets the version number of this class definition.
    pub inline fn setVersion(self: Class, ver: i32) void {
        raw.runtime.class_setVersion(self.ptr, ver);
    }

    /// Returns the size in bytes of instances of this class.
    pub inline fn instanceSize(self: Class) usize {
        return raw.runtime.class_getInstanceSize(self.ptr);
    }

    /// Returns a specified instance method for this class, or null if not found.
    pub inline fn instanceMethod(self: Class, sel_val: Selector) ?Method {
        return Method.fromRaw(raw.runtime.class_getInstanceMethod(self.ptr, sel_val.toRaw()));
    }

    /// Returns a specified class method for this class, or null if not found.
    pub inline fn classMethod(self: Class, sel_val: Selector) ?Method {
        return Method.fromRaw(raw.runtime.class_getClassMethod(self.ptr, sel_val.toRaw()));
    }

    /// Returns the function pointer that would be called if a message were sent to an instance.
    pub inline fn methodImplementation(self: Class, sel_val: Selector) ?Imp {
        return Imp.fromRaw(raw.runtime.class_getMethodImplementation(self.ptr, sel_val.toRaw()));
    }

    /// Returns whether instances of this class respond to a given selector.
    pub inline fn respondsTo(self: Class, sel_val: Selector) bool {
        return raw.boolResult(raw.runtime.class_respondsToSelector(self.ptr, sel_val.toRaw()));
    }

    /// Returns an instance variable of this class by name, or null if not found.
    pub inline fn instanceIvar(self: Class, ivar_name: [:0]const u8) ?Ivar {
        return Ivar.fromRaw(raw.runtime.class_getInstanceVariable(self.ptr, ivar_name.ptr));
    }

    /// Returns a class variable of this class by name, or null if not found.
    pub inline fn classIvar(self: Class, ivar_name: [:0]const u8) ?Ivar {
        return Ivar.fromRaw(raw.runtime.class_getClassVariable(self.ptr, ivar_name.ptr));
    }

    /// Returns a property of this class by name, or null if not found.
    pub inline fn property(self: Class, prop_name: [:0]const u8) ?Property {
        return Property.fromRaw(raw.runtime.class_getProperty(self.ptr, prop_name.ptr));
    }

    /// Returns whether this class conforms to the given protocol.
    pub inline fn conformsTo(self: Class, proto: Protocol) bool {
        return raw.boolResult(raw.runtime.class_conformsToProtocol(self.ptr, proto.toRaw()));
    }

    /// Returns the dynamic library name a class originated from, or null.
    pub inline fn imageName(self: Class) ?[:0]const u8 {
        return conversion.spanNullableCString(raw.runtime.class_getImageName(self.ptr));
    }

    /// Creates an uninitialized instance of this class with extra bytes allocated.
    ///
    /// Note: Follows libobjc ownership semantics (returns non-retained instance pointer).
    pub inline fn createInstance(self: Class, extra_bytes: usize) ?Object {
        return Object.fromRaw(raw.runtime.class_createInstance(self.ptr, extra_bytes));
    }

    /// Creates an uninitialized instance wrapped in strong ownership `Retained(Object)`.
    pub fn createInstanceRetained(self: Class, extra_bytes: usize) ?memory.Retained(Object) {
        const raw_obj = raw.runtime.class_createInstance(self.ptr, extra_bytes) orelse return null;
        return memory.Retained(Object).adopt(Object.fromRawNonNull(raw_obj));
    }

    /// Returns a caller-freed list of instance methods implemented by this class.
    pub fn methods(self: Class) memory.OwnedRuntimeList(Method) {
        var count_val: c_uint = 0;
        const list = raw.runtime.class_copyMethodList(self.ptr, &count_val);
        return memory.OwnedRuntimeList(Method).fromRaw(@ptrCast(list), count_val);
    }

    /// Returns a caller-freed list of class methods implemented by this class (from its metaclass).
    pub fn classMethods(self: Class) memory.OwnedRuntimeList(Method) {
        const meta = raw.runtime.object_getClass(@ptrCast(self.ptr)) orelse return memory.OwnedRuntimeList(Method).empty();
        var count_val: c_uint = 0;
        const list = raw.runtime.class_copyMethodList(meta, &count_val);
        return memory.OwnedRuntimeList(Method).fromRaw(@ptrCast(list), count_val);
    }

    /// Returns a caller-freed list of instance variables declared by this class.
    pub fn ivars(self: Class) memory.OwnedRuntimeList(Ivar) {
        var count_val: c_uint = 0;
        const list = raw.runtime.class_copyIvarList(self.ptr, &count_val);
        return memory.OwnedRuntimeList(Ivar).fromRaw(@ptrCast(list), count_val);
    }

    /// Returns a caller-freed list of properties declared by this class.
    pub fn properties(self: Class) memory.OwnedRuntimeList(Property) {
        var count_val: c_uint = 0;
        const list = raw.runtime.class_copyPropertyList(self.ptr, &count_val);
        return memory.OwnedRuntimeList(Property).fromRaw(@ptrCast(list), count_val);
    }

    /// Returns a caller-freed list of protocols adopted by this class.
    pub fn protocols(self: Class) memory.OwnedRuntimeList(Protocol) {
        var count_val: c_uint = 0;
        const list = raw.runtime.class_copyProtocolList(self.ptr, &count_val);
        return memory.OwnedRuntimeList(Protocol).fromRaw(@ptrCast(list), count_val);
    }

    /// Tests class equality by comparing pointer addresses.
    pub inline fn eql(self: Class, other: Class) bool {
        return self.ptr == other.ptr;
    }

    /// Returns a hash value for use in hash maps based on pointer address.
    pub inline fn hash(self: Class) usize {
        return @intFromPtr(self.ptr);
    }

    // --- Thin Mutation Methods ---

    /// Adds a new method to a class with a given selector, implementation, and type encoding.
    pub fn addMethod(self: Class, sel_val: Selector, implementation: Imp, types_sig: [:0]const u8) bool {
        return raw.boolResult(raw.runtime.class_addMethod(
            self.ptr,
            sel_val.toRaw(),
            implementation.toRaw(),
            types_sig.ptr,
        ));
    }

    /// Replaces the implementation of a method for a given class, returning the previous implementation.
    pub fn replaceMethod(self: Class, sel_val: Selector, implementation: Imp, types_sig: ?[:0]const u8) ?Imp {
        const types_ptr = if (types_sig) |t| t.ptr else null;
        const old = raw.runtime.class_replaceMethod(
            self.ptr,
            sel_val.toRaw(),
            implementation.toRaw(),
            types_ptr,
        );
        return Imp.fromRaw(old);
    }

    /// Adds an instance variable to a class being constructed (before registerClassPair).
    ///
    /// Note: alignment_log2 is the base-2 logarithm of alignment (e.g. 3 for 8-byte alignment).
    pub fn addIvar(
        self: Class,
        ivar_name: [:0]const u8,
        size: usize,
        alignment_log2: u8,
        encoding: [:0]const u8,
    ) bool {
        return raw.boolResult(raw.runtime.class_addIvar(
            self.ptr,
            ivar_name.ptr,
            size,
            alignment_log2,
            encoding.ptr,
        ));
    }

    /// Adds a protocol to this class.
    pub fn addProtocol(self: Class, proto: Protocol) bool {
        return raw.boolResult(raw.runtime.class_addProtocol(self.ptr, proto.toRaw()));
    }

    /// Adds a property to a class with the specified attributes.
    pub fn addProperty(self: Class, prop_name: [:0]const u8, attributes: []const PropertyAttribute) bool {
        return raw.boolResult(raw.runtime.class_addProperty(
            self.ptr,
            prop_name.ptr,
            @ptrCast(attributes.ptr),
            @intCast(attributes.len),
        ));
    }

    /// Replaces a property on a class with the specified attributes.
    pub fn replaceProperty(self: Class, prop_name: [:0]const u8, attributes: []const PropertyAttribute) void {
        raw.runtime.class_replaceProperty(
            self.ptr,
            prop_name.ptr,
            @ptrCast(attributes.ptr),
            @intCast(attributes.len),
        );
    }

    // --- Backward Compatibility Aliases ---

    /// Legacy alias for property.
    pub inline fn getProperty(self: Class, prop_name: [:0]const u8) ?Property {
        return self.property(prop_name);
    }

    /// Legacy alias for respondsTo.
    pub inline fn respondsToSelector(self: Class, sel_val: Selector) bool {
        return self.respondsTo(sel_val);
    }

    /// Legacy alias for conformsTo.
    pub inline fn conformsToProtocol(self: Class, proto: Protocol) bool {
        return self.conformsTo(proto);
    }

    /// Legacy property list copy (must be freed with objc.free).
    pub fn copyPropertyList(self: Class) []Property {
        var count: c_uint = undefined;
        const list = raw.runtime.class_copyPropertyList(self.ptr, &count) orelse return &.{};
        if (count == 0) return &.{};
        const typed_list: [*]Property = @ptrCast(list);
        return typed_list[0..count];
    }

    /// Legacy protocol list copy (must be freed with objc.free).
    pub fn copyProtocolList(self: Class) []Protocol {
        var count: c_uint = undefined;
        const list = raw.runtime.class_copyProtocolList(self.ptr, &count) orelse return &.{};
        if (count == 0) return &.{};
        const typed_list: [*]Protocol = @ptrCast(list);
        return typed_list[0..count];
    }

    comptime {
        std.debug.assert(@sizeOf(@This()) == @sizeOf(raw.Class));
        std.debug.assert(@alignOf(@This()) == @alignOf(raw.Class));
    }
};
