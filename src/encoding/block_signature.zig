//! Objective-C Block signature generation.
//!
//! Generates standard Objective-C type encoding strings for Apple Blocks:
//! `<return_type>@?<arg1><arg2>...`
//! where `@?` represents the implicit Block pointer parameter.

const std = @import("std");
const encoder = @import("encoder.zig");
const zig_type = @import("zig_type.zig");

/// Unwraps pointer-to-function or raw function type.
fn unwrapFunctionType(comptime T: type) type {
    const info = @typeInfo(T);
    if (info == .@"fn") return T;
    if (info == .pointer and info.pointer.size == .one and @typeInfo(info.pointer.child) == .@"fn") {
        return info.pointer.child;
    }
    @compileError("Block signature must be a function type, e.g. fn (c_int) void");
}

/// Calculates the exact byte length of the Block signature encoding.
pub fn blockSignatureLength(comptime F: type) usize {
    const FnType = unwrapFunctionType(F);
    const fn_info = @typeInfo(FnType).@"fn";

    if (fn_info.is_var_args) {
        @compileError("Variadic Block signatures are not supported");
    }

    const RetType = fn_info.return_type orelse void;
    zig_type.assertObjCEncodable(RetType);

    var len: usize = encoder.encodedLength(RetType);
    len += 2; // "@?" for implicit block parameter

    inline for (fn_info.params) |param| {
        const PT = param.type orelse @compileError("Block parameter must have an explicit type");
        zig_type.assertObjCEncodable(PT);
        len += encoder.encodedLength(PT);
    }

    return len;
}

/// Generates a compact Objective-C Block signature type encoding (e.g. `v@?i`)
/// with static storage duration from a function type.
pub fn blockSignature(comptime F: type) [:0]const u8 {
    const S = struct {
        const value = blk: {
            const FnType = unwrapFunctionType(F);
            const fn_info = @typeInfo(FnType).@"fn";
            const total_len = blockSignatureLength(F);
            var buf: [total_len:0]u8 = undefined;
            var idx: usize = 0;

            // 1. Return type encoding
            const RetType = fn_info.return_type orelse void;
            const ret_enc = encoder.comptimeEncode(RetType);
            @memcpy(buf[idx .. idx + ret_enc.len], &ret_enc);
            idx += ret_enc.len;

            // 2. Implicit Block argument (@?)
            buf[idx] = '@';
            buf[idx + 1] = '?';
            idx += 2;

            // 3. Explicit argument encodings
            for (fn_info.params) |param| {
                const PT = param.type.?;
                const p_enc = encoder.comptimeEncode(PT);
                @memcpy(buf[idx .. idx + p_enc.len], &p_enc);
                idx += p_enc.len;
            }

            buf[total_len] = 0;
            break :blk buf;
        };
    };
    return &S.value;
}

test "blockSignature basic signatures" {
    const sig1 = blockSignature(fn () void);
    try std.testing.expectEqualStrings("v@?", sig1);

    const sig2 = blockSignature(fn (c_int) void);
    try std.testing.expectEqualStrings("v@?i", sig2);

    const sig3 = blockSignature(fn (c_int, f64) c_int);
    try std.testing.expectEqualStrings("i@?id", sig3);
}
