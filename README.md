# zobjc — Objective-C Runtime for Zig

[![Zig 0.16.0](https://img.shields.io/badge/Zig-0.16.0-orange.svg)](https://ziglang.org)
[![Platform Darwin](https://img.shields.io/badge/Platform-macOS%20%7C%20iOS%20%7C%20watchOS%20%7C%20tvOS%20%7C%20visionOS-lightgrey.svg)](docs/verification.md)
[![License MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![SemVer 1.0.0](https://img.shields.io/badge/SemVer-1.0.0-brightgreen.svg)](docs/stability.md)

`zobjc` provides production-grade, type-safe Zig bindings and runtime abstractions for Apple's [Objective-C runtime](https://developer.apple.com/documentation/objectivec/objective-c_runtime?language=objc).

The core library links directly to Apple's `libobjc.A.dylib` and `libSystem.B.dylib` with **zero Foundation framework dependency**, providing complete C ABI parity with Clang.

---

## Features

- **Pure libobjc Core**: Zero dependencies on Foundation or Cocoa in the base runtime layer.
- **Deterministic Darwin ABI Dispatch**: Complete calling convention support for Apple Silicon (`aarch64`) and Intel (`x86_64`), including indirect struct returns (`stret`), floating-point returns (`fpret`), and `objc_msgSendSuper2`.
- **Compile-Time Safety**: Rejects invalid ABI types (untyped `comptime_int`, fat slices, non-extern structs) at compile time with actionable diagnostics.
- **Explicit Ownership Model**: Clear separation between non-owning borrowed handles (`Object`, `Class`) and explicit RAII owners (`Retained`, `Weak`, `AutoreleasePool`).
- **Objective-C Blocks**: Support for non-capturing closures, scalar captures, strong/weak object captures, and `ByRef` variable captures outliving stack frames.
- **Dynamic Builders**: Construct new Objective-C classes and protocols at runtime with automatic ivar alignment and method registration.
- **Advanced Facilities**: Type-safe associated objects, atomic and scoped method swizzling, and method replacement.
- **Optional Foundation Module**: Separate `objc_foundation` package for string conversions (`toNSString`/`toSlice`) and `NSFastEnumeration` collection iteration.

---

## Requirements

- **Zig**: `0.16.0`
- **Host / Target**: Apple Darwin platforms (macOS, iOS, tvOS, watchOS, visionOS)

---

## Installation

Add `zobjc` to your `build.zig.zon`:

```zig
.{
    .name = .my_project,
    .version = "1.0.0",
    .dependencies = .{
        .zobjc = .{
            .url = "https://github.com/mitchellh/zig-objc/archive/refs/tags/v1.0.0.tar.gz",
            .hash = "...", // Run `zig fetch` to obtain hash
        },
    },
    .paths = .{ "" },
}
```

In your `build.zig`:

```zig
const zobjc_dep = b.dependency("zobjc", .{
    .target = target,
    .optimize = optimize,
});

// Import core Objective-C runtime (pure libobjc)
exe.root_module.addImport("objc", zobjc_dep.module("objc"));
```

---

## Quick Start

### 1. Pure Core Runtime Inspection
```zig
const std = @import("std");
const objc = @import("objc");

pub fn main() void {
    const NSObject = objc.requireClass("NSObject");
    std.debug.print("Class: {s}\n", .{NSObject.name()});
    std.debug.print("Instance size: {d} bytes\n", .{NSObject.instanceSize()});
}
```

### 2. Messaging & Explicit Ownership
```zig
const std = @import("std");
const objc = @import("objc");

pub fn main() !void {
    const NSObject = objc.requireClass("NSObject");

    // Allocate and initialize instance
    const raw_instance = objc.send(objc.Object, NSObject, "new", .{});

    // Adopt +1 retain obligation; deinit() calls objc_release at scope exit
    var instance = objc.Retained(objc.Object).adopt(raw_instance);
    defer instance.deinit();

    // Borrow non-owning handle to send messages
    const cls = instance.borrow().class();
    std.debug.print("Created instance of: {s}\n", .{cls.name()});
}
```

### 3. Objective-C Blocks
```zig
const std = @import("std");
const objc = @import("objc");

pub fn main() !void {
    // Construct a heap-promoted block
    var block = try objc.OwnedBlock(fn (c_int) c_int).fromFunction(struct {
        fn double(x: c_int) c_int {
            return x * 2;
        }
    }.double);
    defer block.deinit();

    const result = block.call(.{@as(c_int, 21)});
    std.debug.print("Result: {d}\n", .{result}); // 42
}
```

### 4. Optional Foundation Integration
To use Foundation convenience APIs, import `objc_foundation` and link `Foundation`:

```zig
// In build.zig:
exe.root_module.addImport("objc_foundation", zobjc_dep.module("objc_foundation"));
exe.linkFramework("Foundation");
```

```zig
const objc = @import("objc");
const foundation = @import("objc_foundation");

pub fn main() !void {
    var pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    // Convert Zig UTF-8 slice into an NSString
    var str = try foundation.string.toNSString("Hello, World!");
    defer str.deinit();

    const len = objc.send(usize, str.borrow(), "length", .{});
    std.debug.print("String length: {d}\n", .{len});
}
```

---

## Documentation Index

- [Getting Started Guide](docs/getting-started.md)
- [Architecture & Layer Boundaries](docs/architecture.md)
- [Messaging & Type Validation](docs/messaging.md)
- [Ownership & Memory Model](docs/ownership.md)
- [Objective-C Blocks](docs/blocks.md)
- [Dynamic Classes & Subclassing](docs/dynamic-classes.md)
- [Dynamic Protocols](docs/dynamic-protocols.md)
- [Associated Objects](docs/associated-objects.md)
- [Method Swizzling & Replacement](docs/swizzling.md)
- [Type Encodings](docs/encoding.md)
- [Darwin ABI Classification](docs/abi.md)
- [Advanced Unsafe Runtime Facilities](docs/advanced-runtime.md)
- [Optional Foundation Layer](docs/foundation.md)
- [Apple Framework Wrapper Conventions](docs/framework-wrappers.md)
- [Verification & Differential Testing](docs/verification.md)
- [API Stability & SemVer Policy](docs/stability.md)
- [1.0 Migration Guide](docs/migration-1.0.md)
- [Public API Manifest](docs/public-api.txt)

---

## Platform Support

| Platform | Tier | Verification Status |
| :--- | :--- | :--- |
| **macOS (Apple Silicon, arm64)** | **Tier 1** | Runtime verified against Apple SDK & Clang |
| **macOS (Intel, x86_64)** | **Tier 2** | ABI differential verified & static library cross-compiled |
| **iOS / iOS Simulator (arm64)** | **Tier 2** | Static library cross-compiled |
| **tvOS / watchOS / visionOS (arm64)** | **Tier 2** | Static library cross-compiled |

---

## License

MIT License. Copyright (c) Mitchell Hashimoto and `zobjc` contributors.
