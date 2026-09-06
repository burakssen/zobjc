//! Objective-C type encoding serializes.
//!
//! Provides:
//! - `comptimeEncode(comptime T: type)`: Two-pass compile-time null-terminated encoding.
//! - `encode(allocator, qualified)`: Runtime AST serializer into heap-allocated C string.

const std = @import("std");
const raw = @import("../raw/root.zig");
const types = @import("type.zig");
const QualifiedType = types.QualifiedType;
const Type = types.Type;
const Scalar = types.Scalar;
const Qualifiers = types.Qualifiers;
const zig_type = @import("zig_type.zig");
const Object = @import("../runtime/object.zig").Object;
const Class = @import("../runtime/class.zig").Class;
const Selector = @import("../runtime/selector.zig").Selector;

// --- Compile-Time Encoder ---

/// Calculates the exact character count needed to encode `T`.
pub fn encodedLength(comptime T: type) usize {
    comptime {
        zig_type.assertObjCEncodable(T);

        // 1. Explicit override
        switch (@typeInfo(T)) {
            .@"struct", .@"union", .@"enum", .@"opaque" => {
                if (@hasDecl(T, "objc_type_encoding")) {
                    return @field(T, "objc_type_encoding").len;
                }
            },
            else => {},
        }

        // 2. High-level runtime handles
        if (T == Object or T == ?Object or T == raw.id) return 1; // '@'
        if (T == Class or T == ?Class or T == raw.Class) return 1; // '#'
        if (T == Selector or T == ?Selector or T == raw.SEL) return 1; // ':'

        // 3. C strings
        if (T == [*c]const u8 or T == [*:0]const u8 or T == ?[*:0]const u8) {
            return 2; // "r*"
        }
        if (T == [*c]u8 or T == [*:0]u8 or T == ?[*:0]u8) {
            return 1; // '*'
        }

        // 4. Primitives
        if (T == void) return 1;
        if (T == bool) return 1;
        if (T == raw.BOOL) return 1;
        if (T == c_char or T == i8 or T == u8 or
            T == c_short or T == i16 or T == c_ushort or T == u16 or
            T == c_int or T == i32 or T == c_uint or T == u32 or
            T == c_long or T == c_ulong or T == c_longlong or T == i64 or
            T == c_ulonglong or T == u64 or T == f32 or T == f64 or
            T == c_longdouble or T == i128 or T == u128)
        {
            return 1;
        }

        // 5. Types by structural info
        return switch (@typeInfo(T)) {
            .@"enum" => |e| encodedLength(e.tag_type),
            .array => |arr| blk: {
                var len_digits: usize = 0;
                var temp = arr.len;
                if (temp == 0) len_digits = 1;
                while (temp > 0) : (temp /= 10) len_digits += 1;
                break :blk 1 + len_digits + encodedLength(arr.child) + 1; // "[len...]"
            },
            .pointer => |ptr| switch (ptr.size) {
                .one, .c => 1 + pointerChildLength(ptr.child, 1),
                else => unreachable,
            },
            .optional => |opt| switch (@typeInfo(opt.child)) {
                .pointer => |ptr| 1 + pointerChildLength(ptr.child, 1),
                else => unreachable,
            },
            .@"struct" => |s| aggregateLength(T, s.fields, true),
            .@"union" => |u| aggregateLength(T, u.fields, false),
            .@"fn" => |f| {
                var total: usize = encodedLength(f.return_type orelse void);
                for (f.params) |p| {
                    if (p.type) |pt| {
                        total += encodedLength(pt);
                    }
                }
                return total;
            },
            .@"opaque" => 1, // 'v'
            else => unreachable,
        };
    }
}

fn pointerChildLength(comptime Child: type, comptime depth: usize) usize {
    comptime {
        if (Child == anyopaque) return 1; // 'v' -> "^v"
        switch (@typeInfo(Child)) {
            .pointer => |p| return 1 + pointerChildLength(p.child, depth + 1),
            .optional => |o| switch (@typeInfo(o.child)) {
                .pointer => |p| return 1 + pointerChildLength(p.child, depth + 1),
                else => {},
            },
            .@"struct" => {
                if (depth > 1) {
                    // Clang omits fields at indirection depth > 1: "^^{CGPoint}"
                    const name = zig_type.getAggregateName(Child);
                    return 1 + name.len + 1; // "{Name}"
                }
            },
            .@"union" => {
                if (depth > 1) {
                    const name = zig_type.getAggregateName(Child);
                    return 1 + name.len + 1; // "(Name)"
                }
            },
            else => {},
        }
        return encodedLength(Child);
    }
}

