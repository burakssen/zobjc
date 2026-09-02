# Typed Objective-C Runtime Handle Layer

The `runtime/` subsystem establishes strongly typed, non-owning Zig representations of Objective-C runtime entities on top of the handwritten low-level C ABI (`src/raw/`).

---

## 1. Architectural Invariants

Every handle type in `runtime/` obeys four strict architectural rules:

1. **Non-Owning Handles**:
   Runtime handles represent runtime identity and metadata. They hold zero ownership policy, never automatically retain or release memory, and never free underlying runtime metadata. Safe ownership semantics (`Retained(T)`, `Weak(T)`, `OwnedSlice(T)`) are strictly isolated to `src/memory/` (Phase 3).
2. **Non-Null Invariant**:
   Underlying C pointers in `raw` may be nullable (`raw.id`, `raw.Class`, `raw.Method`). Typed handles in `runtime/` represent **valid, non-null entities only** (`ptr: *raw.objc_xxx`). Absent values, failed lookups, or nil references are represented using standard Zig optionals (`?Class`, `?Object`, `?Method`).
3. **Pointer-Sized Zero-Cost Invariant**:
   All 8 core wrapper types (`Object`, `Class`, `Selector`, `Method`, `Ivar`, `Property`, `Protocol`, `Imp`) are pointer-sized structs:
   ```zig
   @sizeOf(T) == @sizeOf(usize)
   @alignOf(T) == @alignOf(usize)
   ```
   They introduce zero memory overhead, zero virtual tables, and zero indirection compared to bare raw C pointers.
4. **Standard Conversion Vocabulary**:
   Every handle implements uniform bidirectional conversions:
   - `pub inline fn fromRaw(val: raw.T) ?T`: Safely unwraps a nullable raw C pointer into an optional handle.
   - `pub inline fn toRaw(self: T) raw.T`: Unwraps the typed handle into the underlying raw C pointer.
   - `pub inline fn fromRawNonNull(ptr: *raw.objc_xxx) T`: Creates a handle from a known non-null raw pointer without branch overhead.
5. **Zero Allocator Dependency**:
   No handle method accepts `std.mem.Allocator`. Buffer-based methods (`method.returnType`, `method.argumentType`) write directly into caller-provided slices. List APIs returning runtime-allocated arrays remain in `raw` until Phase 3's `OwnedSlice(T)`.

---

## 2. Core Handle Catalog

```text
src/runtime/
├── root.zig                   # Typed runtime facade re-exporting all handles and lookups
├── object.zig                 # Object handle (class, className, setClass, getIvar, setIvar, eql)
├── class.zig                  # Class handle (introspection + thin mutation)
├── selector.zig               # Selector handle, sel() shorthand, Sel alias
├── method.zig                 # Method handle (selector, implementation, argumentCount, types)
├── ivar.zig                   # Ivar handle (name, typeEncoding, offset)
├── property.zig               # Property handle (name, attributes, copyAttributeValue)
├── protocol.zig               # Protocol handle (name, eql, conformsTo, methodDescription)
├── imp.zig                    # Imp function pointer handle (.as(FnType) cast helper)
├── method_description.zig     # MethodDescription descriptor struct
├── property_attribute.zig     # PropertyAttribute descriptor struct (1:1 ABI layout)
├── conversion.zig             # Internal unwrapping and C-string span helpers
├── lookup.zig                 # Global lookup functions (getClass, requireClass, getProtocol)
└── iterator.zig               # Fast enumeration collection iterator
```

### 2.1 `objc.Object`
Represents an instance of an Objective-C class (`id`).
- `class(self) Class`: Returns the class of the object (`object_getClass`).
- `setClass(self, new_class) Class`: Changes the class of the object (dynamic isa-swizzling), returning the previous class.
- `className(self) [:0]const u8`: Returns the class name.
- `isClass(self) bool`: Returns whether this object is a Class object.
- `indexedIvars(self) ?*anyopaque`: Returns pointer to extra memory allocated with instance.
- `getIvar(self, ivar: Ivar) ?Object`: Reads an object instance variable.
- `setIvar(self, ivar: Ivar, val: ?Object) void`: Writes an object instance variable.
- `eql(self, other: Object) bool`: Pointer identity comparison.
- `msgSend(...)` / `msgSendSuper(...)`: Legacy message dispatch facades.

### 2.2 `objc.Class`
Represents an Objective-C class or metaclass (`Class`).
- **Introspection**:
  - `name(self) [:0]const u8`: Returns the class name.
  - `isMetaClass(self) bool`: Checks whether the class is a metaclass.
  - `superclass(self) ?Class`: Returns the superclass, or `null` for root classes.
  - `version(self) i32` / `setVersion(self, v: i32) void`: Inspects or mutates class version.
  - `instanceSize(self) usize`: Returns instance byte size.
  - `respondsTo(self, sel: Selector) bool`: Checks selector response.
  - `instanceMethod(self, sel: Selector) ?Method`: Looks up instance method.
  - `classMethod(self, sel: Selector) ?Method`: Looks up class method.
  - `methodImplementation(self, sel: Selector) ?Imp`: Looks up cached IMP.
  - `instanceIvar(self, name: [:0]const u8) ?Ivar`: Looks up instance variable.
  - `classIvar(self, name: [:0]const u8) ?Ivar`: Looks up class variable.
  - `property(self, name: [:0]const u8) ?Property`: Looks up declared property.
  - `conformsTo(self, proto: Protocol) bool`: Checks protocol adoption.
  - `imageName(self) ?[:0]const u8`: Returns dynamic library image name.
  - `createInstance(self, extra_bytes: usize) ?Object`: Instantiates without messaging.
  - `eql(self, other: Class) bool` / `hash(self) usize`: Identity and hash.
