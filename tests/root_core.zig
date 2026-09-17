//! Master test suite entry point for pure libobjc core runtime.
//!
//! Must link only libobjc.dylib and libc (zero Foundation linkage).

test {
    _ = @import("architecture_test.zig");
    _ = @import("raw/root.zig");
    _ = @import("compatibility/root.zig");
    _ = @import("runtime/root.zig");
    _ = @import("memory/root.zig");
    _ = @import("messaging/root.zig");
    _ = @import("encoding/root.zig");
    _ = @import("abi/root.zig");
    _ = @import("block/root.zig");
    _ = @import("builder/root.zig");
}
