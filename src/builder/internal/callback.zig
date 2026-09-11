//! Objective-C method callback validation, trampoline generation, and IMP resolution.

const std = @import("std");
const raw = @import("../../raw/root.zig");
const runtime = @import("../../runtime/root.zig");
const encoding = @import("../../encoding/root.zig");
const Object = runtime.Object;
const Class = runtime.Class;
const Selector = runtime.Selector;
const Imp = runtime.Imp;

/// Validates that `callback` has a valid Objective-C method implementation signature.
pub fn validateCallbackSignature(comptime callback: anytype) void {
    const RawFn = @TypeOf(callback);
    const fn_info = switch (@typeInfo(RawFn)) {
        .@"fn" => @typeInfo(RawFn).@"fn",
        .pointer => |p| switch (@typeInfo(p.child)) {
            .@"fn" => |f| f,
            else => @compileError("callback must be a function or function pointer"),
        },
        else => @compileError("callback must be a function or function pointer"),
    };

    if (fn_info.params.len < 2) {
        @compileError("Objective-C method implementation must take at least 2 arguments (self, _cmd)");
    }

    const P0 = fn_info.params[0].type orelse @compileError("parameter 0 must have a type");
    if (P0 != Object and P0 != ?Object and P0 != Class and P0 != ?Class and
        P0 != raw.id and P0 != raw.Class)
    {
        @compileError("First parameter of an Objective-C method must be Object or Class (or raw id/Class)");
    }

    const P1 = fn_info.params[1].type orelse @compileError("parameter 1 must have a type");
    if (P1 != Selector and P1 != ?Selector and P1 != raw.SEL) {
        @compileError("Second parameter of an Objective-C method must be a Selector (or raw SEL)");
    }

    const Ret = fn_info.return_type orelse void;
    encoding.assertObjCEncodable(Ret);

    inline for (fn_info.params[2..]) |param| {
        const PT = param.type orelse @compileError("parameter must have a type");
        encoding.assertObjCEncodable(PT);
    }
}

/// Returns the number of explicit Objective-C arguments (excluding self and _cmd).
pub fn explicitArgCount(comptime callback: anytype) usize {
    const RawFn = @TypeOf(callback);
    const fn_info = switch (@typeInfo(RawFn)) {
        .@"fn" => @typeInfo(RawFn).@"fn",
        .pointer => |p| switch (@typeInfo(p.child)) {
            .@"fn" => |f| f,
            else => unreachable,
        },
        else => unreachable,
    };
    return fn_info.params.len - 2;
}

/// Determines whether `callback` requires a trampoline for ABI compatibility.
pub fn needsTrampoline(comptime callback: anytype) bool {
    const RawFn = @TypeOf(callback);
    const fn_info = switch (@typeInfo(RawFn)) {
        .@"fn" => @typeInfo(RawFn).@"fn",
        .pointer => |p| switch (@typeInfo(p.child)) {
            .@"fn" => |f| f,
            else => unreachable,
        },
        else => unreachable,
    };

    const cc_tag: std.builtin.CallingConvention.Tag = fn_info.calling_convention;
    const c_tag: std.builtin.CallingConvention.Tag = std.builtin.CallingConvention.c;
    if (cc_tag != c_tag) return true;

    const P0 = fn_info.params[0].type.?;
    if (P0 != raw.id and P0 != raw.Class) return true;

    const P1 = fn_info.params[1].type.?;
    if (P1 != raw.SEL) return true;

    const Ret = fn_info.return_type orelse void;
    if (Ret != encoding.StorageType(Ret)) return true;

    inline for (fn_info.params[2..]) |param| {
        const PT = param.type.?;
        if (PT != encoding.StorageType(PT)) return true;
    }

    return false;
}

