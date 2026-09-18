# Changelog

All notable changes to zobjc are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Verified (no change needed)

- `raw.objc_bool_is_bool` was audited against the toolchain instead of just
  the header text: Apple's `<objc/objc.h>` honors the compiler-predefined
  `__OBJC_BOOL_IS_BOOL` macro first, and Apple Clang 21 / zig cc 0.16.0
  define it as 1 for macOS arm64 and all 64-bit iOS-family targets (0 only
  for macOS x86_64). The existing architecture-first switch already encodes
  exactly this; the header's `TARGET_OS_OSX → signed char` fallback only
  applies to compilers without the predefined macro. The Clang differential
  test `checkDifferential(raw.BOOL, fixture_encode_bool)` plus new
  target-specific regression assertions pin this per toolchain.

### Fixed

- Fixed CI bootstrap: `mlugg/setup-zig@v1` 404s on Zig 0.16.0; moved to
  `mlugg/setup-zig@v2`.
- Added native x86-64 CI coverage (`macos-15-intel`) alongside arm64
  (`macos-14`) so `stret`/`fpret` messenger selection and `fp2ret`
  non-selection invariants are exercised natively.
- Made `sendChecked` genuinely signature-aware in safety builds: beyond
  `respondsToSelector`, it now compares `method_getTypeEncoding()` against
  the Zig-requested signature and panics on mismatch.
- Replaced `.ptr` duck typing with an explicit Objective-C wrapper trait
  (`objc_wrapper` marker or `asObject`/`fromObject`), shared by messaging,
  memory, encoding, and Blocks paths.

### Changed

- Documented the intended module DAG (`docs/architecture.md`): the `zobjc`
  facade knows every subsystem; no subsystem may import the facade. Legacy
  back-edges are being removed incrementally.
- Hardened ownership documentation (`docs/ownership.md`): `Retained`, `Weak`,
  `OwnedBlock`, and `AutoreleasePool` are move-only by convention; Zig cannot
  enforce it, so accidental by-value copies are documented as double-release
  hazards with pointer-receiver guidance.

## [1.0.0] - 2026-09-17

- Initial stable API surface: raw libobjc declarations, runtime handles,
  typed messaging with ABI classification, ownership wrappers, Blocks, and
  type encoding with differential fixtures.
