//! Parity test suite verifying layout, struct, constant, and function contracts against Apple SDK headers.

test {
    _ = @import("types_test.zig");
    _ = @import("structs_test.zig");
    _ = @import("constants_test.zig");
    _ = @import("functions_test.zig");
}
