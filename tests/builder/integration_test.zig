//! End-to-end dynamic class, protocol, ivar, method, and messaging integration tests.

const std = @import("std");
const objc = @import("objc");
const testing = std.testing;

test "Integration: dynamic class with object ivar conforming to dynamic protocol" {
    // 1. Build a dynamic protocol
    var proto_builder = try objc.ProtocolBuilder.init("ZigTest_Integration_Valuable");
    errdefer proto_builder.abort();

    try proto_builder.addMethod(
        "value",
        fn (objc.Object, objc.Selector) ?objc.Object,
        .{ .required = true, .instance = true },
    );
    try proto_builder.addMethod(
        "setValue:",
        fn (objc.Object, objc.Selector, ?objc.Object) void,
        .{ .required = true, .instance = true },
    );
    const valuable_proto = proto_builder.register();

    // 2. Build a dynamic class implementing the protocol
    const NSObject = objc.requireClass("NSObject");
    var class_builder = try objc.ClassBuilder.init("ZigTest_Integration_Box", NSObject);
    errdefer class_builder.abort();

    // Add protocol conformance
    try class_builder.addProtocol(valuable_proto);

    // Add instance variable for object storage
    try class_builder.addIvar(?objc.Object, "_value");

    // Add property metadata
    try class_builder.addProperty(?objc.Object, "value", .{
        .retain = true,
        .nonatomic = true,
        .ivar = "_value",
    });

    // Implement methods using ergonomic callbacks
    const getValue = struct {
        fn run(self: objc.Object, _: objc.Selector) ?objc.Object {
            const cls = self.class();
            const ivar_val = cls.instanceIvar("_value").?;
            return self.getIvar(ivar_val);
        }
    }.run;

    const setValue = struct {
        fn run(self: objc.Object, _: objc.Selector, new_val: ?objc.Object) void {
            const cls = self.class();
            const ivar_val = cls.instanceIvar("_value").?;
            self.setIvar(ivar_val, new_val);
        }
    }.run;

    const classIdentity = struct {
        fn run(cls: objc.Class, _: objc.Selector) c_int {
            _ = cls;
            return 777;
        }
    }.run;

    try class_builder.addMethod("value", getValue);
    try class_builder.addMethod("setValue:", setValue);
    try class_builder.addClassMethod("classIdentity", classIdentity);

    // Register dynamic class
    const BoxClass = class_builder.register();

    // 3. Verify protocol conformance
    try testing.expect(BoxClass.conformsTo(valuable_proto));

    // 4. Verify class method dispatch
    const cid = BoxClass.send(c_int, "classIdentity", .{});
    try testing.expectEqual(777, cid);

    // 5. Instantiate and verify instance method message dispatch
    const box = BoxClass.send(objc.Object, "new", .{});
    try testing.expect(box.send(?objc.Object, "value", .{}) == null);

    // Create a payload object to store in the box
    const NSString = objc.requireClass("NSString");
    const payload = NSString.send(objc.Object, "stringWithUTF8String:", .{"Hello from dynamic Box!"});

    // Store in box
    box.send(void, "setValue:", .{payload});

    // Read back from box
    const retrieved = box.send(?objc.Object, "value", .{}).?;
    try testing.expect(retrieved.eql(payload));

    const utf8 = retrieved.send([*:0]const u8, "UTF8String", .{});
    try testing.expectEqualStrings("Hello from dynamic Box!", std.mem.span(utf8));
}

test "Integration: dynamic class with scalar ivar and arithmetic methods" {
    const NSObject = objc.requireClass("NSObject");
    var builder = try objc.ClassBuilder.init("ZigTest_Integration_Counter", NSObject);
    errdefer builder.abort();

    try builder.addIvar(c_int, "_count");

    // Implement methods reading/writing scalar ivar via offset
    const getCount = struct {
        fn run(self: objc.Object, _: objc.Selector) c_int {
            const cls = self.class();
            const ivar_val = cls.instanceIvar("_count").?;
            const base: [*]u8 = @ptrCast(self.ptr);
            const off: usize = @intCast(ivar_val.offset());
            const ptr: *const c_int = @ptrCast(@alignCast(&base[off]));
            return ptr.*;
        }
    }.run;

    const setCount = struct {
        fn run(self: objc.Object, _: objc.Selector, new_count: c_int) void {
            const cls = self.class();
            const ivar_val = cls.instanceIvar("_count").?;
            const base: [*]u8 = @ptrCast(self.ptr);
            const off: usize = @intCast(ivar_val.offset());
            const ptr: *c_int = @ptrCast(@alignCast(&base[off]));
            ptr.* = new_count;
        }
    }.run;

    const addAndReturn = struct {
        fn run(self: objc.Object, _: objc.Selector, delta: c_int) c_int {
            const cls = self.class();
            const ivar_val = cls.instanceIvar("_count").?;
            const base: [*]u8 = @ptrCast(self.ptr);
            const off: usize = @intCast(ivar_val.offset());
            const ptr: *c_int = @ptrCast(@alignCast(&base[off]));
            ptr.* += delta;
            return ptr.*;
        }
    }.run;

    try builder.addMethod("count", getCount);
    try builder.addMethod("setCount:", setCount);
    try builder.addMethod("add:", addAndReturn);

    const CounterClass = builder.register();

    const counter = CounterClass.send(objc.Object, "new", .{});
    try testing.expectEqual(0, counter.send(c_int, "count", .{}));

    counter.send(void, "setCount:", .{@as(c_int, 100)});
    try testing.expectEqual(100, counter.send(c_int, "count", .{}));

    const updated = counter.send(c_int, "add:", .{@as(c_int, 42)});
    try testing.expectEqual(142, updated);
    try testing.expectEqual(142, counter.send(c_int, "count", .{}));
}
