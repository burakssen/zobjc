//! Complete Objective-C runtime API declarations.
//!
//! Mirrors public declarations in <objc/runtime.h>.
//! All declarations follow Apple C names, integer widths, and pointer nullability directly.

const types = @import("types.zig");
const std = @import("std");
const testing = std.testing;
const raw = @import("zobjc").raw;
const id = types.id;
const Class = types.Class;
const SEL = types.SEL;
const IMP = types.IMP;
const Ivar = types.Ivar;
const Method = types.Method;
const objc_property_t = types.objc_property_t;
const Protocol = types.Protocol;
const BOOL = types.BOOL;
const objc_method_description = types.objc_method_description;
const objc_property_attribute_t = types.objc_property_attribute_t;
const availability = @import("availability.zig");

// ============================================================================
// 1. Instances
// ============================================================================

/// Creates an instance of a class, allocating memory for the class and its instance variables.
pub extern "c" fn class_createInstance(cls: Class, extraBytes: usize) id;

/// Creates a copy of an object.
pub extern "c" fn object_copy(obj: id, size: usize) id;

/// Frees the memory occupied by a given object.
pub extern "c" fn object_dispose(obj: id) id;

/// Returns the class of an object.
pub extern "c" fn object_getClass(obj: id) Class;

/// Sets the class of an object.
pub extern "c" fn object_setClass(obj: id, cls: Class) Class;

/// Returns a boolean value indicating whether an object is a class.
pub extern "c" fn object_isClass(obj: id) BOOL;

/// Reads the value of an instance variable in an object.
pub extern "c" fn object_getIvar(obj: id, ivar: Ivar) id;

/// Sets the value of an instance variable in an object.
pub extern "c" fn object_setIvar(obj: id, ivar: Ivar, value: id) void;

/// Sets the value of an instance variable with strong default memory management.
pub extern "c" fn object_setIvarWithStrongDefault(obj: id, ivar: Ivar, value: id) void;

/// Obtains the value of an instance variable of an object by name.
pub extern "c" fn object_getInstanceVariable(obj: id, name: [*:0]const u8, outValue: ?*?*anyopaque) Ivar;

/// Changes the value of an instance variable of a class instance by name.
pub extern "c" fn object_setInstanceVariable(obj: id, name: [*:0]const u8, value: ?*anyopaque) Ivar;

/// Changes the value of an instance variable with strong default memory management by name.
pub extern "c" fn object_setInstanceVariableWithStrongDefault(obj: id, name: [*:0]const u8, value: ?*anyopaque) Ivar;

/// Creates an instance of a class at the specified location.
pub extern "c" fn objc_constructInstance(cls: Class, bytes: ?*anyopaque) id;

/// Destroys an instance of a class without freeing its memory.
pub extern "c" fn objc_destructInstance(obj: id) ?*anyopaque;

// ============================================================================
// 2. Classes
// ============================================================================

/// Returns the name of a class.
pub extern "c" fn class_getName(cls: Class) [*:0]const u8;

/// Returns a boolean value indicating whether a class object is a metaclass.
pub extern "c" fn class_isMetaClass(cls: Class) BOOL;

/// Returns the superclass of a class.
pub extern "c" fn class_getSuperclass(cls: Class) Class;

/// Returns the version number of a class definition.
pub extern "c" fn class_getVersion(cls: Class) c_int;

/// Sets the version number of a class definition.
pub extern "c" fn class_setVersion(cls: Class, version: c_int) void;

/// Returns the size of instances of a class.
pub extern "c" fn class_getInstanceSize(cls: Class) usize;

// ============================================================================
// 3. Methods
// ============================================================================

/// Returns a specified instance method for a given class.
pub extern "c" fn class_getInstanceMethod(cls: Class, name: SEL) Method;

/// Returns a pointer to the data structure describing a given class method for a given class.
pub extern "c" fn class_getClassMethod(cls: Class, name: SEL) Method;

/// Returns the function pointer that would be called if a particular message were sent to an instance of a class.
pub extern "c" fn class_getMethodImplementation(cls: Class, name: SEL) IMP;

/// Architecture-guarded stret method implementation lookup.
/// Unavailable on ARM64. Mirrors `class_getMethodImplementation_stret` from <objc/runtime.h>.
pub const class_getMethodImplementation_stret = if (availability.has_msgSendStret)
    struct {
        pub extern "c" fn class_getMethodImplementation_stret(cls: Class, name: SEL) IMP;
    }.class_getMethodImplementation_stret
