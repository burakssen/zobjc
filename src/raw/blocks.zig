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

// Pointer to opaque instead of anyopaque: https://github.com/ziglang/zig/issues/18461
pub const _NSConcreteStackBlock = @extern(*opaque {}, .{ .name = "_NSConcreteStackBlock" });
pub const _NSConcreteMallocBlock = @extern(*opaque {}, .{ .name = "_NSConcreteMallocBlock" });

/// Copies a block from the stack to the heap, or increments its reference count.
pub extern "c" fn _Block_copy(src: *const anyopaque) ?*anyopaque;

/// Decrements the reference count of a heap block, freeing it when zero.
pub extern "c" fn _Block_release(src: *const anyopaque) void;

/// Retains/copies an object captured by a block.
pub extern "c" fn _Block_object_assign(dst: *anyopaque, src: ?*const anyopaque, flag: BlockFieldFlags) void;

/// Releases an object captured by a block.
pub extern "c" fn _Block_object_dispose(src: ?*const anyopaque, flag: BlockFieldFlags) void;
