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
                const proto_name = try self.allocator.dupe(u8, self.input[proto_start..self.index]);
                try protocols.append(self.allocator, proto_name);
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

            const field_type = try self.parseQualifiedType();
            try fields.append(self.allocator, .{
                .name = field_name,
                .type = field_type,
            });
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
        // ponytail: clean up AST if trailing input is present
        var mut_res = result;
        mut_res.deinit(allocator);
        return error.TrailingInput;
    }
    return result;
}
