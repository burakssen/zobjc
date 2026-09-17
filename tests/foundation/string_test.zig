//! Unit tests for NSString wrapper and UTF-8 bridging.
// ponytail: minimalist tests for NSString construction, UTF-8 conversion, and ownership lifecycle.

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");
const foundation = @import("objc_foundation");
const NSString = foundation.NSString;

test "NSString: fromUTF8 autoreleased creation" {
    var pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    const str = NSString.fromUTF8("Hello, Objective-C!") orelse return error.StringCreationFailed;
    try testing.expectEqual(@as(usize, 19), str.lengthUtf16());

    const cstr = str.utf8CString().?;
    try testing.expectEqualStrings("Hello, Objective-C!", cstr);

    const r = str.range();
    try testing.expectEqual(@as(usize, 0), r.location);
    try testing.expectEqual(@as(usize, 19), r.length);
}

test "NSString: fromUTF8Owned retained lifecycle" {
    var owned_str = NSString.fromUTF8Owned("Owned NSString String") orelse return error.StringCreationFailed;
    defer owned_str.deinit();

    const borrowed = owned_str.borrow();
    try testing.expectEqual(@as(usize, 21), borrowed.lengthUtf16());

    // Clone retained wrapper
    var cloned = owned_str.clone();
    defer cloned.deinit();

    try testing.expect(cloned.borrow().isEqualToString(borrowed));
}

test "NSString: fromUTF8SliceOwned with subslice" {
    const full_text = "The quick brown fox jumps over the lazy dog";
    const subslice = full_text[4..9]; // "quick"

    var owned = NSString.fromUTF8SliceOwned(subslice) orelse return error.StringCreationFailed;
    defer owned.deinit();

    try testing.expectEqual(@as(usize, 5), owned.borrow().lengthUtf16());
    try testing.expectEqualStrings("quick", owned.borrow().utf8CString().?);
}

test "NSString: toUTF8Alloc caller allocation" {
    const allocator = testing.allocator;

    var owned = NSString.fromUTF8Owned("Allocated UTF-8 slice test") orelse return error.StringCreationFailed;
    defer owned.deinit();

    const copy = try owned.borrow().toUTF8Alloc(allocator);
    defer allocator.free(copy);

    try testing.expectEqualStrings("Allocated UTF-8 slice test", copy);
}

test "NSString: equality and hash" {
    var s1 = NSString.fromUTF8Owned("Identical Content") orelse return error.StringCreationFailed;
    defer s1.deinit();

    var s2 = NSString.fromUTF8Owned("Identical Content") orelse return error.StringCreationFailed;
    defer s2.deinit();

    var s3 = NSString.fromUTF8Owned("Different Content") orelse return error.StringCreationFailed;
    defer s3.deinit();

    try testing.expect(s1.borrow().isEqualToString(s2.borrow()));
    try testing.expect(!s1.borrow().isEqualToString(s3.borrow()));
    try testing.expectEqual(s1.borrow().hash(), s2.borrow().hash());
}

test "NSString: Unicode UTF-8 and UTF-16 roundtrip (Turkish and emoji)" {
    var pool = objc.AutoreleasePool.init();
    defer pool.deinit();

    // Turkish text: "İstanbul, Türkiye: şçğöü"
    const turkish = "İstanbul, Türkiye: şçğöü";
    const str_tr = NSString.fromUTF8(turkish).?;
    try testing.expectEqualStrings(turkish, str_tr.utf8CString().?);

    // Emoji and non-BMP: "🚀✨ Objective-C "
    const emoji = "🚀✨ Objective-C ";
    const str_emoji = NSString.fromUTF8(emoji).?;
    try testing.expectEqualStrings(emoji, str_emoji.utf8CString().?);
}
