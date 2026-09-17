# Upstream `zig-objc` to `zobjc` Compatibility Matrix & Migration Guide

This document specifies the exact relationship between upstream `zig-objc` and modern `zobjc`, breaking changes, and migration recipes for existing codebases.

---

## 1. Upstream to Modern Mapping Table

| Upstream `zig-objc` Construct | Modern `zobjc` Canonical | Backward-Compatible Alias | Status / Notes |
| :--- | :--- | :--- | :--- |
| `objc.getClass("NSObject")` | `objc.getClass("NSObject")` | `objc.getClass` | **100% Identical** |
| `objc.getMetaClass("NSObject")` | `objc.getMetaClass("NSObject")` | `objc.getMetaClass` | **100% Identical** |
| `objc.sel("description")` | `objc.sel("description")` | `objc.sel` | **100% Identical** |
| `objc.Sel` | `objc.Selector` | `objc.Sel` | `objc.Sel` is aliased to `objc.Selector` |
| `objc.c` | `objc.raw.c` | `objc.c` | Preserved via compatibility alias |
| `obj.msgSend(Ret, sel, args)` | `objc.send(Ret, obj, sel, args)` | `obj.msgSend(Ret, sel, args)` | Method syntax preserved as facade |
| `cls.msgSend(Ret, sel, args)` | `objc.send(Ret, cls, sel, args)` | `cls.msgSend(Ret, sel, args)` | Method syntax preserved as facade |
| `obj.msgSendSuper(super, Ret, sel, args)` | `objc.sendSuper(Ret, obj, super, sel, args)` | `obj.msgSendSuper(...)` | Method syntax preserved as facade |
| `objc.AutoreleasePool` | `objc.AutoreleasePool` | `objc.AutoreleasePool` | **100% Identical** |
| `objc.Block` | `objc.OwnedBlock` / `objc.Block` | `objc.Block` | Upstream 3-param `objc.Block(Captures, Args, Ret)` preserved |
| `objc.allocateClassPair` | `objc.allocateClassPair` | `objc.allocateClassPair` | **100% Identical** |
| `objc.registerClassPair` | `objc.registerClassPair` | `objc.registerClassPair` | **100% Identical** |
| `objc.disposeClassPair` | `objc.disposeClassPair` | `objc.disposeClassPair` | **100% Identical** |
| `cls.addMethod(sel, imp, types)` | `builder.addMethod(sel, func)` | `cls.addMethod` | Raw runtime addMethod preserved on Class |
| `cls.addIvar(name, size, align, types)` | `builder.addIvar(name, T)` | `cls.addIvar` | Raw runtime addIvar preserved on Class |
| `cls.addProtocol(proto)` | `builder.addProtocol(proto)` | `cls.addProtocol` | Raw runtime addProtocol preserved on Class |
| `cls.copyMethodList(&count)` | `cls.methods()` | `raw.runtime.class_copyMethodList` | Returns RAII `OwnedRuntimeList(Method)` |
| `cls.copyIvarList(&count)` | `cls.ivars()` | `raw.runtime.class_copyIvarList` | Returns RAII `OwnedRuntimeList(Ivar)` |
| `cls.copyPropertyList(&count)` | `cls.properties()` | `raw.runtime.class_copyPropertyList` | Returns RAII `OwnedRuntimeList(Property)` |
| `objc.copyClassList(&count)` | `objc.runtime.classes()` | `raw.runtime.objc_copyClassList` | Returns RAII `OwnedRuntimeList(Class)` |
| `objc.free(ptr)` | `list.deinit()` / `raw.runtime.free` | `raw.runtime.free` | Replaced by RAII owned containers |

---

## 2. Breaking Changes & Intentional Compile Rejections

To prevent undefined behavior and silent ABI mismatch corruption, `zobjc` enforces strict compile-time validation:

