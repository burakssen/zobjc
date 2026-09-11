# Dynamic Protocol Construction (`ProtocolBuilder`)

`ProtocolBuilder` provides a fluent interface for dynamically declaring and registering Objective-C protocols at runtime using Apple's `libobjc` protocol construction APIs (`objc_allocateProtocol`, `protocol_addMethodDescription`, `protocol_addProtocol`, `protocol_addProperty`, `objc_registerProtocol`).

```text
ProtocolBuilder.init(name)
       ↓
[.allocated]
  ├── addMethod(selector, Signature, options)
  ├── inherit(parent_protocol)
  └── addProperty(T, name, prop_options, proto_options)
       ↓
builder.register() → objc.Protocol  [.registered]
       or
builder.abort()                     [.aborted]
```

---

## Lifecycle & State Machine

Every `ProtocolBuilder` instance tracks its lifecycle explicitly via `objc.builder.State`:

| State | Description | Permitted Operations |
|---|---|---|
| `.allocated` | Initial state after `ProtocolBuilder.init()`. The protocol record is allocated in the runtime. | `addMethod`, `inherit`, `addProperty`, `register`, `abort` |
| `.registered` | Protocol has been registered via `objc_registerProtocol`. Internal handle is consumed. | None (builder is consumed; use returned `objc.Protocol`) |
| `.aborted` | Protocol construction was aborted. Internal handle is cleared. | None |

> [!IMPORTANT]
> **No Runtime Protocol Disposal**: Apple's `libobjc` does not provide an `objc_disposeProtocol` entry point. Calling `abort()` transitions the builder to `.aborted` and drops internal handles, but the unregistered protocol record cannot be explicitly freed prior to process termination.

---

## Method Declarations (`addMethod`)

Protocols declare method signatures rather than implementations. `addMethod` accepts function types or function signatures directly:

```zig
var builder = try objc.ProtocolBuilder.init("MyWorkerProtocol");
errdefer builder.abort();

// Required instance method
try builder.addMethod(
    "performTask:",
    fn (objc.Object, objc.Selector, c_int) c_int,
    .{ .required = true, .instance = true },
);

// Optional class method
try builder.addMethod(
    "defaultWorker",
    fn (objc.Class, objc.Selector) ?objc.Object,
    .{ .required = false, .instance = false },
);
```

### Options

- `required`: When `true`, marks the method as a required protocol method. When `false`, marks it as optional (`@optional` in Objective-C).
- `instance`: When `true`, declares an instance method (`-`). When `false`, declares a class method (`+`).

### Automatic Type Encoding & Arity Checking

Method encodings are generated automatically using Phase 4's `objc.encoding.methodEncoding()`. Selector colons are verified against argument count, returning `error.SelectorArityMismatch` if mismatched.

---

## Protocol Inheritance (`inherit`)

Adopt existing or dynamic protocols:

```zig
if (objc.getProtocol("NSCopying")) |nscopying| {
    try builder.inherit(nscopying);
}
```

---

## Declared Properties (`addProperty`)

Declare protocol properties with typed attributes:

```zig
try builder.addProperty(
    ?objc.Object,
    "delegate",
    .{ .weak = true, .nonatomic = true },
    .{ .required = true, .instance = true },
);
```

---

## Registration (`register`)

Registers the protocol with the runtime system and returns the non-owning `objc.Protocol` handle:

```zig
const MyProtocol = builder.register();
```

Classes constructed via `ClassBuilder` can adopt this protocol via `class_builder.addProtocol(MyProtocol)`.
