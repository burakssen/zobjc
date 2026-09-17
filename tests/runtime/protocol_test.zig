//! Protocol handle tests.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

test "protocol: NSObject protocol introspection" {
    const proto = objc.getProtocol("NSObject") orelse return error.ProtocolNotFound;

    // Name
    try testing.expectEqualStrings("NSObject", proto.name());

    // Protocol equality
    const proto_again = objc.getProtocol("NSObject").?;
    try testing.expect(proto.eql(proto_again));

    // Self-conformance
    try testing.expect(proto.conformsTo(proto));

    // Method description lookup
    const desc_desc = proto.methodDescription(objc.sel("description"), .{
        .required = true,
        .instance = true,
    });
    try testing.expect(desc_desc != null);
    try testing.expect(desc_desc.?.selector != null);
    try testing.expect(desc_desc.?.selector.?.eql(objc.sel("description")));

    // Optional method that does not exist in required set
    const non_existent = proto.methodDescription(objc.sel("nonExistentSelector123"), .{
        .required = true,
        .instance = true,
    });
    try testing.expectEqual(@as(?objc.MethodDescription, null), non_existent);
}

test "protocol: requireProtocol succeeds on valid protocol" {
    const proto = objc.requireProtocol("NSObject");
    try testing.expect(std.mem.eql(u8, "NSObject", proto.name()));
}
