//! Legacy message dispatch implementation.

const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const raw = @import("../raw/root.zig");
const selector_pkg = @import("../runtime/selector.zig");
const Selector = selector_pkg.Selector;
const sel_fn = selector_pkg.sel;

/// Returns a struct that implements the msgSend and msgSendSuper functions for type T.
pub fn MsgSend(comptime T: type, comptime ObjectType: type) type {
    return struct {
        /// Invoke a selector on the target, i.e. an instance method on an
        /// object or a class method on a class. The args should be a tuple.
        pub fn msgSend(
            target: T,
            comptime Return: type,
            sel_raw: anytype,
            args: anytype,
        ) Return {
            const is_object = Return == ObjectType;
            const is_opt_object = Return == ?ObjectType;
            const RealReturn = if (is_object or is_opt_object) raw.id else Return;

            // We accept multiple types for sel but we need to turn it into
            // a Selector ultimately.
            const sel: Selector = switch (@TypeOf(sel_raw)) {
                Selector => sel_raw,
                else => sel_fn(sel_raw),
            };

            const target_raw = unwrapValue(target);

            // Build our function type and call it
            const Fn = MsgSendFn(RealReturn, @TypeOf(target_raw), @TypeOf(args));
            const msg_send_fn = comptime msgSendPtr(RealReturn, false);
            const msg_send_ptr: *const Fn = @ptrCast(@alignCast(msg_send_fn));

            // Unwrap any Object/handle types in args to their underlying raw pointers
            const unwrapped_args = buildUnwrappedArgs(args);
            const result = @call(.auto, msg_send_ptr, .{ target_raw, sel.ptr } ++ unwrapped_args);

            if (is_object) {
                return ObjectType.fromRaw(result) orelse @panic("msgSend returned nil for non-optional Object");
            }
            if (is_opt_object) {
                return ObjectType.fromRaw(result);
            }
            return result;
        }

        /// Invoke a selector on the superclass.
        pub fn msgSendSuper(
            target: T,
            superclass: anytype,
            comptime Return: type,
            sel_raw: anytype,
            args: anytype,
        ) Return {
            const is_object = Return == ObjectType;
            const is_opt_object = Return == ?ObjectType;
            const RealReturn = if (is_object or is_opt_object) raw.id else Return;
            const sel: Selector = switch (@TypeOf(sel_raw)) {
                Selector => sel_raw,
                else => sel_fn(sel_raw),
            };

            const Fn = MsgSendFn(RealReturn, *raw.objc_super, @TypeOf(args));
            const msg_send_fn = comptime msgSendPtr(RealReturn, true);
            const msg_send_ptr: *const Fn = @ptrCast(@alignCast(msg_send_fn));

            const target_raw = unwrapValue(target);
            const super_raw = unwrapValue(superclass);
            var super: raw.objc_super = .{
                .receiver = @ptrCast(target_raw),
                .super_class = @ptrCast(super_raw),
            };

            const unwrapped_args = buildUnwrappedArgs(args);
            const result = @call(.auto, msg_send_ptr, .{ &super, sel.ptr } ++ unwrapped_args);

            if (is_object) {
                return ObjectType.fromRaw(result) orelse @panic("msgSend returned nil for non-optional Object");
            }
            if (is_opt_object) {
                return ObjectType.fromRaw(result);
            }
            return result;
        }

        /// Returns the objc_msgSend or objc_msgSendSuper pointer for the
        /// given return type.
        // TODO(phase-5): Replace legacy x86_64 ABI heuristic with the unified ABI classifier.
        fn msgSendPtr(
            comptime Return: type,
            comptime super: bool,
        ) *const fn () callconv(.c) void {
            return switch (builtin.target.cpu.arch) {
                // Aarch64 uses objc_msgSend for everything.
                .aarch64 => if (super) &raw.message.objc_msgSendSuper else &raw.message.objc_msgSend,

                // x86_64 depends on the return type.
                .x86_64 => switch (@typeInfo(Return)) {
                    inline .int,
                    .bool,
                    .@"enum",
                    .pointer,
                    .void,
                    => if (super) &raw.message.objc_msgSendSuper else &raw.message.objc_msgSend,

                    .optional => |opt| opt: {
                        assert(@typeInfo(opt.child) == .pointer);
                        break :opt if (super) &raw.message.objc_msgSendSuper else &raw.message.objc_msgSend;
                    },

                    .@"struct" => blk: {
                        // TODO(phase-5): Replace size heuristic with real System V AMD64 ABI classification.
                        if (@sizeOf(Return) > 16) {
                            break :blk if (super)
                                &raw.message.objc_msgSendSuper_stret
                            else
                                &raw.message.objc_msgSend_stret;
                        } else {
                            break :blk if (super)
                                &raw.message.objc_msgSendSuper
                            else
                                &raw.message.objc_msgSend;
                        }
                    },

                    .float => |float| switch (float.bits) {
                        64 => if (super) &raw.message.objc_msgSendSuper_fpret else &raw.message.objc_msgSend_fpret,
                        else => if (super) &raw.message.objc_msgSendSuper else &raw.message.objc_msgSend,
                    },

                    else => {
                        @compileLog(@typeInfo(Return));
                        @compileError("unsupported return type for objc runtime on x86_64");
                    },
                },

                else => @compileError("unsupported objc architecture"),
            };
        }
    };
}

