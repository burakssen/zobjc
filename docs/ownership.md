# Ownership

- `Object`: non-owning, non-null handle (`+0` view). Copying the handle is
  cheap and safe; it confers no ownership.
- `?Object`: nullable non-owning handle. Message sends to `null` follow
  Objective-C nil-messaging semantics.
- `Retained(T)`: owns exactly one `+1` reference.
  - `retain(borrowed)` : `+0` → `+1` (increments).
  - `adopt(owned)` : takes over an existing `+1` (no increment).
  - `borrow()` : `+0` view, valid only while the owner lives.
  - `clone()` : second independent `+1`.
  - `deinit()` : releases the `+1`; idempotent for moved-from state.
  - `intoUnmanaged()` : transfers the `+1` out without releasing.
- `Weak(T)`: zeroing weak slot. Objective-C weak slots are
  address-sensitive: initialize in place, use `copyFrom`/`moveFrom`, never
  rely on plain Zig assignment to relocate a live slot.
- `AutoreleasePool` / `OwnedBlock`: same move-only discipline as `Retained`.

## Move-only discipline (Zig cannot enforce it)

Zig has no move-only structs. This compiles but is wrong:

```zig
var a = Retained(Object).adopt(obj);
var b = a; // two Zig values, one +1 obligation — do not do this
a.deinit();
b.deinit(); // double release
```

Rules:

- Never copy an owner by value. Pass owners by pointer (`*Retained(T)`),
  return them by value only as a transfer, and use `clone()` for a second
  owner.
- `deinit()` is idempotent only for the moved-from/initialized-empty state
  (`intoUnmanaged` / double `deinit` on the same value). It cannot save a
  bitwise copy.
- Prefer `defer owner.deinit()` immediately after acquiring ownership so the
  `+1` is tied to a scope.
