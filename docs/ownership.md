# Ownership, Lifetime, and Memory Management

This document defines the ownership model, lifetime guarantees, and memory management abstractions in `zobjc`.

---

## 1. The Core Architectural Invariant

The fundamental principle of `zobjc` is that **runtime handles are strictly non-owning**:

```text
Object, Class, Method, Ivar, Property, Protocol, Imp
                         =
         non-owning, non-null runtime handles
            (@sizeOf(T) == @sizeOf(usize))
```

A handle never implicitly retains on copy, never implicitly releases on scope exit, and never performs hidden allocations. Lifetime management is explicit, composable, and divided into **four separate domains**.

---

## 2. The Four Lifetime Domains

```text
┌─────────────────────────────────────────────────────────────────────────┐
│ 1. Strong Objective-C Reference: Retained(T)                            │
│    - Owns one +1 reference count on an Objective-C object               │
│    - Cleans up with raw.compiler_runtime.objc_release on deinit()       │
├─────────────────────────────────────────────────────────────────────────┤
│ 2. Weak Objective-C Slot: Weak(T)                                       │
│    - Registers a zeroing weak reference in Apple's runtime table        │
│    - Must be initialized in-place at a stable memory address            │
│    - Cleans up with raw.compiler_runtime.objc_destroyWeak on deinit()    │
├─────────────────────────────────────────────────────────────────────────┤
│ 3. C Runtime Allocations: OwnedRuntimeList(T), OwnedCString, ...         │
│    - Buffers returned by class_copyMethodList, method_copyReturnType    │
│    - Allocated by libobjc via malloc, freed via std.c.free on deinit()  │
├─────────────────────────────────────────────────────────────────────────┤
│ 4. Scoped Autorelease Token: AutoreleasePool                            │
│    - Token returned by objc_autoreleasePoolPush                         │
│    - Drains autoreleased objects via objc_autoreleasePoolPop            │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Domain 1: Strong Ownership with `Retained(T)`

`Retained(T)` is a move-only smart pointer that holds exactly one reference count (+1) on an Objective-C object.

### Compile-Time Trait Verification
Only types meeting `memory.traits.isRetainable(T)` can be wrapped in `Retained(T)`.
- `Object` is retainable.
- Custom structs implementing `.asObject() Object` and `.fromObject(Object) Self` are retainable.
- `Class`, `Method`, `Ivar`, `Property`, `Protocol`, `Selector`, and primitive types are **rejected at compile-time**.

### Construction Semantics
- **`adopt(obj: T) Retained(T)`**:
  Takes ownership of an object that *already has* a +1 reference count (e.g., returned by `alloc`, `new`, `copy`, `mutableCopy`, or `createInstanceRetained`). Does **not** increment the reference count.
- **`retain(obj: T) Retained(T)`**:
  Takes a borrowed object, increments its reference count (+1) via `objc_retain`, and wraps it.
- **`retainOptional(?T)` / `adoptOptional(?T)`**:
  Convenience helpers returning `?Retained(T)`.

### Lifecycle Operations
- **`borrow(self: *const Retained(T)) T`**:
  Returns the underlying non-owning handle `T`.
- **`clone(self: *const Retained(T)) Retained(T)`**:
  Increments reference count and returns a second strong owner.
- **`intoUnmanaged(self: *Retained(T)) T`**:
  Relinquishes ownership without calling `objc_release`. The caller assumes manual release responsibility.
- **`deinit(self: *Retained(T)) void`**:
  Calls `objc_release` on the underlying pointer and zeroes the inner handle. Safe to call multiple times (idempotent).

```zig
const cls = objc.requireClass("NSObject");

// Adopting a newly allocated instance (+1 from alloc):
const raw = cls.msgSend(objc.Object, "alloc", .{}).msgSend(objc.Object, "init", .{});
var strong = objc.Retained(objc.Object).adopt(raw);
defer strong.deinit();

