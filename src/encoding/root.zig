//! Objective-C type encoding and signature subsystem facade.
//!
//! Provides bidirectional translation between Zig types, Objective-C encoding
//! strings, and semantic AST representations:
//! - `comptimeEncode(T)`: Zig type -> Objective-C encoding string
//! - `parse(allocator, str)`: Objective-C encoding string -> semantic QualifiedType AST
//! - `encode(allocator, ast)`: Semantic QualifiedType AST -> Objective-C encoding string
//! - `parseMethod(allocator, str)`: Method encoding string -> MethodSignature
//! - `methodEncoding(Fn)`: Zig C callback -> compact method encoding string (e.g. `v@:i`)
//! - `parseProperty(allocator, str)`: Declared property attributes -> PropertyEncoding

const std = @import("std");

// Subsystem modules
pub const types = @import("type.zig");
pub const zig_type = @import("zig_type.zig");
pub const encoder = @import("encoder.zig");
pub const parser = @import("parser.zig");
pub const method = @import("method.zig");
pub const property = @import("property.zig");

// --- Semantic AST Types ---
pub const Type = types.Type;
pub const QualifiedType = types.QualifiedType;
pub const Qualifiers = types.Qualifiers;
pub const Scalar = types.Scalar;
pub const ObjectType = types.ObjectType;
pub const PointerType = types.PointerType;
pub const ArrayType = types.ArrayType;
pub const Field = types.Field;
pub const AggregateType = types.AggregateType;
pub const BitFieldType = types.BitFieldType;
pub const BlockType = types.BlockType;
pub const AtomicType = types.AtomicType;

// --- Parsing ---
pub const parse = parser.parse;
pub const ParseError = parser.ParseError;
pub const Parser = parser.Parser;
pub const parseMethod = method.parseMethod;
pub const parseProperty = property.parseProperty;

// --- Serialization & Encoding ---
pub const comptimeEncode = encoder.comptimeEncode;
pub const encode = encoder.encode;
pub const encodeMethod = method.encodeMethod;
pub const methodEncoding = method.methodEncoding;
pub const methodEncodingLength = method.methodEncodingLength;

// --- Method Signature Representation ---
pub const MethodSignature = method.MethodSignature;
pub const MethodArgument = method.MethodArgument;
pub const MethodEncodeOptions = method.MethodEncodeOptions;
pub const validateMethodImplementation = method.validateMethodImplementation;

// --- Property Attributes Representation ---
pub const PropertyEncoding = property.PropertyEncoding;

// --- Type Traits & Validation ---
pub const isObjCEncodable = zig_type.isObjCEncodable;
pub const assertObjCEncodable = zig_type.assertObjCEncodable;
pub const StorageType = zig_type.StorageType;

// --- Legacy Compatibility Shim ---
// Preserved for compatibility with upstream code querying Encoding.init(T).
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
            void => .void,
            [*c]u8, [*c]const u8 => .char_string,
            else => .unknown,
        };
    }
};

test {
    std.testing.refAllDecls(@This());
}
