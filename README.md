# zobjc

Type-safe Zig bindings for Apple's Objective-C runtime. zobjc provides raw
`libobjc` declarations plus higher-level wrappers for objects, classes,
messaging, memory management, Blocks, ABI classification, and type encoding.

## Requirements

- macOS
- Zig 0.16.0 or newer
- Apple's Objective-C runtime (`libobjc`)

## Build

From the repository root:

```bash
zig build
zig build test
```

Run an example:

```bash
zig build run-basic_object
```

Other examples are available through the `run-*` build steps, including:

- `run-subclass`
- `run-block`
- `run-autorelease_pool`
- `run-runtime_introspection`
- `run-ownership_and_memory`
- `run-type_encodings`
- `run-abi_classification`
- `run-messaging`

## Usage

```zig
const std = @import("std");
const objc = @import("zobjc");

pub fn main() void {
    const NSObject = objc.requireClass("NSObject");
    const object = NSObject.send(objc.Object, "new", .{});
    defer object.send(void, "release", .{});

    std.debug.print("class: {s}\n", .{object.className()});
}
```

## Project Layout

- `src/raw/`: direct Objective-C runtime ABI declarations
- `src/runtime/`: typed runtime handles and reflection helpers
- `src/messaging/`: compile-time-checked message dispatch
- `src/memory/`: ownership and lifetime wrappers
- `src/block/`: Objective-C Blocks support
- `src/encoding/`: Objective-C type encoding and parsing
- `src/abi/`: target-specific calling-convention classification
- `examples/`: runnable usage examples

See `docs/` for architecture, API, ABI, ownership, and verification details.

## License

See [LICENSE](LICENSE).