- **Thin Mutation**:
  - `addMethod(self, sel: Selector, imp: Imp, types: [:0]const u8) bool`
  - `replaceMethod(self, sel: Selector, imp: Imp, types: ?[:0]const u8) ?Imp`
  - `addIvar(self, name: [:0]const u8, size: usize, alignment_log2: u8, encoding: [:0]const u8) bool`
  - `addProtocol(self, proto: Protocol) bool`
  - `addProperty(self, name: [:0]const u8, attributes: []const PropertyAttribute) bool`
  - `replaceProperty(self, name: [:0]const u8, attributes: []const PropertyAttribute) void`

### 2.3 `objc.Selector`
Represents an Objective-C selector (`SEL`).
- `Selector.register(name: [:0]const u8) Selector`: Registers with the runtime.
- `Selector.getUid(name: [:0]const u8) Selector`: Looks up selector UID.
- `objc.sel(name: [:0]const u8) Selector`: Canonical shorthand.
- `name(self) [:0]const u8`: Returns selector C-string name.
- `isMapped(self) bool`: Verifies selector registration.
- `eql(self, other) bool`: Pointer equality.
- `hash(self) usize`: Identity hash value.

### 2.4 `objc.Method`
Represents a class or instance method definition (`Method`).
- `selector(self) Selector`: Returns method selector.
- `implementation(self) Imp`: Returns method implementation pointer.
- `typeEncoding(self) ?[:0]const u8`: Returns raw Objective-C type encoding string.
- `argumentCount(self) u32`: Returns number of arguments (including `self` and `_cmd`).
- `returnType(self, buffer: []u8) void`: Writes C-string return type into buffer.
- `argumentType(self, index: u32, buffer: []u8) void`: Writes C-string argument type.
- `description(self) ?MethodDescription`: Returns `MethodDescription` struct.
- `setImplementation(self, new_imp: Imp) Imp`: Mutates IMP, returning old IMP.
- `exchange(self, other: Method) void`: Atomically swizzles two method implementations.
- `eql(self, other: Method) bool`: Identity check.

### 2.5 `objc.Ivar`
Represents an instance variable definition (`Ivar`).
- `name(self) ?[:0]const u8`: Returns ivar identifier name.
- `typeEncoding(self) ?[:0]const u8`: Returns ivar type encoding.
- `offset(self) isize`: Returns byte offset within instance layout.
- `eql(self, other: Ivar) bool`: Identity check.

### 2.6 `objc.Property`
Represents a declared property (`objc_property_t`).
- `name(self) [:0]const u8`: Returns property name.
- `attributes(self) ?[:0]const u8`: Returns raw attribute string (e.g. `"T@\"NSString\",C,N,V_title"`).
- `copyAttributeValue(self, attr_name: [:0]const u8) ?[:0]u8`: Copies attribute value (caller frees with `std.heap.c_allocator`).
- `eql(self, other: Property) bool`: Identity check.

### 2.7 `objc.Protocol`
Represents an Objective-C protocol (`Protocol`).
- `name(self) [:0]const u8`: Returns protocol name.
- `eql(self, other: Protocol) bool`: Runtime equality check via `protocol_isEqual`.
- `conformsTo(self, other: Protocol) bool`: Verifies protocol adoption.
- `methodDescription(self, sel: Selector, options: ProtocolMethodOptions) ?MethodDescription`: Looks up method requirement.
- `property(self, name: [:0]const u8, options: ProtocolPropertyOptions) ?Property`: Looks up declared property.

### 2.8 `objc.Imp`
Represents an untyped implementation function pointer (`IMP`).
- `as(self, comptime FnType: type) FnType`: Compile-time validated cast to a C-calling-convention function pointer.
- `eql(self, other: Imp) bool`: Function pointer equality.

---

## 3. Global Runtime Lookups

Exported directly at `objc.*`:

| Function | Signature | Description |
| :--- | :--- | :--- |
| `objc.getClass` | `fn([:0]const u8) ?Class` | Looks up class by name, returning `null` if unregistered |
| `objc.lookupClass` | `fn([:0]const u8) ?Class` | Runtime lookup variant |
| `objc.requireClass` | `fn([:0]const u8) Class` | Looks up class by name, aborting if not found (`objc_getRequiredClass`) |
| `objc.getMetaClass` | `fn([:0]const u8) ?Class` | Looks up metaclass by name |
| `objc.getProtocol` | `fn([:0]const u8) ?Protocol` | Looks up protocol by name |
| `objc.allocateClassPair` | `fn(?Class, [:0]const u8) ?Class` | Allocates dynamic class pair |
| `objc.registerClassPair` | `fn(Class) void` | Registers dynamic class pair |
| `objc.disposeClassPair` | `fn(Class) void` | Destroys registered dynamic class pair |
