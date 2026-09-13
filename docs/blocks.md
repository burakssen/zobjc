# Objective-C Blocks ABI (`objc.block`, `Block`, `OwnedBlock`)

`zobjc` provides an authoritative, Apple libclosure-conforming implementation of Objective-C Blocks.

It seamlessly bridges Zig function signatures, capture structs, and closures with Apple's Blocks ABI, coordinating ABI classification, compile-time type encodings, runtime memory management, and method IMP bridging.

```text
raw (libclosure / libobjc)
 ├── _NSConcreteStackBlock / _NSConcreteGlobalBlock / _NSConcreteMallocBlock
 ├── _Block_copy / _Block_release
 ├── _Block_object_assign / _Block_object_dispose
 └── imp_implementationWithBlock / imp_removeBlock
      │
      ▼
objc.block Subsystem
 ├── Handles: Block(Signature), OwnedBlock(Signature)
 ├── Captures: Strong(T), Weak(T), BlockRef(Sig), ByRef(T)
 ├── Memory: Literal(Captures), CopyDisposeHelpers, ByRefCell(T)
 ├── Descriptors: Descriptor(copy, sig, layout), Compact/Extended Layout
 ├── Classification: Darwin ABI Return Classification (BLOCK_USE_STRET)
 └── Bridging: OwnedImp, makeImp, MethodBlock(MethodFn)
```

---

## 1. Block Handles: `Block` vs `OwnedBlock`

| Handle | Ownership | Lifetime Management | Conversions |
|---|---|---|---|
| `Block(Signature)` | Non-owning borrow | Caller manages lifetime | `.copy() -> !OwnedBlock(Sig)`, `.asObject() -> Object`, `.toRaw()` |
| `OwnedBlock(Signature)` | Heap-owning handle | `_Block_release` on `.deinit()` | `.borrow() -> Block(Sig)`, `.clone() -> !OwnedBlock(Sig)`, `.intoRaw()` |

### Function Signature Specification
Modern blocks specify a native Zig function signature:
```zig
const IntUnary = fn (c_int) c_int;
const Handler = fn (objc.Object, c_int) void;
```
Block signatures are validated at compile time:
- Non-variadic functions only (`is_var_args == false`).
- Valid Apple ABI return and parameter types.
- Non-Darwin architectures or Pointer Authentication (`ptrauth`) targets produce actionable compile-time diagnostics.

---

## 2. Block Creation

### Zero-Allocation Global Blocks (`objc.block.global`)
When a block captures no variables, `objc.block.global` constructs a statically allocated literal initialized with `_NSConcreteGlobalBlock`:

```zig
const square = objc.block.global(fn (c_int) c_int, struct {
    fn run(x: c_int) c_int {
        return x * x;
    }
}.run);

const result = square.call(.{7}); // 49
```
- Zero heap allocations.
- No retain/release overhead (`_Block_copy` returns identity).
- Lifetime extends for the duration of the process.

### Non-Capturing Heap Blocks (`fromFunction`)
Promotes a stateless callback to an `OwnedBlock`:

```zig
var blk = try objc.OwnedBlock(fn (f64) f64).fromFunction(struct {
    fn run(x: f64) f64 {
        return x * 2.0;
    }
}.run);
defer blk.deinit();

const res = blk.call(.{12.5}); // 25.0
```

### Capturing Heap Blocks (`capture`)
Captures arbitrary Zig structs:

```zig
const Captures = struct {
    base: c_int,
    multiplier: f64,
};

var blk = try objc.OwnedBlock(fn (c_int) f64).capture(
    Captures,
    .{ .base = 10, .multiplier = 2.5 },
    struct {
        fn run(caps: *const Captures, input: c_int) f64 {
            return @as(f64, @floatFromInt(caps.base + input)) * caps.multiplier;
        }
    }.run,
);
defer blk.deinit();

const res = blk.call(.{2}); // (10 + 2) * 2.5 = 30.0
```

---

## 3. Capture Semantics & Lifetime Management

All capture types are automatically analyzed at compile time by `CaptureTraits(T)`.

| Capture Wrapper | Category | Libclosure Flags | Runtime Management |
|---|---|---|---|
| Primitive / POD | `.trivial` | `0` | Bitwise copy, no helpers required |
| `objc.block.Strong(T)` | `.strong` | `BLOCK_FIELD_IS_OBJECT` | Retained via `_Block_object_assign`, released via `_Block_object_dispose` |
| `objc.block.Weak(T)` | `.weak` | `BLOCK_FIELD_IS_WEAK \| BLOCK_FIELD_IS_OBJECT` | Non-retaining weak pointer registered with runtime |
| `objc.block.BlockRef(Sig)` | `.block` | `BLOCK_FIELD_IS_BLOCK` | Copied via `_Block_object_assign`, released via `_Block_object_dispose` |
| `objc.block.ByRefCapture(T)` | `.byref` | `BLOCK_FIELD_IS_BYREF` | Stack cell forwarded or migrated to heap |

