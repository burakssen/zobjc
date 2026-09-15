# Runtime Introspection and Image Discovery

Phase 9 introduces comprehensive inspection facilities for loaded Mach-O images, image-contained classes, class hierarchy relationships, and filtered class enumeration.

---

## 1. Mach-O Image Discovery

The Objective-C runtime tracks every loaded Mach-O image (executable binary, framework, or dynamic library) containing Objective-C metadata.

### 1.1 Enumerating Loaded Images

```zig
var img_list = objc.runtime.images();
defer img_list.deinit();

var iter = img_list.iterator();
while (iter.next()) |image_path| {
    std.debug.print("Image: {s}\n", .{image_path});
}
```

The returned `OwnedCStringList` frees the string array automatically upon `deinit()`.

### 1.2 Inspecting Originating Image for a Class

```zig
const NSString = objc.requireClass("NSString");
if (NSString.imageName()) |image_path| {
    std.debug.print("NSString defined in: {s}\n", .{image_path});
}
```

### 1.3 Classes Inside an Image

```zig
var class_names = objc.runtime.classNamesForImage(image_path);
defer class_names.deinit();

var iter = class_names.iterator();
while (iter.next()) |cls_name| {
    std.debug.print("Class: {s}\n", .{cls_name});
}
```

If the specified path does not exist or contains no Objective-C classes, an empty `OwnedCStringList` (`len == 0`) is returned.

---

## 2. Subclass Hierarchy Introspection

`objc.Class` provides methods to query class hierarchies:

```zig
const NSObject = objc.requireClass("NSObject");
const NSString = objc.requireClass("NSString");

// Reflexive: returns true if self is target or inherits from target
try testing.expect(NSString.isSubclassOf(NSObject));
try testing.expect(NSObject.isSubclassOf(NSObject));

// Strict: returns true ONLY if self inherits from target and self != target
try testing.expect(NSString.isStrictSubclassOf(NSObject));
try testing.expect(!NSObject.isStrictSubclassOf(NSObject));
```

---

## 3. Filtered Class Enumeration (`objc_enumerateClasses`)

On modern Darwin platforms (macOS 13+, iOS 16+), the runtime provides `objc_enumerateClasses`, which iterates over registered classes matching specific filters.

### 3.1 Availability Check

Because `objc_enumerateClasses` was introduced in macOS 13, `zobjc` resolves it dynamically via `dlsym` at runtime:

```zig
if (objc.runtime.hasClassEnumeration()) {
    // Supported on current OS
}
```

### 3.2 Enumeration Options

```zig
pub const ClassEnumerationOptions = struct {
    image: ImageFilter = .caller,
    name_prefix: ?[:0]const u8 = null,
    conforming_to: ?Protocol = null,
    subclassing: ?Class = null,
};
```

`ImageFilter` supports:
- `.caller`: Restricts search to classes defined in the caller's image (default).
- `.dynamic`: Restricts search to dynamically registered classes (`OBJC_DYNAMIC_CLASSES`).
- `.{ .handle = dlopen_handle }`: Searches a specific image handle returned by `dlopen(3)` or Mach header.

### 3.3 Example: Finding Subclasses with Early Stop

```zig
var count: usize = 0;
try objc.runtime.enumerateClasses(
    .{
        .subclassing = objc.requireClass("NSObject"),
        .name_prefix = "NS",
    },
    &count,
    struct {
        fn cb(c: *usize, cls: objc.Class) bool {
            c.* += 1;
            std.debug.print("Found: {s}\n", .{cls.name()});
            return c.* < 10; // Return false to stop enumeration early
        }
    }.cb,
);
```
