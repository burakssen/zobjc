//! Objective-C Blocks ABI and runtime subsystem.
//!
//! Provides typed Block handles (`Block`, `OwnedBlock`), capture semantics (`Strong`,
//! `Weak`, `BlockRef`), forwarding cells (`ByRef`), large descriptor synthesis,
//! Phase 5 ABI-integrated `BLOCK_USE_STRET` derivation, and Block ↔ IMP bridging.

const std = @import("std");
const raw = @import("../raw/root.zig");

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
pub const fromFunction = create.fromFunction;
pub const createNoCapture = create.fromFunction;
pub const global = create.global;
pub const callBlock = invoke.callBlock;

// --- Block ↔ IMP Bridging ---
pub const OwnedImp = imp.OwnedImp;
pub const makeImp = imp.makeImp;
pub const MethodBlock = imp.MethodBlock;

// --- Legacy Compatibility Shim ---
// Preserved for backward compatibility with pre-Phase 8 code specifying 3 arguments.
pub fn LegacyBlock(
    comptime CapturesArg: type,
    comptime Args: anytype,
    comptime Return: type,
) type {
    _ = Args;
    const captures_info = @typeInfo(CapturesArg).@"struct";
    const total_fields = captures_info.fields.len + 5;
    var field_names: [total_fields][]const u8 = undefined;
    var field_types: [total_fields]type = undefined;
    var field_attrs: [total_fields]std.builtin.Type.StructField.Attributes = undefined;

    field_names[0] = "isa";
    field_types[0] = ?*anyopaque;
    field_attrs[0] = .{ .@"align" = @alignOf(?*anyopaque) };

    field_names[1] = "flags";
    field_types[1] = c_int;
    field_attrs[1] = .{ .@"align" = @alignOf(c_int) };

    field_names[2] = "reserved";
    field_types[2] = c_int;
    field_attrs[2] = .{ .@"align" = @alignOf(c_int) };

    field_names[3] = "invoke";
    field_types[3] = ?*const anyopaque;
    field_attrs[3] = .{ .@"align" = @alignOf(?*const anyopaque) };

    field_names[4] = "descriptor";
    field_types[4] = ?*const anyopaque;
    field_attrs[4] = .{ .@"align" = @alignOf(?*const anyopaque) };

    for (captures_info.fields, 5..) |field, i| {
        field_names[i] = field.name;
        field_types[i] = field.type;
        field_attrs[i] = .{ .@"align" = field.alignment };
    }

    const CtxType = @Struct(.@"extern", null, &field_names, &field_types, &field_attrs);

    return struct {
        const Self = @This();
        pub const Captures = CapturesArg;
        pub const Context = CtxType;

        pub fn init(captures: Captures, func: anytype) Context {
            const fn_ptr = if (@typeInfo(@TypeOf(func)) == .@"fn") &func else func;
            var ctx: Context = undefined;
            ctx.isa = raw.blocks._NSConcreteStackBlock;
            ctx.flags = 0;
            ctx.reserved = 0;
            ctx.invoke = @ptrCast(fn_ptr);
            ctx.descriptor = null;
            inline for (captures_info.fields) |f| {
                @field(ctx, f.name) = @field(captures, f.name);
            }
            return ctx;
        }

        pub fn invoke(ctx: *const Context, args: anytype) Return {
            _ = args;
            const func: *const fn (*const Context) callconv(.c) Return = @ptrCast(@alignCast(ctx.invoke.?));
            return func(ctx);
        }
    };
}

test {
    std.testing.refAllDecls(@This());
}
