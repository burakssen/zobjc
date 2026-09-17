# Building Framework Wrappers on zobjc

## Architectural Principles

The core `objc` package is designed to be the foundational runtime substrate for the entire Apple platform ecosystem in Zig.

When creating higher-level framework wrappers (such as AppKit, UIKit, Metal, CoreGraphics, WebKit, or AVFoundation), adhere to the following architectural guidelines established by `objc_foundation`:

```text
┌─────────────────────────────────────────────────────────────┐
│                    Higher-Level Wrappers                    │
│             (zappkit, zuikit, zmetal, zwebkit)              │
└──────────────────────────────┬──────────────────────────────┘
                               │ imports
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                       objc_foundation                       │
│    (NSString, FastEnumerationIterator, NSEnumerator, ...)   │
└──────────────────────────────┬──────────────────────────────┘
                               │ imports
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                            objc                             │
│       (libobjc primitives, memory, messaging, blocks)       │
└─────────────────────────────────────────────────────────────┘
```

---

## 1. Zero-Cost Wrapper Types

Do not allocate heap memory for Objective-C object representations in Zig. Wrap `objc.Object` directly:

```zig
pub const NSView = struct {
    object: objc.Object,

    // Trait integration for Retained(T) / Weak(T)
    pub inline fn asObject(self: NSView) objc.Object {
        return self.object;
    }

    pub inline fn fromObject(obj: objc.Object) NSView {
        return .{ .object = obj };
    }

    pub inline fn toRaw(self: NSView) objc.raw.id {
        return self.object.ptr;
    }
};

comptime {
    std.debug.assert(@sizeOf(NSView) == @sizeOf(objc.Object));
    std.debug.assert(@alignOf(NSView) == @alignOf(objc.Object));
}
```

---

## 2. Strong Ownership with `objc.Retained(T)`

By defining `.asObject()` and `.fromObject()`, your wrapper types automatically qualify as retainable types under `objc.memory.traits.isRetainable(T)`.

You never need to write manual reference counting logic:

```zig
pub fn createCustomView() !objc.Retained(NSView) {
    const cls = objc.requireClass("NSView");
    const raw_view = objc.send(objc.Object, cls, "alloc", .{})
        .send(objc.Object, "initWithFrame:", .{rect});

    return objc.Retained(NSView).adopt(NSView.fromObject(raw_view));
}

// Caller usage:
var view = try createCustomView();
defer view.deinit(); // Automatically calls objc_release
```

---

## 3. High-Level Messaging with `objc.send`

Use `objc.send` to dispatch methods with strict comptime type validation and ABI classification:

```zig
pub inline fn addSubview(self: NSView, child: NSView) void {
    objc.send(void, self.object, "addSubview:", .{child.object});
}

pub inline fn bounds(self: NSView) NSRect {
    return objc.send(NSRect, self.object, "bounds", .{});
}
```

---

## 4. Protocol Implementation with `ClassBuilder`

When your framework wrapper needs to register custom delegates or data sources:

```zig
pub fn registerCustomWindowDelegate() objc.Class {
    var builder = objc.ClassBuilder.init("ZigWindowDelegate", objc.requireClass("NSObject")) catch unreachable;

    // Adopt protocol
    if (objc.getProtocol("NSWindowDelegate")) |proto| {
        _ = builder.addProtocol(proto) catch {};
    }

    // Add method implementation
    _ = builder.addMethod(
        objc.sel("windowWillClose:"),
        struct {
            fn callback(target: objc.raw.id, sel_val: objc.raw.SEL, notification: objc.raw.id) callconv(.c) void {
                _ = target; _ = sel_val; _ = notification;
                std.debug.print("Window will close!\n", .{});
            }
        }.callback,
        "v@:@",
    ) catch unreachable;

    return builder.register();
}
```

---

## 5. Block Callbacks with `objc.OwnedBlock`

When passing asynchronous completion handlers to Cocoa APIs:

```zig
pub fn performAsyncAnimation(view: NSView, on_complete: fn () void) !void {
    var blk = try objc.OwnedBlock(fn () void).fromFn(on_complete);
    defer blk.deinit();

    objc.send(void, view.object, "animateWithCompletion:", .{blk.toObject()});
}
```
