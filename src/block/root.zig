//! Objective-C Blocks ABI and runtime subsystem.
//!
//! Provides typed Block handles (`Block`, `OwnedBlock`), capture semantics (`Strong`,
//! `Weak`, `BlockRef`), forwarding cells (`ByRef`), large descriptor synthesis,
//! ABI-integrated `BLOCK_USE_STRET` derivation, and Block ↔ IMP bridging.

const std = @import("std");

// Subsystem modules
pub const abi = @import("abi.zig");
pub const flags = @import("flags.zig");
pub const descriptor = @import("descriptor.zig");
pub const signature = @import("signature.zig");
pub const layout = @import("layout.zig");
pub const capture_traits = @import("capture_traits.zig");
pub const strong = @import("strong.zig");
pub const weak = @import("weak.zig");
pub const block_ref = @import("block_ref.zig");
pub const byref = @import("byref.zig");
pub const byref_cell = @import("byref_cell.zig");
pub const capture = @import("capture.zig");
pub const block = @import("block.zig");
pub const owned = @import("owned.zig");
pub const create = @import("create.zig");
pub const invoke = @import("invoke.zig");
pub const imp = @import("imp.zig");
pub const enumeration = @import("enumeration.zig");
pub const replacement = @import("replacement.zig");
pub const diagnostics = @import("diagnostics.zig");
pub const validation = @import("validation.zig");
pub const internal = @import("internal/literal.zig");

// --- Primary Public Types ---
pub const Block = block.Block;
pub const OwnedBlock = owned.OwnedBlock;
pub const Strong = strong.Strong;
pub const Weak = weak.Weak;
pub const BlockRef = block_ref.BlockRef;
pub const ByRef = byref.ByRef;
pub const ByRefCapture = byref.ByRefCapture;
pub const ByRefCell = byref_cell.ByRefCell;

// --- ABI & Descriptor Types ---
pub const BlockFlags = flags.BlockFlags;
pub const Descriptor = descriptor.Descriptor;
pub const LayoutResult = layout.LayoutResult;
pub const blockSignature = signature.blockSignature;
pub const blockSignatureLength = signature.blockSignatureLength;

// --- Capture System ---
pub const CaptureTraits = capture_traits.CaptureTraits;
pub const CaptureCategory = capture_traits.CaptureCategory;
pub const CaptureStorage = capture.CaptureStorage;
pub const CaptureInfo = capture.CaptureInfo;

// --- Creation & Invocation ---
pub const createBlock = create.createBlock;
pub const closure = create.closure;
pub const fromFunction = create.fromFunction;
pub const createNoCapture = create.fromFunction;
pub const global = create.global;
pub const callBlock = invoke.callBlock;

// --- Block ↔ IMP Bridging ---
pub const OwnedImp = imp.OwnedImp;
pub const BlockMethodReplacement = replacement.BlockMethodReplacement;
pub const enumerateClasses = enumeration.enumerateClasses;
pub const ClassEnumerationOptions = enumeration.ClassEnumerationOptions;
pub const ImageFilter = enumeration.ImageFilter;
pub const makeImp = imp.makeImp;
pub const MethodBlock = imp.MethodBlock;

test {
    std.testing.refAllDecls(@This());
}
