//! Objective-C runtime raw ABI declarations.
//!
//! In Phase 0, this module bridges the translated Objective-C headers (`objc-c`).
//! In Phase 1, this module will provide complete, direct handwritten ABI declarations
//! (`objc.raw.runtime.*`) without convenience behavior or ownership policies.

// TODO(phase-1): Replace translated header dependency with handwritten raw declarations.
pub const c = @import("objc-c");

/// On some targets, Objective-C uses `i8` instead of `bool`.
/// This helper casts a target value type to `bool`.
pub fn boolResult(result: c.BOOL) bool {
    return switch (c.BOOL) {
        bool => result,
        i8 => result == 1,
        else => @compileError("unexpected boolean type"),
    };
}

/// On some targets, Objective-C uses `i8` instead of `bool`.
/// This helper casts a `bool` value to the target value type.
pub fn boolParam(param: bool) c.BOOL {
    return switch (c.BOOL) {
        bool => param,
        i8 => @intFromBool(param),
        else => @compileError("unexpected boolean type"),
    };
}