else
    @compileError("class_getMethodImplementation_stret is unavailable on this architecture (ARM64)");

/// Returns a boolean value indicating whether instances of a class respond to a particular selector.
pub extern "c" fn class_respondsToSelector(cls: Class, name: SEL) BOOL;

/// Returns a Boolean value that indicates whether two selectors are equal.
pub extern "c" fn sel_isEqual(lhs: SEL, rhs: SEL) BOOL;

/// Describes the instance methods implemented by a class. Must be freed with free().
pub extern "c" fn class_copyMethodList(cls: Class, outCount: ?*c_uint) ?[*]Method;

/// Adds a new method to a class with a given name and implementation.
pub extern "c" fn class_addMethod(cls: Class, name: SEL, imp: IMP, types_sig: ?[*:0]const u8) BOOL;

/// Replaces the implementation of a method for a given class.
pub extern "c" fn class_replaceMethod(cls: Class, name: SEL, imp: IMP, types_sig: ?[*:0]const u8) IMP;

/// Creates a pointer to a function that calls the specified block when the method is called.
pub extern "c" fn imp_implementationWithBlock(block: id) IMP;

/// Returns the block associated with an IMP created by imp_implementationWithBlock.
pub extern "c" fn imp_getBlock(anImp: IMP) id;

/// Disassociates a block from an IMP created by imp_implementationWithBlock.
pub extern "c" fn imp_removeBlock(anImp: IMP) BOOL;

// ============================================================================
// 4. Instance Variables (Ivars)
// ============================================================================

/// Returns the Ivar for a specified instance variable of a given class.
pub extern "c" fn class_getInstanceVariable(cls: Class, name: [*:0]const u8) Ivar;

/// Returns the Ivar for a specified class variable of a given class.
pub extern "c" fn class_getClassVariable(cls: Class, name: [*:0]const u8) Ivar;

/// Describes the instance variables declared by a class. Must be freed with free().
pub extern "c" fn class_copyIvarList(cls: Class, outCount: ?*c_uint) ?[*]Ivar;

/// Adds a new instance variable to a class. Must be called between allocateClassPair and registerClassPair.
/// Note: alignment is log2 of the required alignment (e.g. 3 for 8-byte pointer alignment).
pub extern "c" fn class_addIvar(cls: Class, name: [*:0]const u8, size: usize, alignment: u8, types_sig: ?[*:0]const u8) BOOL;

/// Returns a description of the layout of instance variables for a given class.
pub extern "c" fn class_getIvarLayout(cls: Class) ?[*:0]const u8;

/// Sets the layout for instance variables for a given class.
pub extern "c" fn class_setIvarLayout(cls: Class, layout: ?[*:0]const u8) void;

/// Returns a description of the layout of weak instance variables for a given class.
pub extern "c" fn class_getWeakIvarLayout(cls: Class) ?[*:0]const u8;

/// Sets the layout for weak instance variables for a given class.
pub extern "c" fn class_setWeakIvarLayout(cls: Class, layout: ?[*:0]const u8) void;

// ============================================================================
// 5. Protocols Adopted by Classes
// ============================================================================

/// Adds a protocol to a class.
pub extern "c" fn class_addProtocol(cls: Class, protocol: Protocol) BOOL;

/// Returns a boolean value indicating whether a class conforms to a given protocol.
pub extern "c" fn class_conformsToProtocol(cls: Class, protocol: Protocol) BOOL;

/// Describes the protocols adopted by a class. Must be freed with free().
pub extern "c" fn class_copyProtocolList(cls: Class, outCount: ?*c_uint) ?[*]Protocol;

// ============================================================================
// 6. Properties
// ============================================================================

/// Returns a property with a given name of a given class.
pub extern "c" fn class_getProperty(cls: Class, name: [*:0]const u8) objc_property_t;

/// Describes the properties declared by a class. Must be freed with free().
pub extern "c" fn class_copyPropertyList(cls: Class, outCount: ?*c_uint) ?[*]objc_property_t;

/// Adds a property to a class.
pub extern "c" fn class_addProperty(cls: Class, name: [*:0]const u8, attributes: ?[*]const objc_property_attribute_t, attributeCount: c_uint) BOOL;

/// Replaces a property of a class.
pub extern "c" fn class_replaceProperty(cls: Class, name: [*:0]const u8, attributes: ?[*]const objc_property_attribute_t, attributeCount: c_uint) void;

