//! Generated C-ABI invoke trampoline for Apple Blocks.
//!
//! Synthesizes the exact C function pointer stored in `Block_layout.invoke`.
//! Unpacks captures, converts ABI arguments to Zig types, invokes the user callback,
//! and normalizes the return value to ABI representation.

const std = @import("std");
const raw = @import("raw");
const convert = @import("convert.zig");
const literal_mod = @import("literal.zig");
const Object = @import("runtime").Object;
const Class = @import("runtime").Class;
const Selector = @import("runtime").Selector;

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

    return struct {
        fn convertArg(comptime T: type, raw_val: anytype) T {
            return convert.fromAbi(T, raw_val);
        }

        fn convertRet(ret_val: anytype) AbiRet {
            return convert.toAbi(ret_val);
        }

        fn isCaptureParam(comptime P: type, comptime C: type) bool {
            if (P == C) return true;
            if (P == *C or P == *const C) return true;
            if (@typeInfo(C) == .@"struct" and @typeInfo(C).@"struct".fields.len == 1) {
                const Inner = @typeInfo(C).@"struct".fields[0].type;
                if (P == Inner or P == *Inner or P == *const Inner) return true;
            }
            return false;
        }

        inline fn getCaptureArg(comptime P: type, lit: *Lit) P {
            if (comptime P == *Captures or P == *const Captures) {
                return lit.getCaptures();
            } else if (comptime P == Captures) {
                return lit.getCaptures().*;
            } else if (comptime @typeInfo(Captures) == .@"struct" and @typeInfo(Captures).@"struct".fields.len == 1) {
                const field_name = @typeInfo(Captures).@"struct".fields[0].name;
                const FieldType = @typeInfo(Captures).@"struct".fields[0].type;
                if (comptime P == FieldType) {
                    return @field(lit.getCaptures(), field_name);
                } else if (comptime P == *FieldType or P == *const FieldType) {
                    return &@field(lit.getCaptures(), field_name);
                }
            }
            return lit.getCaptures().*;
        }

        inline fn invokeCallback(lit: *Lit, all_args: anytype) AbiRet {
            const cb_count = cb_info.params.len;
            const has_caps = comptime blk: {
                if (@sizeOf(Captures) == 0) break :blk false;
                if (cb_count == params.len + 1) break :blk true;
                if (cb_count > 0 and isCaptureParam(cb_info.params[0].type.?, Captures)) break :blk true;
                break :blk false;
            };

            const res = if (comptime has_caps) blk: {
                const cap = getCaptureArg(cb_info.params[0].type.?, lit);
                const block_arg_count = cb_count - 1;
                break :blk switch (block_arg_count) {
                    0 => callback(cap),
                    1 => callback(cap, all_args[0]),
                    2 => if (all_args.len >= 2) callback(cap, all_args[0], all_args[1]) else unreachable,
                    3 => if (all_args.len >= 3) callback(cap, all_args[0], all_args[1], all_args[2]) else unreachable,
                    4 => if (all_args.len >= 4) callback(cap, all_args[0], all_args[1], all_args[2], all_args[3]) else unreachable,
                    5 => if (all_args.len >= 5) callback(cap, all_args[0], all_args[1], all_args[2], all_args[3], all_args[4]) else unreachable,
                    else => @compileError("Too many callback arguments"),
                };
            } else blk: {
                break :blk switch (cb_count) {
                    0 => callback(),
                    1 => callback(all_args[0]),
                    2 => if (all_args.len >= 2) callback(all_args[0], all_args[1]) else unreachable,
                    3 => if (all_args.len >= 3) callback(all_args[0], all_args[1], all_args[2]) else unreachable,
                    4 => if (all_args.len >= 4) callback(all_args[0], all_args[1], all_args[2], all_args[3]) else unreachable,
                    5 => if (all_args.len >= 5) callback(all_args[0], all_args[1], all_args[2], all_args[3], all_args[4]) else unreachable,
                    else => @compileError("Too many callback arguments"),
                };
            };
            return convertRet(res);
        }

        // fixed-arity static dispatcher for 0..5 block arguments
        pub const Runner = switch (params.len) {
            0 => struct {
                pub fn trampoline(raw_block: *anyopaque) callconv(.c) AbiRet {
                    const lit: *Lit = @ptrCast(@alignCast(raw_block));
                    return invokeCallback(lit, .{});
                }
            },
            1 => struct {
                const A0 = convert.AbiArgumentType(params[0].type.?);
                pub fn trampoline(raw_block: *anyopaque, a0: A0) callconv(.c) AbiRet {
                    const lit: *Lit = @ptrCast(@alignCast(raw_block));
                    return invokeCallback(lit, .{convertArg(params[0].type.?, a0)});
                }
            },
            2 => struct {
                const A0 = convert.AbiArgumentType(params[0].type.?);
                const A1 = convert.AbiArgumentType(params[1].type.?);
                pub fn trampoline(raw_block: *anyopaque, a0: A0, a1: A1) callconv(.c) AbiRet {
                    const lit: *Lit = @ptrCast(@alignCast(raw_block));
                    return invokeCallback(lit, .{
                        convertArg(params[0].type.?, a0),
                        convertArg(params[1].type.?, a1),
                    });
                }
            },
            3 => struct {
                const A0 = convert.AbiArgumentType(params[0].type.?);
                const A1 = convert.AbiArgumentType(params[1].type.?);
                const A2 = convert.AbiArgumentType(params[2].type.?);
                pub fn trampoline(raw_block: *anyopaque, a0: A0, a1: A1, a2: A2) callconv(.c) AbiRet {
                    const lit: *Lit = @ptrCast(@alignCast(raw_block));
                    return invokeCallback(lit, .{
                        convertArg(params[0].type.?, a0),
                        convertArg(params[1].type.?, a1),
                        convertArg(params[2].type.?, a2),
                    });
                }
            },
            4 => struct {
                const A0 = convert.AbiArgumentType(params[0].type.?);
                const A1 = convert.AbiArgumentType(params[1].type.?);
                const A2 = convert.AbiArgumentType(params[2].type.?);
                const A3 = convert.AbiArgumentType(params[3].type.?);
                pub fn trampoline(raw_block: *anyopaque, a0: A0, a1: A1, a2: A2, a3: A3) callconv(.c) AbiRet {
                    const lit: *Lit = @ptrCast(@alignCast(raw_block));
                    return invokeCallback(lit, .{
                        convertArg(params[0].type.?, a0),
                        convertArg(params[1].type.?, a1),
                        convertArg(params[2].type.?, a2),
                        convertArg(params[3].type.?, a3),
                    });
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
                    return invokeCallback(lit, .{
                        convertArg(params[0].type.?, a0),
                        convertArg(params[1].type.?, a1),
                        convertArg(params[2].type.?, a2),
                        convertArg(params[3].type.?, a3),
                        convertArg(params[4].type.?, a4),
                    });
                }
            },
            else => @compileError("Block signatures with more than 5 arguments are currently unsupported"),
        };
    };
}
