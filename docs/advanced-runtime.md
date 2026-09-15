# Advanced Runtime Operations

The `objc.advanced` module houses dangerous, low-level runtime facilities that bypass standard Objective-C memory management and ARC conventions.

---

## 1. Safety Model

Functions in `objc.advanced` require direct caller participation in object layout and lifetime management:

- **Bypasses ARC**: The runtime's automatic reference counting is unaware of manually constructed instances until properly registered.
- **Manual Allocation**: The caller is strictly responsible for memory allocation, zero-filling, pointer alignment, and eventual freeing.
- **No Implicit `-dealloc`**: Destruction functions do not send `-dealloc` messages or free backing bytes.

---

## 2. Manual Instance Construction

### 2.1 Construction Primitives

```zig
pub fn constructInstance(class: Class, storage: *anyopaque) ?Object;
pub fn destructInstance(object: Object) ?*anyopaque;
```

#### Invariants:
1. `storage` must point to at least `class.instanceSize()` bytes.
2. The memory must be aligned to `@alignOf(raw.id)` (8 bytes on 64-bit platforms).
3. The memory **must be zero-filled** prior to calling `constructInstance`.

```zig
const size = cls.instanceSize();
const storage = try allocator.alignedAlloc(u8, .fromByteUnits(@alignOf(objc.raw.id)), size);
defer allocator.free(storage);
@memset(storage, 0);

const inst = objc.advanced.constructInstance(cls, storage.ptr).?;
_ = inst.msgSend(objc.Object, "init", .{});

// Use instance ...

const raw_buf = objc.advanced.destructInstance(inst);
// Memory can now be reused or freed
```

### 2.2 `ConstructedInstance` Handle

`ConstructedInstance` wraps a manually constructed instance to prevent use-after-free:

```zig
var handle = objc.advanced.ConstructedInstance.init(inst);

// Borrow non-owning Object
_ = handle.borrow();

// Destruct instance without freeing storage; clears internal Object handle
const buf = handle.destruct();
allocator.free(buf);
```

---

## 3. Object Memory Copy and Disposal

Low-level wrappers around `object_copy` and `object_dispose`:

```zig
// Allocates a raw bitwise copy of object memory with extra_bytes
const copy = objc.advanced.copyObjectMemory(original, 0);

// Frees memory without sending Objective-C -dealloc
objc.advanced.disposeObjectMemory(copy);
```

> [!WARNING]
> Use standard Objective-C `-copy` and `-release` for normal objects. `copyObjectMemory` and `disposeObjectMemory` are low-level runtime allocators that bypass class-specific copy and cleanup logic.

---

## 4. Bulk Association Removal

```zig
objc.advanced.removeAllAssociatedObjects(host);
```

Removes all associated objects across all keys on `host`. As cautioned by Apple, this wipes associations created by external frameworks and should not be used for routine object teardown. Prefer `host.clearAssociated(&key)`.
