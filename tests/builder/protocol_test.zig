//! Dynamic protocol construction and introspection tests.

const std = @import("std");
const objc = @import("objc");
const testing = std.testing;

test "ProtocolBuilder: collision detection on existing protocol" {
    // Attempting to define "NSObject" protocol must return ProtocolAlreadyExists
    const res = objc.ProtocolBuilder.init("NSObject");
    try testing.expectError(error.ProtocolAlreadyExists, res);
}

test "ProtocolBuilder: full definition lifecycle and introspection" {
    var builder = try objc.ProtocolBuilder.init("ZigTest_Proto_Lifecycle");
    errdefer builder.abort();

    // Required instance method
    try builder.addMethod(
        "serialize",
        fn (objc.Object, objc.Selector) ?objc.Object,
        .{ .required = true, .instance = true },
    );

    // Optional class method
    try builder.addMethod(
        "deserialize:",
        fn (objc.Class, objc.Selector, ?objc.Object) ?objc.Object,
        .{ .required = false, .instance = false },
    );

    // Protocol property
    try builder.addProperty(
        ?objc.Object,
        "identifier",
        .{},
        .{ .required = true, .instance = true },
    );

    // Inherit from NSCopying if available
    if (objc.getProtocol("NSCopying")) |nscopying| {
        try builder.inherit(nscopying);
    }

    const proto = builder.register();
    try testing.expectEqualStrings("ZigTest_Proto_Lifecycle", proto.name());

    // Verify method descriptions in registered protocol
    const inst_desc = proto.methodDescription(objc.sel("serialize"), .{
        .required = true,
        .instance = true,
    });
    try testing.expect(inst_desc != null);
    try testing.expectEqualStrings("serialize", inst_desc.?.selector.?.name());

    const cls_desc = proto.methodDescription(objc.sel("deserialize:"), .{
        .required = false,
        .instance = false,
    });
    try testing.expect(cls_desc != null);
    try testing.expectEqualStrings("deserialize:", cls_desc.?.selector.?.name());

    // Verify property
    const prop = proto.property("identifier", .{ .required = true, .instance = true });
    try testing.expect(prop != null);
    try testing.expectEqualStrings("identifier", prop.?.name());

    // Verify inheritance
    if (objc.getProtocol("NSCopying")) |nscopying| {
        try testing.expect(proto.conformsTo(nscopying));
    }

    // Post-registration mutations must fail
    const mut_res = builder.addMethod(
        "fail",
        fn (objc.Object, objc.Selector) void,
        .{ .required = true, .instance = true },
    );
    try testing.expectError(error.InvalidState, mut_res);
}

test "ProtocolBuilder: abort marks builder aborted" {
    var builder = try objc.ProtocolBuilder.init("ZigTest_Proto_Aborted");
    try testing.expectEqual(objc.builder.State.allocated, builder.state);

    builder.abort();
    try testing.expectEqual(objc.builder.State.aborted, builder.state);
    try testing.expect(builder.proto_val == null);
}
