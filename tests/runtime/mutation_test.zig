//! Class dynamic mutation tests.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

test "mutation: dynamic class creation, methods, ivars, protocols, and properties" {
    const NSObject = objc.requireClass("NSObject");
    const DynClass = objc.allocateClassPair(NSObject, "DynamicMutationFullTest").?;

    // 1. Add Ivar
    const ivar_added = DynClass.addIvar(
        "counter",
        @sizeOf(i64),
        @truncate(std.math.log2(@alignOf(i64))),
        "q",
    );
    try testing.expect(ivar_added);

    // 2. Add Method
    const add_fn = struct {
        fn add(target: objc.raw.id, sel_val: objc.raw.SEL, a: i32, b: i32) callconv(.c) i32 {
            _ = target;
            _ = sel_val;
            return a + b;
        }
    }.add;
    const add_sel = objc.sel("add:and:");
    try testing.expect(DynClass.addMethod(add_sel, objc.Imp.fromRawNonNull(@ptrCast(&add_fn)), "i@:ii"));

    // 3. Add Protocol
    if (objc.getProtocol("NSObject")) |proto| {
        try testing.expect(DynClass.addProtocol(proto));
    }

    // 4. Add Property
    const attrs = [_]objc.PropertyAttribute{
        .{ .name = "T", .value = "q" },
        .{ .name = "V", .value = "counter" },
    };
    try testing.expect(DynClass.addProperty("counter", &attrs));

    // Register class
    objc.registerClassPair(DynClass);
    defer objc.disposeClassPair(DynClass);

    // 5. Replace Method after registration
    const new_add_fn = struct {
        fn new_add(target: objc.raw.id, sel_val: objc.raw.SEL, a: i32, b: i32) callconv(.c) i32 {
            _ = target;
            _ = sel_val;
            return (a + b) * 10;
        }
    }.new_add;
    const old_imp = DynClass.replaceMethod(add_sel, objc.Imp.fromRawNonNull(@ptrCast(&new_add_fn)), "i@:ii");
    try testing.expect(old_imp != null);

    // Test execution on instance
    const inst = DynClass.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    defer inst.msgSend(void, "dealloc", .{});

    const sum = inst.msgSend(i32, add_sel, .{ @as(i32, 2), @as(i32, 3) });
    try testing.expectEqual(@as(i32, 50), sum);

    // Protocol conformance
    if (objc.getProtocol("NSObject")) |proto| {
        try testing.expect(DynClass.conformsTo(proto));
    }

    // Property lookup
    const prop = DynClass.property("counter");
    try testing.expect(prop != null);
    try testing.expectEqualStrings("counter", prop.?.name());
}
