//! Master test suite runner for the objc_foundation module.

test {
    _ = @import("types_test.zig");
    _ = @import("string_test.zig");
    _ = @import("fast_enumeration_test.zig");
    _ = @import("enumerator_test.zig");
}