// Cloning increments reference count:
var second_owner = strong.clone();
defer second_owner.deinit();
```

---

## 4. Domain 2: Weak Storage with `Weak(T)`

`Weak(T)` manages a zeroing weak reference slot. When all strong owners of an object are destroyed, the Objective-C runtime automatically zeroes the slot.

### Address-Stability Invariant
Apple's weak reference table registers the **exact memory address of the storage slot** (`&self.slot`). Therefore:
- `Weak(T)` **must be initialized in-place** on the stack or inside a stable heap allocation.
- `Weak(T)` **must never be returned by value** from a constructor function.
- Initialization pattern:
  ```zig
  var weak: objc.Weak(objc.Object) = .{};
  weak.init(strong.borrow());
  defer weak.deinit();
  ```

### Reading Weak References
Weak references can be deallocated asynchronously by other threads. To prevent use-after-free, reading should load a temporary strong reference:
- **`loadRetained(self: *Weak(T)) ?Retained(T)`**:
  Calls `objc_loadWeakRetained`. Returns a strong `Retained(T)` if the target is alive, or `null` if deallocated.
- **`loadBorrowed(self: *Weak(T)) ?T`**:
  Calls `objc_loadWeak`. Returns an autoreleased borrowed handle.

### Manipulation
- **`store(self: *Weak(T), value: ?T) void`**: Updates the slot to refer to a different object (or clears it if `null`).
- **`clear(self: *Weak(T)) void`**: Explicitly zeroes the weak slot.
- **`copyFrom(destination: *Weak(T), source: *const Weak(T)) void`**: Copies a weak registration via `objc_copyWeak`.
- **`moveFrom(destination: *Weak(T), source: *Weak(T)) void`**: Moves weak registration via `objc_moveWeak` and unregisters the source.
- **`deinit(self: *Weak(T)) void`**: Calls `objc_destroyWeak` to unregister the slot from the runtime table.

---

## 5. Domain 3: C Runtime Allocations

Many runtime introspection APIs return arrays or strings allocated via standard C `malloc`:
- `class_copyMethodList`
- `class_copyIvarList`
- `class_copyPropertyList`
- `class_copyProtocolList`
- `objc_copyClassList`
- `objc_copyProtocolList`
- `objc_copyImageNames`
- `objc_copyClassNamesForImage`
- `method_copyReturnType`
- `method_copyArgumentType`
- `property_copyAttributeValue`

These buffers **must be freed using `std.c.free`**, NOT `objc_release`, and NOT Zig allocator APIs.

### Owned Containers
| Container | Wraps | Deallocator |
| :--- | :--- | :--- |
| `OwnedCString` | `[*:0]u8` | `free(ptr)` |
| `OwnedRuntimeList(T)` | `[*]RawHandle` | `free(ptr)` |
| `OwnedMethodDescriptions` | `[*]raw.objc_method_description` | `free(ptr)` |
| `OwnedPropertyAttributes` | `[*]raw.objc_property_attribute_t` | `free(ptr)` |
| `OwnedCStringList` | `[*][*:0]const u8` | `free(ptr)` |

### Container APIs
All `Owned*` containers provide:
- `.count() usize`: Number of elements.
- `.isEmpty() bool`: Returns `count == 0`.
- `.get(index: usize) ?T`: Bounds-checked element access returning `null` if out of bounds.
- `.iterator() Iterator`: Standard iterator with `next() ?T`.
- `.deinit() void`: Idempotent deallocation via `std.c.free`.
- `OwnedRuntimeList(T).dupe(allocator) ![]T`: Copies elements into a normal Zig-managed slice that outlives the container.

```zig
var methods = cls.methods();
defer methods.deinit();

var iter = methods.iterator();
while (iter.next()) |method| {
    if (method.copyReturnType()) |ret_type| {
        var mut_ret = ret_type;
        defer mut_ret.deinit();
        std.debug.print("Return encoding: {s}\n", .{mut_ret.slice()});
    }
}
```

---

## 6. Domain 4: Scoped Autorelease Pools

`AutoreleasePool` is a scoped token that bounds the lifetime of autoreleased objects.

### Usage
```zig
var pool = objc.AutoreleasePool.init();
defer pool.deinit();

// Objects autoreleased in this scope will be released when pool drains
const date = NSDate.msgSend(objc.Object, "date", .{});
_ = date;
```

### Safety Features
- **`init() AutoreleasePool`**: Calls `objc_autoreleasePoolPush`.
- **`drain(self: *AutoreleasePool) void`**: Calls `objc_autoreleasePoolPop` and clears the token.
- **`deinit(self: *AutoreleasePool) void`**: Calls `drain()`. Safe to call multiple times.
- **LIFO ordering**: Nested pools must be drained in strict reverse order of creation.

---

## 7. Migration from Legacy `objc.free`

In prior versions, introspection queries returned bare slices (`[]Property`) requiring manual calls to `objc.free(list)`.

In Phase 3:
1. High-level introspection methods return typed `Owned*` containers:
   - `cls.methods() OwnedRuntimeList(Method)`
   - `cls.ivars() OwnedRuntimeList(Ivar)`
   - `cls.properties() OwnedRuntimeList(Property)`
   - `cls.protocols() OwnedRuntimeList(Protocol)`
   - `objc.classes() OwnedRuntimeList(Class)`
   - `objc.protocols() OwnedRuntimeList(Protocol)`
2. `objc.free(ptr)` is retained as a compatibility shim supporting slices, pointers, and optionals, but callers should migrate to `defer list.deinit()`.
