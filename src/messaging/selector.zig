//! Selector normalization and validation for Objective-C message dispatch.
//!
//! Converts Selector handles, raw SEL pointers, and sentinel-terminated strings
//! into canonical runtime SEL values while verifying argument counts at compile time.

const std = @import("std");
const raw = @import("raw");
const runtime = @import("runtime");
const wrapper = @import("internal").wrapper;
const Selector = runtime.Selector;

// Use the Objective-C runtime's interned selector machinery directly with zero extra caching.

/// Returns true if `T` is an acceptable selector representation.
pub fn isValidSelector(comptime T: type) bool {
    if (T == Selector or T == raw.SEL or T == *raw.objc_selector) return true;
    if (wrapper.isObjCWrapper(T) and wrapper.wrapperKind(T) == .selector) return true;
    switch (@typeInfo(T)) {
        .pointer => |ptr| {
            if (ptr.child == u8 and ptr.sentinel_ptr != null) return true;
            if (@typeInfo(ptr.child) == .array and @typeInfo(ptr.child).array.child == u8) {
                if (ptr.sentinel_ptr != null or @typeInfo(ptr.child).array.sentinel_ptr != null) return true;
            }
        },
        else => {},
    }
    return false;
}

/// Asserts at compile-time that `T` is a valid selector representation.
pub fn assertValidSelector(comptime T: type) void {
    if (comptime T == []const u8) {
        @compileError("A plain Zig slice '[]const u8' cannot be used as a selector because it is not sentinel-terminated. " ++
            "Pass a string literal (e.g. \"init\") or a sentinel-terminated slice [:0]const u8.");
    }
    if (comptime !isValidSelector(T)) {
        @compileError("Invalid selector type: '" ++ @typeName(T) ++ "'. Expected Selector, raw.SEL, or sentinel-terminated string [:0]const u8.");
    }
}

/// Counts the number of colon characters ':' in a comptime string.
pub fn countColons(comptime str: []const u8) comptime_int {
    var count: comptime_int = 0;
    for (str) |c| {
        if (c == ':') count += 1;
    }
    return count;
}

/// Verifies that the colon count in a comptime string selector matches the number of supplied arguments.
pub fn validateColonCount(comptime sel_name: []const u8, comptime arg_count: usize) void {
    const colons = countColons(sel_name);
    if (comptime colons != arg_count) {
        @compileError(std.fmt.comptimePrint(
            "Selector \"{s}\" expects {d} explicit argument{s}, but {d} {s} provided.",
            .{
                sel_name,
                colons,
                if (colons == 1) "" else "s",
                arg_count,
                if (arg_count == 1) "was" else "were",
            },
        ));
    }
}

/// Normalizes a selector representation into a raw `raw.SEL`.
pub inline fn toRaw(sel: anytype) raw.SEL {
    const T = @TypeOf(sel);
    assertValidSelector(T);

    if (comptime T == Selector) {
        return sel.ptr;
    } else if (comptime (T == raw.SEL or T == *raw.objc_selector)) {
        return sel;
    } else if (comptime wrapper.isObjCWrapper(T)) {
        return sel.ptr;
    } else {
        // String literal or sentinel-terminated slice: register with libobjc
        const str_slice: [:0]const u8 = switch (@typeInfo(T)) {
            .pointer => |ptr| switch (ptr.size) {
                .one => switch (@typeInfo(ptr.child)) {
                    .array => |arr| sel[0..arr.len :0],
                    else => unreachable,
                },
                .slice => sel,
                .many, .c => std.mem.span(sel),
            },
            else => unreachable,
        };
        return Selector.register(str_slice).toRaw();
    }
}
