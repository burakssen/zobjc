//! Block creation engine for Apple Blocks.
//!
//! Synthesizes stack literals and immediately promotes them to the heap via _Block_copy,
//! returning a safe OwnedBlock. Also provides zero-allocation global Blocks.

const std = @import("std");
const raw = @import("../raw/root.zig");
const abi = @import("abi.zig");
const block_mod = @import("block.zig");
const owned_mod = @import("owned.zig");
const capture_mod = @import("capture.zig");
const literal_mod = @import("internal/literal.zig");
const copy_dispose_mod = @import("internal/copy_dispose.zig");
const trampoline_mod = @import("internal/trampoline.zig");
const validation = @import("validation.zig");

/// Primary constructor: creates an OwnedBlock with captures.
pub fn createBlock(
    comptime Signature: type,
    comptime Captures: type,
    captures: Captures,
    comptime callback: anytype,
) !owned_mod.OwnedBlock(Signature) {
    validation.validateBlockSignature(Signature);
    validation.validateNotPtrauth();

    const Info = capture_mod.CaptureInfo(Captures);
    const fn_info = @typeInfo(Signature).@"fn";
    const RetType = fn_info.return_type orelse void;
    const uses_stret = abi.usesStret(RetType);

    const Lit = literal_mod.Literal(Captures);
    const helpers = copy_dispose_mod.CopyDisposeHelpers(Captures);

    const S = struct {
        const sig_str = abi.blockSignature(Signature);
        const trampoline = trampoline_mod.InvokeTrampoline(Signature, Captures, callback).Runner.trampoline;
        const layout_res = Info.computeLayout();
        const DescType = abi.Descriptor(Info.requires_helpers, true, layout_res.has_layout);
        const desc: DescType = if (Info.requires_helpers and layout_res.has_layout) .{
            .reserved = 0,
            .size = @sizeOf(Lit),
            .copy = &helpers.copy,
            .dispose = &helpers.dispose,
            .signature = sig_str,
            .layout = layout_res.rawPointer(),
        } else if (Info.requires_helpers and !layout_res.has_layout) .{
            .reserved = 0,
            .size = @sizeOf(Lit),
            .copy = &helpers.copy,
            .dispose = &helpers.dispose,
            .signature = sig_str,
        } else if (!Info.requires_helpers and layout_res.has_layout) .{
            .reserved = 0,
            .size = @sizeOf(Lit),
            .signature = sig_str,
            .layout = layout_res.rawPointer(),
        } else .{
            .reserved = 0,
            .size = @sizeOf(Lit),
            .signature = sig_str,
        };
    };

    const flags = (abi.BlockFlags{
        .copy_dispose = Info.requires_helpers,
        .stret = uses_stret,
        .signature = true,
        .extended_layout = S.layout_res.has_layout,
    }).bits();

    var lit: Lit = undefined;
    lit.header.isa = raw.blocks._NSConcreteStackBlock;
    lit.header.flags = flags;
    lit.header.reserved = 0;
    lit.header.invoke = @ptrCast(&S.trampoline);
    lit.header.descriptor = @ptrCast(&S.desc);

    if (@sizeOf(Captures) > 0) {
        lit.getCaptures().* = captures;
    }

    // // ponytail: promote stack literal to heap immediately via _Block_copy; stack literal never escapes
    const copied = raw.blocks._Block_copy(&lit) orelse return error.OutOfMemory;
    return owned_mod.OwnedBlock(Signature).fromRaw(@ptrCast(@alignCast(copied)));
}

/// Creates an OwnedBlock without captures from a free function or closure.
pub fn fromFunction(
    comptime Signature: type,
    comptime callback: anytype,
) !owned_mod.OwnedBlock(Signature) {
    return createBlock(Signature, struct {}, .{}, callback);
}

/// Global Block optimization: returns a statically allocated non-capturing Block.
pub fn global(
    comptime Signature: type,
    comptime callback: anytype,
) block_mod.Block(Signature) {
    validation.validateBlockSignature(Signature);
    validation.validateNotPtrauth();

    const fn_info = @typeInfo(Signature).@"fn";
    const RetType = fn_info.return_type orelse void;
    const S = struct {
        const is_stret = abi.usesStret(RetType);
        const sig_str = abi.blockSignature(Signature);
        const trampoline = trampoline_mod.InvokeTrampoline(Signature, struct {}, callback).Runner.trampoline;
        const DescType = abi.Descriptor(false, true, false);
        const desc: DescType = .{
            .reserved = 0,
            .size = @sizeOf(raw.blocks.Block_layout),
            .signature = sig_str,
        };

        var lit: raw.blocks.Block_layout = .{
            .isa = raw.blocks._NSConcreteGlobalBlock,
            .flags = (abi.BlockFlags{
                .global = true,
                .stret = is_stret,
                .signature = true,
            }).bits(),
            .reserved = 0,
            .invoke = @ptrCast(&trampoline),
            .descriptor = @ptrCast(&desc),
        };
    };

    return block_mod.Block(Signature).fromRaw(&S.lit);
}
