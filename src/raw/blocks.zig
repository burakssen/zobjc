//! Objective-C Blocks ABI and runtime declarations.
//!
//! Mirrors compiler-rt / Apple BlocksRuntime ABI structures and helper entry points.

const std = @import("std");

/// Flags passed to _Block_object_assign and _Block_object_dispose.
///
/// https://github.com/llvm/llvm-project/blob/main/compiler-rt/lib/BlocksRuntime/Block_private.h
pub const BlockFieldFlags = enum(c_int) {
    object = 3, // BLOCK_FIELD_IS_OBJECT
    block = 7, // BLOCK_FIELD_IS_BLOCK
    byref = 8, // BLOCK_FIELD_IS_BYREF
    weak = 16, // BLOCK_FIELD_IS_WEAK
    byref_caller = 128, // BLOCK_BYREF_CALLER
};

// Raw bit flag constants for _Block_object_assign and _Block_object_dispose.
pub const BLOCK_FIELD_IS_OBJECT: c_int = 3;
pub const BLOCK_FIELD_IS_BLOCK: c_int = 7;
pub const BLOCK_FIELD_IS_BYREF: c_int = 8;
pub const BLOCK_FIELD_IS_WEAK: c_int = 16;
pub const BLOCK_BYREF_CALLER: c_int = 128;

// Block literal flag constants (stored in BlockLiteral.flags).
pub const BLOCK_DEALLOCATING: c_int = 0x0001;
pub const BLOCK_REFCOUNT_MASK: c_int = 0xfffe;
pub const BLOCK_INLINE_LAYOUT_STRING: c_int = 1 << 21;
pub const BLOCK_IS_NOESCAPE: c_int = 1 << 23;
pub const BLOCK_NEEDS_FREE: c_int = 1 << 24;
pub const BLOCK_HAS_COPY_DISPOSE: c_int = 1 << 25;
pub const BLOCK_HAS_CTOR: c_int = 1 << 26;
pub const BLOCK_IS_GC: c_int = 1 << 27;
pub const BLOCK_IS_GLOBAL: c_int = 1 << 28;
pub const BLOCK_USE_STRET: c_int = 1 << 29;
pub const BLOCK_HAS_SIGNATURE: c_int = 1 << 30;
pub const BLOCK_HAS_EXTENDED_LAYOUT: c_int = @as(c_int, @bitCast(@as(u32, 1 << 31)));

// ByRef structure flag constants (stored in Block_byref.flags).
pub const BLOCK_BYREF_LAYOUT_MASK: c_int = @as(c_int, @bitCast(@as(u32, 0xf << 28)));
pub const BLOCK_BYREF_LAYOUT_EXTENDED: c_int = 1 << 28;
pub const BLOCK_BYREF_LAYOUT_NON_OBJECT: c_int = 2 << 28;
pub const BLOCK_BYREF_LAYOUT_STRONG: c_int = 3 << 28;
pub const BLOCK_BYREF_LAYOUT_WEAK: c_int = 4 << 28;
pub const BLOCK_BYREF_LAYOUT_UNRETAINED: c_int = 5 << 28;
pub const BLOCK_BYREF_IS_GC: c_int = 1 << 27;
pub const BLOCK_BYREF_HAS_COPY_DISPOSE: c_int = 1 << 25;
pub const BLOCK_BYREF_NEEDS_FREE: c_int = 1 << 24;

/// Bitfield flags stored in BlockLiteral.flags.
pub const BlockFlags = packed struct(c_int) {
    _unused: u23 = 0,
    noescape: bool = false,
    _unused_2: u1 = 0,
    copy_dispose: bool = false,
    ctor: bool = false,
    _unused_3: u1 = 0,
    global: bool = false,
    stret: bool = false,
    signature: bool = false,
    _unused_4: u1 = 0,
};

/// Block descriptor structure holding size and copy/dispose helpers.
pub const BlockDescriptor = extern struct {
    reserved: c_ulong = 0,
    size: c_ulong,
    copy_helper: ?*const fn (dst: *anyopaque, src: *anyopaque) callconv(.c) void = null,
    dispose_helper: ?*const fn (src: *anyopaque) callconv(.c) void = null,
    signature: ?[*:0]const u8 = null,
};

/// Low-level memory layout of an Objective-C Block literal.
pub const BlockLiteral = extern struct {
    isa: ?*const anyopaque,
    flags: c_int,
    reserved: c_int,
    invoke: ?*const anyopaque,
    descriptor: *const BlockDescriptor,
};

/// Canonical Apple runtime Block layout type alias.
pub const Block_layout = BlockLiteral;

/// Low-level memory layout of an Objective-C __block (byref) forwarding cell header.
pub const Block_byref = extern struct {
    isa: ?*anyopaque,
    forwarding: *Block_byref,
    flags: c_int,
    size: u32,
};

// Pointer to opaque instead of anyopaque: https://github.com/ziglang/zig/issues/18461
pub const _NSConcreteStackBlock = @extern(*opaque {}, .{ .name = "_NSConcreteStackBlock" });
pub const _NSConcreteMallocBlock = @extern(*opaque {}, .{ .name = "_NSConcreteMallocBlock" });
pub const _NSConcreteGlobalBlock = @extern(*opaque {}, .{ .name = "_NSConcreteGlobalBlock" });

/// Copies a block from the stack to the heap, or increments its reference count.
pub extern "c" fn _Block_copy(src: *const anyopaque) ?*anyopaque;

/// Decrements the reference count of a heap block, freeing it when zero.
pub extern "c" fn _Block_release(src: *const anyopaque) void;

/// Retains/copies an object captured by a block.
pub extern "c" fn _Block_object_assign(dst: *anyopaque, src: ?*const anyopaque, flag: c_int) void;

/// Releases an object captured by a block.
pub extern "c" fn _Block_object_dispose(src: ?*const anyopaque, flag: c_int) void;
