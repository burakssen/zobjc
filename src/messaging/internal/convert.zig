//! Internal conversion bridge between public types and ABI representations.

const arguments_mod = @import("../arguments.zig");
const returns_mod = @import("../returns.zig");

pub const toAbi = arguments_mod.toAbi;
pub const fromAbi = returns_mod.fromAbi;
pub const AbiArgumentType = arguments_mod.AbiArgumentType;
pub const AbiReturnType = returns_mod.AbiReturnType;