### Managed Object Captures (`Strong(T)`)
Prevents premature deallocation of Objective-C objects retained by closures:

```zig
var tracker = DeallocTracker.init();
{
    var blk = try objc.OwnedBlock(fn () void).capture(
        struct { tracker: objc.block.Strong(DeallocTracker) },
        .{ .tracker = objc.block.Strong(DeallocTracker).init(&tracker) },
        struct {
            fn run(caps: *const struct { tracker: objc.block.Strong(DeallocTracker) }) void {
                _ = caps.tracker.borrow();
            }
        }.run,
    );
    defer blk.deinit();

    // Object is retained while block lives
    blk.call(.{});
}
// Block disposed -> object released
```

### Mutable `__block` Storage (`ByRef(T)`)
Implements Apple's address-stable `__block` storage cell with forwarding pointers (`byref.forwarding`):

```zig
var counter: objc.block.ByRef(c_int) = undefined;
counter.init(100);
defer counter.deinit();

const Caps = struct { ctr: objc.block.ByRefCapture(c_int) };
var blk = try objc.OwnedBlock(fn (c_int) void).capture(
    Caps,
    .{ .ctr = counter.capture() },
    struct {
        fn run(caps: *const Caps, delta: c_int) void {
            caps.ctr.set(caps.ctr.get().* + delta);
        }
    }.run,
);
defer blk.deinit();

blk.call(.{25});
// Original stack holder sees modified value via forwarding pointer:
std.debug.assert(counter.get().* == 125);
```

When `_Block_copy` runs, the stack-allocated `ByRefCell` is promoted to the heap. Both the stack cell's forwarding pointer and the heap block's cell pointer are updated to point to the canonical heap cell, ensuring modifications remain synchronized.

---

## 4. ABI Classification & Descriptors

### Type Encoding (`@?` Signatures)
Per Apple's runtime specification, Block type signatures begin with the return type encoding, followed by `@?` (representing the block pointer itself), followed by argument type encodings:
```text
fn (c_int) c_int           →  i@?i
fn (Object, Selector) void  →  v@?@:
```

### Return Convention (`BLOCK_USE_STRET`)
Unlike messaging which has separate `objc_msgSend` entry points, libclosure encodes whether a block uses structure-return convention directly into `Block_layout.flags`:
- ARM64: Structures are returned in registers (`x0`–`x7` or `v0`–`v7`) or indirect result pointer without STRET convention (`BLOCK_USE_STRET` is never set).
- x86_64: Aggregates not fitting in `RAX`/`RDX` set `BLOCK_USE_STRET` (bit 29).

### Descriptor Generation
The subsystem dynamically selects the minimum required Apple descriptor layout:
- Small descriptor (16 bytes): `reserved` + `size` (for global blocks without signatures).
- Signature descriptor (24 bytes): `reserved` + `size` + `signature`.
- Copy/Dispose descriptor (32 bytes): adds `copy` and `dispose` function pointers.
- Extended Layout descriptor (40 bytes): adds compact 12-bit layout encoding (`0xXYZ` for strong/byref/weak counts) or extended runtime layout pointers.

---

## 5. Block ↔ IMP Bridging (`OwnedImp`)

Apple allows registering Blocks as class method implementations via `imp_implementationWithBlock`.

```zig
var block = try objc.OwnedBlock(fn (objc.Object, c_int) c_int).fromFunction(struct {
    fn run(self: objc.Object, delta: c_int) c_int {
        _ = self;
        return delta * 10;
    }
}.run);
defer block.deinit();

var imp = try block.makeImp();
defer imp.deinit(); // Removes IMP binding via imp_removeBlock

const result = objc.callImp(c_int, imp.borrow(), target_obj, objc.sel("multiply:"), .{5});
// result == 50
```

> [!IMPORTANT]
> Per Apple specification, the Block passed to `imp_implementationWithBlock` omits the `_cmd` selector argument: its signature is `^(self, args...)`. Use `MethodBlock(MethodFn)` to translate standard method signatures `fn (self, _cmd, args...) Ret` into the corresponding Block signature.

---

## 6. Verification & Differential Testing

The Block subsystem is comprehensively verified against Clang and Apple's runtime:
- **Clang Comparison**: `tests/fixtures/blocks/fixtures.m` creates blocks using Clang's `-fblocks` compiler flag and verifies exact bitmask compatibility, descriptor sizing, and invocations.
- **Bi-directional Invocations**: Clang blocks invoked from Zig; Zig blocks passed to Clang and invoked.
- **Master Test Suite**: 26 dedicated block tests and 257 total tests across the entire `zobjc` suite (`zig build test-block`, `zig build test`).
