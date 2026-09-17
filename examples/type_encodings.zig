//! Example demonstrating Objective-C type encoding and signature system.

const std = @import("std");
const objc = @import("zobjc");

const Point = extern struct {
    x: f64,
    y: f64,
};

const Rect = extern struct {
    origin: Point,
    size: extern struct {
        width: f64,
        height: f64,
    },
};

const SampleCallback = fn (
    self: objc.Object,
    sel: objc.Selector,
    count: c_int,
    rect: Rect,
) callconv(.c) ?objc.Object;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("--- 1. Compile-Time Type Encoding ---\n", .{});
    std.debug.print("i32:         {s}\n", .{objc.encoding.comptimeEncode(i32)});
    std.debug.print("f64:         {s}\n", .{objc.encoding.comptimeEncode(f64)});
    std.debug.print("bool:        {s}\n", .{objc.encoding.comptimeEncode(bool)});
    std.debug.print("Object:      {s}\n", .{objc.encoding.comptimeEncode(objc.Object)});
    std.debug.print("Class:       {s}\n", .{objc.encoding.comptimeEncode(objc.Class)});
    std.debug.print("Selector:    {s}\n", .{objc.encoding.comptimeEncode(objc.Selector)});
    std.debug.print("Point:       {s}\n", .{objc.encoding.comptimeEncode(Point)});
    std.debug.print("Rect:        {s}\n", .{objc.encoding.comptimeEncode(Rect)});
    std.debug.print("[4]f32:      {s}\n", .{objc.encoding.comptimeEncode([4]f32)});

    std.debug.print("\n--- 2. Method Callback Encoding ---\n", .{});
    const method_enc = objc.encoding.methodEncoding(SampleCallback);
    std.debug.print("SampleCallback:       {s}\n", .{method_enc});

    std.debug.print("\n--- 3. Parsing & Round-Trip Serializing ---\n", .{});
    const rect_enc = "{Rect={Point=dd}{?=dd}}";
    var parsed_rect = try objc.encoding.parse(allocator, rect_enc);
    defer parsed_rect.deinit(allocator);

    const re_encoded = try objc.encoding.encode(allocator, parsed_rect);
    defer allocator.free(re_encoded);
    std.debug.print("Original:   {s}\n", .{rect_enc});
    std.debug.print("Re-encoded: {s}\n", .{re_encoded});

    std.debug.print("\n--- 4. Method Signature Parsing with Stack Layout ---\n", .{});
    const sig_str = "@32@0:8i16{Point=dd}24";
    var parsed_method = try objc.encoding.parseMethod(allocator, sig_str);
    defer parsed_method.deinit(allocator);

    std.debug.print("Raw signature: {s}\n", .{sig_str});
    if (parsed_method.frame_size) |fs| {
        std.debug.print("Stack frame size: {d} bytes\n", .{fs});
    }
    std.debug.print("Return type: ", .{});
    switch (parsed_method.return_type.type) {
        .object => |obj| std.debug.print("Object (class={?s})\n", .{obj.class_name}),
        else => std.debug.print("{s}\n", .{@tagName(parsed_method.return_type.type)}),
    }
    std.debug.print("Arguments ({d}):\n", .{parsed_method.arguments.len});
    for (parsed_method.arguments, 0..) |arg, idx| {
        std.debug.print("  [{d}] offset={?d} type={s}\n", .{
            idx,
            arg.offset,
            @tagName(arg.type.type),
        });
    }

    std.debug.print("\n--- 5. Runtime Entity Introspection ---\n", .{});
    const cls = objc.requireClass("NSObject");

    // Introspect -[NSObject description]
    if (cls.instanceMethod(objc.sel("description"))) |m| {
        var parsed_sig = try m.parsedSignature(allocator);
        defer parsed_sig.deinit(allocator);
        std.debug.print("Method -[NSObject description]:\n", .{});
        std.debug.print("  Type encoding: {s}\n", .{m.typeEncoding().?});
        if (parsed_sig.frame_size) |fs| {
            std.debug.print("  Frame size:    {d}\n", .{fs});
        }
        std.debug.print("  Arg count:     {d}\n", .{parsed_sig.arguments.len});
    }

    // Introspect NSObject property
    if (cls.property("description")) |prop| {
        var parsed_prop = try prop.parse(allocator);
        defer parsed_prop.deinit(allocator);
        std.debug.print("Property 'description':\n", .{});
        if (parsed_prop.type) |pt| {
            std.debug.print("  Type AST:    {s}\n", .{@tagName(pt.type)});
        }
        std.debug.print("  Readonly:    {}\n", .{parsed_prop.readonly});
        std.debug.print("  Copy:        {}\n", .{parsed_prop.copy});
        std.debug.print("  Getter:      {?s}\n", .{parsed_prop.getter});
    }
}