// ============================================================================
// 7. Dynamic Class Creation & Lookup
// ============================================================================

/// Creates a new class and metaclass pair.
pub extern "c" fn objc_allocateClassPair(superclass: Class, name: [*:0]const u8, extraBytes: usize) Class;

/// Registers a class that was allocated using objc_allocateClassPair.
pub extern "c" fn objc_registerClassPair(cls: Class) void;

/// Creates a duplicate of a class.
pub extern "c" fn objc_duplicateClass(original: Class, name: [*:0]const u8, extraBytes: usize) Class;

/// Destroys a class and its associated metaclass.
pub extern "c" fn objc_disposeClassPair(cls: Class) void;

/// Returns the class definition of a specified class, or null if not registered.
pub extern "c" fn objc_getClass(name: [*:0]const u8) Class;

/// Returns the metaclass definition of a specified class, or null if not registered.
pub extern "c" fn objc_getMetaClass(name: [*:0]const u8) Class;

/// Returns the class definition of a specified class, or null if not recognized.
pub extern "c" fn objc_lookUpClass(name: [*:0]const u8) Class;

/// Returns the class definition of a specified class, terminating process if not found.
pub extern "c" fn objc_getRequiredClass(name: [*:0]const u8) Class;

/// Obtains the list of registered class definitions.
pub extern "c" fn objc_getClassList(buffer: ?[*]Class, bufferCount: c_int) c_int;

/// Creates and returns a list of pointers to all registered class definitions. Must be freed with free().
pub extern "c" fn objc_copyClassList(outCount: ?*c_uint) ?[*]Class;

/// Used by Foundation's distributed objects.
pub extern "c" fn objc_getFutureClass(name: [*:0]const u8) Class;

/// Realizes a class from Swift metadata.
pub extern "c" fn _objc_realizeClassFromSwift(cls: Class, previously: ?*anyopaque) Class;

/// Sets the message forwarding handler function pointers.
pub extern "c" fn objc_setForwardHandler(fwd: ?*const anyopaque, fwd_stret: ?*const anyopaque) void;

// ============================================================================
// 8. Method Metadata
// ============================================================================

/// Returns the name of a method.
pub extern "c" fn method_getName(m: Method) SEL;

/// Returns the implementation of a method.
pub extern "c" fn method_getImplementation(m: Method) IMP;

/// Returns a string describing a method's parameter and return types.
pub extern "c" fn method_getTypeEncoding(m: Method) ?[*:0]const u8;

/// Returns the number of arguments accepted by a method.
pub extern "c" fn method_getNumberOfArguments(m: Method) c_uint;

/// Returns a string describing a method's return type. Must be freed with free().
pub extern "c" fn method_copyReturnType(m: Method) ?[*:0]u8;

/// Returns a string describing a single parameter type of a method. Must be freed with free().
pub extern "c" fn method_copyArgumentType(m: Method, index: c_uint) ?[*:0]u8;

/// Returns by reference a string describing a method's return type.
pub extern "c" fn method_getReturnType(m: Method, dst: [*]u8, dst_len: usize) void;

/// Returns by reference a string describing a single parameter type of a method.
pub extern "c" fn method_getArgumentType(m: Method, index: c_uint, dst: [*]u8, dst_len: usize) void;

/// Returns a pointer to a method description structure.
pub extern "c" fn method_getDescription(m: Method) ?*objc_method_description;

/// Sets the implementation of a method.
pub extern "c" fn method_setImplementation(m: Method, imp: IMP) IMP;

/// Exchanges the implementations of two methods.
pub extern "c" fn method_exchangeImplementations(m1: Method, m2: Method) void;

// ============================================================================
// 9. Ivar Metadata
// ============================================================================

/// Returns the name of an instance variable.
pub extern "c" fn ivar_getName(v: Ivar) ?[*:0]const u8;

/// Returns the type string of an instance variable.
pub extern "c" fn ivar_getTypeEncoding(v: Ivar) ?[*:0]const u8;

/// Returns the offset of an instance variable.
pub extern "c" fn ivar_getOffset(v: Ivar) isize;

// ============================================================================
// 10. Property Metadata
// ============================================================================

/// Returns the name of a property.
pub extern "c" fn property_getName(p: objc_property_t) [*:0]const u8;

/// Returns the attribute string of a property.
pub extern "c" fn property_getAttributes(p: objc_property_t) ?[*:0]const u8;