fn aggregateLength(comptime T: type, comptime fields: anytype, comptime is_struct: bool) usize {
    comptime {
        _ = is_struct;
        const name = zig_type.getAggregateName(T);
        var total: usize = 1 + name.len; // "{" or "(" + name
        if (fields.len > 0) {
            total += 1; // "="
            for (fields) |f| {
                total += encodedLength(f.type);
            }
        }
        total += 1; // "}" or ")"
        return total;
    }
}

/// Encodes a Zig type into an Objective-C encoding null-terminated string at compile-time.
pub fn comptimeEncode(comptime T: type) [encodedLength(T):0]u8 {
    const S = struct {
        const value = blk: {
            const len = encodedLength(T);
            var buf: [len:0]u8 = undefined;
            var idx: usize = 0;
            writeComptimeType(T, &buf, &idx, 0);
            buf[len] = 0;
            break :blk buf;
        };
    };
    return S.value;
}

fn writeComptimeType(comptime T: type, buf: []u8, idx: *usize, comptime ptr_depth: usize) void {
    comptime {
        // 1. Explicit override
        switch (@typeInfo(T)) {
            .@"struct", .@"union", .@"enum", .@"opaque" => {
                if (@hasDecl(T, "objc_type_encoding")) {
                    const override = @field(T, "objc_type_encoding");
                    @memcpy(buf[idx.* .. idx.* + override.len], override);
                    idx.* += override.len;
                    return;
                }
            },
            else => {},
        }

        // 2. High-level runtime handles
        if (T == Object or T == ?Object or T == raw.id) {
            buf[idx.*] = '@';
            idx.* += 1;
            return;
        }
        if (T == Class or T == ?Class or T == raw.Class) {
            buf[idx.*] = '#';
            idx.* += 1;
            return;
        }
        if (T == Selector or T == ?Selector or T == raw.SEL) {
            buf[idx.*] = ':';
            idx.* += 1;
            return;
        }

        // 3. C strings
        if (T == [*c]const u8 or T == [*:0]const u8 or T == ?[*:0]const u8) {
            buf[idx.*] = 'r';
            buf[idx.* + 1] = '*';
            idx.* += 2;
            return;
        }
        if (T == [*c]u8 or T == [*:0]u8 or T == ?[*:0]u8) {
            buf[idx.*] = '*';
            idx.* += 1;
            return;
        }

        // 4. Primitives
        if (T == void) {
            buf[idx.*] = 'v';
            idx.* += 1;
            return;
        }
        if (T == bool) {
            buf[idx.*] = 'B';
            idx.* += 1;
            return;
        }
        if (T == raw.BOOL) {
            buf[idx.*] = if (raw.objc_bool_is_bool) 'B' else 'c';
            idx.* += 1;
            return;
        }
        if (T == c_char or T == i8) {
            buf[idx.*] = 'c';
            idx.* += 1;
            return;
        }
        if (T == u8) {
            buf[idx.*] = 'C';
            idx.* += 1;
            return;
        }
        if (T == c_short or T == i16) {
            buf[idx.*] = 's';
            idx.* += 1;
            return;
        }
        if (T == c_ushort or T == u16) {
            buf[idx.*] = 'S';
            idx.* += 1;
            return;
        }
        if (T == c_int or T == i32) {
            buf[idx.*] = 'i';
            idx.* += 1;
            return;
        }
        if (T == c_uint or T == u32) {
            buf[idx.*] = 'I';
            idx.* += 1;
            return;
        }
        if (T == c_long) {
            buf[idx.*] = if (@sizeOf(c_long) == 8) 'q' else 'l';
            idx.* += 1;
            return;
        }
        if (T == c_ulong) {
            buf[idx.*] = if (@sizeOf(c_ulong) == 8) 'Q' else 'L';
            idx.* += 1;
            return;
        }
        if (T == c_longlong or T == i64) {
            buf[idx.*] = 'q';
            idx.* += 1;
            return;
        }
        if (T == c_ulonglong or T == u64) {
            buf[idx.*] = 'Q';
            idx.* += 1;
            return;
        }
        if (T == f32) {
            buf[idx.*] = 'f';
            idx.* += 1;
            return;
        }
        if (T == f64) {
            buf[idx.*] = 'd';
            idx.* += 1;
            return;
        }
        if (T == c_longdouble) {
            buf[idx.*] = 'D';
            idx.* += 1;
            return;
        }
        if (T == i128) {
            buf[idx.*] = 'j';
            idx.* += 1;
            return;
        }
        if (T == u128) {
            buf[idx.*] = 'J';
            idx.* += 1;
            return;
        }

        // 5. Types by structural info
        switch (@typeInfo(T)) {
            .@"enum" => |e| writeComptimeType(e.tag_type, buf, idx, ptr_depth),
            .array => |arr| {
                buf[idx.*] = '[';
                idx.* += 1;

                var digits: [32]u8 = undefined;
                const printed = std.fmt.bufPrint(&digits, "{d}", .{arr.len}) catch unreachable;
                @memcpy(buf[idx.* .. idx.* + printed.len], printed);
                idx.* += printed.len;

                writeComptimeType(arr.child, buf, idx, 0);

                buf[idx.*] = ']';
                idx.* += 1;
            },
            .pointer => |ptr| switch (ptr.size) {
                .one, .c => {
                    buf[idx.*] = '^';
                    idx.* += 1;
                    if (ptr.child == anyopaque) {
                        buf[idx.*] = 'v';
                        idx.* += 1;
                    } else {
                        writePointerChildType(ptr.child, buf, idx, ptr_depth + 1);
                    }
                },
                else => unreachable,
            },
            .optional => |opt| switch (@typeInfo(opt.child)) {
                .pointer => |ptr| {
                    buf[idx.*] = '^';
                    idx.* += 1;
                    if (ptr.child == anyopaque) {
                        buf[idx.*] = 'v';
                        idx.* += 1;
                    } else {
                        writePointerChildType(ptr.child, buf, idx, ptr_depth + 1);
                    }
                },
                else => unreachable,
            },
            .@"struct" => |s| writeAggregate(T, s.fields, buf, idx, true, ptr_depth),
            .@"union" => |u| writeAggregate(T, u.fields, buf, idx, false, ptr_depth),
            .@"fn" => |f| {
                writeComptimeType(f.return_type orelse void, buf, idx, ptr_depth);
                for (f.params) |p| {
                    if (p.type) |pt| {
                        writeComptimeType(pt, buf, idx, ptr_depth);
                    }
                }
            },
            .@"opaque" => {
                buf[idx.*] = 'v';
                idx.* += 1;
            },
            else => unreachable,
        }
    }
}

