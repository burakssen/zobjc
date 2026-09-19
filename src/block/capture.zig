//! Block capture aggregation and storage layout.
//!
//! Synthesizes C-ABI compatible capture storage and analyzes capture fields.

const std = @import("std");
const traits_mod = @import("capture_traits.zig");
const layout_mod = @import("layout.zig");
const CaptureTraits = traits_mod.CaptureTraits;

/// Storage type matching `Captures`.
pub fn CaptureStorage(comptime Captures: type) type {
    return Captures;
}

/// Metadata and layout analysis for a Block's capture payload.
pub fn CaptureInfo(comptime Captures: type) type {
    const info = @typeInfo(Captures);

    const counts = blk: {
        var req_helpers = false;
        var strong_cnt: u8 = 0;
        var byref_cnt: u8 = 0;
        var weak_cnt: u8 = 0;

        if (info == .@"struct") {
            const struct_fields = info.@"struct".fields;
            for (struct_fields) |field| {
                const Traits = CaptureTraits(field.type);
                if (Traits.requires_helpers) req_helpers = true;
                switch (Traits.category) {
                    .strong => strong_cnt += 1,
                    .byref => byref_cnt += 1,
                    .weak => weak_cnt += 1,
                    .block => strong_cnt += 1, // Libclosure treats block pointers as strong pointer words in compact layout
                    .trivial => {},
                }
            }
        } else {
            const Traits = CaptureTraits(Captures);
            if (Traits.requires_helpers) req_helpers = true;
            switch (Traits.category) {
                .strong => strong_cnt += 1,
                .byref => byref_cnt += 1,
                .weak => weak_cnt += 1,
                .block => strong_cnt += 1,
                .trivial => {},
            }
        }

        break :blk .{
            .requires_helpers = req_helpers,
            .strong_count = strong_cnt,
            .byref_count = byref_cnt,
            .weak_count = weak_cnt,
        };
    };

    return struct {
        pub const requires_helpers = counts.requires_helpers;
        pub const strong_count = counts.strong_count;
        pub const byref_count = counts.byref_count;
        pub const weak_count = counts.weak_count;
        pub const Storage = CaptureStorage(Captures);

        /// Computes the layout result for this capture structure.
        pub fn computeLayout() layout_mod.LayoutResult {
            if (!requires_helpers) {
                return .{ .has_layout = false };
            }

            // Attempt compact layout encoding
            if (layout_mod.encodeCompactLayout(strong_count, byref_count, weak_count)) |compact| {
                return .{
                    .has_layout = true,
                    .is_compact = true,
                    .compact_value = compact,
                };
            }

            // Fallback: extended layout
            return .{
                .has_layout = false,
            };
        }
    };
}

test "CaptureInfo and CaptureStorage" {
    const TestCaptures = struct {
        x: c_int,
        y: f64,
    };
    const Info = CaptureInfo(TestCaptures);
    try std.testing.expect(!Info.requires_helpers);
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(Info.Storage));
}