### 2.1 Untyped Integer and Float Literals
* **Upstream**: Allowed untyped literals such as `obj.msgSend(void, "setVal:", .{ 42 })`, which silently defaulted to machine integer sizes that could misalign Darwin C calling convention registers.
* **Modern `zobjc`**: Rejects `comptime_int` and `comptime_float` at compile time.
* **Migration**:
  ```zig
  // Before (upstream):
  obj.msgSend(void, "setVal:", .{ 42 });

  // After (modern):
  objc.send(void, obj, "setVal:", .{ @as(c_int, 42) });
  ```

### 2.2 Slices vs C Strings
* **Upstream**: Permitted slices `[]const u8` as arguments, producing invalid pointers across the C ABI because slices are 16-byte fat pointers (ptr + len).
* **Modern `zobjc`**: Emits a compile error if a slice `[]const u8` is passed as a message argument.
* **Migration**:
  ```zig
  // Before (upstream):
  const str: []const u8 = "hello";
  obj.msgSend(void, "setName:", .{ str });

  // After (modern):
  const str: [:0]const u8 = "hello";
  objc.send(void, obj, "setName:", .{ str });
  ```

### 2.3 Non-Extern Struct Layouts
* **Upstream**: Allowed any Zig struct to be passed or returned by value, which produced memory corruption if Zig reordered fields.
* **Modern `zobjc`**: Asserts that aggregate arguments and return types are `extern struct` or `extern union`.
* **Migration**:
  ```zig
  // Ensure structs passed across the Objective-C boundary are extern:
  pub const NSRange = extern struct {
      location: usize,
      length: usize,
  };
  ```

### 2.4 Method Implementation `_cmd` Parameter
* **Upstream**: Callback signatures varied across dynamic builder attempts.
* **Modern `zobjc`**: Enforces the Objective-C C ABI convention: every method callback must take at least `(self, _cmd)`.
* **Migration**:
  ```zig
  // Ensure custom method implementations accept self and _cmd:
  fn customMethod(self: objc.Object, _cmd: objc.Selector, arg0: c_int) c_int {
      _ = _cmd;
      return arg0 * 2;
  }
  ```

### 2.5 Foundation Framework Decoupling
* **Upstream**: Mixed `Foundation` and `AppKit` imports into runtime tests and headers.
* **Modern `zobjc`**: Core `objc` module links strictly against `libobjc.A.dylib` and `libSystem.B.dylib`. Foundation types (`NSString`, `NSArray`, `NSDictionary`, `NSValue`, `NSFastEnumeration`) live in the optional `objc_foundation` module.
* **Migration**:
  ```zig
  // In build.zig:
  exe.root_module.addImport("objc", objc_dep.module("objc"));
  // Only if Foundation conveniences are needed:
  exe.root_module.addImport("objc_foundation", objc_dep.module("objc_foundation"));
  exe.linkFramework("Foundation");
  ```

---

## 3. Recommended Migration Recipes

### Recipe 1: Messaging Refactoring
```zig
// Upstream zig-objc:
const array = objc.getClass("NSArray").?.msgSend(objc.Object, "alloc", .{})
    .msgSend(objc.Object, "init", .{});
defer array.msgSend(void, "release", .{});
const count = array.msgSend(usize, "count", .{});

// Modern zobjc (Idiomatic):
const NSArray = objc.getClass("NSArray").?;
var array = objc.memory.Retained(objc.Object).adopt(
    objc.send(objc.Object, NSArray, "alloc", .{}).send(objc.Object, "init", .{})
);
defer array.deinit();
const count = objc.send(usize, array.borrow(), "count", .{});
```

### Recipe 2: Blocks Creation
```zig
// Upstream zig-objc:
const blk = objc.Block(struct {}, fn (c_int) c_int, c_int).init(struct {
    fn run(_: *const struct {}, x: c_int) c_int { return x * 2; }
}.run, .{});

// Modern zobjc (Idiomatic):
var blk = try objc.OwnedBlock(fn (c_int) c_int).fromFunction(struct {
    fn run(x: c_int) c_int { return x * 2; }
}.run);
defer blk.deinit();
```
