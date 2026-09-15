# Method Swizzling and Reversible Replacement

Method swizzling exchanges the implementations of two Objective-C methods at runtime. Reversible replacement substitutes a method's implementation with a Zig function or Block while tracking state to ensure safe rollback.

---

## 1. Method Swizzling

### 1.1 Unchecked Swizzling: `Swizzle`

```zig
const mA = cls.instanceMethod(objc.sel("methodA")).?;
const mB = cls.instanceMethod(objc.sel("methodB")).?;

var swiz = objc.Swizzle.install(mA, mB);

// Method implementations are now exchanged
// ...

// Restore original implementations
swiz.restore();
```

### 1.2 Scoped RAII Swizzling: `ScopedSwizzle`

For test cases and temporary scopes, `ScopedSwizzle` guarantees restoration via `defer`:

```zig
{
    var scoped = objc.ScopedSwizzle.init(mA, mB);
    defer scoped.deinit();

    // Swizzled within this block only
}
// Restored upon exiting the block
```

### 1.3 Signature-Checked Swizzling: `installChecked`

Swizzling methods with incompatible ABI return or argument types causes undefined behavior or memory corruption. `installChecked` validates signatures before swapping:

```zig
var swiz = try objc.Swizzle.installChecked(allocator, mA, mB);
defer swiz.restore();
```

If signatures do not match, it aborts without modifying the methods and returns `error.IncompatibleSignatures`.

---

## 2. Reversible Method Replacement

### 2.1 Replacing with Zig Functions: `MethodReplacement`

`MethodReplacement` substitutes a method with a typed Zig callback function, reusing the Phase 7 trampoline mechanism:

```zig
var replacement = objc.MethodReplacement.replaceWith(mA, struct {
    fn custom(self: objc.Object, _cmd: objc.Selector) c_int {
        _ = self;
        _ = _cmd;
        return 42;
    }
}.custom);

// Restore original implementation
try replacement.restore();
```

### 2.2 Conflict Detection

If another thread or third-party library modified the method while our replacement was active, blindly restoring our previous IMP would destroy the intervening patch:

```zig
// In MethodReplacement.restore():
if (!self.method.implementation().eql(self.installed)) {
    return error.ImplementationChanged;
}
```

If a conflict is detected, `restore()` returns `error.ImplementationChanged` instead of overwriting the concurrent change.

---

## 3. Block-Backed Method Replacement: `BlockMethodReplacement`

To replace a method with an Objective-C Block (from Phase 8), `BlockMethodReplacement` bridges the block into an `OwnedImp` via `imp_implementationWithBlock`:

```zig
var blk = try objc.OwnedBlock(fn (objc.Object) c_int).fromFunction(struct {
    fn run(_: objc.Object) c_int {
        return 999;
    }
}.run);
defer blk.deinit();

var replacement = try objc.BlockMethodReplacement.replace(mA, blk);

// Rollback cleanly:
try replacement.restore();
```

### Restoration Order Invariant
When `restore()` is called on `BlockMethodReplacement`:
1. It validates that the method still points to our installed IMP.
2. It restores the previous IMP onto the method.
3. It releases the Block IMP via `imp_removeBlock`.

Releasing the IMP before restoring the method would create a window where messages dispatched to the method execute unmapped memory.