/// Returns an array of property attributes. Must be freed with free().
pub extern "c" fn property_copyAttributeList(p: objc_property_t, outCount: ?*c_uint) ?[*]objc_property_attribute_t;

/// Returns the value of a property attribute given the attribute name. Must be freed with free().
pub extern "c" fn property_copyAttributeValue(p: objc_property_t, attributeName: [*:0]const u8) ?[*:0]u8;

// ============================================================================
// 11. Protocol Metadata & Dynamic Protocol Construction
// ============================================================================

/// Returns a specified protocol.
pub extern "c" fn objc_getProtocol(name: [*:0]const u8) Protocol;

/// Returns an array of all the protocols known to the runtime. Must be freed with free().
pub extern "c" fn objc_copyProtocolList(outCount: ?*c_uint) ?[*]Protocol;

/// Returns a boolean value indicating whether one protocol conforms to another protocol.
pub extern "c" fn protocol_conformsToProtocol(p: Protocol, other: Protocol) BOOL;

/// Returns a boolean value indicating whether two protocols are equal.
pub extern "c" fn protocol_isEqual(p: Protocol, other: Protocol) BOOL;

/// Returns the name of a protocol.
pub extern "c" fn protocol_getName(p: Protocol) [*:0]const u8;

/// Returns a method description structure for a specified method of a given protocol.
pub extern "c" fn protocol_getMethodDescription(p: Protocol, aSel: SEL, isRequiredMethod: BOOL, isInstanceMethod: BOOL) objc_method_description;

/// Returns an array of method descriptions of methods meeting a given specification for a given protocol. Must be freed with free().
pub extern "c" fn protocol_copyMethodDescriptionList(p: Protocol, isRequiredMethod: BOOL, isInstanceMethod: BOOL, outCount: ?*c_uint) ?[*]objc_method_description;

/// Returns the specified property of a given protocol.
pub extern "c" fn protocol_getProperty(p: Protocol, name: [*:0]const u8, isRequiredProperty: BOOL, isInstanceProperty: BOOL) objc_property_t;

/// Returns an array of the required instance properties declared by a protocol. Must be freed with free().
pub extern "c" fn protocol_copyPropertyList(p: Protocol, outCount: ?*c_uint) ?[*]objc_property_t;

/// Returns an array of properties declared by a protocol. Must be freed with free().
pub extern "c" fn protocol_copyPropertyList2(p: Protocol, outCount: ?*c_uint, isRequiredProperty: BOOL, isInstanceProperty: BOOL) ?[*]objc_property_t;

/// Returns an array of the protocols adopted by an adopted protocol. Must be freed with free().
pub extern "c" fn protocol_copyProtocolList(p: Protocol, outCount: ?*c_uint) ?[*]Protocol;

/// Creates a new protocol instance.
pub extern "c" fn objc_allocateProtocol(name: [*:0]const u8) Protocol;

/// Registers a newly created protocol with the runtime system.
pub extern "c" fn objc_registerProtocol(proto: Protocol) void;

/// Adds a method description to a protocol being constructed.
pub extern "c" fn protocol_addMethodDescription(proto: Protocol, name: SEL, types_sig: ?[*:0]const u8, isRequiredMethod: BOOL, isInstanceMethod: BOOL) void;

/// Adds an adopted protocol to a protocol being constructed.
pub extern "c" fn protocol_addProtocol(proto: Protocol, addition: Protocol) void;

/// Adds a property to a protocol being constructed.
pub extern "c" fn protocol_addProperty(proto: Protocol, name: [*:0]const u8, attributes: ?[*]const objc_property_attribute_t, attributeCount: c_uint, isRequiredProperty: BOOL, isInstanceProperty: BOOL) void;

// ============================================================================
// 12. Image / Binary Introspection
// ============================================================================

/// Returns the names of all the loaded Objective-C frameworks and dynamic libraries. Must be freed with free().
pub extern "c" fn objc_copyImageNames(outCount: ?*c_uint) ?[*][*:0]const u8;

/// Returns the dynamic library name a class originated from.
pub extern "c" fn class_getImageName(cls: Class) ?[*:0]const u8;

/// Returns the names of all the classes within a specified library or framework. Must be freed with free().
pub extern "c" fn objc_copyClassNamesForImage(image: [*:0]const u8, outCount: ?*c_uint) ?[*][*:0]const u8;

/// Special constant passed to objc_enumerateClasses to enumerate dynamic classes.
pub const OBJC_DYNAMIC_CLASSES: ?*const anyopaque = @ptrFromInt(~@as(usize, 0));

