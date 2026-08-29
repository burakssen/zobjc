# Development Guide

## 1. Compiler Baseline

`zobjc` targets **Zig 0.16.0** as its official development and build baseline.
Nightly compiler builds are explicitly unsupported during the architecture migration.

To check your Zig version:
```bash
zig version
# Expected: 0.16.0
```

---

## 2. Prerequisites

Building `zobjc` requires:
- macOS (Apple Silicon or Intel x86_64)
- Xcode Command Line Tools installed (providing Apple SDK headers and `libobjc`)
- Zig `0.16.0`

---

## 3. Build & Test Commands

### Run Master Test Suite:
```bash
zig build test --summary all
```

### Run Runtime Tests:
```bash
zig build test-runtime --summary all
```

### Run Integration Tests:
```bash
zig build test-integration --summary all
```

### Run All Tests:
```bash
zig build test-all --summary all
```

### Compile Examples:
```bash
zig build examples
```

### Code Formatting:
```bash
zig fmt --check .
```
