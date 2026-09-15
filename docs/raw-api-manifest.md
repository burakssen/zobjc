# Objective-C Runtime ABI Declaration Manifest

This document records every declaration in `src/raw/`, mapped to its Apple SDK C header, declaration module, and platform availability status.

Audit Status: **146 / 146 SDK declarations covered (100.0%)**.

---

## 1. Fundamental Types & ABI Structures (`src/raw/types.zig`)

| Type Name | Source Header | Category | Description |
| :--- | :--- | :--- | :--- |
| `objc_object` | `<objc/objc.h>` | Opaque Handle | Underlying structure for Objective-C objects |
| `objc_class` | `<objc/runtime.h>` | Opaque Handle | Underlying structure for Objective-C classes |
| `objc_selector` | `<objc/objc.h>` | Opaque Handle | Underlying structure for method selectors |
| `objc_method` | `<objc/runtime.h>` | Opaque Handle | Method metadata handle |
| `objc_ivar` | `<objc/runtime.h>` | Opaque Handle | Instance variable metadata handle |
| `objc_property` | `<objc/runtime.h>` | Opaque Handle | Declared property handle |
| `objc_category` | `<objc/runtime.h>` | Opaque Handle | Category metadata handle |
| `id` | `<objc/objc.h>` | Pointer Alias | Pointer to `objc_object` |
| `Class` | `<objc/objc.h>` | Pointer Alias | Pointer to `objc_class` |
| `SEL` | `<objc/objc.h>` | Pointer Alias | Pointer to `objc_selector` |
| `IMP` | `<objc/objc.h>` | Function Pointer | Untyped implementation pointer (`?*const fn () callconv(.c) void`) |
| `Method` | `<objc/runtime.h>` | Pointer Alias | Pointer to `objc_method` |
| `Ivar` | `<objc/runtime.h>` | Pointer Alias | Pointer to `objc_ivar` |
| `objc_property_t` | `<objc/runtime.h>` | Pointer Alias | Pointer to `objc_property` |
| `Protocol` | `<objc/runtime.h>` | Pointer Alias | Pointer to protocol (`?*objc_object`) |
| `Category` | `<objc/runtime.h>` | Pointer Alias | Pointer to `objc_category` |
| `BOOL` | `<objc/objc.h>` | Scalar | Target-aware boolean (`i8` on macOS, `bool` on iOS64) |
| `YES` / `NO` | `<objc/objc.h>` | Constants | Boolean literal values |
| `objc_super` | `<objc/message.h>` | ABI Struct | Superclass dispatch context (`receiver`, `super_class`) |
| `objc_method_description` | `<objc/runtime.h>` | ABI Struct | Protocol method description (`name`, `types`) |
| `objc_property_attribute_t` | `<objc/runtime.h>` | ABI Struct | Property attribute name/value pair (`name`, `value`) |

---

## 2. Public Functions: `<objc/objc.h>` (`src/raw/objc.zig` & `src/raw/deprecated.zig`)

| Function Name | Module | Status | Description |
| :--- | :--- | :--- | :--- |
| `sel_getName` | `src/raw/objc.zig` | Active | Returns selector name string |
| `sel_registerName` | `src/raw/objc.zig` | Active | Registers a method name and returns a selector |
| `sel_getUid` | `src/raw/objc.zig` | Active | Alias for `sel_registerName` |
| `sel_isMapped` | `src/raw/objc.zig` | Active | Checks if a selector is registered |
| `object_getClassName` | `src/raw/objc.zig` | Active | Returns the class name of an object instance |
| `object_getIndexedIvars` | `src/raw/objc.zig` | Active | Returns pointer to indexed instance variables |
| `objc_retainedObject` | `src/raw/deprecated.zig` | Deprecated | Obsolete ARC object retain conversion |
| `objc_unretainedObject` | `src/raw/deprecated.zig` | Deprecated | Obsolete ARC unretained object conversion |
| `objc_unretainedPointer` | `src/raw/deprecated.zig` | Deprecated | Obsolete ARC pointer conversion |

---

## 3. Public Functions: `<objc/runtime.h>` (`src/raw/runtime.zig` & `src/raw/deprecated.zig`)

