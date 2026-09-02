//! Example demonstrating Phase 2 runtime introspection handles.

const std = @import("std");
const objc = @import("objc");

pub fn main() void {
    // 1. Class Introspection
    const cls = objc.requireClass("NSObject");
    std.debug.print("Class: {s}\n", .{cls.name()});
    std.debug.print("  isMetaClass: {}\n", .{cls.isMetaClass()});
    std.debug.print("  instanceSize: {d} bytes\n", .{cls.instanceSize()});

    if (cls.superclass()) |super| {
        std.debug.print("  superclass: {s}\n", .{super.name()});
    } else {
        std.debug.print("  superclass: (root class)\n", .{});
    }

    // 2. Method Introspection
    const desc_sel = objc.sel("description");
    if (cls.instanceMethod(desc_sel)) |method| {
        std.debug.print("Method: -[{s} {s}]\n", .{ cls.name(), method.selector().name() });
        if (method.typeEncoding()) |enc| {
            std.debug.print("  typeEncoding: {s}\n", .{enc});
        }
        std.debug.print("  argumentCount: {d}\n", .{method.argumentCount()});

        var ret_buf: [32]u8 = undefined;
        method.returnType(&ret_buf);
        std.debug.print("  returnType: {s}\n", .{std.mem.sliceTo(&ret_buf, 0)});
    }

    // 3. Protocol Introspection
    if (objc.getProtocol("NSObject")) |proto| {
        std.debug.print("Protocol: {s}\n", .{proto.name()});
        std.debug.print("  NSObject conforms: {}\n", .{cls.conformsTo(proto)});
    }

    // 4. Instance Introspection
    const obj = cls.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    defer obj.msgSend(void, "dealloc", .{});

    std.debug.print("Object: instance of {s}\n", .{obj.className()});
    std.debug.print("  isClass: {}\n", .{obj.isClass()});
}
