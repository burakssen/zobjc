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

- Removed the final `block` -> `zobjc` facade dependency. The subsystem
  module graph is now acyclic, with all subsystem dependencies wired
  explicitly downward.
- Block tests now link libobjc and their Clang Block fixture directly
  instead of inheriting test linkage through the facade.
- Broke `runtime` -> `block`: `BlockMethodReplacement` and Block-bridged
  class enumeration moved into `block`.
- Broke `memory` -> `runtime`: shared `Selector`/`MethodDescription`/
  `PropertyAttribute` now live in `internal` (re-exported by `runtime` with
  unchanged identity), and ownership reconstruction is structural
  (`fromRawNonNull` preference, `fromObject`/`fromObjC` conventions,
  direct `.ptr` fallback) with unit fixtures for every path.
- Decoupled `runtime` and `memory` from the facade: live runtime and
  ownership tests moved to facade integration coverage while pure
  conversion/layout tests stay in-module; both test targets link `libobjc`
  explicitly; no facade edges remain.
- Simplified the wrapper trait to the two meaningful `.imp` field shapes
  (`raw.IMP` and the unwrapped pointer), dropping the nested `?raw.IMP`
  form; `callImp` normalizes both shapes and fails closed on null.
- Made messaging `invoke`/`callImp` normalizers reject null raw
  `Method`/`IMP` handles with a panic, preserving the previous non-null
  `runtime.Method`/`Imp` invariant; converted remaining messaging
  integration-test cleanups from `dealloc` to `release`.
- Decoupled `messaging` from `runtime` and the facade: handle normalization
  (`receiver`/`arguments`/`returns`/`selector`/`validation`) is
  wrapper-trait-authoritative, selectors register via `raw`, super dispatch
  uses a `classToRaw` helper without `.ptr` duck typing, `invoke`/`callImp`
  accept raw handles or narrow normalizers, and live tests moved to the
  facade. Also fixed optional custom wrappers decaying to raw ABI handles.
- Pinned `abi` admission with a `categorize` table test and
  `classifyReturn` handle/raw equivalence assertions at the facade.
- Decoupled `abi` into a pure compile-time leaf with no `runtime`,
  `encoding`, `internal`, facade, or `raw` imports: handles classify by
  machine representation: raw handles as pointers, single-pointer
  wrapper structs as aggregates of one pointer, and optional single-pointer
  wrappers via pointer classification; `assertValidReturn` removed in favor of
  the single `categorize` accept/reject switch, and handle coverage moved to
  facade equivalence tests (`returnConvention(T) == returnConvention(raw)`).
- Made `objc_wrapper = false` an explicit wrapper-trait opt-out (taking
  precedence over inferred conventions) and reject non-boolean marker
  declarations at compile time.
- Decoupled `encoding` from `runtime` and the facade via the wrapper trait:
  the five core handles now carry `objc_wrapper`, `encoder`/`StorageType`/
  method validation derive handle behavior from wrapper kinds (with a
  canonical `@:` and a new pure-trait `Imp → ^?` path), live differential
  tests moved to the facade, and `wireModules()` now lists remaining upward
  facade edges explicitly.
- Made `raw.boolResult()` follow C truthiness (`!= 0`) instead of `== 1`,
  so non-canonical signed-char `BOOL` values convert correctly; pinned with
  char-`BOOL`-target regression assertions.
- Fixed an x86_64-only test compile error: `class_addMethod` returns raw
  `BOOL` (`i8` on Intel), so the Block test now asserts via
  `raw.boolResult()`; also releases instead of directly deallocating the test
  instance.

- Made `methodEncoding()` emit canonical `@:` for the implicit `self`/`_cmd`
  parameters regardless of Zig receiver type (a `Class` first parameter no
  longer produces `#:`); generic `comptimeEncode(Class)` still returns `#`.
  Pinned by unit tests plus a Clang differential test showing instance and
  class methods on the `ABIFixture` class both hide `self` as `@`.
- Made the expected `sendChecked` receiver encoding canonical `@` for both
  instance and class receivers (removed the `#` distinction and
  `receiverEncodingChar`), and unified method lookup through
  `object_getClass` + `class_getInstanceMethod` for both receivers, dropping
  the fallback chain and `receiverIsClass`.
- Extracted the pure `checkSignatures` comparison with table regression
  tests covering exact matches, mismatches, structural `skip`, and
  unknown-type fail-open behavior.
- Removed the file-internal `raw` <-> `root.zig` import edges: raw sources
  now reference local declarations and sibling files directly, with the
  `BOOL` helper assertions moved to the facade test block.
- Fixed a misleading `sendChecked` comment claiming some runtime encodings
  (e.g. `+alloc` as `@16@0:8`) omit `_cmd`; `@0` is `self` and `:8` is
  `_cmd`. The check now gates on the standard receiver/selector-first
  structure (failing open otherwise) and compares explicit arguments exactly
  at `[2..]` instead of tail-aligned.
- Removed the `raw` -> `zobjc` module back-edge: `raw` sources now use
  relative imports and `wireModules()` adds no upward edge for `raw`, the
  first step toward the documented dependency DAG.
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

- Moved `BlockMethodReplacement` from `runtime` to `block` (top-level
  `objc.BlockMethodReplacement` spelling unchanged) and class enumeration
  (`enumerateClasses`, `ClassEnumerationOptions`, `ImageFilter`) from
  `runtime` to `block`, exposed at the top level as `objc.enumerateClasses`
  etc.; the `objc.runtime.*` paths for these no longer exist.
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
