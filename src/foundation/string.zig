//! High-level, zero-overhead NSString handle.
// ponytail: minimalist zero-overhead wrapper over Object, automatic Retained(NSString) integration via Phase 3 traits.

const std = @import("std");
const objc = @import("objc");
const types = @import("types.zig");
const NSRange = types.NSRange;
const StringEncoding = types.StringEncoding;

/// A non-owning, typed handle to an Objective-C `NSString` instance.
///
/// Implements `.asObject()` and `.fromObject()`, allowing seamless participation
/// in `objc.Retained(NSString)` and `objc.Weak(NSString)`.
pub const NSString = struct {
    object: objc.Object,

    // --- Retainable Traits Integration ---

    pub inline fn asObject(self: NSString) objc.Object {
        return self.object;
    }

    pub inline fn fromObject(obj: objc.Object) NSString {
        return .{ .object = obj };
    }

    pub inline fn toRaw(self: NSString) objc.raw.id {
        return self.object.ptr;
    }

    pub inline fn fromRaw(raw_id: objc.raw.id) ?NSString {
        const obj = objc.Object.fromId(raw_id) orelse return null;
        return .{ .object = obj };
    }

    // --- Explicit Memory Management ---

    pub inline fn retain(self: NSString) NSString {
        return NSString.fromObject(self.object.retain());
    }

    pub inline fn release(self: NSString) void {
        self.object.release();
    }

    pub inline fn autorelease(self: NSString) NSString {
        const ptr = objc.raw.compiler_runtime.objc_autorelease(self.object.ptr);
        return NSString.fromObject(objc.Object.fromRawNonNull(ptr.?));
    }

    // --- Constructors ---

    /// Creates an autoreleased (+0) NSString from a null-terminated UTF-8 slice.
    /// Calls `+[NSString stringWithUTF8String:]`.
    pub fn fromUTF8(bytes: [:0]const u8) ?NSString {
        const cls = objc.getClass("NSString") orelse return null;
        const obj = objc.send(?objc.Object, cls, "stringWithUTF8String:", .{bytes.ptr}) orelse return null;
        return NSString.fromObject(obj);
    }

    /// Creates an owned (+1) `Retained(NSString)` from a null-terminated UTF-8 slice.
    /// Calls `[[NSString alloc] initWithUTF8String:]`.
    pub fn fromUTF8Owned(bytes: [:0]const u8) ?objc.Retained(NSString) {
        const cls = objc.getClass("NSString") orelse return null;
        const allocated = objc.send(objc.Object, cls, "alloc", .{});
        const initialized = objc.send(?objc.Object, allocated, "initWithUTF8String:", .{bytes.ptr}) orelse return null;
        return objc.Retained(NSString).adopt(NSString.fromObject(initialized));
    }

    /// Creates an owned (+1) `Retained(NSString)` from a standard non-null-terminated UTF-8 slice.
    /// Calls `[[NSString alloc] initWithBytes:length:encoding:]`.
    pub fn fromUTF8SliceOwned(bytes: []const u8) ?objc.Retained(NSString) {
        const cls = objc.getClass("NSString") orelse return null;
        const allocated = objc.send(objc.Object, cls, "alloc", .{});
        const initialized = objc.send(
            ?objc.Object,
            allocated,
            "initWithBytes:length:encoding:",
            .{
                bytes.ptr,
                bytes.len,
                StringEncoding.UTF8,
            },
        ) orelse return null;
        return objc.Retained(NSString).adopt(NSString.fromObject(initialized));
    }

    // --- Inspection ---

    /// Returns the number of UTF-16 code units in the string (matching `-[NSString length]`).
    pub inline fn lengthUtf16(self: NSString) usize {
        return objc.send(usize, self.object, "length", .{});
    }

    /// Returns the full range of the string in UTF-16 code units.
    pub inline fn range(self: NSString) NSRange {
        return NSRange.init(0, self.lengthUtf16());
    }

    /// Returns a borrowed UTF-8 C string pointer.
    ///
    /// CAUTION: The returned slice points directly into Cocoa autoreleased or internal storage.
    /// It must not be retained beyond the active autorelease pool scope.
    pub fn utf8CString(self: NSString) ?[:0]const u8 {
        const c_str = objc.send(?[*:0]const u8, self.object, "UTF8String", .{}) orelse return null;
        return std.mem.span(c_str);
    }

    /// Allocates and copies a UTF-8 representation of this string into a caller-owned slice.
    pub fn toUTF8Alloc(self: NSString, allocator: std.mem.Allocator) ![]u8 {
        if (self.utf8CString()) |c_str| {
            return try allocator.dupe(u8, c_str);
        }
        return error.StringEncodingFailed;
    }

    /// Tests string content equality via `-[NSString isEqualToString:]`.
    pub inline fn isEqualToString(self: NSString, other: NSString) bool {
        return objc.send(bool, self.object, "isEqualToString:", .{other.object});
    }

    /// Returns the hash value of this string via `-[NSObject hash]`.
    pub inline fn hash(self: NSString) usize {
        return objc.send(usize, self.object, "hash", .{});
    }

    /// Returns the description of this string.
    pub inline fn description(self: NSString) NSString {
        const desc = objc.send(objc.Object, self.object, "description", .{});
        return NSString.fromObject(desc);
    }
};

comptime {
    std.debug.assert(@sizeOf(NSString) == @sizeOf(objc.Object));
    std.debug.assert(@alignOf(NSString) == @alignOf(objc.Object));
}
