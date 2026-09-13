//! Master test runner for the Objective-C Block subsystem.

test {
    _ = @import("layout_test.zig");
    _ = @import("flags_test.zig");
    _ = @import("signature_test.zig");
    _ = @import("creation_test.zig");
    _ = @import("capture_test.zig");
    _ = @import("lifecycle_test.zig");
    _ = @import("byref_test.zig");
    _ = @import("invocation_test.zig");
    _ = @import("imp_test.zig");
    _ = @import("validation_test.zig");
}