### 3.1 Instances
- `class_createInstance`: Creates an instance of a class.
- `object_copy`: Creates a copy of an object.
- `object_dispose`: Destroys an instance of a class.
- `object_getClass`: Returns the class of an object.
- `object_setClass`: Sets the class of an object.
- `object_isClass`: Returns whether an object is a class or metaclass.
- `object_getIvar`: Reads the value of an instance variable.
- `object_setIvar`: Sets the value of an instance variable.
- `object_setIvarWithStrongDefault`: Sets ivar with strong ARC default.
- `object_getInstanceVariable`: Obtains an instance variable by name.
- `object_setInstanceVariable`: Sets an instance variable by name.
- `object_setInstanceVariableWithStrongDefault`: Sets ivar by name with strong ARC default.

### 3.2 Classes
- `class_getName`: Returns class name.
- `class_isMetaClass`: Returns whether class is a metaclass.
- `class_getSuperclass`: Returns superclass.
- `class_setSuperclass` *(deprecated)*: Sets superclass.
- `class_getVersion`: Returns class version.
- `class_setVersion`: Sets class version.
- `class_getInstanceSize`: Returns instance size in bytes.

### 3.3 Methods & Selectors
- `class_getInstanceMethod`: Returns instance method.
- `class_getClassMethod`: Returns class method.
- `class_getMethodImplementation`: Returns method implementation pointer.
- `class_getMethodImplementation_stret` *(target-guarded, x86_64)*: Returns stret IMP.
- `class_respondsToSelector`: Checks selector responsiveness.
- `sel_isEqual`: Checks selector equality.
- `class_copyMethodList`: Copies method array.
- `class_addMethod`: Adds a method to a class.
- `class_replaceMethod`: Overrides or adds a method.
- `imp_implementationWithBlock`: Creates an IMP backed by a Block.
- `imp_getBlock`: Retrieves Block from an IMP.
- `imp_removeBlock`: Disassociates Block from an IMP.

### 3.4 Instance Variables (Ivars)
- `class_getInstanceVariable`: Obtains ivar by name.
- `class_getClassVariable`: Obtains class ivar by name.
- `class_copyIvarList`: Copies ivar array.
- `class_addIvar`: Adds an ivar during class construction.
- `class_getIvarLayout`: Returns strong ivar layout encoding.
- `class_setIvarLayout`: Sets strong ivar layout encoding.
- `class_getWeakIvarLayout`: Returns weak ivar layout encoding.
- `class_setWeakIvarLayout`: Sets weak ivar layout encoding.
- `ivar_getName`: Returns ivar name.
- `ivar_getTypeEncoding`: Returns ivar type encoding.
- `ivar_getOffset`: Returns ivar byte offset.

### 3.5 Protocols Adopted by Classes
- `class_addProtocol`: Adopts a protocol.
- `class_conformsToProtocol`: Checks protocol conformance.
- `class_copyProtocolList`: Copies adopted protocols list.

### 3.6 Properties Declared by Classes
- `class_getProperty`: Returns property by name.
- `class_copyPropertyList`: Copies declared property list.
- `class_addProperty`: Adds property to a class.
- `class_replaceProperty`: Replaces property on a class.

### 3.7 Dynamic Class Creation & Lookup
- `objc_allocateClassPair`: Allocates class/metaclass pair.
- `objc_registerClassPair`: Registers class pair.
- `objc_duplicateClass`: Duplicates a class definition.
- `objc_disposeClassPair`: Disposes class pair.
- `objc_getClass`: Looks up registered class.
- `objc_getMetaClass`: Looks up metaclass.
- `objc_lookUpClass`: Non-asserting class lookup.
- `objc_getRequiredClass`: Fatal class lookup.
- `objc_getClassList`: Gets registered classes list.
- `objc_copyClassList`: Copies registered classes list.
- `objc_getFutureClass`: Distributed objects future class.
- `_objc_realizeClassFromSwift`: Realizes class from Swift metadata.
- `objc_setForwardHandler`: Sets forward handler function pointers.
- `_objc_flush_caches` *(deprecated)*: Flushes class method cache.

### 3.8 Method Metadata
- `method_getName`: Returns method selector.
- `method_getImplementation`: Returns method IMP.
- `method_getTypeEncoding`: Returns method type encoding string.
- `method_getNumberOfArguments`: Returns argument count.
- `method_copyReturnType`: Copies return type string.
- `method_copyArgumentType`: Copies argument type string.
- `method_getReturnType`: Fills return type buffer.
- `method_getArgumentType`: Fills argument type buffer.
- `method_getDescription`: Returns `objc_method_description`.
- `method_setImplementation`: Sets method IMP.
- `method_exchangeImplementations`: Swizzles two method implementations.

