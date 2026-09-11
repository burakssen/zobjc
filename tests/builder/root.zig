//! Builder subsystem test suite root.

test {
    _ = @import("lifecycle_test.zig");
    _ = @import("ivar_test.zig");
    _ = @import("method_test.zig");
    _ = @import("property_test.zig");
    _ = @import("protocol_test.zig");
    _ = @import("integration_test.zig");
}