fn writePointerChildType(comptime Child: type, buf: []u8, idx: *usize, comptime depth: usize) void {
    comptime {
        if (depth > 1) {
            switch (@typeInfo(Child)) {
                .@"struct" => {
                    const name = zig_type.getAggregateName(Child);
                    buf[idx.*] = '{';
                    idx.* += 1;
                    @memcpy(buf[idx.* .. idx.* + name.len], name);
                    idx.* += name.len;
                    buf[idx.*] = '}';
                    idx.* += 1;
                    return;
                },
                .@"union" => {
                    const name = zig_type.getAggregateName(Child);
                    buf[idx.*] = '(';
                    idx.* += 1;
                    @memcpy(buf[idx.* .. idx.* + name.len], name);
                    idx.* += name.len;
                    buf[idx.*] = ')';
                    idx.* += 1;
                    return;
                },
                else => {},
            }
        }
        writeComptimeType(Child, buf, idx, depth);
    }
}

fn writeAggregate(
    comptime T: type,
    comptime fields: anytype,
    buf: []u8,
    idx: *usize,
    comptime is_struct: bool,
    comptime ptr_depth: usize,
) void {
    comptime {
        _ = ptr_depth;
        const open_ch: u8 = if (is_struct) '{' else '(';
        const close_ch: u8 = if (is_struct) '}' else ')';
        const name = zig_type.getAggregateName(T);

        buf[idx.*] = open_ch;
        idx.* += 1;

        @memcpy(buf[idx.* .. idx.* + name.len], name);
        idx.* += name.len;

        if (fields.len > 0) {
            buf[idx.*] = '=';
            idx.* += 1;
            for (fields) |f| {
                writeComptimeType(f.type, buf, idx, 0);
            }
        }

        buf[idx.*] = close_ch;
        idx.* += 1;
    }
}

