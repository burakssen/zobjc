//! Architectural compile-time isolation and dependency checks.

const std = @import("std");
const objc = @import("objc");

test "raw can be accessed independently" {
    _ = objc.raw;
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
