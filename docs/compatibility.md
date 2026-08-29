# Backward Compatibility Contract & Migration Policy

`zobjc` is committed to preserving source-level backward compatibility with `zig-objc` throughout its architectural evolution.

---

## 1. Guaranteed Stable During Migration

The following core APIs are guaranteed to remain source-compatible throughout all phases:

| API | Type / Signature | Usage |
| :--- | :--- | :--- |
| `objc.getClass` | `fn([:0]const u8) ?Class` | Class lookup |
| `objc.getMetaClass` | `fn([:0]const u8) ?Class` | Metaclass lookup |
| `Object.msgSend` | `fn(target, comptime Return, sel, args) Return` | Instance message dispatch |
| `Class.msgSend` | `fn(target, comptime Return, sel, args) Return` | Class method message dispatch |
| `Object.msgSendSuper` | `fn(target, superclass, comptime Return, sel, args) Return` | Superclass message dispatch |
| `objc.Block` | `fn(Captures, Args, Return) type` | Block creation and invocation |
| `objc.AutoreleasePool` | `opaque { init(), deinit() }` | Autorelease pool management |
| `objc.sel` | `fn([:0]const u8) Selector` | Selector registration shorthand |
| `objc.Property` | `extern struct { ... }` | Property introspection |
| `objc.Protocol` | `extern struct { ... }` | Protocol introspection |
| `objc.allocateClassPair` | `fn(?Class, [:0]const u8) ?Class` | Dynamic class creation |
| `objc.registerClassPair` | `fn(Class) void` | Class registration |
| `objc.disposeClassPair` | `fn(Class) void` | Class destruction |

---

## 2. Transitional Aliases

These symbols have received canonical replacements, but the legacy names remain fully functional aliases:

- `objc.Sel`: Aliased to `objc.Selector`. New code should use `objc.Selector`.
- `objc.c`: Bridged to `objc.raw.c`. New code should access underlying declarations via `objc.raw`.

---

## 3. Planned Deprecations (Post-Redesign)

The following APIs are planned for deprecation only after safe, idiomatic alternatives have been fully established:

1. **`objc.free(ptr)`**:
   - *Target Replacement*: Owned slice types (`OwnedSlice(T)` / `OwnedCString`) introduced in Phase 3.
2. **Direct manual retain/release (`obj.retain()`, `obj.release()`)**:
   - *Target Replacement*: Type-safe `Retained(T)` and `Weak(T)` wrappers in Phase 3.
3. **`Object.msgSend` / `Class.msgSend`**:
   - *Target Replacement*: Unified `objc.send(Return, target, sel, args)` in Phase 6. (The method syntax will remain supported as convenience facades).
4. **Manual type encoding formatters**:
   - *Target Replacement*: Full type encoding parser and generator in Phase 4.
