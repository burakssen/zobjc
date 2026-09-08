# Darwin Objective-C ABI Classification and Call Convention Engine

This document defines the architecture, target specifications, System V AMD64 and ARM64 Darwin calling conventions, and compile-time return classification facilities in `zobjc` (`src/abi/`).

---

## 1. Architectural Scope and Boundaries

The ABI classification subsystem is a **pure compile-time decision engine**. It answers exactly one question:

```text
Given:
    Target (architecture, OS, ABI)
    + Return type T
    + Darwin Objective-C runtime ABI rules

Which runtime dispatch convention must be used?
```

```text
               ┌────────────────────────┐
               │    Zig Return Type T   │
               └───────────┬────────────┘
                           │
                           ▼
          ┌──────────────────────────────────┐
          │  objc.abi.returnConventionFor()  │
          └────────────────┬─────────────────┘
                           │
            ┌──────────────┴──────────────┐
            ▼                             ▼
   Target.macos_arm64            Target.macos_x86_64
            │                             │
    Unconditionally:              System V AMD64
    .normal                       Section 3.2.3
    (objc_msgSend)                Classification Engine
                                          │
                        ┌─────────────────┴─────────────────┐
                        ▼                                   ▼
             Scalars & <=16B aggregates           >16B or unaligned aggregates
             .normal, .fpret, .fp2ret             .stret
```

### Strict Separation of Concerns
- **Zero Runtime Allocations**: ABI classification operates entirely at `comptime`.
- **Pure Decision Engine (Phase 5)**: This subsystem does **not** invoke `objc_msgSend` or execute message dispatch. Unified message dispatch is the exclusive scope of Phase 6.
- **Cross-Target Evaluation**: Both ARM64 and x86_64 classification rules can be evaluated at compile time on any host platform (e.g. testing x86_64 rules while running on an Apple Silicon arm64 host).

---

## 2. Why Naive Heuristics Fail

Many legacy wrappers and naive bindings rely on simplistic heuristics such as:

```zig
// NAIVE HEURISTICS - DO NOT USE:
if (@sizeOf(Return) > 16) use_stret;
if (@typeInfo(Return) == .float) use_fpret;
```

These heuristics are fundamentally incorrect on Darwin for several reasons:

### 2.1 ARM64 Libobjc Has No `stret` or `fpret`
On Apple Silicon (ARM64), Apple's runtime headers explicitly omit `objc_msgSend_stret` and `objc_msgSend_fpret`:
```c
// <objc/message.h>
#if !defined(__arm64__)
OBJC_EXPORT void objc_msgSend_stret(void /* id, SEL, ... */ );
#endif
```
On ARM64, structures of *any* size (including 32-byte `CGRect` or 64-byte matrices) are dispatched through standard `objc_msgSend`. The ARM64 AAPCS calling convention places indirect result pointers into register `x8`, allowing `objc_msgSend` to preserve `x0` (`self`) and `x1` (`_cmd`) without colliding with the return buffer pointer.

Invoking `objc_msgSend_stret` on ARM64 causes a link error or undefined runtime trap.

### 2.2 x86_64 `fpret` is Exclusively for `long double`
On x86_64 Darwin, `objc_msgSend_fpret` is defined specifically to return `long double` (80-bit x87 float):
```c
// <objc/message.h>
#if defined(__x86_64__)
OBJC_EXPORT long double objc_msgSend_fpret(id self, SEL op, ...);
#endif
```
Standard IEEE 754 single-precision (`f32`) and double-precision (`f64`) floats are returned in SSE register `XMM0` and **must use standard `objc_msgSend`**. Calling `objc_msgSend_fpret` for `f32` or `f64` reads uninitialized x87 stack register `ST(0)`, producing garbage values.

### 2.3 x86_64 `fp2ret` is for Complex `long double`
On x86_64 Darwin, `objc_msgSend_fp2ret` returns `_Complex long double` (returned across `ST(0)` and `ST(1)`). Complex single and double precision floats (`_Complex float`, `_Complex double`) are returned in `XMM0`/`XMM1` and use standard `objc_msgSend`.

### 2.4 x86_64 Aggregate Classification is Structural, Not Just Size-Based
On x86_64, a structure under 16 bytes is **not** automatically returned in registers:
- An aggregate with unaligned fields is returned in memory (`.stret`).
- An aggregate containing `long double` alongside other scalar fields is returned in memory (`.stret`).
- Structures with identical size but different field types occupy different register classes (`INTEGER` in `%rax`/`%rdx` vs `SSE` in `%xmm0`/`%xmm1`).

---

## 3. Architecture Specifications

### 3.1 macOS ARM64 (`src/abi/aarch64.zig`)

Under Darwin AAPCS64:
- All valid Objective-C method return types use the `.normal` convention (`objc_msgSend`).
- Low-level ABI classification distinguishes between:
  - **Direct**: Fundamental scalars, pointers, and Homogeneous Floating-point Aggregates (HFA) up to 4 elements (returned in `V0-V3`), plus general aggregates up to 16 bytes (returned in `X0-X1`).
  - **Indirect**: Aggregates exceeding 16 bytes that are not HFAs (caller allocates memory, passes pointer in `X8`).

