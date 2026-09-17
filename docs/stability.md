# Stability Policy & Semantic Versioning Guarantees

This document establishes the official API stability classifications, Semantic Versioning (SemVer) guarantees, and threading/runtime invariants for `zobjc`.

---

## 1. Semantic Versioning Policy

`zobjc` strictly adheres to [Semantic Versioning 2.0.0](https://semver.org/):

```text
MAJOR.MINOR.PATCH
```

* **MAJOR**: Incompatible changes to public API declarations, removals of deprecated APIs, or behavioral changes that break documented contracts.
* **MINOR**: Backward-compatible additive features, support for new Apple SDK symbols or OS releases, new platform targets, or new optional modules.
* **PATCH**: Backward-compatible bug fixes, performance improvements, documentation updates, and ABI correctness fixes that align behavior with documented Apple/Clang runtime contracts.

> [!NOTE]
> **ABI Correctness Nuance**: If an ABI classifier or message dispatch path generated incorrect machine code under a specific aggregate or register condition, correcting it to match Clang's code generation is classified as a **PATCH** bug fix, even if calling code previously relied on erroneous behavior.

---

## 2. API Stability Tiers

Every symbol in `zobjc` belongs to one of six explicit stability tiers:

| Tier | Scopes | SemVer Guarantee | Notes |
| :--- | :--- | :--- | :--- |
| **Stable** | `objc.*`, `objc.runtime.*`, `objc.memory.*`, `objc.messaging.*`, `objc.block.*`, `objc.builder.*`, `objc_foundation.*` | **Strict SemVer** | Canonical high-level APIs for production applications. |
| **Advanced** | `objc.advanced.*` | **Strict SemVer** | High-level API signatures are frozen, but operations carry inherently dangerous semantics (manual object memory allocation, mass association teardown). |
| **Deprecated** | `Object.release()`, `Object.retain()`, `objc.free()`, `.msgSend()`, `Sel` | **Temporary Backward Compatibility** | Preserved for at least one major cycle (1.x); migration replacements are prominently documented. |
| **Raw** | `objc.raw.*` | **Upstream Apple C ABI Mirror** | Declarations mirror Apple's public `<objc/*.h>` headers. Signatures remain stable unless Apple alters SDK prototypes. |
| **Experimental** | `objc.raw.internal.*` | **No SemVer Guarantees** | Private Apple runtime SPI (e.g. forward handlers). May be modified, disabled, or removed in any release without warning. |
| **Internal** | `src/internal/*`, unexported module symbols | **None (Private)** | Implementation details subject to continuous refactoring. |

---

## 3. Public API Boundary

A symbol is part of the public API if and only if it is:
1. Re-exported by `src/objc.zig` or `src/foundation/root.zig`.
2. Cataloged in [docs/public-api.txt](file:///Users/burakssen/dev/personal/apple/zobjc/docs/public-api.txt).
3. Documented in the official guides under `docs/`.

Private implementation types (such as `Parser.Cursor`, `X86EightbyteState`, `NormalizedArgs`, `BlockLiteralBuilder`) are internal and must not be imported directly by external codebases.

---

## 4. Compiler Errors & Panics Policy

### 4.1 Compile-Time Error Assertions
`zobjc` prefers compile-time rejection over runtime crashes for invalid C ABI types:
- Passing untyped `comptime_int` or `comptime_float` to `send(...)`.
- Passing non-sentinel slices (`[]const u8`) instead of C strings (`[:0]const u8`).
- Passing Zig-layout structs instead of `extern struct`.
- Constructing method callbacks without the mandatory `(self, _cmd)` parameters.
- Passing non-retainable types to `Retained(T)` or `Weak(T)`.

*SemVer Policy on Error Messages*: The **fact** that invalid constructs are rejected at compile time is a stable guarantee. However, the exact wording of compiler error strings is not part of SemVer and may be refined for clarity.

### 4.2 Runtime Panics
The runtime core never panics during normal execution. Runtime panics are restricted to:
1. **Use-After-Free / Use-After-Deinit**: Calling `.borrow()` or `.call()` on an already-deinitialized `Retained(T)` or `OwnedBlock(F)`.
2. **Contract Violation on Non-Null Returns**: Receiving `nil` from an Objective-C message when the caller explicitly requested a non-optional return type (`objc.send(objc.Object, ...)` instead of `objc.send(?objc.Object, ...)`).
3. **Missing Required Entities**: `requireClass("Name")` or `requireProtocol("Name")` when the target class or protocol does not exist.

---

## 5. Thread-Safety & Concurrency Guarantees

* **Selector Registration (`objc.sel`)**: Fully thread-safe (guaranteed by Apple's runtime string deduplication table).
* **Message Dispatch (`objc.send`, `sendSuper`, `invoke`)**: Reentrant and thread-safe at the dispatch level. Concurrency safety of method execution depends on the receiver object's implementation.
* **Associated Objects (`setAssociated`, `associated`)**: Thread-safety is governed by the selected `AssociationPolicy` (e.g. `OBJC_ASSOCIATION_RETAIN` vs `OBJC_ASSOCIATION_RETAIN_NONATOMIC`).
* **Dynamic Builders (`ClassBuilder`, `ProtocolBuilder`)**: Registration (`register()`) performs global runtime mutations. Callers must coordinate class creation to avoid duplicate names.
* **Method Swizzling (`Swizzle`, `MethodReplacement`)**: Modifies global class method tables. Callers must ensure synchronization across threads.
* **Weak References (`Weak(T)`)**: Synchronized via Apple's runtime weak table lock.
