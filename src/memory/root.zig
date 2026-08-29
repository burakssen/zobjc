//! Memory management and ownership for Objective-C entities.
//!
//! In Phase 0, this exports AutoreleasePool.
//! Full ownership semantics (Retained, Weak, OwnedSlice) are scheduled for Phase 3.

pub const AutoreleasePool = @import("autorelease_pool.zig").AutoreleasePool;

// TODO(phase-3): Implement Retained(T), Weak(T), OwnedSlice(T), OwnedCString.
