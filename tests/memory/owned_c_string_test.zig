//! Owned C string tests (OwnedCString).

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

test "OwnedCString: method.copyReturnType" {
    const NSObject = objc.requireClass("NSObject");
    const desc_method = NSObject.instanceMethod(objc.sel("description")).?;

    var ret_type = desc_method.copyReturnType().?;
    defer ret_type.deinit();

    // Objective-C object encoding is "@"
    try testing.expectEqualStrings("@", ret_type.slice());
    try testing.expectEqual(@as(usize, 1), ret_type.len());

    // Multiple deinit is idempotent
    ret_type.deinit();
    try testing.expectEqual(@as(usize, 0), ret_type.len());
}

test "OwnedCString: method.copyArgumentType" {
    const NSObject = objc.requireClass("NSObject");
    const is_equal_method = NSObject.instanceMethod(objc.sel("isEqual:")).?;

    // Argument 0: self (@)
    var arg0 = is_equal_method.copyArgumentType(0).?;
    defer arg0.deinit();
    try testing.expectEqualStrings("@", arg0.slice());

    // Argument 1: _cmd (:)
    var arg1 = is_equal_method.copyArgumentType(1).?;
    defer arg1.deinit();
    try testing.expectEqualStrings(":", arg1.slice());

    // Argument 2: object (@)
    var arg2 = is_equal_method.copyArgumentType(2).?;
    defer arg2.deinit();
    try testing.expectEqualStrings("@", arg2.slice());

    // Argument out of bounds returns null
    const out_of_bounds = is_equal_method.copyArgumentType(99);
    try testing.expect(out_of_bounds == null);
}

test "OwnedCString: property.copyAttributeValue" {
    const NSObject = objc.requireClass("NSObject");
    if (NSObject.getProperty("className")) |prop| {
        if (prop.copyAttributeValue("T")) |val| {
            var mut_val = val;
            defer mut_val.deinit();
            try testing.expect(mut_val.len() > 0);
            try testing.expect(mut_val.slice().len > 0);
        }
    }
}

test "OwnedCString: intoRaw relinquishes ownership" {
    const NSObject = objc.requireClass("NSObject");
    const desc_method = NSObject.instanceMethod(objc.sel("description")).?;

    var ret_type = desc_method.copyReturnType().?;
    const raw_ptr = ret_type.intoRaw();

    // ret_type is now empty
    try testing.expectEqual(@as(usize, 0), ret_type.len());
    ret_type.deinit(); // safe no-op

    // Verify raw pointer contains "@"
    try testing.expectEqualStrings("@", std.mem.span(raw_ptr));

    // Caller is now responsible for freeing raw_ptr
    objc.free(raw_ptr);
}

test "OwnedCString: empty fromRaw(null)" {
    const empty_str = objc.OwnedCString.fromRaw(null);
    try testing.expect(empty_str == null);
}
