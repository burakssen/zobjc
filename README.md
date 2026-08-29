# zobjc - Objective-C Runtime Bindings for Zig

`zobjc` provides high-performance Zig bindings and architectural abstractions for the Apple [Objective-C runtime](https://developer.apple.com/documentation/objectivec/objective-c_runtime?language=objc).

The library is currently undergoing an architectural expansion toward complete public runtime coverage while strictly preserving existing API compatibility.

---

## Compiler Baseline

- **Supported Zig Version**: `0.16.0` (released version)
- **Supported Targets**: Apple Darwin platforms (macOS, iOS, tvOS, watchOS on `aarch64` and `x86_64`)

---

## Features

- **Classes & Metaclasses**: Class lookup, metaclass inspection, dynamic subclass creation, method overriding, and ivar injection.
- **Objects**: Instance creation, property get/set, instance variable access, and message dispatch.
- **Message Dispatch**: Automatic argument unwrapping and return type wrapping via `msgSend` and `msgSendSuper`.
- **Blocks**: Type-safe Objective-C Block definition, closure capture, invocation, and automatic reference counting for captured objects.
- **Protocols & Properties**: Introspection of adopted protocols and declared properties.
- **Autorelease Pools**: Scoped memory management via `objc.AutoreleasePool`.
- **Fast Enumeration**: Iteration over Objective-C collections (`NSArray`, `NSDictionary`) conforming to `NSFastEnumeration`.

---

## Quick Example

Using `NSProcessInfo` to determine if the host system meets a minimum version:

```zig
const std = @import("std");
const objc = @import("objc");

pub fn macosVersionAtLeast(major: i64, minor: i64, patch: i64) bool {
    const NSProcessInfo = objc.getClass("NSProcessInfo") orelse return false;
    const info = NSProcessInfo.msgSend(objc.Object, "processInfo", .{});

    const NSOperatingSystemVersion = extern struct {
        major: i64,
        minor: i64,
        patch: i64,
    };

    return info.msgSend(bool, "isOperatingSystemAtLeastVersion:", .{
        NSOperatingSystemVersion{ .major = major, .minor = minor, .patch = patch },
    });
}
```

---

## Adding to Your Project

In your `build.zig.zon`:

```zig
.{
    .name = .my_project,
    .version = "0.1.0",
    .dependencies = .{
        .zobjc = .{
            .url = "...", // or path
        },
    },
}
```

In your `build.zig`:

```zig
const zobjc_dep = b.dependency("zobjc", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("objc", zobjc_dep.module("objc"));
```

---

## Development & Testing

```bash
# Run the complete test suite
zig build test --summary all

# Run runtime tests
zig build test-runtime

# Compile all examples
zig build examples

# Check formatting
zig fmt --check .
```

For detailed architecture and roadmap information, see:
- [Architecture & Module Boundaries](docs/architecture.md)
- [Compatibility Contract](docs/compatibility.md)
- [Technical Roadmap (Phases 0–11)](docs/roadmap.md)
- [Known Limitations](docs/known-limitations.md)
