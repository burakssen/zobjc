//! Objective-C Darwin ABI classification and messenger dispatch convention subsystem.
//!
//! Provides compile-time ABI analysis to answer:
//! "Given target architecture + Zig return type T, which Objective-C runtime entry point must be used?"
//!
//! Public API:
//! - `Target`: target platform and architecture model.
//! - `ReturnConvention`: `.normal`, `.stret`, `.fpret`, `.fp2ret`.
//! - `ReturnInfo`: rich size, alignment, indirectness, and convention metadata.
//! - `ABIResult`: low-level platform return mechanism (.direct, .indirect, .x87, .complex_x87).
//! - `returnConvention(T)`: determines runtime messenger for native target.
//! - `returnConventionFor(target, T)`: determines runtime messenger for explicit target.
//! - `classifyReturn(target, T)`: determines low-level direct vs indirect return mechanism.
//! - `returnInfo(target, T)`: returns full layout and convention descriptor.

pub const target = @import("target.zig");
pub const Target = target.Target;

pub const convention = @import("convention.zig");
pub const ReturnConvention = convention.ReturnConvention;
pub const ReturnInfo = convention.ReturnInfo;
pub const ABIResult = convention.ABIResult;

pub const layout = @import("layout.zig");
pub const classify = @import("classify.zig");

pub const returnConvention = classify.returnConvention;
pub const returnConventionFor = classify.returnConventionFor;
pub const classifyReturn = classify.classifyReturn;
pub const returnInfo = classify.returnInfo;

// Sub-architecture access for advanced testing/inspection
pub const aarch64 = @import("aarch64.zig");
pub const x86_64 = @import("x86_64.zig");
