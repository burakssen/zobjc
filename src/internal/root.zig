//! Internal implementation details for zobjc.
//!
//! Consumers must never rely on this module; it is an implementation detail.

pub const platform = @import("platform.zig");
pub const assertions = @import("assertions.zig");
pub const cast = @import("cast.zig");
pub const wrapper = @import("wrapper.zig");
