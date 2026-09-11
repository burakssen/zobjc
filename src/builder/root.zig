//! Stateful dynamic class and protocol builder subsystem facade.

pub const state = @import("state.zig");
pub const errors = @import("errors.zig");
pub const ivar = @import("ivar.zig");
pub const method = @import("method.zig");
pub const property = @import("property.zig");
pub const class = @import("class.zig");
pub const protocol = @import("protocol.zig");

// Public builder types
pub const State = state.State;
pub const ClassBuilder = class.ClassBuilder;
pub const ProtocolBuilder = protocol.ProtocolBuilder;
pub const PropertyOptions = property.PropertyOptions;

// Public error sets
pub const ClassBuilderError = errors.ClassBuilderError;
pub const ProtocolBuilderError = errors.ProtocolBuilderError;

// Functional builder helpers
pub const addIvar = ivar.addIvar;
pub const addIvarEncoded = ivar.addIvarEncoded;
pub const addMethodToClass = method.addMethodToClass;
pub const addPropertyToClass = property.addPropertyToClass;
pub const addPropertyToProtocol = property.addPropertyToProtocol;
