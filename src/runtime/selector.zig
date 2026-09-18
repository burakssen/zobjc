//! Objective-C method selector representation.
//!
//! A non-owning, non-null handle to an interned Objective-C method selector (`SEL`).

const std = @import("std");
const testing = std.testing;
const raw = @import("raw");

/// Shorthand function to register and return a Selector.
pub inline fn sel(sel_name: [:0]const u8) Selector {
    return Selector.register(sel_name);
}

/// Alias of the shared selector handle; the struct lives in `internal`.
pub const Selector = @import("internal").selector.Selector;

test "selector: registration and name lookup" {
    const s1 = Selector.register("init");
    const s2 = Selector.getUid("init");
    const s3 = sel("init");
    try testing.expect(s1.eql(s2));
    try testing.expect(s1.eql(s3));
    try testing.expectEqualStrings("init", s1.name());
    try testing.expect(s1.isMapped());
}

test "selector: inequality and hashing" {
    const init_sel = sel("init");
    const dealloc_sel = sel("dealloc");
    try testing.expect(!init_sel.eql(dealloc_sel));
    try testing.expect(init_sel.hash() != 0);
    try testing.expect(dealloc_sel.hash() != 0);
    try testing.expect(init_sel.hash() != dealloc_sel.hash());
}

test "conversion: Selector fromRaw and toRaw roundtrip" {
    const raw_sel = raw.objc.sel_registerName("init");
    try testing.expect(raw_sel != null);
    try testing.expectEqual(raw_sel, Selector.fromRaw(raw_sel).?.toRaw());
    try testing.expectEqual(raw_sel, Selector.fromRawNonNull(raw_sel.?).toRaw());
    try testing.expectEqual(@as(?Selector, null), Selector.fromRaw(null));
}

test "handle: Selector is pointer-sized and pointer-aligned" {
    try testing.expectEqual(@sizeOf(usize), @sizeOf(Selector));
    try testing.expectEqual(@alignOf(usize), @alignOf(Selector));
}
