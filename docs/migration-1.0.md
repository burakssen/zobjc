# Migrating to zobjc 1.0

This guide assists developers migrating from upstream `zig-objc` or pre-1.0 releases to the modern `zobjc 1.0` architecture.

---

## 1. Architectural Summary of Changes

`zobjc 1.0` introduces five fundamental architectural improvements:
1. **Explicit Ownership Model**: Non-owning handles (`Object`, `Class`) never manage memory; `Retained(T)` and `Weak(T)` provide explicit RAII lifetime tracking.
2. **Deterministic Darwin ABI Dispatch**: `objc.send` strictly enforces Apple ABI return conventions (AAPCS64, SysV x86_64, `objc_msgSend_stret`, `objc_msgSend_fpret`).
3. **Strict Compile-Time Safety**: Rejects untyped literals, slices across the C ABI, and non-extern structs at compile time to prevent memory corruption.
4. **Pure libobjc Core**: Core `objc` links solely to `libobjc.A.dylib` with zero Foundation dependencies.
5. **Typed Blocks & Dynamic Builders**: Native closure captures and builder state machines.

---

## 2. Step-by-Step Migration Recipes

### 2.1 Messaging (`msgSend` → `send`)

* **Upstream**:
  ```zig
  const count = array.msgSend(usize, objc.sel("count"), .{});
  ```

* **1.0 Idiomatic**:
  ```zig
  // Preferred canonical function:
  const count = objc.send(usize, array, "count", .{});

  // Or ergonomic handle method:
  const count = array.send(usize, "count", .{});
  ```

> [!TIP]
> `object.msgSend` and `class.msgSend` are retained as compatibility aliases, but are marked deprecated.

---

### 2.2 Super Calls (`msgSendSuper` → `sendSuper`)

* **Upstream**:
  ```zig
  const super_cls = objc.getClass("NSObject").?;
  _ = obj.msgSendSuper(super_cls, void, objc.sel("init"), .{});
  ```

* **1.0 Modern**:
  ```zig
  // sendSuper uses Super2 semantics where `current_class` is the currently executing class:
  _ = objc.sendSuper(void, obj, current_class, "init", .{});
  ```

---

### 2.3 Memory Management (`release()` → `Retained`)

* **Upstream**:
  ```zig
  const obj = NSClass.msgSend(objc.Object, objc.sel("alloc"), .{})
                     .msgSend(objc.Object, objc.sel("init"), .{});
  defer obj.release();
  ```

* **1.0 Modern**:
  ```zig
  var obj = objc.Retained(objc.Object).adopt(
      NSClass.send(objc.Object, "alloc", .{}).send(objc.Object, "init", .{})
  );
  defer obj.deinit();

  // Borrow non-owning handle for calls:
  const name = obj.borrow().className();
  ```

---

### 2.4 Argument Typing (Compile Rejections)

* **Upstream**:
  ```zig
  // Silently coerced to target int, risking stack alignment mismatches:
  obj.msgSend(void, objc.sel("setCount:"), .{ 42 });
  ```

* **1.0 Modern**:
  ```zig
  // Explicit ABI type annotation is mandatory:
  objc.send(void, obj, "setCount:", .{ @as(c_int, 42) });
  ```

---

### 2.5 Slices vs C Strings

* **Upstream**:
  ```zig
  const title: []const u8 = "My Title";
  obj.msgSend(void, objc.sel("setTitle:"), .{ title }); // Pass fat pointer (BUG!)
  ```

* **1.0 Modern**:
  ```zig
  const title: [:0]const u8 = "My Title"; // Sentinel-terminated C string
  objc.send(void, obj, "setTitle:", .{ title });
  ```

---

### 2.6 Creating Blocks

* **Upstream**:
  ```zig
  const MyBlock = objc.Block(struct {}, fn (c_int) c_int, c_int);
  var blk = MyBlock.init(callback, .{});
  ```

* **1.0 Modern**:
  ```zig
  // Without captures:
  var blk = try objc.OwnedBlock(fn (c_int) c_int).fromFunction(callback);
  defer blk.deinit();

  // With captures:
  var blk = try objc.OwnedBlock(fn (c_int) c_int).capture(
      Captures,
      .{ .scale = 2 },
      callbackWithCaptures,
  );
  defer blk.deinit();
  ```

---

### 2.7 Fast Enumeration Iterators

* **Upstream**:
  ```zig
  var it = objc.Iterator.init(ns_array);
  while (it.next()) |item| { ... }
  ```

* **1.0 Modern**:
  Fast enumeration belongs to Foundation. It is located in `objc_foundation`:
  ```zig
  const foundation = @import("objc_foundation");

  var it = foundation.FastEnumerationIterator(16).init(ns_array);
  while (it.next()) |item| { ... }
  ```

---

### 2.8 Runtime Allocation Memory (`objc.free`)

* **Upstream**:
  ```zig
  var count: c_uint = 0;
  const list = cls.copyMethodList(&count);
  defer objc.free(list);
  ```

* **1.0 Modern**:
  ```zig
  // RAII list automatically frees with C free() on deinit:
  var list = cls.methods();
  defer list.deinit();
  for (list.slice()) |method| { ... }
  ```

---

## 3. Compatibility Summary Table

| Legacy Construct | Modern Construct | Status |
| :--- | :--- | :--- |
| `objc.Sel` | `objc.Selector` | Alias retained |
| `object.msgSend(...)` | `objc.send(...)` / `object.send(...)` | Supported (deprecated) |
| `class.msgSend(...)` | `objc.send(...)` / `class.send(...)` | Supported (deprecated) |
| `object.msgSendSuper(...)` | `objc.sendSuper(...)` | Supported (deprecated) |
| `object.release()` | `Retained(Object).adopt(...)` | Supported (deprecated) |
| `object.retain()` | `Retained(Object).retain(...)` | Supported (deprecated) |
| `objc.free(...)` | `list.deinit()` / `raw.runtime.free(...)` | Supported (deprecated) |
| `objc.Iterator` | `objc_foundation.FastEnumerationIterator` | Moved to `objc_foundation` |
| `objc.LegacyBlock` | `objc.OwnedBlock` | Supported (deprecated) |
