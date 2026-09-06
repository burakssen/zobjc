//! Objective-C runtime raw ABI layer.
//!
//! Authoritative low-level boundary between Zig and Apple's libobjc.
//! Exposes exact, unopinionated C declarations without higher-level policies or wrappers.

pub const types = @import("types.zig");
pub const objc = @import("objc.zig");
pub const runtime = @import("runtime.zig");
pub const message = @import("message.zig");
pub const blocks = @import("blocks.zig");
pub const compiler_runtime = @import("compiler_runtime.zig");
pub const availability = @import("availability.zig");
pub const deprecated = @import("deprecated.zig");

// --- Fundamental Types ---

pub const objc_object = types.objc_object;
pub const objc_class = types.objc_class;
pub const objc_selector = types.objc_selector;
pub const objc_method = types.objc_method;
pub const objc_ivar = types.objc_ivar;
pub const objc_property = types.objc_property;
pub const objc_category = types.objc_category;

pub const id = types.id;
pub const Class = types.Class;
pub const SEL = types.SEL;
pub const IMP = types.IMP;
pub const Method = types.Method;
pub const Ivar = types.Ivar;
pub const objc_property_t = types.objc_property_t;
pub const Protocol = types.Protocol;
pub const Category = types.Category;

pub const BOOL = types.BOOL;
pub const YES = types.YES;
pub const NO = types.NO;
pub const objc_bool_is_bool = types.objc_bool_is_bool;

pub const objc_super = types.objc_super;
pub const objc_method_description = types.objc_method_description;
pub const objc_property_attribute_t = types.objc_property_attribute_t;

// --- Boolean Helpers ---

/// Converts a target-specific Objective-C BOOL into a Zig bool.
pub inline fn boolResult(result: BOOL) bool {
    if (BOOL == bool) return result;
    return result == 1;
}

/// Converts a Zig bool into a target-specific Objective-C BOOL.
pub inline fn boolParam(param: bool) BOOL {
    if (BOOL == bool) return param;
    return @intFromBool(param);
}

// --- Compatibility Bridge ---
// Provides a backward-compatible 'c' namespace for existing callers during migration.
pub const c = struct {
    pub const id = types.id;
    pub const Class = types.Class;
    pub const SEL = types.SEL;
    pub const IMP = types.IMP;
    pub const Method = types.Method;
    pub const Ivar = types.Ivar;
    pub const objc_property_t = types.objc_property_t;
    pub const Protocol = types.Protocol;
    pub const BOOL = types.BOOL;
    pub const objc_super = types.objc_super;

    // Functions forwarded to raw modules
    pub const sel_registerName = objc.sel_registerName;
    pub const sel_getName = objc.sel_getName;
    pub const objc_getClass = runtime.objc_getClass;
    pub const objc_getMetaClass = runtime.objc_getMetaClass;
    pub const objc_allocateClassPair = runtime.objc_allocateClassPair;
    pub const objc_registerClassPair = runtime.objc_registerClassPair;
    pub const objc_disposeClassPair = runtime.objc_disposeClassPair;
    pub const objc_getProtocol = runtime.objc_getProtocol;
    pub const objc_enumerationMutation = runtime.objc_enumerationMutation;
    pub const objc_msgSend = message.objc_msgSend;
    pub const objc_msgSendSuper = message.objc_msgSendSuper;
};
