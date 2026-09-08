//! Comptime integer and layout arithmetic helpers.

// ponytail: Pure, non-allocating compile-time arithmetic.

/// Aligns `offset` forward to the next multiple of `alignment`.
pub fn alignForward(offset: usize, alignment: usize) usize {
    if (alignment == 0) return offset;
    return (offset + alignment - 1) & ~(alignment - 1);
}

/// Returns the zero-based eightbyte index for a given byte offset.
pub fn eightbyteIndex(offset: usize) usize {
    return offset / 8;
}

/// Returns true if two half-open byte ranges [start1, start1+len1) and [start2, start2+len2) overlap.
pub fn rangeOverlap(start1: usize, len1: usize, start2: usize, len2: usize) bool {
    if (len1 == 0 or len2 == 0) return false;
    const end1 = start1 + len1;
    const end2 = start2 + len2;
    return start1 < end2 and start2 < end1;
}

/// Returns ceil(a / b).
pub fn ceilDiv(a: usize, b: usize) usize {
    return (a + b - 1) / b;
}
