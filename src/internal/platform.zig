//! Target platform detection and metadata.
//!
//! Centralizes target platform and architecture checks to avoid repeating
//! `@import("builtin")` throughout the codebase.

const builtin = @import("builtin");

// ponytail: Use builtin target info directly without custom wrappers.
pub const is_darwin = builtin.os.tag.isDarwin();
pub const os = builtin.os.tag;
pub const arch = builtin.cpu.arch;

pub fn assertDarwin() void {
    if (!is_darwin) {
        @compileError("zobjc currently only supports Apple Darwin targets (macOS, iOS, tvOS, watchOS)");
    }
}
