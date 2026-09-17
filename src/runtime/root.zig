//! Objective-C runtime typed entity facade.
//!
//! Exposes strongly typed, non-owning handles around Objective-C runtime entities:
//! - Object: instance handle
//! - Class: class handle
//! - Selector: selector handle (and `sel` helper, `Sel` alias)
//! - Method: method handle
//! - Ivar: instance variable handle
//! - Property: declared property handle
//! - Protocol: protocol handle
//! - Imp: implementation function pointer handle
//! - Iterator: collection fast-enumeration iterator
//!
//! Also re-exports metadata descriptor types:
//! - MethodDescription
//! - PropertyAttribute
//! - ProtocolMethodOptions
//! - ProtocolPropertyOptions
//!
//! And global runtime lookup routines:
//! - getClass, lookupClass, requireClass, getMetaClass, getProtocol
//! - allocateClassPair, registerClassPair, disposeClassPair

pub const Object = @import("object.zig").Object;
pub const Class = @import("class.zig").Class;
pub const Selector = @import("selector.zig").Selector;
pub const Sel = Selector;
pub const sel = @import("selector.zig").sel;
pub const Method = @import("method.zig").Method;
pub const Ivar = @import("ivar.zig").Ivar;
pub const Property = @import("property.zig").Property;
pub const Protocol = @import("protocol.zig").Protocol;
pub const Imp = @import("imp.zig").Imp;

// Descriptor types
pub const MethodDescription = @import("method_description.zig").MethodDescription;
pub const PropertyAttribute = @import("property_attribute.zig").PropertyAttribute;
pub const ProtocolMethodOptions = @import("protocol.zig").ProtocolMethodOptions;
pub const ProtocolPropertyOptions = @import("protocol.zig").ProtocolPropertyOptions;

// Global lookups and dynamic class pair management
pub const lookup = @import("lookup.zig");
pub const getClass = lookup.getClass;
pub const lookupClass = lookup.lookupClass;
pub const requireClass = lookup.requireClass;
pub const getMetaClass = lookup.getMetaClass;
pub const getProtocol = lookup.getProtocol;
pub const requireProtocol = lookup.requireProtocol;
pub const allocateClassPair = lookup.allocateClassPair;
pub const registerClassPair = lookup.registerClassPair;
pub const disposeClassPair = lookup.disposeClassPair;
pub const classes = lookup.classes;
pub const protocols = lookup.protocols;
pub const imageNames = image.images;
pub const images = image.images;
pub const classNamesForImage = image.classNamesForImage;

// Subsystems
pub const association = @import("association.zig");
pub const image = @import("image.zig");
pub const enumeration = @import("enumeration.zig");
pub const swizzle = @import("swizzle.zig");
pub const replacement = @import("replacement.zig");

// Associations
pub const AssociationPolicy = association.AssociationPolicy;
pub const AssociationKey = association.AssociationKey;
pub const setAssociated = association.setAssociated;
pub const associated = association.associated;
pub const clearAssociated = association.clearAssociated;
pub const associatedRetained = association.associatedRetained;

// Enumeration
pub const ImageFilter = enumeration.ImageFilter;
pub const ClassEnumerationOptions = enumeration.ClassEnumerationOptions;
pub const enumerateClasses = enumeration.enumerateClasses;
pub const hasClassEnumeration = enumeration.hasClassEnumeration;

// Swizzling & Replacement
pub const Swizzle = swizzle.Swizzle;
pub const ScopedSwizzle = swizzle.ScopedSwizzle;
pub const MethodReplacement = replacement.MethodReplacement;
pub const BlockMethodReplacement = replacement.BlockMethodReplacement;
