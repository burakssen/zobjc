//! Typed Objective-C property attribute representation.

const std = @import("std");
const testing = std.testing;
const raw = @import("raw");

/// Alias of the shared property attribute struct.
pub const PropertyAttribute = @import("internal").metadata.PropertyAttribute;
