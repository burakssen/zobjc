//! ABI test suite root.

test {
    _ = @import("target_test.zig");
    _ = @import("x86_64_merge_test.zig");
    _ = @import("x86_64_scalar_test.zig");
    _ = @import("x86_64_aggregate_test.zig");
    _ = @import("aarch64_test.zig");
    _ = @import("differential_test.zig");
}
