const objc = @import("zobjc");
const std = @import("std");
const testing = std.testing;

test "core architecture: Foundation is not loaded in core test process" {
    var image_list = objc.runtime.images();
    defer image_list.deinit();

    var iter = image_list.iterator();
    while (iter.next()) |img| {
        try @import("std").testing.expect(@import("std").mem.indexOf(u8, img, "Foundation.framework") == null);
    }
}
