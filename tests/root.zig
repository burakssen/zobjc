//! Master test suite entry point for zobjc.

test {
    _ = @import("architecture_test.zig");
    _ = @import("compatibility/root.zig");
    _ = @import("runtime/root.zig");
    _ = @import("messaging/root.zig");
    _ = @import("encoding/root.zig");
    _ = @import("block/root.zig");
    _ = @import("integration/root.zig");
}
