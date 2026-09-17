//! Recursive-descent parser for Objective-C type encodings.
//!
//! Parses primitive types, qualifiers, objects, blocks, atomics, pointers,
//! arrays, structures (including opaque and quoted-field variants), and unions.

const std = @import("std");
const types = @import("type.zig");
const QualifiedType = types.QualifiedType;
const Type = types.Type;
const Scalar = types.Scalar;
const Qualifiers = types.Qualifiers;
const Field = types.Field;
const AggregateType = types.AggregateType;
const ObjectType = types.ObjectType;
const testing = std.testing;
const encoder = @import("encoder.zig");

extern fn fixture_encode_char() [*:0]const u8;
extern fn fixture_encode_uchar() [*:0]const u8;
extern fn fixture_encode_short() [*:0]const u8;
extern fn fixture_encode_ushort() [*:0]const u8;
extern fn fixture_encode_int() [*:0]const u8;
extern fn fixture_encode_uint() [*:0]const u8;
extern fn fixture_encode_long() [*:0]const u8;
extern fn fixture_encode_ulong() [*:0]const u8;
extern fn fixture_encode_longlong() [*:0]const u8;
extern fn fixture_encode_ulonglong() [*:0]const u8;
extern fn fixture_encode_float() [*:0]const u8;
extern fn fixture_encode_double() [*:0]const u8;
extern fn fixture_encode_long_double() [*:0]const u8;
extern fn fixture_encode_bool() [*:0]const u8;
extern fn fixture_encode_c99_bool() [*:0]const u8;
extern fn fixture_encode_void() [*:0]const u8;
extern fn fixture_encode_char_ptr() [*:0]const u8;
extern fn fixture_encode_const_char_ptr() [*:0]const u8;
extern fn fixture_encode_void_ptr() [*:0]const u8;
extern fn fixture_encode_id() [*:0]const u8;
extern fn fixture_encode_class() [*:0]const u8;
extern fn fixture_encode_sel() [*:0]const u8;
extern fn fixture_encode_int_ptr() [*:0]const u8;
extern fn fixture_encode_int_ptr_ptr() [*:0]const u8;
extern fn fixture_encode_int_array_4() [*:0]const u8;
extern fn fixture_encode_float_array_16() [*:0]const u8;
extern fn fixture_encode_matrix_4_4() [*:0]const u8;
extern fn fixture_encode_struct_s1() [*:0]const u8;
extern fn fixture_encode_struct_cgpoint() [*:0]const u8;
extern fn fixture_encode_union_u1() [*:0]const u8;
extern fn fixture_encode_struct_nested() [*:0]const u8;
extern fn fixture_encode_struct_s1_ptr() [*:0]const u8;
extern fn fixture_encode_struct_s1_ptr_ptr() [*:0]const u8;
extern fn fixture_encode_block_void() [*:0]const u8;
extern fn fixture_encode_block_int() [*:0]const u8;
extern fn fixture_encode_atomic_int() [*:0]const u8;

pub const ParseError = error{
    UnexpectedEnd,
    UnexpectedCharacter,
    InvalidQualifier,
    InvalidNumber,
    NumberOverflow,
    MissingArrayTerminator,
    MissingStructTerminator,
    MissingUnionTerminator,
    MissingAggregateName,
    UnterminatedQuotedName,
    InvalidObjectEncoding,
    TrailingInput,
    MaxDepthExceeded,
    OutOfMemory,
};

