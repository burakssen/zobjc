# zobjc architecture

Intended module dependency DAG (no arrows point upward):

```text
                         zobjc (facade)
                           │
            ┌──────────────┼──────────────┐
            ▼              ▼              ▼
          block          runtime        memory
            │              │              │
            └──────┬───────┴──────┬───────┘
                   ▼              ▼
               messaging       traits (internal/wrapper)
                   │
            ┌──────┴──────┐
            ▼             ▼
           abi         encoding
            │             │
            └──────┬──────┘
                   ▼
                  raw
                   ▼
                 libobjc
```

Rules:

- `raw` mirrors libobjc and must not import `zobjc` or any higher layer.
- `internal` holds shared traits (`wrapper`) above `raw` only.
- `encoding` sits above `raw` + `internal` only: it knows wrapper
  abstractions (object/class/selector/imp kinds), never `runtime` types by
  name. `abi` sits above `raw` only.
- `messaging` sits above `abi` + `encoding` + `raw` and shared traits.
- `runtime`, `memory`, and `block` sit above `messaging` and traits.
- The `zobjc` facade (`src/root.zig`) knows every subsystem; no subsystem
  may import the facade. `build.zig:wireModules()` must not add upward edges
  (no `subsystem.addImport("zobjc", ...)`).

Status: the codebase is migrating toward this graph. New code must follow it;
`raw` is already a leaf (relative imports only, no `zobjc` edge in
`wireModules()`), and `encoding`/`internal` no longer import `runtime` or
the facade (`wireModules()` lists only an explicit `legacy_facade_dependents`
set: abi, block, memory, messaging, runtime). Remaining back-edges are
removed incrementally, next `abi`.

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