/// Enumerates classes in a given image, prefix, conforming protocol, or superclass using a block.
pub extern "c" fn objc_enumerateClasses(
    image: ?*const anyopaque,
    namePrefix: ?[*:0]const u8,
    conformingTo: Protocol,
    subclassing: Class,
    block: id,
) void;

pub const objc_func_loadImage = ?*const fn (header: ?*const anyopaque) callconv(.c) void;
pub const objc_hook_getClass = ?*const fn (name: [*:0]const u8, outCls: ?*Class) callconv(.c) BOOL;
pub const objc_hook_getImageName = ?*const fn (cls: Class, outName: ?*?[*:0]const u8) callconv(.c) BOOL;
pub const objc_hook_lazyClassNamer = ?*const fn (cls: Class) callconv(.c) ?[*:0]const u8;

/// Adds a function to be called whenever an image containing Objective-C code is loaded.
pub extern "c" fn objc_addLoadImageFunc(func: objc_func_loadImage) void;

/// Sets a hook for class lookup.
pub extern "c" fn objc_setHook_getClass(newValue: objc_hook_getClass, outOldValue: ?*objc_hook_getClass) void;

/// Sets a hook for class image name determination.
pub extern "c" fn objc_setHook_getImageName(newValue: objc_hook_getImageName, outOldValue: ?*objc_hook_getImageName) void;

/// Sets a hook for lazy class naming.
pub extern "c" fn objc_setHook_lazyClassNamer(newValue: objc_hook_lazyClassNamer, oldOutValue: ?*objc_hook_lazyClassNamer) void;

// ============================================================================
// 13. Associated Objects
// ============================================================================

/// Policies for associated objects.
pub const OBJC_ASSOCIATION_ASSIGN: usize = 0;
pub const OBJC_ASSOCIATION_RETAIN_NONATOMIC: usize = 1;
pub const OBJC_ASSOCIATION_COPY_NONATOMIC: usize = 3;
pub const OBJC_ASSOCIATION_RETAIN: usize = 769; // 01401
pub const OBJC_ASSOCIATION_COPY: usize = 771; // 01403

/// Sets an associated value for a given object using a given key and association policy.
pub extern "c" fn objc_setAssociatedObject(object: id, key: ?*const anyopaque, value: id, policy: usize) void;

/// Returns the value associated with a given object for a given key.
pub extern "c" fn objc_getAssociatedObject(object: id, key: ?*const anyopaque) id;

/// Removes all associations for a given object.
pub extern "c" fn objc_removeAssociatedObjects(object: id) void;

// ============================================================================
// 14. Fast Enumeration Mutation
// ============================================================================

/// Called by the compiler when a mutation is detected during fast enumeration.
pub extern "c" fn objc_enumerationMutation(obj: id) void;

/// Sets the mutation handler for fast enumeration.
pub extern "c" fn objc_setEnumerationMutationHandler(handler: ?*const fn (id) callconv(.c) void) void;

// ============================================================================
// 15. Synchronization Primitives (<objc/objc-sync.h>)
// ============================================================================

pub const OBJC_SYNC_SUCCESS: c_int = 0;
pub const OBJC_SYNC_NOT_OWNING_THREAD_ERROR: c_int = -1;
pub const OBJC_SYNC_TIMED_OUT: c_int = -2;
pub const OBJC_SYNC_NOT_INITIALIZED: c_int = -3;

/// Begins synchronizing on an object (equivalent to @synchronized (obj)).
pub extern "c" fn objc_sync_enter(obj: id) c_int;

/// Ends synchronizing on an object.
pub extern "c" fn objc_sync_exit(obj: id) c_int;

test "raw.runtime: class lookup and inspection" {
    const cls = raw.runtime.objc_getClass("NSObject");
    try testing.expect(cls != null);

    const name = raw.runtime.class_getName(cls);
    try testing.expectEqualStrings("NSObject", std.mem.span(name));

    const super_cls = raw.runtime.class_getSuperclass(cls);
    try testing.expect(super_cls == null);

    try testing.expect(!raw.boolResult(raw.runtime.class_isMetaClass(cls)));

    const meta_cls = raw.runtime.objc_getMetaClass("NSObject");
    try testing.expect(meta_cls != null);
    try testing.expect(raw.boolResult(raw.runtime.class_isMetaClass(meta_cls)));

    const size = raw.runtime.class_getInstanceSize(cls);
    try testing.expect(size >= @sizeOf(usize));

    const sel_init = raw.objc.sel_registerName("init");
    try testing.expect(raw.boolResult(raw.runtime.class_respondsToSelector(cls, sel_init)));
}