pub const Parser = struct {
    input: []const u8,
    index: usize = 0,
    allocator: std.mem.Allocator,
    depth: usize = 0,
    max_depth: usize = 128,

    pub fn init(allocator: std.mem.Allocator, input: []const u8) Parser {
        return .{
            .input = input,
            .index = 0,
            .allocator = allocator,
            .depth = 0,
            .max_depth = 128,
        };
    }

    pub fn peek(self: *const Parser) ?u8 {
        if (self.index < self.input.len) {
            return self.input[self.index];
        }
        return null;
    }

    pub fn next(self: *Parser) ?u8 {
        if (self.index < self.input.len) {
            const ch = self.input[self.index];
            self.index += 1;
            return ch;
        }
        return null;
    }

    pub fn expect(self: *Parser, expected_ch: u8) !void {
        const ch = self.next() orelse return error.UnexpectedEnd;
        if (ch != expected_ch) return error.UnexpectedCharacter;
    }

    /// Parses optional type qualifiers ('r', 'n', 'N', 'o', 'O', 'R', 'V').
    pub fn parseQualifiers(self: *Parser) Qualifiers {
        var q: Qualifiers = .{};
        while (self.peek()) |ch| {
            switch (ch) {
                'r' => q.const_ = true,
                'n' => q.in = true,
                'N' => q.inout = true,
                'o' => q.out = true,
                'O' => q.bycopy = true,
                'R' => q.byref = true,
                'V' => q.oneway = true,
                else => break,
            }
            self.index += 1;
        }
        return q;
    }

    /// Parses a decimal integer from the input.
    pub fn parseNumber(self: *Parser) !usize {
        const start = self.index;
        while (self.peek()) |ch| {
            if (ch >= '0' and ch <= '9') {
                self.index += 1;
            } else {
                break;
            }
        }
        if (self.index == start) return error.InvalidNumber;
        return std.fmt.parseInt(usize, self.input[start..self.index], 10) catch error.NumberOverflow;
    }

    /// Parses a signed decimal integer from the input.
    pub fn parseSignedNumber(self: *Parser) !isize {
        const start = self.index;
        if (self.peek()) |ch| {
            if (ch == '+' or ch == '-') {
                self.index += 1;
            }
        }
        const digit_start = self.index;
        while (self.peek()) |ch| {
            if (ch >= '0' and ch <= '9') {
                self.index += 1;
            } else {
                break;
            }
        }
        if (self.index == digit_start) return error.InvalidNumber;
        return std.fmt.parseInt(isize, self.input[start..self.index], 10) catch error.NumberOverflow;
    }

    /// Parses a single type along with any preceding qualifiers.
    pub fn parseQualifiedType(self: *Parser) ParseError!QualifiedType {
        if (self.depth >= self.max_depth) return error.MaxDepthExceeded;
        self.depth += 1;
        defer self.depth -= 1;

        const start = self.index;
        const q = self.parseQualifiers();
        const t = try self.parseType();

        return .{
            .qualifiers = q,
            .type = t,
            .source = self.input[start..self.index],
        };
    }

    /// Parses the semantic type itself.
    pub fn parseType(self: *Parser) ParseError!Type {
        const ch = self.next() orelse return error.UnexpectedEnd;
        switch (ch) {
            'c' => return .{ .scalar = .char },
            'C' => return .{ .scalar = .uchar },
            's' => return .{ .scalar = .short },
            'S' => return .{ .scalar = .ushort },
            'i' => return .{ .scalar = .int },
            'I' => return .{ .scalar = .uint },
            'l' => return .{ .scalar = .long },
            'L' => return .{ .scalar = .ulong },
            'q' => return .{ .scalar = .longlong },
            'Q' => return .{ .scalar = .ulonglong },
            'j' => return .{ .scalar = .int128 },
            'J' => return .{ .scalar = .uint128 },
            'f' => return .{ .scalar = .float },
            'd' => return .{ .scalar = .double },
            'D' => return .{ .scalar = .long_double },
            'B' => return .{ .scalar = .bool },
            'v' => return .{ .scalar = .void },
            '*' => return .{ .scalar = .char_string },
            '#' => return .class,
            ':' => return .selector,
            '?' => return .unknown,
            '@' => return self.parseObjectOrBlock(),
            '^' => return self.parsePointerOrFnPtr(),
            '[' => return self.parseArray(),
            '{' => return self.parseAggregate('}', false),
            '(' => return self.parseAggregate(')', true),
            'b' => return self.parseBitfield(),
            'A' => return self.parseAtomic(),
            else => return error.UnexpectedCharacter,
        }
    }

    fn parseObjectOrBlock(self: *Parser) ParseError!Type {
        if (self.peek()) |ch| {
            if (ch == '?') {
                self.index += 1;
                return .{ .block = .{} };
            }
            if (ch == '"') {
                self.index += 1;
                return self.parseDetailedObject();
            }
        }
        return .{ .object = .{} };
    }

    fn parseDetailedObject(self: *Parser) ParseError!Type {
        // Syntax: @"ClassName<Proto1><Proto2>" or @"<Proto1>"
        var class_name: ?[]const u8 = null;
        var protocols: std.ArrayList([]const u8) = .empty;
        errdefer {
            if (class_name) |c| self.allocator.free(c);
            for (protocols.items) |p| self.allocator.free(p);
            protocols.deinit(self.allocator);
        }

        const name_start = self.index;
        while (self.peek()) |ch| {
            if (ch == '"' or ch == '<') break;
            self.index += 1;
        }

        if (self.index > name_start) {
            class_name = try self.allocator.dupe(u8, self.input[name_start..self.index]);
        }

        while (self.peek()) |ch| {
            if (ch == '<') {
                self.index += 1;
                const proto_start = self.index;
                while (self.peek()) |p_ch| {
                    if (p_ch == '>') break;
                    self.index += 1;
                }
                if (self.peek() != '>') return error.InvalidObjectEncoding;
                var proto_name: ?[]const u8 = try self.allocator.dupe(u8, self.input[proto_start..self.index]);
                errdefer if (proto_name) |value| self.allocator.free(value);
                try protocols.append(self.allocator, proto_name.?);
                proto_name = null;
                self.index += 1; // consume '>'
            } else if (ch == '"') {
                self.index += 1; // consume closing quote
                break;
            } else {
                return error.InvalidObjectEncoding;
            }
        }

        return .{
            .object = .{
                .class_name = class_name,
                .protocols = try protocols.toOwnedSlice(self.allocator),
            },
        };
    }

    fn parsePointerOrFnPtr(self: *Parser) ParseError!Type {
        if (self.peek()) |ch| {
            if (ch == '?') {
                self.index += 1;
                return .function_pointer;
            }
        }

        const child = try self.allocator.create(QualifiedType);
        errdefer self.allocator.destroy(child);

        child.* = try self.parseQualifiedType();
        return .{ .pointer = .{ .child = child } };
    }

    fn parseArray(self: *Parser) ParseError!Type {
        const len = try self.parseNumber();
        const child = try self.allocator.create(QualifiedType);
        errdefer self.allocator.destroy(child);

        child.* = try self.parseQualifiedType();

        const closing = self.next() orelse return error.MissingArrayTerminator;
        if (closing != ']') return error.MissingArrayTerminator;
        return .{ .array = .{ .len = len, .child = child } };
    }

    fn parseBitfield(self: *Parser) ParseError!Type {
        const bits = try self.parseNumber();
        return .{ .bitfield = .{ .bits = @intCast(bits) } };
    }

    fn parseAtomic(self: *Parser) ParseError!Type {
        const child = try self.allocator.create(QualifiedType);
        errdefer self.allocator.destroy(child);

        child.* = try self.parseQualifiedType();
        return .{ .atomic = .{ .child = child } };
    }

    fn parseAggregate(self: *Parser, closing_ch: u8, is_union: bool) ParseError!Type {
        const name_start = self.index;
        while (self.peek()) |ch| {
            if (ch == '=' or ch == closing_ch) break;
            self.index += 1;
        }

        if (self.index == name_start) return error.MissingAggregateName;
        const name = try self.allocator.dupe(u8, self.input[name_start..self.index]);
        errdefer self.allocator.free(name);

        var fields: std.ArrayList(Field) = .empty;
        errdefer {
            for (fields.items) |*f| f.deinit(self.allocator);
            fields.deinit(self.allocator);
        }

        const next_ch = self.next() orelse return if (is_union) error.MissingUnionTerminator else error.MissingStructTerminator;

        if (next_ch == closing_ch) {
            // Opaque aggregate: {Foo} or (Foo)
            const agg: AggregateType = .{
                .name = name,
                .fields = &.{},
                .@"opaque" = true,
            };
            return if (is_union) .{ .union_ = agg } else .{ .structure = agg };
        }

        if (next_ch != '=') return error.UnexpectedCharacter;

        // Parse fields until closing_ch
        var closed = false;
        while (self.peek()) |ch| {
            if (ch == closing_ch) {
                self.index += 1;
                closed = true;
                break;
            }

            var field_name: ?[]const u8 = null;
            errdefer if (field_name) |field_name_value| self.allocator.free(field_name_value);
            if (ch == '"') {
                self.index += 1;
                const fn_start = self.index;
                while (self.peek()) |q_ch| {
                    if (q_ch == '"') break;
                    self.index += 1;
                }
                if (self.peek() != '"') return error.UnterminatedQuotedName;
                field_name = try self.allocator.dupe(u8, self.input[fn_start..self.index]);
                self.index += 1; // consume closing quote
            }

            var field_type: ?QualifiedType = try self.parseQualifiedType();
            errdefer if (field_type) |*parsed| parsed.deinit(self.allocator);
            try fields.append(self.allocator, .{
                .name = field_name,
                .type = field_type.?,
            });
            field_name = null;
            field_type = null;
        }

        if (!closed) return if (is_union) error.MissingUnionTerminator else error.MissingStructTerminator;

        const agg: AggregateType = .{
            .name = name,
            .fields = try fields.toOwnedSlice(self.allocator),
            .@"opaque" = false,
        };
        return if (is_union) .{ .union_ = agg } else .{ .structure = agg };
    }
};