/// Generates a static trampoline function wrapper around `callback`.
pub fn MethodTrampoline(comptime callback: anytype) type {
    validateCallbackSignature(callback);

    const RawFn = @TypeOf(callback);
    const fn_info = switch (@typeInfo(RawFn)) {
        .@"fn" => @typeInfo(RawFn).@"fn",
        .pointer => |p| switch (@typeInfo(p.child)) {
            .@"fn" => |f| f,
            else => unreachable,
        },
        else => unreachable,
    };

    const Ret = fn_info.return_type orelse void;
    const AbiRet = encoding.StorageType(Ret);
    const P0 = fn_info.params[0].type.?;
    const P1 = fn_info.params[1].type.?;
    const extra_params = fn_info.params[2..];

    return struct {
        fn convertArg(comptime Target: type, raw_val: anytype) Target {
            if (Target == Object) return Object.fromRawNonNull(@ptrCast(raw_val));
            if (Target == ?Object) return Object.fromRaw(@ptrCast(raw_val));
            if (Target == Class) return Class.fromRawNonNull(@ptrCast(raw_val));
            if (Target == ?Class) return Class.fromRaw(@ptrCast(raw_val));
            if (Target == Selector) return Selector.fromRawNonNull(@ptrCast(raw_val));
            if (Target == ?Selector) return Selector.fromRaw(@ptrCast(raw_val));
            if (Target == bool) return raw.boolResult(raw_val);
            if (@typeInfo(Target) == .@"enum") return @enumFromInt(raw_val);
            return raw_val;
        }

        fn convertSelf(raw_self: raw.id) P0 {
            if (P0 == Object) return Object.fromRawNonNull(raw_self.?);
            if (P0 == ?Object) return Object.fromRaw(raw_self);
            if (P0 == Class) return Class.fromRawNonNull(@ptrCast(raw_self.?));
            if (P0 == ?Class) return Class.fromRaw(@ptrCast(raw_self));
            if (P0 == raw.Class) return @ptrCast(raw_self);
            return raw_self;
        }

        fn convertCmd(raw_cmd: raw.SEL) P1 {
            if (P1 == Selector) return Selector.fromRawNonNull(raw_cmd.?);
            if (P1 == ?Selector) return Selector.fromRaw(raw_cmd);
            return raw_cmd;
        }

        fn convertRet(ret_val: Ret) AbiRet {
            if (Ret == void) return;
            if (Ret == Object) return ret_val.toRaw();
            if (Ret == ?Object) return if (ret_val) |o| o.toRaw() else null;
            if (Ret == Class) return ret_val.toRaw();
            if (Ret == ?Class) return if (ret_val) |c| c.toRaw() else null;
            if (Ret == Selector) return ret_val.toRaw();
            if (Ret == ?Selector) return if (ret_val) |s| s.toRaw() else null;
            if (Ret == bool) return raw.boolParam(ret_val);
            if (@typeInfo(Ret) == .@"enum") return @intFromEnum(ret_val);
            return ret_val;
        }

        // ponytail: fixed-arity static dispatcher for 0..6 extra arguments.
        pub const Runner = switch (extra_params.len) {
            0 => struct {
                pub fn trampoline(raw_self: raw.id, raw_cmd: raw.SEL) callconv(.c) AbiRet {
                    const res = callback(convertSelf(raw_self), convertCmd(raw_cmd));
                    return convertRet(res);
                }
            },
            1 => struct {
                const A0 = encoding.StorageType(extra_params[0].type.?);
                pub fn trampoline(raw_self: raw.id, raw_cmd: raw.SEL, a0: A0) callconv(.c) AbiRet {
                    const p0 = convertArg(extra_params[0].type.?, a0);
                    const res = callback(convertSelf(raw_self), convertCmd(raw_cmd), p0);
                    return convertRet(res);
                }
            },
            2 => struct {
                const A0 = encoding.StorageType(extra_params[0].type.?);
                const A1 = encoding.StorageType(extra_params[1].type.?);
                pub fn trampoline(raw_self: raw.id, raw_cmd: raw.SEL, a0: A0, a1: A1) callconv(.c) AbiRet {
                    const p0 = convertArg(extra_params[0].type.?, a0);
                    const p1 = convertArg(extra_params[1].type.?, a1);
                    const res = callback(convertSelf(raw_self), convertCmd(raw_cmd), p0, p1);
                    return convertRet(res);
                }
            },
            3 => struct {
                const A0 = encoding.StorageType(extra_params[0].type.?);
                const A1 = encoding.StorageType(extra_params[1].type.?);
                const A2 = encoding.StorageType(extra_params[2].type.?);
                pub fn trampoline(raw_self: raw.id, raw_cmd: raw.SEL, a0: A0, a1: A1, a2: A2) callconv(.c) AbiRet {
                    const p0 = convertArg(extra_params[0].type.?, a0);
                    const p1 = convertArg(extra_params[1].type.?, a1);
                    const p2 = convertArg(extra_params[2].type.?, a2);
                    const res = callback(convertSelf(raw_self), convertCmd(raw_cmd), p0, p1, p2);
                    return convertRet(res);
                }
            },
            4 => struct {
                const A0 = encoding.StorageType(extra_params[0].type.?);
                const A1 = encoding.StorageType(extra_params[1].type.?);
                const A2 = encoding.StorageType(extra_params[2].type.?);
                const A3 = encoding.StorageType(extra_params[3].type.?);
                pub fn trampoline(raw_self: raw.id, raw_cmd: raw.SEL, a0: A0, a1: A1, a2: A2, a3: A3) callconv(.c) AbiRet {
                    const p0 = convertArg(extra_params[0].type.?, a0);
                    const p1 = convertArg(extra_params[1].type.?, a1);
                    const p2 = convertArg(extra_params[2].type.?, a2);
                    const p3 = convertArg(extra_params[3].type.?, a3);
                    const res = callback(convertSelf(raw_self), convertCmd(raw_cmd), p0, p1, p2, p3);
                    return convertRet(res);
                }
            },
            5 => struct {
                const A0 = encoding.StorageType(extra_params[0].type.?);
                const A1 = encoding.StorageType(extra_params[1].type.?);
                const A2 = encoding.StorageType(extra_params[2].type.?);
                const A3 = encoding.StorageType(extra_params[3].type.?);
                const A4 = encoding.StorageType(extra_params[4].type.?);
                pub fn trampoline(raw_self: raw.id, raw_cmd: raw.SEL, a0: A0, a1: A1, a2: A2, a3: A3, a4: A4) callconv(.c) AbiRet {
                    const p0 = convertArg(extra_params[0].type.?, a0);
                    const p1 = convertArg(extra_params[1].type.?, a1);
                    const p2 = convertArg(extra_params[2].type.?, a2);
                    const p3 = convertArg(extra_params[3].type.?, a3);
                    const p4 = convertArg(extra_params[4].type.?, a4);
                    const res = callback(convertSelf(raw_self), convertCmd(raw_cmd), p0, p1, p2, p3, p4);
                    return convertRet(res);
                }
            },
            6 => struct {
                const A0 = encoding.StorageType(extra_params[0].type.?);
                const A1 = encoding.StorageType(extra_params[1].type.?);
                const A2 = encoding.StorageType(extra_params[2].type.?);
                const A3 = encoding.StorageType(extra_params[3].type.?);
                const A4 = encoding.StorageType(extra_params[4].type.?);
                const A5 = encoding.StorageType(extra_params[5].type.?);
                pub fn trampoline(raw_self: raw.id, raw_cmd: raw.SEL, a0: A0, a1: A1, a2: A2, a3: A3, a4: A4, a5: A5) callconv(.c) AbiRet {
                    const p0 = convertArg(extra_params[0].type.?, a0);
                    const p1 = convertArg(extra_params[1].type.?, a1);
                    const p2 = convertArg(extra_params[2].type.?, a2);
                    const p3 = convertArg(extra_params[3].type.?, a3);
                    const p4 = convertArg(extra_params[4].type.?, a4);
                    const p5 = convertArg(extra_params[5].type.?, a5);
                    const res = callback(convertSelf(raw_self), convertCmd(raw_cmd), p0, p1, p2, p3, p4, p5);
                    return convertRet(res);
                }
            },
            else => @compileError("Methods with more than 6 extra arguments are not supported by the trampoline"),
        };
    };
}