// --- Runtime AST Encoder ---

/// Serializes a parsed `QualifiedType` AST into an allocated null-terminated string.
pub fn encode(allocator: std.mem.Allocator, qualified: QualifiedType) ![:0]u8 {
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(allocator);

    try writeQualified(allocator, &list, qualified);
    return list.toOwnedSliceSentinel(allocator, 0);
}

fn writeQualified(allocator: std.mem.Allocator, list: *std.ArrayList(u8), qualified: QualifiedType) error{OutOfMemory}!void {
    const q = qualified.qualifiers;
    if (q.const_) try list.append(allocator, 'r');
    if (q.in) try list.append(allocator, 'n');
    if (q.inout) try list.append(allocator, 'N');
    if (q.out) try list.append(allocator, 'o');
    if (q.bycopy) try list.append(allocator, 'O');
    if (q.byref) try list.append(allocator, 'R');
    if (q.oneway) try list.append(allocator, 'V');

    try writeTypeAST(allocator, list, qualified.type);
}

fn writeTypeAST(allocator: std.mem.Allocator, list: *std.ArrayList(u8), type_val: Type) error{OutOfMemory}!void {
    switch (type_val) {
        .scalar => |s| try list.append(allocator, switch (s) {
            .char => 'c',
            .uchar => 'C',
            .short => 's',
            .ushort => 'S',
            .int => 'i',
            .uint => 'I',
            .long => 'l',
            .ulong => 'L',
            .longlong => 'q',
            .ulonglong => 'Q',
            .int128 => 'j',
            .uint128 => 'J',
            .float => 'f',
            .double => 'd',
            .long_double => 'D',
            .bool => 'B',
            .void => 'v',
            .char_string => '*',
        }),
        .object => |obj| {
            try list.append(allocator, '@');
            if (obj.class_name) |name| {
                try list.print(allocator, "\"{s}", .{name});
                for (obj.protocols) |proto| {
                    try list.print(allocator, "<{s}>", .{proto});
                }
                try list.append(allocator, '"');
            } else if (obj.protocols.len > 0) {
                try list.append(allocator, '"');
                for (obj.protocols) |proto| {
                    try list.print(allocator, "<{s}>", .{proto});
                }
                try list.append(allocator, '"');
            }
        },
        .class => try list.append(allocator, '#'),
        .selector => try list.append(allocator, ':'),
        .block => try list.appendSlice(allocator, "@?"),
        .function_pointer => try list.appendSlice(allocator, "^?"),
        .unknown => try list.append(allocator, '?'),
        .pointer => |ptr| {
            try list.append(allocator, '^');
            try writeQualified(allocator, list, ptr.child.*);
        },
        .array => |arr| {
            try list.print(allocator, "[{d}", .{arr.len});
            try writeQualified(allocator, list, arr.child.*);
            try list.append(allocator, ']');
        },
        .structure => |s| {
            try list.print(allocator, "{{{s}", .{s.name});
            if (!s.@"opaque" and s.fields.len > 0) {
                try list.append(allocator, '=');
                for (s.fields) |f| {
                    if (f.name) |name| {
                        try list.print(allocator, "\"{s}\"", .{name});
                    }
                    try writeQualified(allocator, list, f.type);
                }
            }
            try list.append(allocator, '}');
        },
        .union_ => |u| {
            try list.print(allocator, "({s}", .{u.name});
            if (!u.@"opaque" and u.fields.len > 0) {
                try list.append(allocator, '=');
                for (u.fields) |f| {
                    if (f.name) |name| {
                        try list.print(allocator, "\"{s}\"", .{name});
                    }
                    try writeQualified(allocator, list, f.type);
                }
            }
            try list.append(allocator, ')');
        },
        .bitfield => |b| try list.print(allocator, "b{d}", .{b.bits}),
        .atomic => |at| {
            try list.append(allocator, 'A');
            try writeQualified(allocator, list, at.child.*);
        },
    }
}
