//! Fundamental Objective-C runtime ABI types.
//!
//! Mirrors Apple SDK declarations in <objc/objc.h>, <objc/runtime.h>, and <objc/message.h>.
//! Contains only ABI types, pointers, constants, and layout structures with zero functions.

const std = @import("std");
const builtin = @import("builtin");

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
/// Apple's <objc/objc.h> defines BOOL conditionally:
/// - macOS and Mac Catalyst: signed char (`i8`) for historical ABI compatibility.
/// - 32-bit legacy iOS: signed char (`i8`).
/// - 64-bit iOS, tvOS, watchOS, visionOS: C99 bool (`bool`).
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
