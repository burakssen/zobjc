//! Selector normalization and arity validation.

const std = @import("std");
const runtime = @import("../../runtime/root.zig");
const raw = @import("../../raw/root.zig");
const Selector = runtime.Selector;

/// Normalizes various selector-like types into a runtime `Selector`.
pub fn normalizeSelector(selector: anytype) Selector {
    const T = @TypeOf(selector);
    if (T == Selector) return selector;
    if (T == raw.SEL) return Selector.fromRawNonNull(selector.?);
    return runtime.sel(selector);
}

/// Retrieves the null-terminated string name of a selector or selector-like value.
pub fn selectorName(selector: anytype) [:0]const u8 {
    const T = @TypeOf(selector);
    if (T == Selector) return selector.name();
    if (T == raw.SEL) return Selector.fromRawNonNull(selector.?).name();
    return selector;
}

/// Counts the number of colons (`:`) in a selector name string.
pub fn countColons(name: []const u8) usize {
    var count: usize = 0;
    for (name) |c| {
        if (c == ':') count += 1;
    }
    return count;
}

/// Validates that the number of colons in the selector equals the number of explicit arguments.
pub fn validateSelectorArity(name: []const u8, explicit_param_count: usize) !void {
    if (countColons(name) != explicit_param_count) {
        return error.SelectorArityMismatch;
    }
}
