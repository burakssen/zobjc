//! System V AMD64 ABI Section 3.2.3 class merge rules.

const Class = @import("class.zig").Class;

// ponytail: Direct implementation of System V ABI 3.2.3 classification merge.
pub fn merge(lhs: Class, rhs: Class) Class {
    // (a) If both classes are equal, this is the resulting class.
    if (lhs == rhs) return lhs;

    // (b) If one of the classes is NO_CLASS, the resulting class is the other class.
    if (lhs == .no_class) return rhs;
    if (rhs == .no_class) return lhs;

    // (c) If one of the classes is MEMORY, the result is the MEMORY class.
    if (lhs == .memory or rhs == .memory) return .memory;

    // (d) If one of the classes is X87, X87UP, COMPLEX_X87 class, MEMORY is used.
    if (lhs == .x87 or rhs == .x87 or
        lhs == .x87up or rhs == .x87up or
        lhs == .complex_x87 or rhs == .complex_x87)
    {
        return .memory;
    }

    // (e) If one of the classes is INTEGER, the result is the INTEGER class.
    if (lhs == .integer or rhs == .integer) return .integer;

    // (f) Otherwise class SSE is used.
    return .sse;
}
