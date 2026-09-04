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
pub const Iterator = @import("iterator.zig").Iterator;

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
pub const allocateClassPair = lookup.allocateClassPair;
pub const registerClassPair = lookup.registerClassPair;
pub const disposeClassPair = lookup.disposeClassPair;
pub const classes = lookup.classes;
pub const protocols = lookup.protocols;
pub const imageNames = lookup.imageNames;
pub const classNamesForImage = lookup.classNamesForImage;
