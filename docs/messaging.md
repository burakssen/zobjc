# Objective-C Messaging and Invocation Subsystem

The `messaging` subsystem (`src/messaging/`) provides the single authoritative implementation of Objective-C message dispatch and function invocation for `zobjc`.

All high-level dispatch paths (`objc.send`, `objc.sendSuper`, `Object.send`, `Class.send`, `Method.invoke`, `objc.callImp`) route through this pipeline.

---

## 1. Architecture and Pipeline Flow

Every message dispatch follows a strict six-stage pipeline:

```text
1. Normalization
   (Object, Class, Selector, args -> raw.id, raw.Class, raw.SEL, AbiArgs)
         ↓
2. Comptime Validation
   (Tuple verification, reject comptime_int/float, reject slices, colon count check)
         ↓
3. ABI Classification (Phase 5)
   (AbiReturnType -> ReturnConvention: normal, stret, fpret, fp2ret)
         ↓
4. Function Signature Construction (@Fn)
   (Pure compile-time non-variadic exact C function type synthesis)
         ↓
5. Dispatch Pointer Selection & Cast (@ptrCast)
   (objc_msgSend*, objc_msgSendSuper2*, method_invoke* via isolated call boundary)
         ↓
6. Invocation & Return Conversion
   (@call(.auto, ...) -> fromAbi(Return, raw_val))
```

---

## 2. Public API

### `objc.send(Return, receiver, selector, args)`
Sends an Objective-C instance or class message.

```zig
// Class message
const NSNumber = objc.getClass("NSNumber").?;
const num = objc.send(objc.Object, NSNumber, "numberWithInt:", .{@as(c_int, 42)});

// Instance message
const val = objc.send(c_int, num, "intValue", .{});

// Aggregate return
const NSRange = extern struct { location: c_ulong, length: c_ulong };
const sub = objc.send(objc.Object, str, "substringWithRange:", .{NSRange{ .location = 0, .length = 5 }});
```

### `objc.sendSuper(Return, receiver, current_class, selector, args)`
Sends a message to the superclass using modern Apple **Super2 semantics**:
- `current_class` specifies the class containing the executing method.
- Runtime method lookup begins at `current_class->superclass`.

```zig
fn childSuperIdentify(self: raw.id, _cmd: raw.SEL) callconv(.c) [*:0]const u8 {
    _ = _cmd;
    const obj = objc.Object.fromRawNonNull(self.?);
    return objc.sendSuper([*:0]const u8, obj, g_child_class, "identify", .{});
}
```

### `Method.invoke(Return, receiver, args)` & `objc.callImp(Return, imp, receiver, selector, args)`
Direct invocation of a resolved method implementation, bypassing dynamic runtime dispatch tables while respecting ABI calling conventions and return classifications.

```zig
const method = NSNumber.classMethod(objc.sel("numberWithInt:")).?;
const imp = method.implementation();
const num = objc.callImp(objc.Object, imp, NSNumber, "numberWithInt:", .{@as(c_int, 999)});
```

### `objc.sendChecked(Return, receiver, selector, args)`
Safely checks `respondsToSelector` before sending. Returns `null` if the receiver does not respond to the selector or is `null`.

```zig
const length = objc.sendChecked(usize, obj, "length", .{});
if (length) |len| {
    std.debug.print("Length: {d}\n", .{len});
}
```

---

## 3. Type Normalization Rules

To maintain a strict boundary between user-facing abstractions and the C ABI:

| Zig User Type | Normalized C ABI Type | Conversion Semantics |
| :--- | :--- | :--- |
| `Object`, `?Object` | `raw.id` (`?*objc_object`) | Direct pointer unwrap; `null` if empty |
| `Class`, `?Class` | `raw.Class` (`?*objc_class`) | Direct pointer unwrap; `null` if empty |
| `Selector`, `?Selector` | `raw.SEL` (`?*objc_selector`) | Direct pointer unwrap |
| `Imp`, `?Imp` | `raw.IMP` | Direct function pointer unwrap |
| `"init"` (`*const [N:0]u8`) | `raw.SEL` (selector arg) / `[*:0]const u8` (data arg) | Comptime/runtime `sel_registerName` or pointer cast |
| `enum(T)` | Underlying tag type `T` | `@intFromEnum(val)` |
| `extern struct` | Unchanged | Passed by value per platform C ABI |

---

## 4. Compile-Time Safety and Diagnostics

The messaging subsystem enforces safety at compile time before emitting any code:

1. **Tuple Verification**: Arguments must always be supplied as a tuple (`.{ a, b }`). Non-tuples trigger an explicit compile error.
2. **Ambiguous Literals Rejected**: Un-annotated `comptime_int` or `comptime_float` trigger clear errors directing the user to explicitly specify types (e.g. `@as(c_int, 42)`).
3. **Untyped `null` Rejected**: Passing `null` without type annotation triggers an error requiring `@as(?objc.Object, null)`.
4. **Non-Sentinel Slices Rejected**: Passing `[]const u8` as a selector or string argument triggers an error directing the user to use string literals or `[:0]const u8`.
5. **Zig-Layout Structs Rejected**: Plain Zig structs without `extern` layout cannot cross the C ABI boundary.
6. **Colon Count Verification**: String literal selectors are checked against the supplied argument count at compile time (e.g. `"foo:bar:"` requires exactly 2 arguments).
7. **Direct `Retained(T)` Returns Rejected**: Methods returning retained ownership must receive as `Object` and explicitly adopt or retain ownership (`Retained(Object).adopt(...)`), avoiding silent leaks.

---

## 5. Nil-Receiver Semantics

In accordance with Objective-C specifications:
- Sending a message to `null` or a nil `?Object` returns zero for scalars, `null` for pointers and optional objects, or an empty extern struct, without crashing.
- Non-null `Object` return types panic with an informative message if a nil receiver or nil return is encountered.
