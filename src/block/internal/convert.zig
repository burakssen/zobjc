//! Internal conversion bridge reusing Phase 6 messaging normalization.

const messaging = @import("../../messaging/root.zig");

pub const toAbi = messaging.toAbi;
pub const fromAbi = messaging.fromAbi;
pub const AbiReturnType = messaging.AbiReturnType;
pub const AbiArgumentType = messaging.AbiArgumentType;
