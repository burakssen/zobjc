//! Unified Objective-C messaging and invocation subsystem.
//!
//! Provides the single authoritative message dispatch pipeline for zobjc:
//! - `send(Return, receiver, selector, args)`
//! - `sendSuper(Return, receiver, current_class, selector, args)`
//! - `invoke(method, Return, receiver, args)`
//! - `callImp(Return, imp, receiver, selector, args)`
//! - `sendChecked(Return, receiver, selector, args)`

pub const send = @import("send.zig").send;
pub const sendSuper = @import("super.zig").sendSuper;
pub const sendSuperV1 = @import("super.zig").sendSuperV1;
pub const invoke = @import("invoke.zig").invoke;
pub const callImp = @import("invoke.zig").callImp;
pub const sendChecked = @import("signature.zig").sendChecked;

pub const receiver = @import("receiver.zig");
pub const selector = @import("selector.zig");
pub const arguments = @import("arguments.zig");
pub const returns = @import("returns.zig");
pub const function_type = @import("function_type.zig");
pub const dispatch = @import("dispatch.zig");
pub const validation = @import("validation.zig");
pub const signature = @import("signature.zig");

// Low-level type mappings
pub const AbiArgumentType = arguments.AbiArgumentType;
pub const AbiReturnType = returns.AbiReturnType;
pub const toAbi = arguments.toAbi;
pub const fromAbi = returns.fromAbi;
