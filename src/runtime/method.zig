//! Objective-C method handle.
//!
//! A non-owning, non-null handle to an Objective-C method descriptor (`Method`).

const std = @import("std");
const testing = std.testing;
const objc = @import("zobjc");
const raw = @import("raw");
const conversion = @import("conversion.zig");
const Selector = @import("selector.zig").Selector;
const Imp = @import("imp.zig").Imp;
const MethodDescription = @import("method_description.zig").MethodDescription;
const memory = @import("memory");
const encoding = @import("encoding");

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

    /// Directly invokes this method on `receiver` with tuple `args`.
    pub inline fn invoke(
        self: Method,
        comptime Return: type,
        receiver: anytype,
        args: anytype,
    ) Return {
        const messaging = @import("messaging");
        return messaging.invoke(self, Return, receiver, args);
    }

    /// Writes the return type string into a caller-provided buffer without heap allocation.
    pub inline fn returnType(self: Method, buffer: []u8) void {
        raw.runtime.method_getReturnType(self.ptr, buffer.ptr, buffer.len);
    }

    /// Writes a single argument type string into a caller-provided buffer without heap allocation.
    pub inline fn argumentType(self: Method, index: u32, buffer: []u8) void {
        raw.runtime.method_getArgumentType(self.ptr, @intCast(index), buffer.ptr, buffer.len);
    }

    /// Returns a caller-freed C string describing the method's return type, or null.
    pub inline fn copyReturnType(self: Method) ?memory.OwnedCString {
        const raw_str = raw.runtime.method_copyReturnType(self.ptr);
        return memory.OwnedCString.fromRaw(raw_str);
    }

    /// Returns a caller-freed C string describing the method's argument type at index, or null.
    pub inline fn copyArgumentType(self: Method, index: u32) ?memory.OwnedCString {
        const raw_str = raw.runtime.method_copyArgumentType(self.ptr, @intCast(index));
        return memory.OwnedCString.fromRaw(raw_str);
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

    /// Parses the method's runtime type encoding into a structured `MethodSignature`.
    pub fn parsedSignature(self: Method, allocator: std.mem.Allocator) !encoding.MethodSignature {
        const enc = self.typeEncoding() orelse return error.MissingTypeEncoding;
        return encoding.parseMethod(allocator, enc);
    }

    comptime {
        std.debug.assert(@sizeOf(@This()) == @sizeOf(raw.Method));
        std.debug.assert(@alignOf(@This()) == @alignOf(raw.Method));
    }
};

test "method: NSObject description method introspection" {
    const cls = objc.requireClass("NSObject");
    const desc_sel = objc.sel("description");
    const method = cls.instanceMethod(desc_sel).?;

    try testing.expect(method.selector().eql(desc_sel));
    try testing.expect(@intFromPtr(method.implementation().ptr) != 0);

    const enc = method.typeEncoding();
    try testing.expect(enc != null);
    try testing.expect(enc.?.len > 0);
    try testing.expect(method.argumentCount() >= 2);

    var ret_buf: [128]u8 = undefined;
    method.returnType(&ret_buf);
    try testing.expectEqualStrings("@", std.mem.sliceTo(&ret_buf, 0));

    var arg0_buf: [128]u8 = undefined;
    method.argumentType(0, &arg0_buf);
    try testing.expectEqualStrings("@", std.mem.sliceTo(&arg0_buf, 0));

    var arg1_buf: [128]u8 = undefined;
    method.argumentType(1, &arg1_buf);
    try testing.expectEqualStrings(":", std.mem.sliceTo(&arg1_buf, 0));

    const desc_struct = method.description();
    try testing.expect(desc_struct != null);
    try testing.expect(desc_struct.?.selector.?.eql(desc_sel));
}

test "method: exchange implementations" {
    const NSObject = objc.requireClass("NSObject");
    const Subclass = objc.allocateClassPair(NSObject, "MethodExchangeTestClass").?;

    const Dummy = struct {
        fn m1(target: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) i32 {
            _ = target;
            _ = sel_val;
            return 100;
        }
        fn m2(target: objc.raw.id, sel_val: objc.raw.SEL) callconv(.c) i32 {
            _ = target;
            _ = sel_val;
            return 200;
        }
    };

    const sel1 = objc.sel("methodOne");
    const sel2 = objc.sel("methodTwo");
    _ = Subclass.addMethod(sel1, objc.Imp.fromRawNonNull(@ptrCast(&Dummy.m1)), "i@:");
    _ = Subclass.addMethod(sel2, objc.Imp.fromRawNonNull(@ptrCast(&Dummy.m2)), "i@:");
    objc.registerClassPair(Subclass);
    defer objc.disposeClassPair(Subclass);

    const method1 = Subclass.instanceMethod(sel1).?;
    const method2 = Subclass.instanceMethod(sel2).?;
    const inst = Subclass.send(objc.Object, "alloc", .{})
        .send(objc.Object, "init", .{});
    defer inst.send(void, "dealloc", .{});

    try testing.expectEqual(@as(i32, 100), inst.send(i32, sel1, .{}));
    try testing.expectEqual(@as(i32, 200), inst.send(i32, sel2, .{}));
    method1.exchange(method2);
    try testing.expectEqual(@as(i32, 200), inst.send(i32, sel1, .{}));
    try testing.expectEqual(@as(i32, 100), inst.send(i32, sel2, .{}));
}

test "conversion: Method fromRaw and toRaw roundtrip" {
    const cls = objc.requireClass("NSObject");
    const method = cls.instanceMethod(objc.sel("init")).?;
    const raw_method = method.toRaw();
    try testing.expect(method.eql(Method.fromRaw(raw_method).?));
    try testing.expectEqual(@as(?Method, null), Method.fromRaw(null));
}

test "handle: Method is pointer-sized and pointer-aligned" {
    try testing.expectEqual(@sizeOf(usize), @sizeOf(Method));
    try testing.expectEqual(@alignOf(usize), @alignOf(Method));
}
