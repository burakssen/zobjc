//! Master entry point for Clang and runtime differential test suite.

test {
    _ = @import("encoding_test.zig");
    _ = @import("abi_test.zig");
    _ = @import("messaging_test.zig");
    _ = @import("blocks_test.zig");
    _ = @import("builders_test.zig");
}
