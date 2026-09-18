//! Generated copy and dispose helpers for Apple Block literals.
//!
//! When a Block moves from stack to heap via _Block_copy, the generated copy helper
//! invokes _Block_object_assign on managed captures. On teardown, the dispose helper
//! invokes _Block_object_dispose in reverse declaration order.

const std = @import("std");
const traits_mod = @import("../capture_traits.zig");
const literal_mod = @import("literal.zig");
const CaptureTraits = traits_mod.CaptureTraits;

pub fn CopyDisposeHelpers(comptime Captures: type) type {
    const Lit = literal_mod.Literal(Captures);
    const struct_fields = @typeInfo(Captures).@"struct".fields;

    return struct {
        pub fn copy(dst_ptr: *anyopaque, src_ptr: *anyopaque) callconv(.c) void {
            const dst: *Lit = @ptrCast(@alignCast(dst_ptr));
            const src: *Lit = @ptrCast(@alignCast(src_ptr));
            const dst_caps = dst.getCaptures();
            const src_caps = src.getCaptures();

            inline for (struct_fields) |field| {
                const Traits = CaptureTraits(field.type);
                if (Traits.requires_helpers) {
                    Traits.copy(
                        &@field(dst_caps, field.name),
                        &@field(src_caps, field.name),
                    );
                }
            }
        }

        pub fn dispose(src_ptr: *anyopaque) callconv(.c) void {
            const src: *Lit = @ptrCast(@alignCast(src_ptr));
            const src_caps = src.getCaptures();

            // dispose managed captures in reverse declaration order
            comptime var i = struct_fields.len;
            inline while (i > 0) {
                i -= 1;
                const field = struct_fields[i];
                const Traits = CaptureTraits(field.type);
                if (Traits.requires_helpers) {
                    Traits.dispose(&@field(src_caps, field.name));
                }
            }
        }
    };
}