/// Resolves the runtime IMP handle for a callback, using a trampoline if needed.
pub fn resolveImp(comptime callback: anytype) Imp {
    validateCallbackSignature(callback);

    if (comptime needsTrampoline(callback)) {
        const TrampolineStruct = MethodTrampoline(callback);
        const trampoline_fn = &TrampolineStruct.Runner.trampoline;
        return Imp.fromRawNonNull(@ptrCast(trampoline_fn));
    } else {
        const ptr = switch (@typeInfo(@TypeOf(callback))) {
            .@"fn" => &callback,
            .pointer => callback,
            else => unreachable,
        };
        return Imp.fromRawNonNull(@ptrCast(ptr));
    }
}

/// Generates the compact Objective-C method type encoding for a callback.
pub fn resolveMethodEncoding(comptime callback: anytype) [:0]const u8 {
    validateCallbackSignature(callback);

    const S = struct {
        const value = blk: {
            if (needsTrampoline(callback)) {
                const TrampolineStruct = MethodTrampoline(callback);
                const TrampFn = @TypeOf(TrampolineStruct.Runner.trampoline);
                break :blk encoding.methodEncoding(TrampFn);
            } else {
                const RawFn = @TypeOf(callback);
                const TargetFn = switch (@typeInfo(RawFn)) {
                    .@"fn" => RawFn,
                    .pointer => |p| p.child,
                    else => unreachable,
                };
                break :blk encoding.methodEncoding(TargetFn);
            }
        };
    };

    return &S.value;
}
