//! Block-bridged Objective-C class enumeration.
//!
//! Wraps enumeration in a Block-based closure API. Lives in `block`
//! (not `runtime`) so the runtime module does not depend upward.

const raw = @import("raw");
const Class = @import("runtime").Class;
const Protocol = @import("runtime").Protocol;
const getEnumerateClassesFn = @import("runtime").getEnumerateClassesFn;
const createBlock = @import("create.zig").createBlock;

/// Scope of images to filter during class enumeration.
pub const ImageFilter = union(enum) {
    caller,
    dynamic,
    handle: *const anyopaque,

    pub fn toRaw(self: ImageFilter) ?*const anyopaque {
        return switch (self) {
            .caller => null,
            .dynamic => raw.runtime.OBJC_DYNAMIC_CLASSES,
            .handle => |h| h,
        };
    }
};

/// Options for filtering classes during runtime enumeration.
pub const ClassEnumerationOptions = struct {
    image: ImageFilter = .caller,
    name_prefix: ?[:0]const u8 = null,
    conforming_to: ?Protocol = null,
    subclassing: ?Class = null,
};

/// Enumerates Objective-C classes matching the given options.
///
/// Callback signature:
/// `fn (context: *Context, cls: Class) bool`
/// Return `true` to continue enumeration, or `false` to stop immediately.
pub fn enumerateClasses(
    options: ClassEnumerationOptions,
    context: anytype,
    comptime callback: anytype,
) !void {
    const enum_fn = getEnumerateClassesFn() orelse return error.UnsupportedRuntime;

    const ContextType = @TypeOf(context);
    const Captures = struct {
        ctx: ContextType,
    };

    const RawBlockSig = fn (raw.Class, *raw.BOOL) void;

    // // bridge through createBlock with stack-to-heap promotion
    var closure_block = try createBlock(
        RawBlockSig,
        Captures,
        .{ .ctx = context },
        struct {
            fn run(caps: *Captures, raw_cls: raw.Class, stop: *raw.BOOL) void {
                const cls = Class.fromRaw(raw_cls) orelse return;
                const should_continue = callback(caps.ctx, cls);

                if (!should_continue) {
                    stop.* = raw.YES;
                }
            }
        }.run,
    );
    defer closure_block.deinit();

    const raw_image = options.image.toRaw();
    const raw_prefix: ?[*:0]const u8 = if (options.name_prefix) |p| p.ptr else null;
    const raw_proto: raw.Protocol = if (options.conforming_to) |p| p.ptr else null;
    const raw_super: raw.Class = if (options.subclassing) |s| s.ptr else null;

    enum_fn(
        raw_image,
        raw_prefix,
        raw_proto,
        raw_super,
        closure_block.borrow().asObject().toRaw(),
    );
}