pub fn MsgSendFn(
    comptime Return: type,
    comptime Target: type,
    comptime Args: type,
) type {
    const argsInfo = @typeInfo(Args).@"struct";
    assert(argsInfo.is_tuple);
    assert(@sizeOf(Target) == @sizeOf(raw.id));

    var param_types: [argsInfo.fields.len + 2]type = undefined;
    param_types[0] = Target;
    param_types[1] = raw.SEL;
    for (argsInfo.fields, 0..) |field, i| param_types[i + 2] = unwrapType(field.type);

    return @Fn(&param_types, &@splat(.{}), Return, .{ .@"callconv" = .c });
}

fn UnwrappedArgs(comptime Args: type) type {
    const fields = @typeInfo(Args).@"struct".fields;
    var types: [fields.len]type = undefined;
    for (fields, 0..) |field, i| types[i] = unwrapType(field.type);
    return @Tuple(&types);
}

fn unwrapType(comptime T: type) type {
    if (@typeInfo(T) == .@"struct") {
        const info = @typeInfo(T).@"struct";
        for (info.fields) |field| {
            if ((std.mem.eql(u8, field.name, "ptr") or std.mem.eql(u8, field.name, "value")) and @sizeOf(field.type) == @sizeOf(raw.id)) {
                return field.type;
            }
        }
    }

    switch (@typeInfo(T)) {
        .int, .float, .bool, .void => {},
        .@"enum" => {},
        .pointer => {},
        .optional => |opt| {
            if (@typeInfo(opt.child) != .pointer)
                @compileError("msgSend: " ++ @typeName(T) ++ " — optional must wrap a pointer");
        },
        .@"struct" => |s| {
            if (s.layout != .@"extern" and s.layout != .@"packed")
                @compileError("msgSend: " ++ @typeName(T) ++ " — struct must be extern or packed");
        },
        .@"union" => |u| {
            if (u.layout != .@"extern")
                @compileError("msgSend: " ++ @typeName(T) ++ " — union must be extern");
        },
        else => @compileError("msgSend: " ++ @typeName(T) ++ " — not C-ABI compatible"),
    }

    return T;
}

inline fn unwrapValue(val: anytype) unwrapType(@TypeOf(val)) {
    const T = @TypeOf(val);
    if (comptime unwrapType(T) != T) {
        if (@hasField(T, "ptr")) {
            return val.ptr;
        } else if (@hasField(T, "value")) {
            return val.value;
        }
    }
    return val;
}

inline fn buildUnwrappedArgs(args: anytype) UnwrappedArgs(@TypeOf(args)) {
    const fields = @typeInfo(@TypeOf(args)).@"struct".fields;
    var result: UnwrappedArgs(@TypeOf(args)) = undefined;
    inline for (fields, 0..) |_, i| {
        result[i] = unwrapValue(args[i]);
    }
    return result;
}
