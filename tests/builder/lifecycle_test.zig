//! Dynamic class lifecycle and state machine tests.

const std = @import("std");
const objc = @import("objc");
const testing = std.testing;

test "ClassBuilder: detects existing class name collision" {
    // Attempting to create a class with the name "NSObject" must fail with ClassAlreadyExists.
    const NSObject = objc.requireClass("NSObject");
    const result = objc.ClassBuilder.init("NSObject", NSObject);
    try testing.expectError(error.ClassAlreadyExists, result);
}

test "ClassBuilder: normal allocation, configuration, and registration" {
    const NSObject = objc.requireClass("NSObject");
    var builder = try objc.ClassBuilder.init("ZigTest_Lifecycle_Normal", NSObject);
    try testing.expectEqual(objc.builder.State.allocated, builder.state);
    try testing.expect(builder.class_val != null);

    const cls = builder.register();
    try testing.expectEqual(objc.builder.State.registered, builder.state);
    try testing.expect(builder.class_val == null);
    try testing.expectEqualStrings("ZigTest_Lifecycle_Normal", cls.name());

    // Verified in global runtime
    const looked_up = objc.getClass("ZigTest_Lifecycle_Normal");
    try testing.expect(looked_up != null);
    try testing.expect(looked_up.?.eql(cls));
}

test "ClassBuilder: abort disposes allocated class pair" {
    const NSObject = objc.requireClass("NSObject");
    var builder = try objc.ClassBuilder.init("ZigTest_Lifecycle_Aborted", NSObject);
    try testing.expectEqual(objc.builder.State.allocated, builder.state);

    builder.abort();
    try testing.expectEqual(objc.builder.State.aborted, builder.state);
    try testing.expect(builder.class_val == null);

    // Class was disposed before registration, so runtime cannot find it
    try testing.expect(objc.getClass("ZigTest_Lifecycle_Aborted") == null);
}

test "ClassBuilder: errdefer abort cleans up on failure" {
    const failFn = struct {
        fn run() !void {
            const NSObject = objc.requireClass("NSObject");
            var builder = try objc.ClassBuilder.init("ZigTest_Lifecycle_Errdefer", NSObject);
            errdefer builder.abort();

            // Simulate an error during class building
            if (true) return error.SimulatedFailure;

            _ = builder.register();
        }
    }.run;

    try testing.expectError(error.SimulatedFailure, failFn());
    // Class was aborted, so it is not in the runtime
    try testing.expect(objc.getClass("ZigTest_Lifecycle_Errdefer") == null);
}

test "ClassBuilder: mutations fail outside allocated state" {
    const NSObject = objc.requireClass("NSObject");
    var builder = try objc.ClassBuilder.init("ZigTest_Lifecycle_Immutability", NSObject);
    _ = builder.register();

    // Adding ivar after registration must return InvalidState
    const ivar_res = builder.addIvar(c_int, "_foo");
    try testing.expectError(error.InvalidState, ivar_res);

    // Adding method after registration must return InvalidState
    const dummy_fn = struct {
        fn dummy(_: objc.raw.id, _: objc.raw.SEL) callconv(.c) void {}
    }.dummy;
    const method_res = builder.addMethod("dummy", dummy_fn);
    try testing.expectError(error.InvalidState, method_res);

    // Adding protocol after registration must return InvalidState
    if (objc.getProtocol("NSCopying")) |proto| {
        const proto_res = builder.addProtocol(proto);
        try testing.expectError(error.InvalidState, proto_res);
    }
}
