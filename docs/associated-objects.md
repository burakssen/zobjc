# Associated Objects

Associated objects allow attaching arbitrary state to existing Objective-C object instances at runtime without subclassing or modifying class ivar layouts.

---

## 1. Overview

Associated objects are backed by the Apple Objective-C runtime's associative reference mechanism (`objc_setAssociatedObject`, `objc_getAssociatedObject`, `objc_removeAssociatedObjects`).

`zobjc` provides a type-safe, leak-free layer over these primitives:
- `objc.AssociationPolicy`: Strongly-typed enum matching runtime ABI values.
- `objc.AssociationKey`: Non-zero-sized key token ensuring unique pointer identity.
- Ergonomic methods on `objc.Object`: `setAssociated`, `associated`, `clearAssociated`, and `associatedRetained`.

---

## 2. Association Policies

| Policy | ABI Value | Behavior |
| :--- | :--- | :--- |
| `assign` | `0` (`OBJC_ASSOCIATION_ASSIGN`) | Weak unretained reference. Does not retain or release. |
| `retain_nonatomic` | `1` (`OBJC_ASSOCIATION_RETAIN_NONATOMIC`) | Strong reference. Retains on attach, releases on clear/host dealloc. Non-thread-safe. |
| `copy_nonatomic` | `3` (`OBJC_ASSOCIATION_COPY_NONATOMIC`) | Copies object via `-copyWithZone:`. Non-thread-safe. |
| `retain` | `769` / `0x301` (`OBJC_ASSOCIATION_RETAIN`) | Strong reference with atomic synchronization. On read, runtime retains and autoreleases. |
| `copy` | `771` / `0x303` (`OBJC_ASSOCIATION_COPY`) | Copied reference with atomic synchronization. |

---

## 3. Association Keys

In Objective-C, keys are compared by pointer address. To prevent compiler optimizations or zero-sized struct deduplication from collapsing keys:

```zig
// Defined with an internal single-byte token to guarantee distinct address identity
pub const AssociationKey = struct {
    token: u8 = 0,

    pub fn init() AssociationKey {
        return .{};
    }
};
```

> [!IMPORTANT]
> Association keys must reside at stable memory addresses for the entire duration of the association (typically static/global storage).

```zig
// Recommended: static global keys
const MyKey = struct {
    var key = objc.AssociationKey.init();
};
```

---

## 4. Usage

### 4.1 Attaching and Retrieving

```zig
const host = objc.requireClass("NSObject").msgSend(objc.Object, "alloc", .{})
    .msgSend(objc.Object, "init", .{});
defer host.msgSend(void, "dealloc", .{});

const tag = objc.requireClass("NSString").msgSend(objc.Object, "stringWithUTF8String:", .{"metadata"});

// Attach
host.setAssociated(&MyKey.key, tag, .retain_nonatomic);

// Retrieve borrowed (+0) handle
if (host.associated(&MyKey.key)) |val| {
    std.debug.print("Found tag: {s}\n", .{val.className()});
}

// Retrieve retained (+1) handle
if (host.associatedRetained(&MyKey.key)) |retained_val| {
    defer retained_val.deinit();
    // Safely hold strong reference
}

// Clear individual key
host.clearAssociated(&MyKey.key);
```

### 4.2 Removing All Associations

To wipe all associations attached to an object (including those installed by other frameworks or libraries):

```zig
objc.advanced.removeAllAssociatedObjects(host);
```

> [!CAUTION]
> Apple explicitly discourages routine use of `objc_removeAssociatedObjects` because it deletes associations installed by unrelated libraries or system frameworks on the same object. Prefer `host.clearAssociated(&key)` for specific keys.
