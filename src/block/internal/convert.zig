//! Internal conversion bridge reusing messaging normalization.

const messaging = @import("messaging");

pub const toAbi = messaging.toAbi;
pub const fromAbi = messaging.fromAbi;
pub const AbiReturnType = messaging.AbiReturnType;
pub const AbiArgumentType = messaging.AbiArgumentType;
