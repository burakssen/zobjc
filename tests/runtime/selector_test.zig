//! Selector handle tests.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

test "selector: registration and name lookup" {
    const s1 = objc.Selector.register("init");
    const s2 = objc.Selector.getUid("init");
    const s3 = objc.sel("init");

    try testing.expect(s1.eql(s2));
    try testing.expect(s1.eql(s3));
    try testing.expectEqualStrings("init", s1.name());
    try testing.expect(s1.isMapped());
}

test "selector: inequality and hashing" {
    const init_sel = objc.sel("init");
    const dealloc_sel = objc.sel("dealloc");

    try testing.expect(!init_sel.eql(dealloc_sel));
    try testing.expect(init_sel.hash() != 0);
    try testing.expect(dealloc_sel.hash() != 0);
    try testing.expect(init_sel.hash() != dealloc_sel.hash());
}
