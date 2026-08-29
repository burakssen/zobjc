//! Internal implementation details for zobjc.
//!
//! Consumers must never rely on @import("objc").internal.

pub const platform = @import("platform.zig");
pub const assertions = @import("assertions.zig");
pub const cast = @import("cast.zig");
