# Foundation Convenience Layer (`objc_foundation`)

## Overview

The `objc_foundation` module provides an optional, idiomatic Zig convenience layer for Apple's **Foundation Framework**.

While the core `objc` package is a pure `libobjc` wrapper that links strictly to `libobjc.A.dylib` with zero framework dependencies, `objc_foundation` provides safe, zero-overhead abstractions for core Foundation types and protocols:

```text
┌─────────────────────────────────────────────────────────────┐
│                       objc_foundation                       │
│    (NSString, FastEnumerationIterator, NSEnumerator, ...)   │
│              links: libobjc + Foundation.framework          │
└──────────────────────────────┬──────────────────────────────┘
                               │ imports (public API only)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                            objc                             │
│   (raw, runtime, memory, encoding, abi, messaging, block,  │
│                   builders, advanced)                       │
│                     links: libobjc only                     │
└─────────────────────────────────────────────────────────────┘
```

---

## Installation & Build Configuration

In `build.zig.zon`:
```zig
.dependencies = .{
    .zobjc = .{
        .url = "...",
        .hash = "...",
    },
},
```

In `build.zig`:
```zig
const zobjc_dep = b.dependency("zobjc", .{
    .target = target,
    .optimize = optimize,
});

// Import core pure-runtime module (links only libobjc)
exe_mod.addImport("objc", zobjc_dep.module("objc"));

// Optional: import Foundation convenience layer (links libobjc + Foundation)
exe_mod.addImport("objc_foundation", zobjc_dep.module("objc_foundation"));
```

---

## Core Primitives and Types

`objc_foundation` exposes fundamental Foundation typedefs and structures matching Darwin 64-bit ABI:

```zig
const foundation = @import("objc_foundation");

// Scalar types
const idx: foundation.NSInteger = -1;
const count: foundation.NSUInteger = 100;
const duration: foundation.NSTimeInterval = 2.5;

// Ordering comparison
const res = foundation.NSComparisonResult.OrderedAscending;

// String encodings
const utf8_enc = foundation.StringEncoding.UTF8;
```

### NSRange Geometry

`NSRange` represents a contiguous subrange within an ordered collection or string:

```zig
const NSRange = foundation.NSRange;

const r = NSRange.init(5, 10);
r.location; // 5
r.length;   // 10
r.max();    // 15 (exclusive upper bound)

r.contains(10); // true
r.contains(15); // false

const other = NSRange.init(8, 12);
if (r.intersection(other)) |inter| {
    // inter.location = 8, inter.length = 7
}
```

---

## NSString

`NSString` is a non-owning, zero-cost handle to an Objective-C `NSString` instance. It participates directly in `objc.Retained(NSString)` and `objc.Weak(NSString)` via the Phase 3 traits system.

### Construction & Memory Ownership

```zig
const NSString = foundation.NSString;

// 1. Autoreleased (+0) instance from a null-terminated UTF-8 slice
var pool = objc.AutoreleasePool.init();
defer pool.deinit();

const str = NSString.fromUTF8("Autoreleased Cocoa String") orelse return error.Failed;

// 2. Owned (+1) instance managed by Retained(NSString)
var owned = NSString.fromUTF8Owned("Owned Cocoa String") orelse return error.Failed;
defer owned.deinit(); // Automatically calls objc_release

// 3. Owned (+1) instance from a non-null-terminated subslice
const text = "Full buffer containing substring";
var sub = NSString.fromUTF8SliceOwned(text[5..11]) orelse return error.Failed;
defer sub.deinit();
```

### Inspection & Extraction

```zig
const borrowed = owned.borrow();

// UTF-16 code units (matching -[NSString length])
const len = borrowed.lengthUtf16();

// Full range
const r = borrowed.range(); // NSRange{ .location = 0, .length = len }

// Borrowed C-string (WARNING: valid only for current autorelease pool lifetime)
if (borrowed.utf8CString()) |c_str| {
    std.debug.print("Content: {s}\n", .{c_str});
}

// Caller-allocated UTF-8 copy
const slice = try borrowed.toUTF8Alloc(allocator);
defer allocator.free(slice);
```

### Equality and Hashing

```zig
if (s1.isEqualToString(s2)) {
    // Exact string value equality via -[NSString isEqualToString:]
}

const hash = s1.hash(); // -[NSObject hash]
```

---

## High-Performance Fast Enumeration (`NSFastEnumeration`)

Objective-C collections (`NSArray`, `NSDictionary`, `NSSet`, `NSEnumerator`, etc.) implement the `NSFastEnumeration` protocol (`countByEnumeratingWithState:objects:count:`).

`FastEnumerationIterator` provides a high-performance Zig iterator that:
- Uses a **stack-allocated buffer** (`[16]objc.raw.id` by default) with **zero heap allocations**.
- Correctly consumes items whether the collection copies them into the stack buffer or points `items_ptr` to internal backing arrays.
- Implements **safe mutation detection**: checks `mutations_ptr` on every element and returns `error.CollectionMutated` if the collection was concurrently modified.

```zig
const array = NSMutableArray.msgSend(objc.Object, "array", .{});
// ... populate array ...

var iter = foundation.fastIterate(array);
while (try iter.next()) |elem| {
    const val = elem.msgSend(c_int, "intValue", .{});
    std.debug.print("val: {d}\n", .{val});
}
```

### Configurable Stack Buffer Size

For tight performance tuning, the stack capacity can be customized at compile-time:

```zig
var iter = foundation.FastEnumerationIterator(64).init(collection);
while (try iter.next()) |elem| { ... }
```

---

## NSEnumerator

`NSEnumerator` provides a handle for streaming or forward-only Cocoa enumerators:

```zig
const raw_enum = array.msgSend(objc.Object, "objectEnumerator", .{});
const enumerator = foundation.NSEnumerator.fromObject(raw_enum);

// Standard Zig iteration:
var it = enumerator.iterator();
while (it.next()) |elem| {
    // ...
}

// Or batch fetch remaining:
const remaining_array = enumerator.allObjects();
```
