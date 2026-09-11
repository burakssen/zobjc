//! Builder lifecycle state machine.

const std = @import("std");

/// Lifecycle states for ClassBuilder and ProtocolBuilder.
pub const State = enum {
    allocated,
    registered,
    aborted,
};

/// Asserts or validates that the builder is in the `.allocated` state.
pub fn requireAllocated(state: State) error{InvalidState}!void {
    if (state != .allocated) return error.InvalidState;
}
