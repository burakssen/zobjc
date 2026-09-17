# Contributing to zobjc

Thank you for contributing to `zobjc`! This project provides production-grade, type-safe Objective-C runtime abstractions and C ABI bindings for the Zig programming language.

---

## 1. Architectural Invariants

To keep the codebase maintainable and prevent regressions, all contributions must respect the frozen layered architecture:

```text
raw -> runtime / encoding -> ABI -> messaging -> builder / block / advanced
```

1. **Layer Isolation**:
   - `src/raw/`: Contains solely raw C ABI declarations mirroring Apple SDK headers. No high-level abstractions or allocations.
   - `src/messaging/`: Sole authority on message dispatch and argument normalization.
   - `src/abi/`: Sole authority on Darwin ABI classification and calling conventions.
   - `src/block/`: Objective-C Blocks ABI, layout, and capture lifecycles.
   - `src/foundation/`: Optional convenience layer. **Foundation.framework must NEVER be imported or linked in the core package.**
2. **Downward Imports Only**:
   - `raw` must never import `runtime`.
   - `encoding` and `abi` must never import `messaging`.
   - Core `objc` must never import `objc_foundation`.
3. **Private SPI Isolation**:
   - Symbols in `objc.raw.internal` are private Apple SPI and must never become dependencies of stable public APIs.

---

## 2. Testing Requirements for PRs

Every change affecting runtime behavior, type encodings, or ABI dispatch must be accompanied by appropriate test coverage:

- **SDK Header Updates**: Must be cataloged in `tools/runtime-api-manifest.json` and pass `zig build audit-runtime` and `zig build test-parity`.
- **ABI & Calling Convention Fixes**: Must include a differential test in `tests/differential/` verified against native Clang execution (`fixtures.m`).
- **Compile Rejections**: If adding compile-time type validation, add a test case to `tests/compile_fail/cases/` and verify with `zig build test-compile-fail`.

---

## 3. Development Commands

```bash
# Run complete release test matrix (all suites + cross targets)
zig build test-all

# Run standard test suite (core + foundation + integration)
zig build test

# Run Clang differential tests
zig build test-differential

# Run SDK parity tests
zig build test-parity

# Audit SDK symbol coverage
zig build audit-runtime

# Compile all examples
zig build examples

# Check formatting
zig fmt --check .
```

Please ensure `zig fmt .` is run before submitting pull requests.
