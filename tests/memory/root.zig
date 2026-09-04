//! Memory and ownership subsystem tests root.

test {
    _ = @import("retained_test.zig");
    _ = @import("weak_test.zig");
    _ = @import("owned_c_string_test.zig");
    _ = @import("owned_runtime_list_test.zig");
    _ = @import("owned_descriptors_test.zig");
    _ = @import("autorelease_pool_test.zig");
}
