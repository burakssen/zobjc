//! Objective-C calling-convention classification.
//!
//! This module answers questions such as:
//! - How is T returned on arm64?
//! - How is T returned on x86_64?
//! - Does this invocation require objc_msgSend_stret?
//! - Does this invocation require objc_msgSend_fpret?
//!
//! ABI classification is implemented in Phase 5.

const raw = @import("../raw/root.zig");

// TODO(phase-5): Implement full Apple ARM64 and x86_64 ABI classification engine.
// ponytail: In Phase 0, we don't invent speculative ABI classifiers; legacy dispatch is retained.