/// Public entry point to parse an Objective-C type encoding string.
pub fn parse(allocator: std.mem.Allocator, input: []const u8) !QualifiedType {
    if (input.len == 0) return error.UnexpectedEnd;
    var parser = Parser.init(allocator, input);
    const result = try parser.parseQualifiedType();
    if (parser.index < input.len) {
        // clean up AST if trailing input is present
        var mut_res = result;
        mut_res.deinit(allocator);
        return error.TrailingInput;
    }
    return result;
}

test "parser: primitives and qualifiers" {
    const allocator = testing.allocator;
    var int_type = try parse(allocator, "i");
    defer int_type.deinit(allocator);
    try testing.expect(int_type.type == .scalar and int_type.type.scalar == .int);

    var dbl_type = try parse(allocator, "d");
    defer dbl_type.deinit(allocator);
    try testing.expect(dbl_type.type == .scalar and dbl_type.type.scalar == .double);

    var void_type = try parse(allocator, "v");
    defer void_type.deinit(allocator);
    try testing.expect(void_type.type == .scalar and void_type.type.scalar == .void);

    var sel_type = try parse(allocator, ":");
    defer sel_type.deinit(allocator);
    try testing.expect(sel_type.type == .selector);

    var cls_type = try parse(allocator, "#");
    defer cls_type.deinit(allocator);
    try testing.expect(cls_type.type == .class);

    var const_ptr = try parse(allocator, "r^i");
    defer const_ptr.deinit(allocator);
    try testing.expect(const_ptr.qualifiers.const_);
    try testing.expect(const_ptr.type == .pointer);

    var inout_obj = try parse(allocator, "N@");
    defer inout_obj.deinit(allocator);
    try testing.expect(inout_obj.qualifiers.inout);
    try testing.expect(inout_obj.type == .object);

    var oneway_void = try parse(allocator, "Vv");
    defer oneway_void.deinit(allocator);
    try testing.expect(oneway_void.qualifiers.oneway);
    try testing.expect(oneway_void.type == .scalar and oneway_void.type.scalar == .void);
}

