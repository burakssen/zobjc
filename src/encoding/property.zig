//! Objective-C declared property attribute parsing.
//!
//! Parses comma-separated attribute strings returned by `property_getAttributes`
//! (e.g., `T@"NSString",R,C,N,V_title`, `Ti,Vcount`).

const std = @import("std");
const types = @import("type.zig");
const QualifiedType = types.QualifiedType;
const parser = @import("parser.zig");

/// Decoded representation of an Objective-C declared property's attributes.
pub const PropertyEncoding = struct {
    type: ?QualifiedType = null,
    readonly: bool = false, // 'R'
    copy: bool = false, // 'C'
    retain: bool = false, // '&'
    nonatomic: bool = false, // 'N'
    dynamic: bool = false, // 'D'
    weak: bool = false, // 'W'
    getter: ?[]const u8 = null, // 'G<name>'
    setter: ?[]const u8 = null, // 'S<name>'
    ivar: ?[]const u8 = null, // 'V<name>'

    pub fn deinit(self: *PropertyEncoding, allocator: std.mem.Allocator) void {
        if (self.type) |*t| t.deinit(allocator);
        if (self.getter) |g| allocator.free(g);
        if (self.setter) |s| allocator.free(s);
        if (self.ivar) |i| allocator.free(i);
        self.* = .{};
    }
};

/// Parses an Objective-C declared property attribute string into a `PropertyEncoding`.
pub fn parseProperty(allocator: std.mem.Allocator, attributes: []const u8) !PropertyEncoding {
    var result: PropertyEncoding = .{};
    errdefer result.deinit(allocator);

    var iter = std.mem.splitScalar(u8, attributes, ',');
    while (iter.next()) |token| {
        if (token.len == 0) continue;
        switch (token[0]) {
            'T' => {
                if (token.len > 1) {
                    result.type = try parser.parse(allocator, token[1..]);
                }
            },
            'R' => result.readonly = true,
            'C' => result.copy = true,
            '&' => result.retain = true,
            'N' => result.nonatomic = true,
            'D' => result.dynamic = true,
            'W' => result.weak = true,
            'G' => {
                if (token.len > 1) {
                    result.getter = try allocator.dupe(u8, token[1..]);
                }
            },
            'S' => {
                if (token.len > 1) {
                    result.setter = try allocator.dupe(u8, token[1..]);
                }
            },
            'V' => {
                if (token.len > 1) {
                    result.ivar = try allocator.dupe(u8, token[1..]);
                }
            },
            else => {}, // Ignore unrecognized property attribute specifiers
        }
    }

    return result;
}