test "raw.runtime: dynamic class creation, method/ivar addition, and disposal" {
    const super_cls = raw.runtime.objc_getClass("NSObject");
    try testing.expect(super_cls != null);

    const unique_name = "RawTestClass_DynamicPair";
    const new_cls = raw.runtime.objc_allocateClassPair(super_cls, unique_name, 0);
    try testing.expect(new_cls != null);

    const ivar_added = raw.runtime.class_addIvar(
        new_cls,
        "_testIvar",
        @sizeOf(usize),
        @alignOf(usize),
        "^v",
    );
    try testing.expect(raw.boolResult(ivar_added));

    const dummy_imp: raw.IMP = @ptrCast(&struct {
        fn dummy(self: raw.id, op: raw.SEL) callconv(.c) usize {
            _ = self;
            _ = op;
            return 42;
        }
    }.dummy);

    const sel_test = raw.objc.sel_registerName("rawTestMethod");
    const method_added = raw.runtime.class_addMethod(
        new_cls,
        sel_test,
        dummy_imp,
        "Q@:",
    );
    try testing.expect(raw.boolResult(method_added));

    raw.runtime.objc_registerClassPair(new_cls);

    const registered = raw.runtime.objc_getClass(unique_name);
    try testing.expectEqual(new_cls, registered);

    const ivar = raw.runtime.class_getInstanceVariable(new_cls, "_testIvar");
    try testing.expect(ivar != null);
    const ivar_name = raw.runtime.ivar_getName(ivar);
    try testing.expect(ivar_name != null);
    try testing.expectEqualStrings("_testIvar", std.mem.span(ivar_name.?));

    const method = raw.runtime.class_getInstanceMethod(new_cls, sel_test);
    try testing.expect(method != null);
    try testing.expectEqual(sel_test, raw.runtime.method_getName(method));

    raw.runtime.objc_disposeClassPair(new_cls);
}

test "raw.runtime: protocol inspection" {
    const proto = raw.runtime.objc_getProtocol("NSObject");
    try testing.expect(proto != null);

    const name = raw.runtime.protocol_getName(proto);
    try testing.expectEqualStrings("NSObject", std.mem.span(name));

    const cls = raw.runtime.objc_getClass("NSObject");
    try testing.expect(cls != null);
    try testing.expect(raw.boolResult(raw.runtime.class_conformsToProtocol(cls, proto)));
}

test "raw.runtime: associated objects" {
    const cls = raw.runtime.objc_getClass("NSObject");
    try testing.expect(cls != null);

    const sel_alloc = raw.objc.sel_registerName("alloc");
    const sel_init = raw.objc.sel_registerName("init");

    const AllocFn = *const fn (raw.Class, raw.SEL) callconv(.c) raw.id;
    const InitFn = *const fn (raw.id, raw.SEL) callconv(.c) raw.id;

    const alloc_fn: AllocFn = @ptrCast(&raw.message.objc_msgSend);
    const init_fn: InitFn = @ptrCast(&raw.message.objc_msgSend);

    const obj = init_fn(alloc_fn(cls, sel_alloc), sel_init);
    try testing.expect(obj != null);
    defer {
        const sel_release = raw.objc.sel_registerName("release");
        const ReleaseFn = *const fn (raw.id, raw.SEL) callconv(.c) void;
        const release_fn: ReleaseFn = @ptrCast(&raw.message.objc_msgSend);
        release_fn(obj, sel_release);
    }

    var assoc_key: u8 = 0;
    const assoc_val: usize = 0x12345678;

    raw.runtime.objc_setAssociatedObject(
        obj,
        &assoc_key,
        @ptrFromInt(assoc_val),
        raw.runtime.OBJC_ASSOCIATION_ASSIGN,
    );

    const retrieved = raw.runtime.objc_getAssociatedObject(obj, &assoc_key);
    try testing.expectEqual(assoc_val, @intFromPtr(retrieved));

    raw.runtime.objc_setAssociatedObject(obj, &assoc_key, null, raw.runtime.OBJC_ASSOCIATION_ASSIGN);
    try testing.expect(raw.runtime.objc_getAssociatedObject(obj, &assoc_key) == null);
}
