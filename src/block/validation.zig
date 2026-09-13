//! Compile-time validation for Apple Block signatures and target compatibility.

const std = @import("std");
const builtin = @import("builtin");
const encoding = @import("../encoding/root.zig");

/// Unwraps pointer-to-function or raw function type.
pub fn unwrapFunctionType(comptime T: type) type {
    const info = @typeInfo(T);
    if (info == .@"fn") return T;
    if (info == .pointer and info.pointer.size == .one and @typeInfo(info.pointer.child) == .@"fn") {
        return info.pointer.child;
    }
    @compileError("Block signature must be a function type, e.g. fn (c_int, f64) void");
}

/// Validates that `Signature` is a legal Objective-C Block function signature.
pub fn validateBlockSignature(comptime Signature: type) void {
    const FnType = unwrapFunctionType(Signature);
    const fn_info = @typeInfo(FnType).@"fn";

    if (fn_info.is_var_args) {
        @compileError("Variadic Block signatures are not supported");
    }

    const RetType = fn_info.return_type orelse void;
    validateBlockType(RetType, true);

    inline for (fn_info.params) |param| {
        const PT = param.type orelse @compileError("Block parameter must have an explicit type");
        validateBlockType(PT, false);
    }
}

/// Validates an individual return or argument type in a Block signature.
fn validateBlockType(comptime T: type, comptime is_return: bool) void {
    switch (@typeInfo(T)) {
        .comptime_int, .comptime_float => {
            @compileError("Block signatures cannot use comptime-only types, specify explicit types like c_int or f64");
        },
        .error_union, .error_set => {
            @compileError("Block signatures cannot use Zig error unions across the C ABI");
        },
        .pointer => |ptr| {
            if (ptr.size == .slice) {
                @compileError("Zig slices cannot cross the Objective-C C ABI; use pointers or arrays instead");
            }
        },
        .null => {
            @compileError("Untyped null is not permitted in Block signatures");
        },
        .undefined => {
            @compileError("Undefined type is not permitted in Block signatures");
        },
        else => {},
    }

    _ = is_return;
    encoding.assertObjCEncodable(T);
}

/// Validates that the compilation target does not require pointer-authenticated Block pointers.
///
/// On Darwin targets using arm64e / ptrauth_calls, function pointers inside Block literals
/// and descriptors must be signed using ptrauth_key_block_function. Since unsigned pointers
/// will crash under hardware authentication, Block construction is explicitly rejected.
pub fn validateNotPtrauth() void {
    if (comptime isPtrauthTarget(builtin.target)) {
        @compileError("Apple Block construction on pointer-authenticated targets (e.g. arm64e) is not yet supported safely.");
    }
}

/// Determines if a target requires pointer-authenticated block pointers.
pub fn isPtrauthTarget(target: std.Target) bool {
    if (target.cpu.arch != .aarch64) return false;
    // Check if arm64e / ptrauth ABI is active
    if (target.os.tag == .macos or target.os.tag == .ios or target.os.tag == .watchos or target.os.tag == .tvos) {
        if (std.mem.indexOf(u8, target.cpu.model.name, "arm64e") != null) {
            return true;
        }
    }
    return false;
}

test "validation: valid signatures" {
    validateBlockSignature(fn (c_int) void);
    validateBlockSignature(fn (c_int, f64) c_int);
    validateBlockSignature(fn () void);
}