### 3.9 Property Metadata
- `property_getName`: Returns property name.
- `property_getAttributes`: Returns attribute string.
- `property_copyAttributeValue`: Copies attribute value by name.
- `property_copyAttributeList`: Copies attribute struct array.

### 3.10 Protocol Metadata & Construction
- `objc_getProtocol`: Looks up protocol by name.
- `objc_copyProtocolList`: Copies protocol list.
- `protocol_conformsToProtocol`: Checks protocol-to-protocol conformance.
- `protocol_isEqual`: Compares protocols.
- `protocol_getName`: Returns protocol name.
- `protocol_getMethodDescription`: Gets method description.
- `protocol_copyMethodDescriptionList`: Copies method description list.
- `protocol_getProperty`: Returns protocol property.
- `protocol_copyPropertyList`: Copies protocol properties.
- `protocol_copyPropertyList2`: Copies protocol properties with filters.
- `protocol_copyProtocolList`: Copies adopted protocols.
- `objc_allocateProtocol`: Allocates dynamic protocol.
- `objc_registerProtocol`: Registers dynamic protocol.
- `protocol_addMethodDescription`: Adds method to protocol.
- `protocol_addProtocol`: Adopts protocol into protocol.
- `protocol_addProperty`: Adds property to protocol.

### 3.11 Image / Binary Introspection & Hooks
- `objc_copyImageNames`: Lists loaded framework/dylib names.
- `class_getImageName`: Returns originating library name for a class.
- `objc_copyClassNamesForImage`: Lists class names in an image.
- `objc_enumerateClasses`: Enumerates classes matching criteria using a Block.
- `objc_addLoadImageFunc`: Registers image load callback.
- `objc_setHook_getClass`: Sets class lookup hook.
- `objc_setHook_getImageName`: Sets image name hook.
- `objc_setHook_lazyClassNamer`: Sets lazy class naming hook.

### 3.12 Associated Objects
- `objc_setAssociatedObject`: Associates value with object.
- `objc_getAssociatedObject`: Retrieves associated value.
- `objc_removeAssociatedObjects`: Clears all associations.

### 3.13 Fast Enumeration
- `objc_enumerationMutation`: Mutation notification.
- `objc_setEnumerationMutationHandler`: Mutation handler configuration.

---

## 4. Public Functions: `<objc/objc-sync.h>` (`src/raw/runtime.zig`)

| Function Name | Status | Description |
| :--- | :--- | :--- |
| `objc_sync_enter` | Active | Acquires recursive mutex for `@synchronized` |
| `objc_sync_exit` | Active | Releases recursive mutex for `@synchronized` |

---

## 5. Public Functions: `<objc/message.h>` (`src/raw/message.zig`)

| Function Name | Availability | Description |
| :--- | :--- | :--- |
| `objc_msgSend` | All | Universal instance message send |
| `objc_msgSendSuper` | All | Universal superclass message send |
| `method_invoke` | All | Direct method invocation |
| `_objc_msgForward` | All | Message forwarding entry point |
| `objc_msgSend_stret` | x86_64 only | Structure-return instance dispatch |
| `objc_msgSendSuper_stret` | x86_64 only | Structure-return superclass dispatch |
| `objc_msgSend_fpret` | x86_64 only | Floating-point return dispatch |
| `objc_msgSend_fp2ret` | x86_64 only | Complex floating-point return dispatch |
| `method_invoke_stret` | x86_64 only | Structure-return direct method invocation |
| `_objc_msgForward_stret` | x86_64 only | Structure-return message forwarding |

---

## 6. Public Functions: `<objc/objc-exception.h>` & ARC (`src/raw/compiler_runtime.zig`)

### 6.1 ARC Primitives
- `objc_retain`: Increments retain count.
- `objc_release`: Decrements retain count.
- `objc_autorelease`: Adds object to autorelease pool.
- `objc_retainAutorelease`: Retains and autoreleases object.
- `objc_storeStrong`: Strong pointer assignment.
- `objc_autoreleasePoolPush`: Pushes autorelease pool context.
- `objc_autoreleasePoolPop`: Pops and drains autorelease pool.
- `objc_initWeak`: Initializes weak pointer.
- `objc_destroyWeak`: Destroys weak pointer.
- `objc_loadWeak`: Loads weak pointer.
- `objc_loadWeakRetained`: Loads and retains weak pointer.
- `objc_storeWeak`: Stores value to weak pointer.
- `objc_copyWeak`: Copies weak pointer.
- `objc_moveWeak`: Moves weak pointer.

