//! Block signature metadata.
//!
//! Provides compile-time type encoding generation for Apple Block signatures.

const std = @import("std");
const encoding = @import("encoding");

/// Generates a static null-terminated Objective-C Block signature string (e.g. `v@?i`).
pub const blockSignature = encoding.blockSignature;
pub const blockSignatureLength = encoding.blockSignatureLength;

test "blockSignature facade" {
    const sig = blockSignature(fn (c_int) c_int);
    try std.testing.expectEqualStrings("i@?i", sig);
}
