//! Fundamental Objective-C runtime ABI types.
//!
//! Mirrors Apple SDK declarations in <objc/objc.h>, <objc/runtime.h>, and <objc/message.h>.
//! Contains only ABI types, pointers, constants, and layout structures with zero functions.

const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const raw = @import("root.zig");

// --- Opaque runtime structures ---

pub const objc_object = opaque {};
pub const objc_class = opaque {};
pub const objc_selector = opaque {};
pub const objc_method = opaque {};
pub const objc_ivar = opaque {};
pub const objc_property = opaque {};
pub const objc_category = opaque {};
pub const objc_protocol = opaque {};

// --- Fundamental pointer aliases ---

/// An opaque type that represents an Objective-C object instance (`id`).
pub const id = ?*objc_object;

/// An opaque type that represents an Objective-C class (`Class`).
pub const Class = ?*objc_class;

/// An opaque type that represents a method selector (`SEL`).
pub const SEL = ?*objc_selector;

/// An opaque type that represents an Objective-C category (`Category`).
pub const Category = ?*objc_category;

/// An opaque type that represents an Objective-C instance variable (`Ivar`).
pub const Ivar = ?*objc_ivar;

/// An opaque type that represents a method in a class definition (`Method`).
pub const Method = ?*objc_method;

/// An opaque type that represents a declared property in a class (`objc_property_t`).
pub const objc_property_t = ?*objc_property;

/// Plain-C representation of an Objective-C protocol.
/// In Apple's headers: `#ifndef __OBJC__ typedef struct objc_object Protocol; #endif`
pub const Protocol = ?*objc_object;

// --- Method Implementation Pointer ---

/// A pointer to the function of a method implementation (`IMP`).
///
/// In modern Apple runtimes (!OBJC_OLD_DISPATCH_PROTOTYPES), IMP is defined as:
/// `typedef void (*IMP)(void /* id, SEL, ... * / );`
/// It represents an untyped function pointer that must be cast to the exact ABI-correct
/// function signature before invocation.
pub const IMP = ?*const fn () callconv(.c) void;

// --- Boolean Types & Constants ---

/// Target-specific boolean representation.
///
/// Mirrors Apple's <objc/objc.h> selection, which honors the compiler's
/// predefined `__OBJC_BOOL_IS_BOOL` macro first and only falls back to
/// OS-based guessing for compilers that don't define it:
///
/// ```c
/// #if defined(__OBJC_BOOL_IS_BOOL)
///     // Honor __OBJC_BOOL_IS_BOOL when available.
/// #elif TARGET_OS_OSX || TARGET_OS_MACCATALYST || <32-bit iOS>
///     // signed char
/// #else
///     // bool
/// #endif
/// ```
///
/// Verified against Apple Clang 21 and zig cc 0.16.0: `__OBJC_BOOL_IS_BOOL`
/// is 1 for macOS arm64 and all 64-bit iOS-family targets (including the
/// x86_64 simulator), and 0 for macOS x86_64. That is exactly what the
/// architecture-first switch below encodes. Note the header's `TARGET_OS_OSX`
/// fallback text alone is misleading: with any current Clang the predefined
/// macro wins, so macOS arm64 `BOOL` is C99 `bool` (`@encode` → `"B"`).
/// The Clang differential test `checkDifferential(raw.BOOL,
/// fixture_encode_bool)` pins this per toolchain; it fails if the model and
/// the C compiler disagree.
pub const objc_bool_is_bool = switch (builtin.cpu.arch) {
    .aarch64 => true,
    else => switch (builtin.os.tag) {
        .ios, .tvos, .watchos, .visionos => builtin.cpu.arch.is64(),
        else => false,
    },
};

pub const BOOL = if (objc_bool_is_bool) bool else i8;
pub const YES: BOOL = if (objc_bool_is_bool) true else 1;
pub const NO: BOOL = if (objc_bool_is_bool) false else 0;

// --- Public ABI Structures ---

/// Specifies the superclass of an instance for super message dispatch (`struct objc_super`).
///
/// Mirrors <objc/message.h>.
pub const objc_super = extern struct {
    /// Specifies an instance of a class.
    receiver: id,
    /// Specifies the particular superclass of the instance to message.
    super_class: Class,
};

