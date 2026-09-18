# zobjc architecture

Intended module dependency DAG (no arrows point upward):

```text
                      zobjc (facade)
                        │
          ┌─────────────┼─────────────┐
          ▼             ▼             ▼
        block         runtime        memory
          │             │             │
          └───────┬─────┴─────┬───────┘
                  ▼           ▼
              messaging    internal
               /     \         ▲
              ▼       ▼        │
             abi   encoding ───┘
              │       │
              │       ▼
              │      raw
              │       │
              │    libobjc
              │
       compile-time leaf
```

Rules:

- `raw` mirrors libobjc and must not import `zobjc` or any higher layer.
- `internal` holds shared traits and low-level value types used by multiple
  higher layers (`wrapper`, `Selector`, `MethodDescription`,
  `PropertyAttribute`); it depends only on `raw`.
- `encoding` sits above `raw` + `internal` only: it knows wrapper
  abstractions (object/class/selector/imp kinds), never `runtime` types by
  name.
- `abi` is a compile-time leaf with no module imports: classification is by
  machine representation (`@typeInfo` shape/size/layout) only.
- `messaging` sits above `abi` + `encoding` + `raw` + `internal` only: all
  handle normalization goes through wrapper kinds, never `runtime` types by
  name; live dispatch tests live at the facade.
- `runtime`, `memory`, and `block` sit above `messaging` and traits.
- The `zobjc` facade (`src/root.zig`) knows every subsystem; no subsystem
  may import the facade. `build.zig:wireModules()` must not add upward edges
  (no `subsystem.addImport("zobjc", ...)`).

Status: the graph below is the enforced design, not a migration target.
The facade imports subsystems. No subsystem imports the facade.
Dependencies between subsystems point only downward.

Module status: `raw`, `internal`, `encoding`, `abi`, `messaging`, `memory`,
`runtime`, and `block` all match the DAG. Shared value types (`Selector`,
`MethodDescription`, `PropertyAttribute`) live in `internal`, re-exported
by `runtime` with unchanged identity. `block` imports `abi`, `encoding`,
`memory`, `messaging`, `raw`, and `runtime` (all downward); no upward
facade edges remain anywhere.

## API layers

- `src/raw/`: exact C declarations for libobjc. No policy, no wrappers.
- `src/encoding/`: `@encode` strings, parsing (`encoding.parseMethod`), and
  comptime generation (`comptimeEncode`, `methodEncoding`).
- `src/abi/`: return-convention classification (`objc_msgSend` vs `stret` /
  `fpret`) per Apple target. `fp2ret` exists in `raw` for ABI completeness but
  is never auto-selected: Zig cannot spell C `_Complex long double`, and an
  ordinary 2x-long-double struct is an aggregate (stret when >16 bytes).
- `src/messaging/`: typed dispatch (`send`, `sendSuper`, `invoke`, `callImp`,
  `sendChecked`). `send` is zero-overhead; `sendChecked` additionally validates
  the runtime method signature in safety builds.
- `src/runtime/`: non-owning handles (`Object`, `Class`, `Selector`, ...).
  `Object` is non-owning, non-null; nullability is `?Object`.
- `src/memory/`: ownership (`Retained(T)` for +1, `Weak(T)` for zeroing weak
  slots, `AutoreleasePool`). See `docs/ownership.md`.
- `src/block/`: Apple Blocks construction, copy/dispose, invocation, IMP
  bridging. arm64e (pointer authentication) fails closed at comptime.

## ABI verification

Differential tests compare Zig behavior against Clang Objective-C fixtures in
`fixtures/` (`encoding.m`, `abi.m`, `block.m`):

- `encoding`: `raw.BOOL`, scalars, aggregates vs `@encode`.
- `messaging`/`abi`: aggregate returns across sizes, register pressure,
  floating-point returns, large structs.
- `block`: Clang ↔ Zig interop rather than self-tests only.

CI runs the full matrix natively on macOS arm64 and macOS x86_64 because the
x86-64 messenger selection (`stret`/`fpret`, plus `fp2ret` non-selection)
cannot be validated by cross-compiled classifier logic alone.

## Type-safety boundary

`send` is type-safe relative to the caller-supplied Zig signature. Only
`sendChecked` (safety builds) cross-checks that signature against
`method_getTypeEncoding()` at runtime. See `docs/verification.md`.
