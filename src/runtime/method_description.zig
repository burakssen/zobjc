//! Typed Objective-C method description representation (alias).
//!
//! The struct lives in `internal/metadata.zig` so `memory` can name it
//! without depending on `runtime`.

/// Alias of the shared method description struct.
pub const MethodDescription = @import("internal").metadata.MethodDescription;
