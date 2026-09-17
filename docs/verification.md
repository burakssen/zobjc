# Verification & Differential Testing Framework

This document details the verification methodology, testing suites, and platform support tiers for `zobjc`.

---

## 1. The Five Verification Contracts

To guarantee that `zobjc` behaves identically to Clang and Apple's native Objective-C runtime across all supported APIs and ABIs, five independent verification contracts are established:

```text
Contract 1: Zig Declarations          ↔  Apple SDK Headers
Contract 2: Zig Type Encodings        ↔  Clang @encode / Runtime Encodings
Contract 3: Zig ABI Classifier        ↔  Darwin Calling Conventions (AAPCS64 / SysV x86_64)
Contract 4: zobjc Messaging & Blocks  ↔  Native Objective-C Execution
Contract 5: Public API Compatibility  ↔  Consumer Packages & Upstream Codebases
```

---

### Contract 1: SDK Header Parity (`test-parity`, `audit-runtime`)
* **Objective**: Ensure that all declarations in `src/raw/` match the layout, sizes, alignments, and signatures of Apple SDK headers (`<objc/objc.h>`, `<objc/runtime.h>`, `<objc/message.h>`, `<objc/objc-sync.h>`, `<objc/objc-exception.h>`).
* **Tooling**:
  - `tools/audit-runtime-api.py`: Automated AST parser checking 146 SDK symbols against `tools/runtime-api-manifest.json` and verifying declaration existence in `src/raw/`.
  - `tests/parity/`: Type, struct, constant, and function pointer equivalence checks compiled directly against translated SDK headers.
* **Guarantee**: 100% (146/146) SDK symbol coverage.

---

### Contract 2: Clang `@encode` Parity (`test-differential`)
* **Objective**: Guarantee that `objc.comptimeEncode(T)` produces byte-for-byte identical signatures to Clang's `@encode(T)`.
* **Verified Types**:
  - All standard scalars (`c_char`, `c_int`, `c_long`, `c_longlong`, `f32`, `f64`, `BOOL`, `*anyopaque`, `SEL`, `id`, `Class`).
  - Complex nested structures (`struct Outer { a: [3]int, b: struct Inner { c: float, d: double } }`).
  - Bitfields and union encodings.
  - Live runtime method type encoding parser round-trips.

---

### Contract 3: Darwin ABI Classification (`test-differential`, `test-abi`)
* **Objective**: Match Darwin calling conventions across architectures.
* **Apple Silicon (AAPCS64)**:
  - Small aggregate direct return in `x0`/`x1` (size <= 16 bytes).
  - Indirect result buffer pointer (`x8`) for return sizes > 16 bytes (`objc_msgSend_stret` is disabled on arm64).
  - Floating point homogeneity (HFA) up to 4 elements in `v0`-`v3`.
* **Intel Mac (x86_64 SysV ABI)**:
  - Integer / pointer returns in `rax`/`rdx`.
  - Floating point returns in `xmm0`/`xmm1` (`objc_msgSend_fpret`).
  - Non-trivial struct return via `objc_msgSend_stret` (size > 16 bytes or unaligned classes).
* **Regression Gates**:
  - Permanent regression tests comparing same-size, different-layout structures (e.g. 16-byte `struct { u64, u64 }` vs `struct { f64, f64 }`).

---

### Contract 4: Native Objective-C Execution Parity (`test-differential`)
* **Objective**: Validate interop execution where Zig and Clang cross-call each other:
  - Clang calling Zig blocks and capturing values.
  - Zig calling Clang blocks via heap promotion (`_Block_copy`).
  - ByRef forwarding pointers outliving stack frames (`BLOCK_FIELD_IS_BYREF`).
  - Strong capture lifecycle tracking verified by observable deallocation hooks.
  - High register pressure parameter passing (10 integer registers, 10 double registers) proving stack-spill correctness.
  - Large struct passing (> 32 bytes) by value.
  - Dynamic subclass super dispatch (`objc_msgSendSuper`).

---

### Contract 5: Compatibility & Consumer Isolation (`test-compat`, `test-consumer`, `test-compile-fail`)
* **Objective**: Prevent regressions for existing codebases and enforce compile-time safety.
* **Guarantees**:
  - Upstream `zig-objc` patterns continue to compile and work.
  - An isolated external consumer package (`tests/consumer/`) imports `zobjc` via `build.zig.zon` and verifies zero Foundation linkage.
  - Compile-fail rejection suite validates that dangerous invalid constructs (`comptime_int` args, missing `_cmd`, non-extern structs, slices as C strings) fail compilation with descriptive error messages.

---

## 2. Platform Support Matrix

| Platform | Architecture | Verification Tier | Test Coverage |
| :--- | :--- | :--- | :--- |
| **macOS** | Apple Silicon (`aarch64-macos`) | **Tier 1 (Host Verified)** | Full suite: core, foundation, integration, parity, differential, compat, consumer, compile-fail |
| **macOS** | Intel (`x86_64-macos`) | **Tier 2 (Cross-Compiled & ABI Verified)** | Static library compilation, ABI classification unit tests |
| **iOS** | Device (`aarch64-ios`) | **Tier 2 (Cross-Compiled)** | Static library compilation |
| **iOS Simulator** | Apple Silicon (`aarch64-ios-simulator`) | **Tier 2 (Cross-Compiled)** | Static library compilation |
| **tvOS** | Apple Silicon (`aarch64-tvos`) | **Tier 2 (Cross-Compiled)** | Static library compilation |
| **watchOS** | Apple Silicon (`aarch64-watchos`) | **Tier 2 (Cross-Compiled)** | Static library compilation |
| **visionOS** | Apple Silicon (`aarch64-visionos`) | **Tier 2 (Cross-Compiled)** | Static library compilation |

---

## 3. Reproduction Commands

To run any verification step individually or the complete release suite:

```bash
# Full release verification matrix (all contracts)
zig build test-all

# SDK Header Parity Suite
zig build test-parity

# Clang Differential Interop Suite
zig build test-differential

# Upstream Compatibility Suite
zig build test-compat

# SDK Runtime API Audit
zig build audit-runtime

# Compile-Fail Rejection Suite
zig build test-compile-fail

# Standalone Consumer Package Verification
zig build test-consumer

# Multi-Platform Apple Cross-Compilation
zig build test-cross
```
