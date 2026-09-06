//! Semantic representation of Objective-C type encodings.
//!
//! Models parsed Objective-C encodings as a semantic AST rather than raw characters.
//! Supports recursive structures, qualifiers, objects, blocks, atomics, bitfields, etc.

const std = @import("std");

/// Objective-C method parameter and return type qualifiers.
pub const Qualifiers = packed struct {
    const_: bool = false, // 'r'
    in: bool = false, // 'n'
    inout: bool = false, // 'N'
    out: bool = false, // 'o'
    bycopy: bool = false, // 'O'
    byref: bool = false, // 'R'
    oneway: bool = false, // 'V'

    pub fn isEmpty(self: Qualifiers) bool {
        return !self.const_ and !self.in and !self.inout and !self.out and
            !self.bycopy and !self.byref and !self.oneway;
    }
};

/// Primitive scalar types in Objective-C type encoding.
pub const Scalar = enum {
    char, // 'c'
    uchar, // 'C'
    short, // 's'
    ushort, // 'S'
    int, // 'i'
    uint, // 'I'
    long, // 'l'
    ulong, // 'L'
    longlong, // 'q'
    ulonglong, // 'Q'
    int128, // 'j' (Clang extension)
    uint128, // 'J' (Clang extension)
    float, // 'f'
    double, // 'd'
    long_double, // 'D' (modern Clang)
    bool, // 'B'
    void, // 'v'
    char_string, // '*' (char *)
};

/// Objective-C object type encoding ('@', '@"NSString"', '@"<NSCopying>"').
pub const ObjectType = struct {
    class_name: ?[]const u8 = null,
    protocols: []const []const u8 = &.{},

    pub fn deinit(self: *ObjectType, allocator: std.mem.Allocator) void {
        if (self.class_name) |name| allocator.free(name);
        for (self.protocols) |proto| {
            allocator.free(proto);
        }
        if (self.protocols.len > 0) {
            allocator.free(self.protocols);
        }
        self.* = .{};
    }

    pub fn eql(self: ObjectType, other: ObjectType) bool {
        if (self.class_name == null and other.class_name != null) return false;
        if (self.class_name != null and other.class_name == null) return false;
        if (self.class_name != null and other.class_name != null) {
            if (!std.mem.eql(u8, self.class_name.?, other.class_name.?)) return false;
        }
        if (self.protocols.len != other.protocols.len) return false;
        for (self.protocols, other.protocols) |p1, p2| {
            if (!std.mem.eql(u8, p1, p2)) return false;
        }
        return true;
    }
};

/// Pointer type encoding ('^T').
pub const PointerType = struct {
    child: *QualifiedType,

    pub fn deinit(self: *PointerType, allocator: std.mem.Allocator) void {
        self.child.deinit(allocator);
        allocator.destroy(self.child);
    }
};

/// Fixed-size array type encoding ('[len T]').
pub const ArrayType = struct {
    len: usize,
    child: *QualifiedType,

    pub fn deinit(self: *ArrayType, allocator: std.mem.Allocator) void {
        self.child.deinit(allocator);
        allocator.destroy(self.child);
    }
};

/// Field inside an aggregate (structure or union).
pub const Field = struct {
    name: ?[]const u8 = null,
    type: QualifiedType,

    pub fn deinit(self: *Field, allocator: std.mem.Allocator) void {
        if (self.name) |n| allocator.free(n);
        self.type.deinit(allocator);
    }

    pub fn eql(self: Field, other: Field) bool {
        if (self.name == null and other.name != null) return false;
        if (self.name != null and other.name == null) return false;
        if (self.name != null and other.name != null) {
            if (!std.mem.eql(u8, self.name.?, other.name.?)) return false;
        }
        return self.type.eql(other.type);
    }
};

/// Aggregate type encoding (structure '{name=...}' or union '(name=...)').
pub const AggregateType = struct {
    name: []const u8,
    fields: []Field = &.{},
    @"opaque": bool = false,

    pub fn deinit(self: *AggregateType, allocator: std.mem.Allocator) void {
        if (self.name.len > 0) allocator.free(self.name);
        for (self.fields) |*f| {
            f.deinit(allocator);
        }
        if (self.fields.len > 0) {
            allocator.free(self.fields);
        }
        self.* = .{ .name = "" };
    }

    pub fn eql(self: AggregateType, other: AggregateType) bool {
        if (self.@"opaque" != other.@"opaque") return false;
        if (!std.mem.eql(u8, self.name, other.name)) return false;
        if (self.fields.len != other.fields.len) return false;
        for (self.fields, other.fields) |f1, f2| {
            if (!f1.eql(f2)) return false;
        }
        return true;
    }
};

/// Bitfield type encoding ('bN').
pub const BitFieldType = struct {
    bits: u32,
};

/// Block pointer encoding ('@?').
pub const BlockType = struct {};

/// Atomic wrapper type encoding ('A...').
pub const AtomicType = struct {
    child: *QualifiedType,

    pub fn deinit(self: *AtomicType, allocator: std.mem.Allocator) void {
        self.child.deinit(allocator);
        allocator.destroy(self.child);
    }
};

/// Semantic Objective-C type.
pub const Type = union(enum) {
    scalar: Scalar,
    object: ObjectType,
    class, // '#'
    selector, // ':'
    pointer: PointerType,
    array: ArrayType,
    structure: AggregateType,
    union_: AggregateType,
    bitfield: BitFieldType,
    block: BlockType,
    function_pointer, // '^?'
    atomic: AtomicType,
    unknown, // '?'

    pub fn deinit(self: *Type, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .object => |*obj| obj.deinit(allocator),
            .pointer => |*ptr| ptr.deinit(allocator),
            .array => |*arr| arr.deinit(allocator),
            .structure, .union_ => |*agg| agg.deinit(allocator),
            .atomic => |*at| at.deinit(allocator),
            else => {},
        }
        self.* = .unknown;
    }

    pub fn eql(self: Type, other: Type) bool {
        const Tag = std.meta.Tag(Type);
        if (@as(Tag, self) != @as(Tag, other)) return false;

        return switch (self) {
            .scalar => |s| s == other.scalar,
            .object => |obj| obj.eql(other.object),
            .class, .selector, .block, .function_pointer, .unknown => true,
            .pointer => |ptr| ptr.child.eql(other.pointer.child.*),
            .array => |arr| arr.len == other.array.len and arr.child.eql(other.array.child.*),
            .structure => |s| s.eql(other.structure),
            .union_ => |u| u.eql(other.union_),
            .bitfield => |b| b.bits == other.bitfield.bits,
            .atomic => |a| a.child.eql(other.atomic.child.*),
        };
    }
};

/// A type coupled with its method parameter/return qualifiers.
pub const QualifiedType = struct {
    qualifiers: Qualifiers = .{},
    type: Type,
    source: ?[]const u8 = null,

    pub fn deinit(self: *QualifiedType, allocator: std.mem.Allocator) void {
        self.type.deinit(allocator);
        self.qualifiers = .{};
        self.source = null;
    }

    pub fn eql(self: QualifiedType, other: QualifiedType) bool {
        if (!std.meta.eql(self.qualifiers, other.qualifiers)) return false;
        return self.type.eql(other.type);
    }
};
