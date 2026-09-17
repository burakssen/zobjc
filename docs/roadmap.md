# Technical Roadmap: Phases 0–11

This roadmap outlines the complete 12-phase technical evolution of `zobjc`.

---

### Phase 0 — Architectural Baseline, Repository Restructuring, and Compatibility Contract
- Establish modular directory structure (`raw/`, `runtime/`, `messaging/`, `abi/`, `encoding/`, `memory/`, `block/`, `builder/`, `internal/`).
- Preserve 100% backward compatibility via `src/objc.zig`.
- Document architectural boundaries, dependency rules, and coding standards.
- Separate unit, runtime, messaging, block, and integration test suites.
- Establish compilable examples in `examples/`.

### Phase 1 — Complete Objective-C Raw Runtime ABI
- Replace `objc-c` header translation with handwritten, complete, non-opinionated raw runtime declarations (`objc.raw.runtime.*`).
- Declare all Apple Objective-C runtime C functions, structs, and constants.

### Phase 2 — Typed Runtime Handles & Introspection
- Expand typed handle wrappers: `Method`, `Ivar`, `Imp`.
- Standardize nullable-handle invariants (`Class`, `Object`, `Selector` non-null).
- Comprehensive runtime introspection accessors (`cls.name()`, `cls.methods()`, `cls.ivars()`, `method.selector()`, `ivar.offset()`).

### Phase 3 — Safe Memory Management & Ownership Semantics
- Implement `Retained(T)` and `Weak(T)` smart pointer wrappers.
- Implement `OwnedSlice(T)` and `OwnedCString` for runtime-allocated memory.
- Deprecate unstructured manual `objc.free()`.

### Phase 4 — Objective-C Type Encoding Parser & Generator
- Implement a comprehensive type encoding parser (`encoding.parse`).
- Dynamic type encoding inspection, comparison, and method signature validation.
- Comptime encoding generator hardening.

### Phase 5 — Target Calling Convention & ABI Classification
- Implement ARM64 and x86_64 calling-convention ABI classification in `abi/`.
- Correct handling of aggregate return values (`objc_msgSend_stret`).
- Correct floating-point return handling (`objc_msgSend_fpret`).

### Phase 6 — Unified Messaging Engine
- Centralize message dispatch in `messaging/root.zig`: `objc.send()`, `objc.sendSuper()`, `invoke()`.
- Route `Object.msgSend` and `Class.msgSend` through the unified dispatcher.
- Automatic argument type checking and coercion.

### Phase 7 — Dynamic Builders
- Implement `ClassBuilder` for fluent dynamic class registration, method addition, and ivar sizing.
- Implement `ProtocolBuilder` for runtime protocol creation.

### Phase 8 — Objective-C Blocks Modernization
- Modernize block memory layout and copy/dispose helper generation.
- Full support for capturing non-object primitives and complex Zig types.

### Phase 9 — Associated Objects & Extended Runtime APIs
- Add support for associated objects (`objc_setAssociatedObject`, `objc_getAssociatedObject`).
- Add image inspection (`class_copyPropertyList`, `objc_copyImageNames`, `objc_copyClassNamesForImage`).

### Phase 10 — Foundation Separation & Convenience Layer [COMPLETED]
- [x] Separate Core Objective-C runtime abstractions from Apple Foundation conveniences (`objc` vs `objc_foundation`).
- [x] Pure `libobjc` core runtime linking strictly to `libobjc.A.dylib` and `libc`.
- [x] Verify zero `Foundation.framework` linkage in `test-core` via image introspection and `otool -L`.
- [x] Move `NSFastEnumeration` (`FastEnumerationIterator`, `fastIterate`) and Cocoa string conversions (`NSString`) into optional `objc_foundation` module.
- [x] Zero-overhead `NSString` handle with `Retained(NSString)` and UTF-8 conversions.
- [x] Zero-heap-allocation stack-buffered fast enumeration iterator with safe mutation detection (`error.CollectionMutated`).
- [x] `NSEnumerator`, `NSRange`, `StringEncoding`, and foundational typedefs.

### Phase 11 — Comprehensive Test Matrix & CI Hardening
- Establish cross-architecture testing (macOS aarch64 & x86_64).
- Address edge cases, tagged pointer variants, and compiler stress tests.