### 3.2 macOS x86_64 (`src/abi/x86_64/`)

Under System V AMD64 ABI Section 3.2.3:
1. **Scalar Rules**:
   - `void`, integer, pointer, `objc.Object` $\to$ `.normal` (RAX)
   - `f32`, `f64` $\to$ `.normal` (XMM0)
   - `c_longdouble` $\to$ `.fpret` (ST0)
   - `ComplexLongDouble` $\to$ `.fp2ret` (ST0, ST1)
2. **Aggregate Decomposition**:
   - Structures, arrays, and unions are recursively flattened into eightbyte slices.
   - Each field within an eightbyte is classified into: `NO_CLASS`, `INTEGER`, `SSE`, `SSEUP`, `X87`, `X87UP`, `COMPLEX_X87`, `MEMORY`.
3. **Merge Rules** (Section 3.2.3):
   - Both equal $\to$ resulting class.
   - One `NO_CLASS` $\to$ the other class.
   - One `MEMORY` $\to$ `MEMORY`.
   - One `X87`, `X87UP`, or `COMPLEX_X87` $\to$ `MEMORY`.
   - One `INTEGER` $\to$ `INTEGER`.
   - Otherwise $\to$ `SSE`.
4. **Post-Classification Cleanup**:
   - If any eightbyte is `MEMORY`, the entire structure is returned via `stret`.
   - If `X87` appears anywhere other than a pure long double (`[.x87, .x87up]` or `[.x87, .no_class]`), the aggregate is returned via `stret`.
   - If `SSEUP` is not preceded by `SSE`, it is converted to `SSE`.
   - If total size $> 16$ bytes, the structure is returned via `stret`.

---

## 4. Public API Reference (`src/abi/root.zig`)

### 4.1 Target Types
```zig
pub const Target = struct {
    arch: std.Target.Cpu.Arch,
    os: std.Target.Os.Tag,
    abi: std.Target.Abi,

    pub const macos_arm64: Target;
    pub const macos_x86_64: Target;

    pub fn native() Target;
    pub fn isSupported(self: Target) bool;
    pub fn assertSupported(self: Target) void;
};
```

### 4.2 Convention & Result Types
```zig
pub const ReturnConvention = enum {
    normal, // objc_msgSend
    stret,  // objc_msgSend_stret
    fpret,  // objc_msgSend_fpret
    fp2ret, // objc_msgSend_fp2ret

    pub fn messengerName(self: ReturnConvention) []const u8;
    pub fn superMessengerName(self: ReturnConvention) []const u8;
};

pub const ABIResult = enum {
    direct,      // Returned in registers (X0-X1, RAX/RDX, XMM0-X1, etc.)
    indirect,    // Returned via hidden buffer pointer (X8 / RDI)
    x87,         // Returned on x87 FPU stack (ST0)
    complex_x87, // Returned on x87 FPU stack (ST0, ST1)
};
```

### 4.3 Classification Functions
```zig
/// Query convention for the native host compiler target:
pub fn returnConvention(comptime T: type) ReturnConvention;

/// Query convention for an explicit target (enabling cross-target classification):
pub fn returnConventionFor(comptime target: Target, comptime T: type) ReturnConvention;

/// Query low-level register classification:
pub fn classifyReturn(comptime target: Target, comptime T: type) ABIResult;
```

---

## 5. Differential Clang Verification

All rules are verified against Apple Clang assembly generation using the automated verification suite `tools/verify-abi-clang.py` and differential test matrix `tests/abi/differential_test.zig`:

| Type | Size | macOS arm64 Clang | macOS x86_64 Clang | zobjc arm64 | zobjc x86_64 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `void` | 0 | `objc_msgSend` | `objc_msgSend` | `.normal` | `.normal` |
| `int` | 4 | `objc_msgSend` | `objc_msgSend` | `.normal` | `.normal` |
| `float` | 4 | `objc_msgSend` | `objc_msgSend` | `.normal` | `.normal` |
| `double` | 8 | `objc_msgSend` | `objc_msgSend` | `.normal` | `.normal` |
| `long double` | 8/16 | `objc_msgSend` | `objc_msgSend_fpret` | `.normal` | `.fpret` |
| `_Complex long double` | 16/32 | `objc_msgSend` | `objc_msgSend_fp2ret`| `.normal` | `.fp2ret` |
| `id` / `Object` | 8 | `objc_msgSend` | `objc_msgSend` | `.normal` | `.normal` |
| `CGPoint` | 16 | `objc_msgSend` | `objc_msgSend` | `.normal` | `.normal` |
| `CGRect` | 32 | `objc_msgSend` | `objc_msgSend_stret` | `.normal` | `.stret` |
| `{int, double}` | 16 | `objc_msgSend` | `objc_msgSend` | `.normal` | `.normal` |
| `{int, long double}` | 16/32 | `objc_msgSend` | `objc_msgSend_stret` | `.normal` | `.stret` |
