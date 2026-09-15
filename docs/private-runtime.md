# Private Runtime SPI and Raw-Only Operations

This document describes the quarantine boundaries for unstable Apple runtime SPIs (`objc.raw.internal`) and dangerous raw-only runtime operations (`objc_duplicateClass`).

---

## 1. Private SPI Quarantine (`objc.raw.internal`)

Apple's Objective-C runtime exports several private symbols (SPIs) used internally by CoreFoundation, Foundation, and libdispatch.

### 1.1 Architectural Policies
1. **No SemVer Guarantees**: Any symbol in `raw.internal` may break, alter signatures, or disappear across OS versions without notice.
2. **Zero Core Dependencies**: Stable `zobjc` high-level facilities (`objc.*`, `objc.runtime.*`, `objc.messaging.*`, etc.) **never depend** on `raw.internal`.
3. **Dynamic Resolution**: Symbols in `raw.internal` are resolved dynamically via `dlsym` (with Darwin's `RTLD_DEFAULT = ((void *)-2)`). They are never linked directly at compile time, eliminating dyld image load failures on older or newer OS releases.

### 1.2 Handled SPIs

#### `objc_setForwardHandler`
The historical forwarding handler hook used by CoreFoundation (`__CFInitialize`) to install forwarding dispatchers (`___forwarding___` and `___forwarding_stret___`):

```zig
const handler = objc.raw.internal.getSetForwardHandler();
if (handler) |set_fwd| {
    // Dynamically available on host OS
}
```

---

## 2. Raw-Only Operations: `objc_duplicateClass`

The function `objc_duplicateClass(Class original, const char *name, size_t extraBytes)` is intentionally restricted to `objc.raw.runtime.objc_duplicateClass` and **omitted from high-level class builders**.

### Why `objc_duplicateClass` is Raw-Only
1. **Known Apple Runtime Bugs**: Apple's own documentation and open-source `objc4` comments acknowledge known defects in `objc_duplicateClass` regarding ivar offset inheritance, metaclass linking, and method cache state.
2. **Dynamic Subclassing Alternative**: Modern dynamic subclassing via `objc.ClassBuilder` / `objc.allocateClassPair` is standard, thread-safe, and fully supported across all Apple platforms.
3. **Intentional Boundary**: Exposing `objc_duplicateClass` in `objc.Class` or `objc.ClassBuilder` would invite hard-to-debug runtime crashes. Callers requiring it for legacy binary patches can still access `objc.raw.runtime.objc_duplicateClass` directly with full knowledge of its risks.
