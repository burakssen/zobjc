//! Typed Objective-C method description representation.

const raw = @import("raw");
const Selector = @import("selector.zig").Selector;
const conversion = @import("conversion.zig");

/// Defines an Objective-C method description holding a selector and its type encoding.
pub const MethodDescription = struct {
    selector: ?Selector,
    types: ?[:0]const u8,

    /// Converts a raw `objc_method_description` ABI struct into a typed `MethodDescription`.
    pub fn fromRaw(raw_desc: raw.objc_method_description) MethodDescription {
        return .{
            .selector = Selector.fromRaw(raw_desc.name),
            .types = conversion.spanNullableCString(raw_desc.types),
        };
    }

    /// Converts this typed `MethodDescription` into the raw ABI representation.
    pub fn toRaw(self: MethodDescription) raw.objc_method_description {
        return .{
            .name = if (self.selector) |s| s.toRaw() else null,
            .types = if (self.types) |t| t.ptr else null,
        };
    }
};
