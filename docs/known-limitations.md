# Known Limitations & Planned Mitigations

This document catalogues intentional architectural and functional limitations present in the Phase 0 baseline, along with references to the future phases that will address them.

---

## 1. x86_64 Calling Convention & Aggregate Return Classification

- **Limitation**: In the legacy dispatch code (`messaging/msg_send.zig`), structs larger than 16 bytes are assumed to require `objc_msgSend_stret` on x86_64 based on a simple size heuristic. The actual System V AMD64 ABI classification rules for aggregates (eightbyte classification into INTEGER, SSE, MEMORY) are significantly more nuanced.
- **Phase Mitigation**: **Phase 5 (Target Calling Convention & ABI Classification)** implements a complete System V AMD64 ABI and Apple ARM64 ABI classifier.

---

## 2. Floating-Point Return Dispatch (`objc_msgSend_fpret`)

- **Limitation**: The current implementation checks for 64-bit float (`f64`) on x86_64, but 80-bit long double and complex float returns on x86_64 have specific calling conventions.
- **Phase Mitigation**: **Phase 5 (ABI Classification)**.

---

## 3. Manual Memory Management

- **Limitation**: Object references currently require manual `.retain()` and `.release()` calls, and dynamically returned property lists require explicit `objc.free()` calls.
- **Phase Mitigation**: **Phase 3 (Safe Memory Management & Ownership Semantics)** will introduce `Retained(T)`, `Weak(T)`, and `OwnedSlice(T)` to automate memory management.

---

## 4. Incomplete Runtime API Surface

- **Limitation**: The current library wraps only a subset of the Objective-C runtime C functions.
- **Phase Mitigation**: **Phase 1 (Raw ABI)** will provide 100% coverage of the underlying Apple runtime C declarations.

---

## 5. Type Encoding Parser Completeness

- **Limitation**: The current type encoding subsystem focuses on comptime encoding generation rather than arbitrary runtime string parsing.
- **Phase Mitigation**: **Phase 4 (Type Encoding Parser & Generator)** will add a comprehensive bidirectional parser.

---

## 6. Dynamic Class Construction Flexibility

- **Limitation**: Dynamic class creation is currently performed via imperative calls to `allocateClassPair`, `addMethod`, `addIvar`, and `registerClassPair`.
- **Phase Mitigation**: **Phase 7 (Dynamic Builders)** will introduce a fluent, compile-time verified `ClassBuilder`.

---

## 7. Foundation Coupling

- **Limitation**: `NSFastEnumeration` support (`Iterator`) currently resides inside `runtime/` and depends on Foundation framework linkage.
- **Phase Mitigation**: **Phase 10 (Foundation Separation & Convenience Layer)** will decouple core runtime bindings from Apple Foundation conveniences.