test "parser: object variants" {
    const allocator = testing.allocator;
    var plain_obj = try parse(allocator, "@");
    defer plain_obj.deinit(allocator);
    try testing.expect(plain_obj.type == .object);
    try testing.expect(plain_obj.type.object.class_name == null);

    var block_obj = try parse(allocator, "@?");
    defer block_obj.deinit(allocator);
    try testing.expect(block_obj.type == .block);

    var str_obj = try parse(allocator, "@\"NSString\"");
    defer str_obj.deinit(allocator);
    try testing.expect(str_obj.type == .object);
    try testing.expectEqualStrings("NSString", str_obj.type.object.class_name.?);

    var proto_obj = try parse(allocator, "@\"<NSCopying>\"");
    defer proto_obj.deinit(allocator);
    try testing.expect(proto_obj.type == .object);
    try testing.expect(proto_obj.type.object.class_name == null);
    try testing.expectEqual(@as(usize, 1), proto_obj.type.object.protocols.len);
    try testing.expectEqualStrings("NSCopying", proto_obj.type.object.protocols[0]);

    var multi_obj = try parse(allocator, "@\"NSString<NSCopying><NSSecureCoding>\"");
    defer multi_obj.deinit(allocator);
    try testing.expect(multi_obj.type == .object);
    try testing.expectEqualStrings("NSString", multi_obj.type.object.class_name.?);
    try testing.expectEqual(@as(usize, 2), multi_obj.type.object.protocols.len);
    try testing.expectEqualStrings("NSCopying", multi_obj.type.object.protocols[0]);
    try testing.expectEqualStrings("NSSecureCoding", multi_obj.type.object.protocols[1]);
}

