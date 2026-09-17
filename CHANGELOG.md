# Changelog

All notable changes to `zobjc` are documented in this file in accordance with [Keep a Changelog](https://keepachangelog.com/).

---

## [1.0.0] - 2026-09-17

Initial 1.0 release delivering a complete, robust, type-safe Objective-C runtime architecture for Zig.

### Added
* **Complete Raw libobjc ABI Bindings**: Full 146/146 SDK declarations from `<objc/*.h>` (`runtime.h`, `objc.h`, `message.h`, `objc-sync.h`, `objc-exception.h`) with 100% automated verification.
* **Unified Messaging Engine (`objc.send`)**:
  - Direct Darwin ABI classification for AAPCS64 (arm64) and SysV (x86_64).
  - Register pressure handling with proper stack spills for large parameter lists.
  - Automatic dispatch routing for direct, `objc_msgSend_stret`, `objc_msgSend_fpret`, and `objc_msgSendSuper2`.
  - Compile-time validation preventing invalid C ABI argument passing.
* **Explicit Ownership Model (`objc.Retained`, `objc.Weak`)**:
  - Separation of non-owning handles (`Object`, `Class`) from ownership obligations.
  - Zeroing weak references tracked by Apple's runtime weak table.
  - Scoped `AutoreleasePool` management.
  - RAII caller-freed runtime containers (`OwnedRuntimeList`, `OwnedCString`).
* **Objective-C Blocks Subsystem (`objc.OwnedBlock`)**:
  - Support for non-capturing, scalar-capturing, strong object-capturing (`Strong`), and weak-capturing (`Weak`) closures.
  - `ByRef` variable captures with automatic heap forwarding and stack-outliving lifecycle.
  - Bidirectional interoperability (Clang invoking Zig blocks, Zig invoking Clang blocks).
  - Block-to-IMP bridge generation (`objc.block.OwnedImp`).
* **Dynamic Builders**:
  - `ClassBuilder`: Safe state-machine class creation, automatic log2 ivar alignment, and method/protocol registration.
  - `ProtocolBuilder`: Runtime protocol generation with required/optional instance/class method descriptors.
* **Advanced Runtime Facilities**:
  - Type-safe associated objects (`AssociationKey`, `AssociationPolicy`).
  - Atomic method swizzling (`Swizzle`) and RAII scoped swizzling (`ScopedSwizzle`).
  - Direct method replacement (`MethodReplacement`) and block-backed method replacement (`BlockMethodReplacement`).
  - Unsafe runtime memory operations (`objc.advanced`).
* **Optional Foundation Convenience Layer (`objc_foundation`)**:
  - Decoupled from runtime core; links Foundation framework only when explicitly imported.
  - `toNSString` / `toSlice` UTF-8 string conversions.
  - `FastEnumerationIterator` stack-buffered iterator for `NSFastEnumeration`.
* **Multi-Platform Apple Support**:
  - Tier 1: Host verified on macOS Apple Silicon (`aarch64-macos`).
  - Tier 2: Cross-compiled and ABI verified for `macos-x86_64`, `ios-aarch64`, `ios-simulator-aarch64`, `tvos-aarch64`, `watchos-aarch64`, `visionos-aarch64`.

### Changed
* Core package `objc` now has **zero dependencies on Foundation.framework**.
* `objc.Selector` is now the canonical name for selector handles (`objc.Sel` is retained as a compatibility alias).
* `objc.send(Return, receiver, selector, args)` is now the canonical message dispatch API.
* Dynamic method callbacks require explicit `(self, _cmd)` parameters matching Apple C ABI conventions.

### Deprecated
* Bare `Object.release()` and `Object.retain()`: Non-owning handles should not manage memory; use `Retained(Object)`.
* `objc.free()`: Prefer RAII containers (`list.deinit()`) or `objc.raw.runtime.free()`.
* `.msgSend()` and `.msgSendSuper()`: Replaced by `.send()` and `objc.sendSuper()`.
* `objc.LegacyBlock`: Use modern `objc.OwnedBlock`.

### Fixed
* Fixed ABI mismatches on Darwin ARM64 for struct returns > 16 bytes (proper indirect result buffer routing).
* Fixed ivar alignment calculation to use log2 byte alignment required by `class_addIvar`.
* Fixed stack frame variable outliving for Block captures using `__block` byref descriptors.
