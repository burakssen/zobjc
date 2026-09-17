//! Architectural compile-time isolation and dependency checks.

const std = @import("std");
const objc = @import("objc");

test "raw can be accessed independently" {
    _ = objc.raw;
    _ = objc.raw.objc;
    _ = objc.raw.runtime;
    _ = objc.raw.message;
    _ = objc.raw.blocks;
    _ = objc.raw.compiler_runtime;
    _ = objc.raw.availability;
    _ = objc.raw.deprecated;
}

test "abi placeholder can be accessed independently" {
    _ = objc.abi;
}

test "encoding can be accessed independently" {
    _ = objc.encoding;
}

test "memory can be accessed independently" {
    _ = objc.memory;
}

test "messaging can be accessed independently" {
    _ = objc.messaging;
}

test "runtime facade imports cleanly" {
    _ = objc.runtime;
}

test "block can be accessed independently" {
    _ = objc.block;
}

test "builder placeholder can be accessed independently" {
    _ = objc.builder;
}

test "core architecture: Foundation is not loaded in core test process" {
    var image_list = objc.runtime.images();
    defer image_list.deinit();

    var iter = image_list.iterator();
    while (iter.next()) |img| {
        try std.testing.expect(std.mem.indexOf(u8, img, "Foundation.framework") == null);
    }
}
