//! Block signature encoding tests.

const std = @import("std");
const objc = @import("objc");
const testing = std.testing;

extern "c" fn make_int_multiplier_block(multiplier: c_int) *anyopaque;
extern "c" fn get_clang_block_signature(block: *anyopaque) ?[*:0]const u8;

test "signature: generated block signatures" {
    try testing.expectEqualStrings("v@?", objc.block.blockSignature(fn () void));
    try testing.expectEqualStrings("v@?i", objc.block.blockSignature(fn (c_int) void));
    try testing.expectEqualStrings("i@?id", objc.block.blockSignature(fn (c_int, f64) c_int));
    try testing.expectEqualStrings("@@?@", objc.block.blockSignature(fn (objc.Object) objc.Object));
}

test "signature: validate against Clang block" {
    const clang_blk = make_int_multiplier_block(5);
    defer objc.raw.blocks._Block_release(clang_blk);

    const sig_raw = get_clang_block_signature(clang_blk);
    try testing.expect(sig_raw != null);

    const sig_str = std.mem.span(sig_raw.?);
    // Clang may emit with frame offsets e.g. "i12@?0i8" or compact "i@?i"
    // Validate that it has the return 'i', block '@?', and param 'i'
    try testing.expect(std.mem.startsWith(u8, sig_str, "i"));
    try testing.expect(std.mem.indexOf(u8, sig_str, "@?") != null);
    try testing.expect(std.mem.endsWith(u8, sig_str, "i") or std.mem.indexOf(u8, sig_str, "i8") != null);
}

test "signature: validateSignature on Zig block" {
    var blk = try objc.OwnedBlock(fn (c_int) c_int).fromFunction(struct {
        fn run(x: c_int) c_int {
            return x * 2;
        }
    }.run);
    defer blk.deinit();

    try blk.borrow().validateSignature();
    const sig = blk.borrow().signature();
    try testing.expect(sig != null);
    try testing.expectEqualStrings("i@?i", std.mem.span(sig.?));
}
