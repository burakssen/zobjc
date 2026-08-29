//! Unified Objective-C message dispatch.
//!
//! In Phase 6, this module will provide the central messaging API:
//! - send(comptime Return, target, selector, args)
//! - sendSuper(comptime Return, target, superclass, selector, args)
//! - invoke(comptime Return, method, target, args)
//!
//! In Phase 0, message dispatch is handled by MsgSend and the methods on Object and Class.

pub const MsgSend = @import("msg_send.zig").MsgSend;
pub const MsgSendFn = @import("msg_send.zig").MsgSendFn;

// TODO(phase-6): Route all messaging through a unified send() engine.
