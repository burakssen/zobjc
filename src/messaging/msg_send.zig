//! Legacy message dispatch implementation.

const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const raw = @import("../raw/root.zig");
const c = raw.c;
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
            // Our one special-case: If the return type is our own Object
            // type then we wrap it.
            const is_object = Return == ObjectType;

            // Our actual return value is an "id" if we are using one of
            // our built-in types (see above). Otherwise, we trust the caller.
            const RealReturn = if (is_object) c.id else Return;

            // We accept multiple types for sel but we need to turn it into
            // a Selector ultimately.
            const sel: Selector = switch (@TypeOf(sel_raw)) {
                Selector => sel_raw,
                else => sel_fn(sel_raw),
            };

            // Build our function type and call it
            const Fn = MsgSendFn(RealReturn, @TypeOf(target.value), @TypeOf(args));
            const msg_send_fn = comptime msgSendPtr(RealReturn, false);
            const msg_send_ptr: *const Fn = @ptrCast(@alignCast(msg_send_fn));

            // Unwrap any Object/handle types in args to their underlying c.id / c.SEL
            const unwrapped_args = buildUnwrappedArgs(args);
            const result = @call(.auto, msg_send_ptr, .{ target.value, sel.value } ++ unwrapped_args);

            if (!is_object) return result;
            return .{ .value = result };
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
            const RealReturn = if (is_object) c.id else Return;
            const sel: Selector = switch (@TypeOf(sel_raw)) {
                Selector => sel_raw,
                else => sel_fn(sel_raw),
            };

            const Fn = MsgSendFn(RealReturn, *c.objc_super, @TypeOf(args));
            const msg_send_fn = comptime msgSendPtr(RealReturn, true);
            const msg_send_ptr: *const Fn = @ptrCast(@alignCast(msg_send_fn));
            var super: c.objc_super =
                if (comptime @hasField(c.objc_super, "super_class"))
                    .{
                        .receiver = target.value,
                        .super_class = superclass.value,
                    }
                else
                    .{
                        .receiver = target.value,
                        .class = superclass.value,
                    };

            const unwrapped_args = buildUnwrappedArgs(args);
            const result = @call(.auto, msg_send_ptr, .{ &super, sel.value } ++ unwrapped_args);

            if (!is_object) return result;
            return .{ .value = result };
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
                .aarch64 => if (super) &c.objc_msgSendSuper else &c.objc_msgSend,

                // x86_64 depends on the return type.
                .x86_64 => switch (@typeInfo(Return)) {
                    inline .int,
                    .bool,
                    .@"enum",
                    .pointer,
                    .void,
                    => if (super) &c.objc_msgSendSuper else &c.objc_msgSend,

                    .optional => |opt| opt: {
                        assert(@typeInfo(opt.child) == .pointer);
                        break :opt if (super) &c.objc_msgSendSuper else &c.objc_msgSend;
                    },

                    .@"struct" => blk: {
                        // TODO(phase-5): Replace size heuristic with real System V AMD64 ABI classification.
                        if (@sizeOf(Return) > 16) {
                            break :blk if (super)
                                &c.objc_msgSendSuper_stret
                            else
                                &c.objc_msgSend_stret;
                        } else {
                            break :blk if (super)
                                &c.objc_msgSendSuper
                            else
                                &c.objc_msgSend;
                        }
                    },

                    .float => |float| switch (float.bits) {
                        64 => if (super) &c.objc_msgSendSuper_fpret else &c.objc_msgSend_fpret,
                        else => if (super) &c.objc_msgSendSuper else &c.objc_msgSend,
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
    assert(@sizeOf(Target) == @sizeOf(c.id));

    var param_types: [argsInfo.fields.len + 2]type = undefined;
    param_types[0] = Target;
    param_types[1] = c.SEL;
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
            if (std.mem.eql(u8, field.name, "value") and @sizeOf(field.type) == @sizeOf(c.id)) {
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

inline fn buildUnwrappedArgs(args: anytype) UnwrappedArgs(@TypeOf(args)) {
    const fields = @typeInfo(@TypeOf(args)).@"struct".fields;
    var result: UnwrappedArgs(@TypeOf(args)) = undefined;
    inline for (fields, 0..) |_, i| {
        result[i] = if (unwrapType(@TypeOf(args[i])) != @TypeOf(args[i]))
            args[i].value
        else
            args[i];
    }
    return result;
}