/// Defines an Objective-C method description (`struct objc_method_description`).
///
/// Mirrors <objc/runtime.h>.
pub const objc_method_description = extern struct {
    name: SEL,
    types: ?[*:0]const u8,
};

/// Defines an Objective-C property attribute (`objc_property_attribute_t`).
///
/// Mirrors <objc/runtime.h>.
pub const objc_property_attribute_t = extern struct {
    name: [*:0]const u8,
    value: [*:0]const u8,
};

test "opaque handle sizes and alignments" {
    try testing.expectEqual(@sizeOf(usize), @sizeOf(raw.id));
    try testing.expectEqual(@alignOf(usize), @alignOf(raw.id));

    try testing.expectEqual(@sizeOf(usize), @sizeOf(raw.Class));
    try testing.expectEqual(@alignOf(usize), @alignOf(raw.Class));

    try testing.expectEqual(@sizeOf(usize), @sizeOf(raw.SEL));
    try testing.expectEqual(@alignOf(usize), @alignOf(raw.SEL));

    try testing.expectEqual(@sizeOf(usize), @sizeOf(raw.IMP));
    try testing.expectEqual(@alignOf(usize), @alignOf(raw.IMP));

    try testing.expectEqual(@sizeOf(usize), @sizeOf(raw.Method));
    try testing.expectEqual(@alignOf(usize), @alignOf(raw.Method));

    try testing.expectEqual(@sizeOf(usize), @sizeOf(raw.Ivar));
    try testing.expectEqual(@alignOf(usize), @alignOf(raw.Ivar));

    try testing.expectEqual(@sizeOf(usize), @sizeOf(raw.objc_property_t));
    try testing.expectEqual(@alignOf(usize), @alignOf(raw.objc_property_t));

    try testing.expectEqual(@sizeOf(usize), @sizeOf(raw.Protocol));
    try testing.expectEqual(@alignOf(usize), @alignOf(raw.Protocol));

    try testing.expectEqual(@sizeOf(usize), @sizeOf(raw.Category));
    try testing.expectEqual(@alignOf(usize), @alignOf(raw.Category));
}

test "BOOL representation and boolean conversion helpers" {
    try testing.expectEqual(1, @sizeOf(raw.BOOL));
    try testing.expectEqual(1, @alignOf(raw.BOOL));

    // Toolchain-verified model: with current Clang, macOS arm64 BOOL is
    // C99 bool (compiler predefines __OBJC_BOOL_IS_BOOL=1); macOS x86_64
    // stays signed char. The Clang differential fixture is authoritative.
    if (builtin.os.tag == .macos and builtin.cpu.arch == .aarch64) {
        try testing.expect(raw.objc_bool_is_bool);
        try testing.expect(raw.BOOL == bool);
    }
    if (builtin.os.tag == .macos and builtin.cpu.arch == .x86_64) {
        try testing.expect(!raw.objc_bool_is_bool);
        try testing.expect(raw.BOOL == i8);
    }

    try testing.expect(raw.boolResult(raw.YES));
    try testing.expect(!raw.boolResult(raw.NO));

    try testing.expectEqual(raw.YES, raw.boolParam(true));
    try testing.expectEqual(raw.NO, raw.boolParam(false));
}

test "ABI struct memory layouts" {
    try testing.expectEqual(2 * @sizeOf(usize), @sizeOf(raw.objc_super));
    try testing.expectEqual(@alignOf(usize), @alignOf(raw.objc_super));

    const s: raw.objc_super = .{
        .receiver = null,
        .super_class = null,
    };
    try testing.expectEqual(@as(raw.id, null), s.receiver);
    try testing.expectEqual(@as(raw.Class, null), s.super_class);

    try testing.expectEqual(2 * @sizeOf(usize), @sizeOf(raw.objc_method_description));
    try testing.expectEqual(@alignOf(usize), @alignOf(raw.objc_method_description));

    try testing.expectEqual(2 * @sizeOf(usize), @sizeOf(raw.objc_property_attribute_t));
    try testing.expectEqual(@alignOf(usize), @alignOf(raw.objc_property_attribute_t));
}