test "parser: pointers, arrays, bitfields, and atomics" {
    const allocator = testing.allocator;
    var ptr = try parse(allocator, "^i");
    defer ptr.deinit(allocator);
    try testing.expect(ptr.type == .pointer);
    try testing.expect(ptr.type.pointer.child.type == .scalar and ptr.type.pointer.child.type.scalar == .int);

    var fn_ptr = try parse(allocator, "^?");
    defer fn_ptr.deinit(allocator);
    try testing.expect(fn_ptr.type == .function_pointer);

    var arr = try parse(allocator, "[8i]");
    defer arr.deinit(allocator);
    try testing.expect(arr.type == .array);
    try testing.expectEqual(@as(usize, 8), arr.type.array.len);
    try testing.expect(arr.type.array.child.type == .scalar and arr.type.array.child.type.scalar == .int);

    var nested_arr = try parse(allocator, "[2[3f]]");
    defer nested_arr.deinit(allocator);
    try testing.expect(nested_arr.type == .array);
    try testing.expectEqual(@as(usize, 2), nested_arr.type.array.len);
    try testing.expect(nested_arr.type.array.child.type == .array);
    try testing.expectEqual(@as(usize, 3), nested_arr.type.array.child.type.array.len);

    var bf = try parse(allocator, "b5");
    defer bf.deinit(allocator);
    try testing.expect(bf.type == .bitfield);
    try testing.expectEqual(@as(u32, 5), bf.type.bitfield.bits);

    var at = try parse(allocator, "Ai");
    defer at.deinit(allocator);
    try testing.expect(at.type == .atomic);
    try testing.expect(at.type.atomic.child.type == .scalar and at.type.atomic.child.type.scalar == .int);
}

test "parser: structures and unions" {
    const allocator = testing.allocator;
    var point = try parse(allocator, "{CGPoint=dd}");
    defer point.deinit(allocator);
    try testing.expect(point.type == .structure);
    try testing.expectEqualStrings("CGPoint", point.type.structure.name);
    try testing.expectEqual(@as(usize, 2), point.type.structure.fields.len);

    var opaque_st = try parse(allocator, "{OpaqueType}");
    defer opaque_st.deinit(allocator);
    try testing.expect(opaque_st.type == .structure);
    try testing.expectEqualStrings("OpaqueType", opaque_st.type.structure.name);
    try testing.expect(opaque_st.type.structure.@"opaque");

    var anon_st = try parse(allocator, "{?=dd}");
    defer anon_st.deinit(allocator);
    try testing.expect(anon_st.type == .structure);
    try testing.expectEqualStrings("?", anon_st.type.structure.name);

    var quoted_st = try parse(allocator, "{CGPoint=\"x\"d\"y\"d}");
    defer quoted_st.deinit(allocator);
    try testing.expect(quoted_st.type == .structure);
    try testing.expectEqualStrings("x", quoted_st.type.structure.fields[0].name.?);
    try testing.expectEqualStrings("y", quoted_st.type.structure.fields[1].name.?);

    var union_val = try parse(allocator, "(U1=if)");
    defer union_val.deinit(allocator);
    try testing.expect(union_val.type == .union_);
    try testing.expectEqualStrings("U1", union_val.type.union_.name);
    try testing.expectEqual(@as(usize, 2), union_val.type.union_.fields.len);
}

