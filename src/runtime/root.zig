//! Objective-C runtime typed entity facade.
//!
//! Exposes typed wrappers around Objective-C runtime handles (Object, Class,
//! Selector, Property, Protocol, Method, Ivar) and class lifecycle helpers.

pub const Object = @import("object.zig").Object;
pub const Class = @import("class.zig").Class;
pub const Selector = @import("selector.zig").Selector;
pub const Sel = Selector;
pub const sel = @import("selector.zig").sel;
pub const Property = @import("property.zig").Property;
pub const Protocol = @import("protocol.zig").Protocol;
pub const Method = @import("method.zig").Method;
pub const Ivar = @import("ivar.zig").Ivar;
pub const Iterator = @import("iterator.zig").Iterator;

pub const getClass = @import("class.zig").getClass;
pub const getMetaClass = @import("class.zig").getMetaClass;
pub const allocateClassPair = @import("class.zig").allocateClassPair;
pub const registerClassPair = @import("class.zig").registerClassPair;
pub const disposeClassPair = @import("class.zig").disposeClassPair;
pub const getProtocol = @import("protocol.zig").getProtocol;
