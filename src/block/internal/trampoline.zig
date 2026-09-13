//! Generated C-ABI invoke trampoline for Apple Blocks.
//!
//! Synthesizes the exact C function pointer stored in `Block_layout.invoke`.
//! Unpacks captures, converts ABI arguments to Zig types, invokes the user callback,
//! and normalizes the return value to ABI representation.

const std = @import("std");
const raw = @import("../../raw/root.zig");
const convert = @import("convert.zig");
const literal_mod = @import("literal.zig");
const Object = @import("../../runtime/object.zig").Object;
const Class = @import("../../runtime/class.zig").Class;
const Selector = @import("../../runtime/selector.zig").Selector;

pub fn InvokeTrampoline(
    comptime Signature: type,
    comptime Captures: type,
    comptime callback: anytype,
) type {
    const Lit = literal_mod.Literal(Captures);
    const fn_info = @typeInfo(Signature).@"fn";
    const RetType = fn_info.return_type orelse void;
    const AbiRet = convert.AbiReturnType(RetType);
    const params = fn_info.params;

    const CallbackFn = @TypeOf(callback);
    const cb_info = @typeInfo(CallbackFn).@"fn";
    const has_captures_param = cb_info.params.len == params.len + 1;

    return struct {
        fn convertArg(comptime T: type, raw_val: anytype) T {
            return convert.fromAbi(T, raw_val);
        }

        fn convertRet(ret_val: anytype) AbiRet {
            return convert.toAbi(ret_val);
        }

        // // ponytail: fixed-arity static dispatcher for 0..8 block arguments
        pub const Runner = switch (params.len) {
            0 => struct {
                pub fn trampoline(raw_block: *anyopaque) callconv(.c) AbiRet {
                    const lit: *Lit = @ptrCast(@alignCast(raw_block));
                    if (has_captures_param) {
                        const caps = lit.getCaptures();
                        const res = callback(caps);
                        return convertRet(res);
                    } else {
                        const res = callback();
                        return convertRet(res);
                    }
                }
            },
            1 => struct {
                const A0 = convert.AbiArgumentType(params[0].type.?);
                pub fn trampoline(raw_block: *anyopaque, a0: A0) callconv(.c) AbiRet {
                    const lit: *Lit = @ptrCast(@alignCast(raw_block));
                    const p0 = convertArg(params[0].type.?, a0);
                    if (has_captures_param) {
                        const caps = lit.getCaptures();
                        const res = callback(caps, p0);
                        return convertRet(res);
                    } else {
                        const res = callback(p0);
                        return convertRet(res);
                    }
                }
            },
            2 => struct {
                const A0 = convert.AbiArgumentType(params[0].type.?);
                const A1 = convert.AbiArgumentType(params[1].type.?);
                pub fn trampoline(raw_block: *anyopaque, a0: A0, a1: A1) callconv(.c) AbiRet {
                    const lit: *Lit = @ptrCast(@alignCast(raw_block));
                    const p0 = convertArg(params[0].type.?, a0);
                    const p1 = convertArg(params[1].type.?, a1);
                    if (has_captures_param) {
                        const caps = lit.getCaptures();
                        const res = callback(caps, p0, p1);
                        return convertRet(res);
                    } else {
                        const res = callback(p0, p1);
                        return convertRet(res);
                    }
                }
            },
            3 => struct {
                const A0 = convert.AbiArgumentType(params[0].type.?);
                const A1 = convert.AbiArgumentType(params[1].type.?);
                const A2 = convert.AbiArgumentType(params[2].type.?);
                pub fn trampoline(raw_block: *anyopaque, a0: A0, a1: A1, a2: A2) callconv(.c) AbiRet {
                    const lit: *Lit = @ptrCast(@alignCast(raw_block));
                    const p0 = convertArg(params[0].type.?, a0);
                    const p1 = convertArg(params[1].type.?, a1);
                    const p2 = convertArg(params[2].type.?, a2);
                    if (has_captures_param) {
                        const caps = lit.getCaptures();
                        const res = callback(caps, p0, p1, p2);
                        return convertRet(res);
                    } else {
                        const res = callback(p0, p1, p2);
                        return convertRet(res);
                    }
                }
            },
            4 => struct {
                const A0 = convert.AbiArgumentType(params[0].type.?);
                const A1 = convert.AbiArgumentType(params[1].type.?);
                const A2 = convert.AbiArgumentType(params[2].type.?);
                const A3 = convert.AbiArgumentType(params[3].type.?);
                pub fn trampoline(raw_block: *anyopaque, a0: A0, a1: A1, a2: A2, a3: A3) callconv(.c) AbiRet {
                    const lit: *Lit = @ptrCast(@alignCast(raw_block));
                    const p0 = convertArg(params[0].type.?, a0);
                    const p1 = convertArg(params[1].type.?, a1);
                    const p2 = convertArg(params[2].type.?, a2);
                    const p3 = convertArg(params[3].type.?, a3);
                    if (has_captures_param) {
                        const caps = lit.getCaptures();
                        const res = callback(caps, p0, p1, p2, p3);
                        return convertRet(res);
                    } else {
                        const res = callback(p0, p1, p2, p3);
                        return convertRet(res);
                    }
                }
            },
            5 => struct {
                const A0 = convert.AbiArgumentType(params[0].type.?);
                const A1 = convert.AbiArgumentType(params[1].type.?);
                const A2 = convert.AbiArgumentType(params[2].type.?);
                const A3 = convert.AbiArgumentType(params[3].type.?);
                const A4 = convert.AbiArgumentType(params[4].type.?);
                pub fn trampoline(raw_block: *anyopaque, a0: A0, a1: A1, a2: A2, a3: A3, a4: A4) callconv(.c) AbiRet {
                    const lit: *Lit = @ptrCast(@alignCast(raw_block));
                    const p0 = convertArg(params[0].type.?, a0);
                    const p1 = convertArg(params[1].type.?, a1);
                    const p2 = convertArg(params[2].type.?, a2);
                    const p3 = convertArg(params[3].type.?, a3);
                    const p4 = convertArg(params[4].type.?, a4);
                    if (has_captures_param) {
                        const caps = lit.getCaptures();
                        const res = callback(caps, p0, p1, p2, p3, p4);
                        return convertRet(res);
                    } else {
                        const res = callback(p0, p1, p2, p3, p4);
                        return convertRet(res);
                    }
                }
            },
            else => @compileError("Block signatures with more than 5 arguments are currently unsupported"),
        };
    };
}