test "parser: round-trip and invalid input" {
    const allocator = testing.allocator;
    const test_encodings = [_][]const u8{ "i", "d", "B", "^i", "[4f]", "{CGPoint=dd}", "(U1=if)", "@\"NSString\"", "@?", "^?", "b7", "Ai" };
    for (test_encodings) |original| {
        var parsed1 = try parse(allocator, original);
        defer parsed1.deinit(allocator);
        const encoded_str = try encoder.encode(allocator, parsed1);
        defer allocator.free(encoded_str);
        var parsed2 = try parse(allocator, encoded_str);
        defer parsed2.deinit(allocator);
        try testing.expect(parsed1.eql(parsed2));
    }

    try testing.expectError(error.UnexpectedEnd, parse(allocator, ""));
    try testing.expectError(error.MissingStructTerminator, parse(allocator, "{CGPoint=dd"));
    try testing.expectError(error.MissingArrayTerminator, parse(allocator, "[4i"));
    try testing.expectError(error.MissingAggregateName, parse(allocator, "{}"));
    try testing.expectError(error.InvalidNumber, parse(allocator, "[i]"));
    try testing.expectError(error.InvalidNumber, parse(allocator, "b"));
    try testing.expectError(error.TrailingInput, parse(allocator, "i extra"));
}

test "parser: allocation failures clean partial aggregate trees" {
    const input = "{Thing=\"first\"@\"Class<Proto>\"\"second\"{Nested=i}}";
    for (0..64) |fail_index| {
        var failing = std.testing.FailingAllocator.init(testing.allocator, .{ .fail_index = fail_index });
        const allocator = failing.allocator();
        if (parse(allocator, input)) |parsed| {
            var owned = parsed;
            owned.deinit(allocator);
        } else |err| switch (err) {
            error.OutOfMemory => {},
            else => return err,
        }
        try testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
    }
}

test "parser: round-trip every Clang fixture encoding" {
    const fixtures = [_]*const fn () callconv(.c) [*:0]const u8{
        fixture_encode_char,
        fixture_encode_uchar,
        fixture_encode_short,
        fixture_encode_ushort,
        fixture_encode_int,
        fixture_encode_uint,
        fixture_encode_long,
        fixture_encode_ulong,
        fixture_encode_longlong,
        fixture_encode_ulonglong,
        fixture_encode_float,
        fixture_encode_double,
        fixture_encode_long_double,
        fixture_encode_bool,
        fixture_encode_c99_bool,
        fixture_encode_void,
        fixture_encode_char_ptr,
        fixture_encode_const_char_ptr,
        fixture_encode_void_ptr,
        fixture_encode_id,
        fixture_encode_class,
        fixture_encode_sel,
        fixture_encode_int_ptr,
        fixture_encode_int_ptr_ptr,
        fixture_encode_int_array_4,
        fixture_encode_float_array_16,
        fixture_encode_matrix_4_4,
        fixture_encode_struct_s1,
        fixture_encode_struct_cgpoint,
        fixture_encode_union_u1,
        fixture_encode_struct_nested,
        fixture_encode_struct_s1_ptr,
        fixture_encode_struct_s1_ptr_ptr,
        fixture_encode_block_void,
        fixture_encode_block_int,
        fixture_encode_atomic_int,
    };

    for (fixtures) |fixture| {
        const original = std.mem.span(fixture());
        var parsed = try parse(testing.allocator, original);
        defer parsed.deinit(testing.allocator);
        const encoded = try encoder.encode(testing.allocator, parsed);
        defer testing.allocator.free(encoded);
        try testing.expectEqualStrings(original, encoded);
    }
}
