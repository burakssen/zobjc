//! Integration tests for objc.sendSuper and Super2 lookup semantics.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");
const raw = objc.raw;

var g_base_class: objc.Class = undefined;
var g_child_class: objc.Class = undefined;
var g_grandchild_class: objc.Class = undefined;

fn baseIdentify(self: raw.id, _cmd: raw.SEL) callconv(.c) [*:0]const u8 {
    _ = self;
    _ = _cmd;
    return "Base";
}

fn childIdentify(self: raw.id, _cmd: raw.SEL) callconv(.c) [*:0]const u8 {
    _ = self;
    _ = _cmd;
    return "Child";
}

fn childSuperIdentify(self: raw.id, _cmd: raw.SEL) callconv(.c) [*:0]const u8 {
    _ = _cmd;
    const obj = objc.Object.fromRawNonNull(self.?);
    return objc.sendSuper([*:0]const u8, obj, g_child_class, "identify", .{});
}

fn grandchildIdentify(self: raw.id, _cmd: raw.SEL) callconv(.c) [*:0]const u8 {
    _ = self;
    _ = _cmd;
    return "Grandchild";
}

fn grandchildSuperIdentify(self: raw.id, _cmd: raw.SEL) callconv(.c) [*:0]const u8 {
    _ = _cmd;
    const obj = objc.Object.fromRawNonNull(self.?);
    return objc.sendSuper([*:0]const u8, obj, g_grandchild_class, "identify", .{});
}

test "super: 3-level class hierarchy with Super2 lookup" {
    const NSObject = objc.getClass("NSObject").?;

    // 1. Register Base
    const base_pair = objc.allocateClassPair(NSObject, "SuperTestBase").?;
    _ = raw.runtime.class_addMethod(
        base_pair.ptr,
        objc.sel("identify").toRaw(),
        @ptrCast(&baseIdentify),
        "r*@:",
    );
    g_base_class = base_pair;
    objc.registerClassPair(base_pair);
    defer objc.disposeClassPair(g_base_class);

    // 2. Register Child (inherits Base)
    const child_pair = objc.allocateClassPair(g_base_class, "SuperTestChild").?;
    _ = raw.runtime.class_addMethod(
        child_pair.ptr,
        objc.sel("identify").toRaw(),
        @ptrCast(&childIdentify),
        "r*@:",
    );
    _ = raw.runtime.class_addMethod(
        child_pair.ptr,
        objc.sel("superIdentify").toRaw(),
        @ptrCast(&childSuperIdentify),
        "r*@:",
    );
    g_child_class = child_pair;
    objc.registerClassPair(child_pair);
    defer objc.disposeClassPair(g_child_class);

    // 3. Register Grandchild (inherits Child)
    const grandchild_pair = objc.allocateClassPair(g_child_class, "SuperTestGrandchild").?;
    _ = raw.runtime.class_addMethod(
        grandchild_pair.ptr,
        objc.sel("identify").toRaw(),
        @ptrCast(&grandchildIdentify),
        "r*@:",
    );
    _ = raw.runtime.class_addMethod(
        grandchild_pair.ptr,
        objc.sel("superIdentify").toRaw(),
        @ptrCast(&grandchildSuperIdentify),
        "r*@:",
    );
    g_grandchild_class = grandchild_pair;
    objc.registerClassPair(grandchild_pair);
    defer objc.disposeClassPair(g_grandchild_class);

    // Create instances
    const child_obj = objc.send(objc.Object, g_child_class, "new", .{});
    const grandchild_obj = objc.send(objc.Object, g_grandchild_class, "new", .{});

    // Direct invocation
    try testing.expectEqualStrings("Child", std.mem.span(objc.send([*:0]const u8, child_obj, "identify", .{})));
    try testing.expectEqualStrings("Grandchild", std.mem.span(objc.send([*:0]const u8, grandchild_obj, "identify", .{})));

    // Child superIdentify -> starts lookup above Child, finds Base!
    const child_super = objc.send([*:0]const u8, child_obj, "superIdentify", .{});
    try testing.expectEqualStrings("Base", std.mem.span(child_super));

    // Grandchild superIdentify -> starts lookup above Grandchild, finds Child!
    const grandchild_super = objc.send([*:0]const u8, grandchild_obj, "superIdentify", .{});
    try testing.expectEqualStrings("Child", std.mem.span(grandchild_super));
}
