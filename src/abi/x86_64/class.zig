//! System V AMD64 ABI register classification classes.
//!
//! Standard classes as defined in System V Application Binary Interface AMD64
//! Architecture Processor Supplement, Section 3.2.3.

pub const Class = enum {
    /// Initial unclassified state or padding.
    no_class,

    /// Returned in general-purpose registers (RAX, RDX).
    integer,

    /// Returned in SSE vector registers (XMM0, XMM1).
    sse,

    /// Upper half of an SSE vector or 128-bit type.
    sseup,

    /// Returned on the x87 floating-point stack (ST0).
    x87,

    /// Upper half of an 80-bit x87 extended precision float.
    x87up,

    /// Complex long double returned on the x87 stack (ST0, ST1).
    complex_x87,

    /// Passed/returned indirectly in memory via hidden pointer (RDI).
    memory,
};
