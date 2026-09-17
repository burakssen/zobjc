//! Capture traits analysis for Apple Blocks.
//!
//! Classifies capture field types into trivial values, strong objects, blocks, weak objects,
//! or byref forwarding cells, and determines required copy/dispose helpers and layout metadata.

const std = @import("std");
const raw = @import("raw");

pub const CaptureCategory = enum {
    trivial,
    strong,
    block,
    weak,
    byref,
};

/// Analyzes type `T` to determine its Block capture semantics.
pub fn CaptureTraits(comptime T: type) type {
    @setEvalBranchQuota(50000);
    comptime {
        validateCaptureType(T);
    }

    const is_container = switch (@typeInfo(T)) {
        .@"struct", .@"enum", .@"union", .@"opaque" => true,
        else => false,
    };

    if (is_container) {
        if (@hasDecl(T, "_is_zobjc_strong") and T._is_zobjc_strong) {
            return struct {
                pub const category: CaptureCategory = .strong;
                pub const requires_helpers = true;
                pub const field_flags: c_int = raw.blocks.BLOCK_FIELD_IS_OBJECT;
                pub const Storage = T;

                pub inline fn copy(dst: *Storage, src: *const Storage) void {
                    raw.blocks._Block_object_assign(
                        @ptrCast(&dst.raw_ptr),
                        src.raw_ptr,
                        raw.blocks.BLOCK_FIELD_IS_OBJECT,
                    );
                }

                pub inline fn dispose(src: *const Storage) void {
                    raw.blocks._Block_object_dispose(
                        src.raw_ptr,
                        raw.blocks.BLOCK_FIELD_IS_OBJECT,
                    );
                }
            };
        } else if (@hasDecl(T, "_is_zobjc_block_ref") and T._is_zobjc_block_ref) {
            return struct {
                pub const category: CaptureCategory = .block;
                pub const requires_helpers = true;
                pub const field_flags: c_int = raw.blocks.BLOCK_FIELD_IS_BLOCK;
                pub const Storage = T;

                pub inline fn copy(dst: *Storage, src: *const Storage) void {
                    raw.blocks._Block_object_assign(
                        @ptrCast(&dst.raw_ptr),
                        @ptrCast(src.raw_ptr),
                        raw.blocks.BLOCK_FIELD_IS_BLOCK,
                    );
                }

                pub inline fn dispose(src: *const Storage) void {
                    raw.blocks._Block_object_dispose(
                        @ptrCast(src.raw_ptr),
                        raw.blocks.BLOCK_FIELD_IS_BLOCK,
                    );
                }
            };
        } else if (@hasDecl(T, "_is_zobjc_weak") and T._is_zobjc_weak) {
            return struct {
                pub const category: CaptureCategory = .weak;
                pub const requires_helpers = true;
                pub const field_flags: c_int = raw.blocks.BLOCK_FIELD_IS_WEAK | raw.blocks.BLOCK_FIELD_IS_OBJECT;
                pub const Storage = T;

                pub inline fn copy(dst: *Storage, src: *const Storage) void {
                    raw.blocks._Block_object_assign(
                        @ptrCast(&dst.raw_ptr),
                        src.raw_ptr,
                        raw.blocks.BLOCK_FIELD_IS_WEAK | raw.blocks.BLOCK_FIELD_IS_OBJECT,
                    );
                }

                pub inline fn dispose(src: *const Storage) void {
                    raw.blocks._Block_object_dispose(
                        src.raw_ptr,
                        raw.blocks.BLOCK_FIELD_IS_WEAK | raw.blocks.BLOCK_FIELD_IS_OBJECT,
                    );
                }
            };
        } else if (@hasDecl(T, "_is_zobjc_byref_capture") and T._is_zobjc_byref_capture) {
            return struct {
                pub const category: CaptureCategory = .byref;
                pub const requires_helpers = true;
                pub const field_flags: c_int = raw.blocks.BLOCK_FIELD_IS_BYREF;
                pub const Storage = T;

                pub inline fn copy(dst: *Storage, src: *const Storage) void {
                    raw.blocks._Block_object_assign(
                        @ptrCast(&dst.cell_ptr),
                        src.cell_ptr,
                        raw.blocks.BLOCK_FIELD_IS_BYREF,
                    );
                }

                pub inline fn dispose(src: *const Storage) void {
                    raw.blocks._Block_object_dispose(
                        src.cell_ptr,
                        raw.blocks.BLOCK_FIELD_IS_BYREF,
                    );
                }
            };
        }
    }

    // Trivial value capture
    return struct {
        pub const category: CaptureCategory = .trivial;
        pub const requires_helpers = false;
        pub const field_flags: c_int = 0;
        pub const Storage = T;

        pub inline fn copy(_: *Storage, _: *const Storage) void {}
        pub inline fn dispose(_: *const Storage) void {}
    };
}

/// Validates that `T` is permitted as a Block capture.
fn validateCaptureType(comptime T: type) void {
    const name = @typeName(T);
    if (std.mem.indexOf(u8, name, "Retained") != null) {
        @compileError("Cannot capture Retained(T) directly in a Block; use objc.block.Strong(T) instead");
    }
    if (std.mem.indexOf(u8, name, "OwnedBlock") != null) {
        @compileError("Cannot capture OwnedBlock directly; use objc.block.BlockRef(Signature) instead");
    }
    if (std.mem.indexOf(u8, name, "OwnedCString") != null or std.mem.indexOf(u8, name, "OwnedRuntimeList") != null) {
        @compileError("Cannot capture owned runtime containers directly in a Block; capture by pointer or ByRef instead");
    }
    if (std.mem.indexOf(u8, name, "ArrayList") != null or std.mem.indexOf(u8, name, "HashMap") != null) {
        @compileError("Cannot capture allocator-owning Zig collections directly in a Block");
    }
    if (@typeInfo(T) == .pointer and @typeInfo(T).pointer.size == .slice) {
        @compileError("Cannot capture Zig slices across the Objective-C Block ABI; capture pointer + length explicitly");
    }
    if (@typeInfo(T) == .comptime_int or @typeInfo(T) == .comptime_float) {
        @compileError("Cannot capture comptime-only values in a Block; use explicit types like c_int or f64");
    }
}

test "CaptureTraits classification" {
    const strong_mod = @import("strong.zig");
    const Object = @import("runtime").Object;

    const IntTraits = CaptureTraits(c_int);
    try std.testing.expectEqual(CaptureCategory.trivial, IntTraits.category);
    try std.testing.expect(!IntTraits.requires_helpers);

    const StrongTraits = CaptureTraits(strong_mod.Strong(Object));
    try std.testing.expectEqual(CaptureCategory.strong, StrongTraits.category);
    try std.testing.expect(StrongTraits.requires_helpers);
    try std.testing.expectEqual(raw.blocks.BLOCK_FIELD_IS_OBJECT, StrongTraits.field_flags);
}
