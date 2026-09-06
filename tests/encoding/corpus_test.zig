//! Runtime corpus test: parses real runtime method signatures, ivars, and properties
//! across Foundation classes (NSObject, NSString, NSArray, NSDictionary).

const std = @import("std");
const testing = std.testing;
const objc = @import("objc");

test "corpus: parse all NSObject methods and properties" {
    const allocator = testing.allocator;

    const class = objc.getClass("NSObject") orelse return error.ClassNotLoaded;

    // Methods
    var method_list = class.methods();
    defer method_list.deinit();

    var parsed_method_count: usize = 0;
    var m_it = method_list.iterator();
    while (m_it.next()) |m| {
        const raw_enc = m.typeEncoding() orelse continue;
        if (raw_enc.len == 0) continue;

        var sig = try m.parsedSignature(allocator);
        defer sig.deinit(allocator);

        parsed_method_count += 1;
    }
    try testing.expect(parsed_method_count > 10);

    // Properties
    var prop_list = class.properties();
    defer prop_list.deinit();

    var parsed_prop_count: usize = 0;
    var p_it = prop_list.iterator();
    while (p_it.next()) |p| {
        var parsed_prop = try p.parse(allocator);
        defer parsed_prop.deinit(allocator);

        parsed_prop_count += 1;
    }
    try testing.expect(parsed_prop_count > 0);
}

test "corpus: parse NSString, NSArray, NSDictionary methods, ivars, and properties" {
    const allocator = testing.allocator;

    const class_names = [_][:0]const u8{
        "NSString",
        "NSArray",
        "NSDictionary",
    };

    for (class_names) |name| {
        const class = objc.getClass(name) orelse continue;

        // Methods
        var method_list = class.methods();
        defer method_list.deinit();

        var m_it = method_list.iterator();
        while (m_it.next()) |m| {
            const raw_enc = m.typeEncoding() orelse continue;
            if (raw_enc.len == 0) continue;

            var sig = try m.parsedSignature(allocator);
            defer sig.deinit(allocator);
        }

        // Properties
        var prop_list = class.properties();
        defer prop_list.deinit();

        var p_it = prop_list.iterator();
        while (p_it.next()) |p| {
            var parsed_prop = try p.parse(allocator);
            defer parsed_prop.deinit(allocator);
        }

        // Ivars
        var ivar_list = class.ivars();
        defer ivar_list.deinit();

        var iv_it = ivar_list.iterator();
        while (iv_it.next()) |iv| {
            var maybe_type = try iv.parsedType(allocator);
            if (maybe_type) |*parsed_type| {
                defer parsed_type.deinit(allocator);
            }
        }
    }
}
