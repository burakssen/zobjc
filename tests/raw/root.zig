//! Raw Objective-C ABI test runner.

test {
    _ = @import("types_test.zig");
    _ = @import("objc_test.zig");
    _ = @import("runtime_test.zig");
    _ = @import("message_test.zig");
    _ = @import("compiler_runtime_test.zig");
    _ = @import("parity_test.zig");
}
