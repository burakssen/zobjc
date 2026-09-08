//! Eightbyte classification state for x86_64 aggregate classification.

const Class = @import("class.zig").Class;

/// Eightbyte classification for aggregates up to 16 bytes (two eightbytes).
pub const EightbyteClassification = struct {
    classes: [2]Class = .{ .no_class, .no_class },

    /// Returns true if either eightbyte was classified as memory.
    pub fn isMemory(self: EightbyteClassification) bool {
        return self.classes[0] == .memory or self.classes[1] == .memory;
    }

    /// Returns true if both eightbytes are unclassified (e.g. empty struct).
    pub fn isAllNoClass(self: EightbyteClassification) bool {
        return self.classes[0] == .no_class and self.classes[1] == .no_class;
    }
};
