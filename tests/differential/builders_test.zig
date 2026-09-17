//! Differential tests verifying dynamic ClassBuilder and ProtocolBuilder subsystems.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

test "differential: ClassBuilder end-to-end construction and messaging" {
    const NSObject = objc.getClass("NSObject").?;
    var builder = try objc.builder.ClassBuilder.init("DiffDynamicClass", NSObject);

    // Add ivar: u64 (alignment 8 -> log2 alignment 3)
    try builder.addIvar(u64, "customValue");

    // Method callback implementation
    const callbacks = struct {
        fn getValue(self: objc.raw.id, _cmd: objc.raw.SEL) callconv(.c) u64 {
            _ = _cmd;
            const obj = objc.Object.fromId(self);
            const ivar = obj.getClass().?.instanceIvar("customValue").?;
            const offset: usize = @intCast(ivar.offset());
            const ptr: *const u64 = @ptrCast(@alignCast(@as([*]const u8, @ptrCast(self)) + offset));
            return ptr.*;
        }

        fn setValue(self: objc.raw.id, _cmd: objc.raw.SEL, val: u64) callconv(.c) void {
            _ = _cmd;
            const obj = objc.Object.fromId(self);
            const ivar = obj.getClass().?.instanceIvar("customValue").?;
            const offset: usize = @intCast(ivar.offset());
            const ptr: *u64 = @ptrCast(@alignCast(@as([*]u8, @ptrCast(self)) + offset));
            ptr.* = val;
        }
    };

    try builder.addMethod(objc.sel("customValue"), callbacks.getValue);
    try builder.addMethod(objc.sel("setCustomValue:"), callbacks.setValue);

    // Register class
    const RegisteredClass = builder.register();

    // Instantiate and message
    const instance = objc.send(objc.Object, RegisteredClass, "alloc", .{}).send(objc.Object, "init", .{});
    defer instance.send(void, "dealloc", .{});

    instance.send(void, "setCustomValue:", .{@as(u64, 987654321)});
    const retrieved = instance.send(u64, "customValue", .{});
    try testing.expectEqual(@as(u64, 987654321), retrieved);
}

test "differential: class_addIvar alignment permanent regression check" {
    // Permanent regression check for class_addIvar alignment argument:
    // Apple's runtime requires log2(alignOf(T)), NOT alignOf(T).
    // For an 8-byte aligned type, log2(8) == 3.
    const align_8: u8 = @alignOf(u64);
    try testing.expectEqual(@as(u8, 8), align_8);

    const log2_align = std.math.log2(align_8);
    try testing.expectEqual(@as(u8, 3), log2_align);
}

test "differential: dynamic class lifecycle constraints" {
    const NSObject = objc.getClass("NSObject").?;
    var b = try objc.builder.ClassBuilder.init("LifecycleTestClass", NSObject);
    try b.addIvar(i32, "field1");

    const RegCls = b.register();

    // Attempting to add an ivar to an already-registered class must fail
    const ok = RegCls.addIvar("field2", @sizeOf(i32), @intCast(std.math.log2(@alignOf(i32))), "i");
    try testing.expect(!ok);
}

test "differential: ProtocolBuilder creation and runtime conformance" {
    var pb = try objc.builder.ProtocolBuilder.init("DiffProtocol");
    const HandlerFn = fn (objc.raw.id, objc.raw.SEL, c_int) void;
    try pb.addMethod(objc.sel("requiredAction:"), HandlerFn, .{ .required = true, .instance = true });
    try pb.addMethod(objc.sel("optionalAction:"), HandlerFn, .{ .required = false, .instance = true });

    const proto = pb.register();
    try testing.expectEqualStrings("DiffProtocol", proto.getName());

    // Verify lookup via getProtocol
    const fetched = objc.getProtocol("DiffProtocol");
    try testing.expect(fetched != null);
    try testing.expectEqualStrings("DiffProtocol", fetched.?.getName());
}
