//! Objective-C type encodings.
//!
//! https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html

const std = @import("std");
const raw = @import("../raw/root.zig");
const assert = std.debug.assert;

// TODO(phase-4): Implement complete type-encoding parser, dynamic type encodings, and validation.

/// How much space is needed to encode this type.
fn comptimeN(comptime T: type) usize {
    comptime {
        const encoding = Encoding.init(T);
        return std.fmt.count("{f}", .{encoding});
    }
}

/// Encode a type into a comptime null-terminated string.
pub fn comptimeEncode(comptime T: type) [comptimeN(T):0]u8 {
    comptime {
        const encoding = Encoding.init(T);

        var buf: [comptimeN(T) + 1]u8 = undefined;
        const result = std.fmt.bufPrint(buf[0 .. buf.len - 1], "{f}", .{encoding}) catch unreachable;
        buf[result.len] = 0;

        return buf[0..comptimeN(T) :0].*;
    }
}

/// Encoding union which parses type information and turns it into Obj-C
/// runtime Type Encodings.
pub const Encoding = union(enum) {
    char,
    int,
    short,
    long,
    longlong,
    uchar,
    uint,
    ushort,
    ulong,
    ulonglong,
    float,
    double,
    bool,
    void,
    char_string,
    object,
    class,
    selector,
    array: struct { arr_type: type, len: usize },
    structure: struct { struct_type: type, show_type_spec: bool },
    @"union": struct { union_type: type, show_type_spec: bool },
    bitfield: u32,
    pointer: struct { ptr_type: type, size: std.builtin.Type.Pointer.Size },
    function: std.builtin.Type.Fn,
    unknown,

    pub fn init(comptime T: type) Encoding {
        return switch (T) {
            i8, c_char => .char,
            c_short => .short,
            i32, c_int => .int,
            c_long => .long,
            i64, c_longlong => .longlong,
            u8 => .uchar,
            c_ushort => .ushort,
            u32, c_uint => .uint,
            c_ulong => .ulong,
            u64, c_ulonglong => .ulonglong,
            f32 => .float,
            f64 => .double,
            bool => .bool,
            void, anyopaque => .void,
            [*c]u8, [*c]const u8 => .char_string,
            raw.SEL => .selector,
            raw.Class => .class,
            raw.id => .object,
            else => switch (@typeInfo(T)) {
                .@"opaque" => .void,
                .@"enum" => |m| .init(m.tag_type),
                .array => |arr| .{ .array = .{ .len = arr.len, .arr_type = arr.child } },
                .@"struct" => |m| switch (m.layout) {
                    .@"packed" => .init(m.backing_integer.?),
                    else => blk: {
                        // ponytail: Duck-type wrappers by single field 'value' to decouple encoding from runtime.
                        if (m.fields.len == 1 and std.mem.eql(u8, m.fields[0].name, "value")) {
                            if (m.fields[0].type == raw.id) break :blk .object;
                            if (m.fields[0].type == raw.Class) break :blk .class;
                            if (m.fields[0].type == raw.SEL) break :blk .selector;
                        }
                        break :blk .{ .structure = .{ .struct_type = T, .show_type_spec = true } };
                    },
                },
                .@"union" => .{ .@"union" = .{
                    .union_type = T,
                    .show_type_spec = true,
                } },
                .optional => |m| switch (@typeInfo(m.child)) {
                    .pointer => |ptr| .{ .pointer = .{ .ptr_type = m.child, .size = ptr.size } },
                    else => @compileError("unsupported non-pointer optional type: " ++ @typeName(T)),
                },
                .pointer => |ptr| .{ .pointer = .{ .ptr_type = T, .size = ptr.size } },
                .@"fn" => |fn_info| .{ .function = fn_info },
                else => @compileError("unsupported type: " ++ @typeName(T)),
            },
        };
    }

    pub fn format(
        comptime self: Encoding,
        writer: anytype,
    ) !void {
        switch (self) {
            .char => try writer.writeAll("c"),
            .int => try writer.writeAll("i"),
            .short => try writer.writeAll("s"),
            .long => try writer.writeAll("l"),
            .longlong => try writer.writeAll("q"),
            .uchar => try writer.writeAll("C"),
            .uint => try writer.writeAll("I"),
            .ushort => try writer.writeAll("S"),
            .ulong => try writer.writeAll("L"),
            .ulonglong => try writer.writeAll("Q"),
            .float => try writer.writeAll("f"),
            .double => try writer.writeAll("d"),
            .bool => try writer.writeAll("B"),
            .void => try writer.writeAll("v"),
            .char_string => try writer.writeAll("*"),
            .object => try writer.writeAll("@"),
            .class => try writer.writeAll("#"),
            .selector => try writer.writeAll(":"),
            .array => |a| {
                try writer.print("[{}", .{a.len});
                const encode_type = init(a.arr_type);
                try encode_type.format(writer);
                try writer.writeAll("]");
            },
            .structure => |s| {
                const struct_info = @typeInfo(s.struct_type);
                assert(struct_info.@"struct".layout == .@"extern");

                var type_name_iter = std.mem.splitBackwardsScalar(u8, @typeName(s.struct_type), '.');
                const type_name = type_name_iter.first();
                try writer.print("{{{s}", .{type_name});

                if (s.show_type_spec) {
                    try writer.writeAll("=");
                    inline for (struct_info.@"struct".fields) |field| {
                        const field_encode = init(field.type);
                        try field_encode.format(writer);
                    }
                }

                try writer.writeAll("}");
            },
            .@"union" => |u| {
                const union_info = @typeInfo(u.union_type);
                assert(union_info.@"union".layout == .@"extern");

                var type_name_iter = std.mem.splitBackwardsScalar(u8, @typeName(u.union_type), '.');
                const type_name = type_name_iter.first();
                try writer.print("({s}", .{type_name});

                if (u.show_type_spec) {
                    try writer.writeAll("=");
                    inline for (union_info.@"union".fields) |field| {
                        const field_encode = init(field.type);
                        try field_encode.format(writer);
                    }
                }

                try writer.writeAll(")");
            },
            .bitfield => |b| try writer.print("b{}", .{b}),
            .pointer => |p| {
                switch (p.size) {
                    .one => {
                        const pointer_info = indirectionCountAndType(p.ptr_type);
                        for (0..pointer_info.indirection_levels) |_| {
                            try writer.writeAll("^");
                        }

                        comptime var encoding = init(pointer_info.child);

                        if (pointer_info.indirection_levels > 1) {
                            switch (encoding) {
                                .structure => |*s| s.show_type_spec = false,
                                .@"union" => |*u| u.show_type_spec = false,
                                else => {},
                            }
                        }

                        try encoding.format(writer);
                    },
                    else => @compileError("Pointer size not supported for encoding"),
                }
            },
            .function => |fn_info| {
                assert(std.meta.eql(fn_info.calling_convention, std.builtin.CallingConvention.c));

                const ret_type_enc = init(fn_info.return_type.?);
                try ret_type_enc.format(writer);
                inline for (fn_info.params) |param| {
                    const param_enc = init(param.type.?);
                    try param_enc.format(writer);
                }
            },
            .unknown => {},
        }
    }
};

fn indirectionCountAndType(comptime T: type) struct {
    child: type,
    indirection_levels: comptime_int,
} {
    var WalkType = T;
    var count: usize = 0;
    while (@typeInfo(WalkType) == .pointer) : (count += 1) {
        WalkType = @typeInfo(WalkType).pointer.child;
    }

    return .{ .child = WalkType, .indirection_levels = count };
}