### 6.2 Exception Handling
- `objc_exception_throw`: Throws Objective-C exception (`noreturn`).
- `objc_exception_rethrow`: Rethrows caught exception (`noreturn`).
- `objc_begin_catch`: Enters catch block.
- `objc_end_catch`: Exits catch block.
- `objc_terminate`: Terminates process on uncaught exception (`noreturn`).
- `objc_setUncaughtExceptionHandler`: Sets uncaught exception callback.
- `objc_setExceptionPreprocessor`: Sets exception preprocessing hook.
- `objc_setExceptionMatcher`: Sets custom exception matching hook.
- `objc_addExceptionHandler` *(macOS)*: Registers thread exception handler.
- `objc_removeExceptionHandler` *(macOS)*: Unregisters thread exception handler.

---

## 7. Blocks Runtime (`src/raw/blocks.zig`)

| Symbol | Category | Description |
| :--- | :--- | :--- |
| `_NSConcreteStackBlock` | Class Pointer | Stack block class handle |
| `_NSConcreteMallocBlock` | Class Pointer | Heap block class handle |
| `_Block_copy` | Entry Point | Copies block to heap or increments refcount |
| `_Block_release` | Entry Point | Releases block, deallocating at zero refcount |
| `_Block_object_assign` | Entry Point | Captures object/byref variable |
| `_Block_object_dispose` | Entry Point | Releases captured object/byref variable |
| `BlockLiteral` | ABI Layout | Block runtime memory layout |
| `BlockDescriptor` | ABI Layout | Block descriptor layout (size, helpers, signature) |
| `BlockFlags` | Bitfield | Block bitfield flags |
| `BlockFieldFlags` | Enum | Capture flags (`object`, `block`, `byref`, `weak`, `byref_caller`) |

---

## 8. High-Level Classification & Safety Tiering

Every raw symbol belongs to one of four clearly separated tiers:

| Raw Symbol | Exposure Tier | Canonical High-Level Path | Rationale / Safety Model |
| :--- | :--- | :--- | :--- |
| `objc_setAssociatedObject` | Safe Runtime | `objc.Object.setAssociated` / `objc.runtime.setAssociated` | Type-safe `AssociationPolicy` and `AssociationKey` |
| `objc_getAssociatedObject` | Safe Runtime | `objc.Object.associated` / `associatedRetained` | Returns `?Object` or `?Retained(Object)` |
| `objc_removeAssociatedObjects` | Advanced Memory | `objc.advanced.removeAllAssociatedObjects` | Bulk removal across all keys; discourages routine use |
| `objc_copyImageNames` | Safe Runtime | `objc.runtime.images` | Returns memory-managed `OwnedCStringList` |
| `objc_copyClassNamesForImage` | Safe Runtime | `objc.runtime.classNamesForImage` | Returns `OwnedCStringList` (empty on unknown image) |
| `class_getImageName` | Safe Runtime | `objc.Class.imageName` | Returns `?[:0]const u8` |
| `objc_enumerateClasses` | Safe Runtime | `objc.runtime.enumerateClasses` | Modern filtered class iterator with early stop |
| `method_exchangeImplementations` | Safe Runtime | `objc.Swizzle` / `objc.ScopedSwizzle` | Reversible method swapping with optional signature check |
| `class_replaceMethod` | Safe Runtime | `objc.MethodReplacement` / `BlockMethodReplacement` | Tracks state, prevents blind overwrite on conflict |
| `objc_constructInstance` | Advanced Memory | `objc.advanced.constructInstance` / `ConstructedInstance` | Requires zero-filled, aligned manual storage |
| `objc_destructInstance` | Advanced Memory | `objc.advanced.destructInstance` / `ConstructedInstance.destruct` | Destructs instance without freeing backing storage |
| `object_copy` | Advanced Memory | `objc.advanced.copyObjectMemory` | Raw bitwise copy with extra bytes; bypasses `-copy` |
| `object_dispose` | Advanced Memory | `objc.advanced.disposeObjectMemory` | Directly frees runtime memory; bypasses `-dealloc` |
| `objc_duplicateClass` | Raw-Only | `objc.raw.runtime.objc_duplicateClass` | Documented Apple bugs; prefer `ClassBuilder` |
| `objc_setForwardHandler` | Quarantined SPI | `objc.raw.internal.getSetForwardHandler` | Unstable private SPI; resolved dynamically via `dlsym` |

