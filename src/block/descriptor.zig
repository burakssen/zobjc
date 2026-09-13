//! Apple Blocks ABI descriptor layout generator.
//!
//! Synthesizes compile-time typed descriptors matching Apple's libclosure memory layout.
//! Base fields (reserved, size) are followed optionally by copy/dispose helpers,
//! and optionally by signature and extended layout metadata.

const std = @import("std");

/// Returns the exact descriptor type corresponding to the given flag requirements.
pub fn Descriptor(
    comptime has_copy_dispose: bool,
    comptime has_signature: bool,
    comptime has_extended_layout: bool,
) type {
    if (has_copy_dispose and has_signature and has_extended_layout) {
        return extern struct {
            reserved: c_ulong = 0,
            size: c_ulong,
            copy: *const fn (dst: *anyopaque, src: *anyopaque) callconv(.c) void,
            dispose: *const fn (src: *anyopaque) callconv(.c) void,
            signature: [*:0]const u8,
            layout: ?*const anyopaque = null,
        };
    } else if (has_copy_dispose and has_signature and !has_extended_layout) {
        return extern struct {
            reserved: c_ulong = 0,
            size: c_ulong,
            copy: *const fn (dst: *anyopaque, src: *anyopaque) callconv(.c) void,
            dispose: *const fn (src: *anyopaque) callconv(.c) void,
            signature: [*:0]const u8,
        };
    } else if (!has_copy_dispose and has_signature and has_extended_layout) {
        return extern struct {
            reserved: c_ulong = 0,
            size: c_ulong,
            signature: [*:0]const u8,
            layout: ?*const anyopaque = null,
        };
    } else if (!has_copy_dispose and has_signature and !has_extended_layout) {
        return extern struct {
            reserved: c_ulong = 0,
            size: c_ulong,
            signature: [*:0]const u8,
        };
    } else if (has_copy_dispose and !has_signature) {
        return extern struct {
            reserved: c_ulong = 0,
            size: c_ulong,
            copy: *const fn (dst: *anyopaque, src: *anyopaque) callconv(.c) void,
            dispose: *const fn (src: *anyopaque) callconv(.c) void,
        };
    } else {
        return extern struct {
            reserved: c_ulong = 0,
            size: c_ulong,
        };
    }
}

test "Descriptor memory layout" {
    const DescSig = Descriptor(false, true, false);
    try std.testing.expectEqual(@as(usize, 24), @sizeOf(DescSig));
    try std.testing.expectEqual(@as(usize, 0), @offsetOf(DescSig, "reserved"));
    try std.testing.expectEqual(@as(usize, 8), @offsetOf(DescSig, "size"));
    try std.testing.expectEqual(@as(usize, 16), @offsetOf(DescSig, "signature"));

    const DescFull = Descriptor(true, true, true);
    try std.testing.expectEqual(@as(usize, 48), @sizeOf(DescFull));
    try std.testing.expectEqual(@as(usize, 16), @offsetOf(DescFull, "copy"));
    try std.testing.expectEqual(@as(usize, 24), @offsetOf(DescFull, "dispose"));
    try std.testing.expectEqual(@as(usize, 32), @offsetOf(DescFull, "signature"));
    try std.testing.expectEqual(@as(usize, 40), @offsetOf(DescFull, "layout"));
}
