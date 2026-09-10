//! Messaging test suite root.

test {
    _ = @import("arguments_test.zig");
    _ = @import("returns_test.zig");
    _ = @import("function_type_test.zig");
    _ = @import("send_test.zig");
    _ = @import("super_test.zig");
    _ = @import("invoke_test.zig");
    _ = @import("differential_test.zig");
}
