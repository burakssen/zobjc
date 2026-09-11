# Dynamic Class Construction (`ClassBuilder`)

`ClassBuilder` provides a stateful, type-safe builder for dynamically defining, configuring, and registering Objective-C classes at runtime.

It coordinates low-level `libobjc` class allocation (`objc_allocateClassPair`), ivar layout, method registration, protocol adoption, and property declarations with compile-time type encodings and safety guarantees.

```text
ClassBuilder.init(name, superclass)
       ↓
[.allocated]
  ├── addIvar(T, name)
  ├── addMethod(selector, callback)
  ├── addClassMethod(selector, callback)
  ├── addProtocol(protocol)
  └── addProperty(T, name, options)
       ↓
builder.register() → objc.Class  [.registered]
       or
builder.abort()                  [.aborted]
```

---

## Lifecycle & State Machine

Every `ClassBuilder` instance tracks its lifecycle explicitly via `objc.builder.State`:

| State | Description | Permitted Operations |
|---|---|---|
| `.allocated` | Initial state after `ClassBuilder.init()`. The class pair is allocated in the runtime but not registered. | `addIvar`, `addMethod`, `addClassMethod`, `addProtocol`, `addProperty`, `register`, `abort` |
| `.registered` | Class pair has been registered with `objc_registerClassPair`. Internal handle is consumed. | None (builder is consumed; use returned `objc.Class`) |
| `.aborted` | Class pair was disposed via `objc_disposeClassPair` prior to registration. | None |

Any mutating call outside `.allocated` fails with `error.InvalidState`.

---

## Safe Rollbacks with `errdefer builder.abort()`

Objective-C class allocation allocates memory in the runtime. If an error occurs during configuration before registration, the class pair must be disposed. `ClassBuilder.abort()` handles this cleanly:

```zig
var builder = try objc.ClassBuilder.init("MyCustomClass", objc.requireClass("NSObject"));
errdefer builder.abort();

try builder.addIvar(c_int, "_count");
try builder.addMethod("count", getCount);

const MyClass = builder.register();
```

If `builder.abort()` is called:
1. `objc_disposeClassPair` destroys the allocated class and metaclass.
2. The internal handle is cleared to `null`.
3. The state transitions to `.aborted`.
4. Subsequent calls to `abort()` are safe no-ops.

---

## Instance Variables (`addIvar`)

The `addIvar` method automatically handles type validation, physical ABI sizing, `log2` alignment, and metadata encodings:

```zig
try builder.addIvar(c_int, "_count");
try builder.addIvar(?objc.Object, "_delegate");
```

### Log2 Alignment

The Objective-C runtime function `class_addIvar` takes the **base-2 logarithm** of byte alignment (`std.math.log2_int(usize, @alignOf(Storage))`). `ClassBuilder` calculates this automatically:
- 8-byte pointer alignment (`@alignOf(Storage) == 8`) → `alignment_log2 = 3`
- 4-byte integer alignment (`@alignOf(Storage) == 4`) → `alignment_log2 = 2`
- 1-byte char/bool alignment (`@alignOf(Storage) == 1`) → `alignment_log2 = 0`

### StorageType Mapping

High-level runtime handles are mapped to their physical C-ABI storage types:
- `Object` / `?Object` → `raw.id`
- `Class` / `?Class` → `raw.Class`
- `Selector` / `?Selector` → `raw.SEL`
- `enum` → backing integer tag type

### Raw Escape Hatch (`addIvarEncoded`)

For custom or opaque structures, an escape hatch allows specifying explicit byte size, log2 alignment, and Objective-C encoding strings:

```zig
try builder.addIvarEncoded("_customPayload", 32, 3, "[32c]");
```

---

## Methods (`addMethod` & `addClassMethod`)

`ClassBuilder` supports two callback styles with automatic validation:

### 1. Direct C-ABI Callbacks

```zig
fn getAnswer(self: objc.raw.id, cmd: objc.raw.SEL) callconv(.c) c_int {
    _ = self; _ = cmd;
    return 42;
}

try builder.addMethod("answer", getAnswer);
```

### 2. Ergonomic Zig Callbacks (Automatic Trampolining)

Functions taking typed runtime handles (`objc.Object`, `objc.Class`, `objc.Selector`) are automatically wrapped in a compile-time static `MethodTrampoline`:

```zig
fn addValues(self: objc.Object, cmd: objc.Selector, a: c_int, b: c_int) c_int {
    _ = self; _ = cmd;
    return a + b;
}

try builder.addMethod("add:and:", addValues);
```

The trampoline handles:
- Converting `raw.id` → `objc.Object`
- Converting `raw.SEL` → `objc.Selector`
- Calling convention marshaling
- Converting typed return values back to raw ABI representations

### Selector Arity Validation

Colons in the selector name are verified against the callback parameter count at compile-time/runtime:
- `setCount:` (1 colon) requires exactly 1 explicit argument (`self`, `cmd`, `value`).
- Mismatches return `error.SelectorArityMismatch`.

### Class Methods (`addClassMethod`)

Class methods are automatically attached to the metaclass of the dynamic class:

```zig
fn classIdentity(cls: objc.Class, cmd: objc.Selector) c_int {
    _ = cls; _ = cmd;
    return 100;
}

try builder.addClassMethod("identity", classIdentity);
```

---

## Protocol Adoption (`addProtocol`)

Attach adopted protocols to the class pair:

```zig
const NSCopying = objc.getProtocol("NSCopying").?;
try builder.addProtocol(NSCopying);
```

After registration, the class responds to `cls.conformsTo(NSCopying)`.

---

## Declared Properties (`addProperty`)

Declare runtime property metadata using typed `PropertyOptions`:

```zig
try builder.addProperty(?objc.Object, "delegate", .{
    .weak = true,
    .nonatomic = true,
    .ivar = "_delegate",
});
```

> [!IMPORTANT]
> **Properties are Metadata Only**: Calling `addProperty` emits runtime property attribute records (`T@,W,N,V_delegate`). It does **not** automatically synthesize getter, setter, or ivar implementations.
