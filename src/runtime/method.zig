//! Objective-C method handle.
//!
//! A non-owning, non-null handle to an Objective-C method descriptor (`Method`).

const std = @import("std");
const raw = @import("../raw/root.zig");
const conversion = @import("conversion.zig");
const Selector = @import("selector.zig").Selector;
const Imp = @import("imp.zig").Imp;
const MethodDescription = @import("method_description.zig").MethodDescription;

pub const Method = struct {
    ptr: *raw.objc_method,

    /// Converts a raw nullable `raw.Method` into an optional `Method`.
    pub inline fn fromRaw(val: raw.Method) ?Method {
        const p = val orelse return null;
        return .{ .ptr = p };
    }

    /// Converts this `Method` into its raw `raw.Method` pointer.
    pub inline fn toRaw(self: Method) raw.Method {
        return self.ptr;
    }

    /// Creates a `Method` from a known non-null raw method pointer.
    pub inline fn fromRawNonNull(p: *raw.objc_method) Method {
        return .{ .ptr = p };
    }

    /// Returns the selector representing the method name.
    pub inline fn selector(self: Method) Selector {
        return Selector.fromRaw(raw.runtime.method_getName(self.ptr)).?;
    }

    /// Returns the implementation function pointer of the method.
    pub inline fn implementation(self: Method) Imp {
        return Imp.fromRaw(raw.runtime.method_getImplementation(self.ptr)).?;
    }

    /// Returns a borrowed string describing the method's parameter and return types.
    pub inline fn typeEncoding(self: Method) ?[:0]const u8 {
        return conversion.spanNullableCString(raw.runtime.method_getTypeEncoding(self.ptr));
    }

    /// Returns the total number of arguments accepted by this method (including receiver and selector).
    pub inline fn argumentCount(self: Method) u32 {
        return @intCast(raw.runtime.method_getNumberOfArguments(self.ptr));
    }

    /// Writes the return type string into a caller-provided buffer without heap allocation.
    pub inline fn returnType(self: Method, buffer: []u8) void {
        raw.runtime.method_getReturnType(self.ptr, buffer.ptr, buffer.len);
    }

    /// Writes a single argument type string into a caller-provided buffer without heap allocation.
    pub inline fn argumentType(self: Method, index: u32, buffer: []u8) void {
        raw.runtime.method_getArgumentType(self.ptr, @intCast(index), buffer.ptr, buffer.len);
    }

    /// Returns a pointer to a method description structure.
    pub inline fn description(self: Method) ?MethodDescription {
        const desc_ptr = raw.runtime.method_getDescription(self.ptr) orelse return null;
        return MethodDescription.fromRaw(desc_ptr.*);
    }

    /// Sets the implementation of this method, returning the previous implementation.
    pub inline fn setImplementation(self: Method, imp_val: Imp) Imp {
        return Imp.fromRaw(raw.runtime.method_setImplementation(self.ptr, imp_val.toRaw())).?;
    }

    /// Atomically exchanges the implementations of two methods (method swizzling).
    pub inline fn exchange(self: Method, other: Method) void {
        raw.runtime.method_exchangeImplementations(self.ptr, other.ptr);
    }

    /// Tests method equality by comparing pointer addresses.
    pub inline fn eql(self: Method, other: Method) bool {
        return self.ptr == other.ptr;
    }

    comptime {
        std.debug.assert(@sizeOf(@This()) == @sizeOf(raw.Method));
        std.debug.assert(@alignOf(@This()) == @alignOf(raw.Method));
    }
};
