//! Stateful Objective-C dynamic protocol construction.

const std = @import("std");
const raw = @import("../raw/root.zig");
const runtime = @import("../runtime/root.zig");
const encoding = @import("../encoding/root.zig");
const errors = @import("errors.zig");
const state_mod = @import("state.zig");
const names = @import("internal/names.zig");
const property = @import("property.zig");
const Protocol = runtime.Protocol;
const ProtocolMethodOptions = runtime.ProtocolMethodOptions;
const ProtocolPropertyOptions = runtime.ProtocolPropertyOptions;
const State = state_mod.State;
const ProtocolBuilderError = errors.ProtocolBuilderError;
const PropertyOptions = property.PropertyOptions;

/// Stateful builder for dynamically defining and registering Objective-C protocols.
pub const ProtocolBuilder = struct {
    proto_val: ?Protocol,
    state: State,
    name: [:0]const u8,

    /// Allocates a new protocol with the specified name.
    ///
    /// Fails with `error.ProtocolAlreadyExists` if a protocol with `name` is already registered.
    pub fn init(name: [:0]const u8) ProtocolBuilderError!ProtocolBuilder {
        if (runtime.getProtocol(name) != null) {
            return error.ProtocolAlreadyExists;
        }

        const raw_proto = raw.runtime.objc_allocateProtocol(name.ptr);
        if (raw_proto == null) {
            return error.ProtocolAllocationFailed;
        }

        return .{
            .proto_val = Protocol.fromRawNonNull(raw_proto.?),
            .state = .allocated,
            .name = name,
        };
    }

    /// Aborts protocol construction.
    ///
    /// Note: Apple libobjc provides no `objc_disposeProtocol` entry point. Calling `abort()`
    /// marks the builder aborted and releases internal references, but cannot deallocate
    /// the runtime-owned protocol record before process termination.
    pub fn abort(self: *ProtocolBuilder) void {
        if (self.state == .allocated) {
            self.proto_val = null;
            self.state = .aborted;
        }
    }

    /// Registers the protocol with the Objective-C runtime system and returns the Protocol handle.
    ///
    /// Transitions state to `.registered` and consumes the internal builder reference.
    pub fn register(self: *ProtocolBuilder) Protocol {
        std.debug.assert(self.state == .allocated);
        const proto = self.proto_val.?;
        raw.runtime.objc_registerProtocol(proto.ptr);
        self.proto_val = null;
        self.state = .registered;
        return proto;
    }

    /// Validates that the builder is currently in the `.allocated` state.
    pub fn requireAllocated(self: *const ProtocolBuilder) ProtocolBuilderError!void {
        if (self.state != .allocated) {
            return error.InvalidState;
        }
    }

    /// Borrows the under-construction `Protocol` handle for inspection.
    pub fn protocol(self: *const ProtocolBuilder) Protocol {
        std.debug.assert(self.state == .allocated);
        return self.proto_val.?;
    }

    /// Adds a method description signature to the protocol.
    pub fn addMethod(
        self: *ProtocolBuilder,
        selector: anytype,
        comptime F: type,
        options: ProtocolMethodOptions,
    ) ProtocolBuilderError!void {
        try self.requireAllocated();

        const fn_info = switch (@typeInfo(F)) {
            .@"fn" => @typeInfo(F).@"fn",
            .pointer => |p| switch (@typeInfo(p.child)) {
                .@"fn" => |f| f,
                else => return error.InvalidMethodSignature,
            },
            else => return error.InvalidMethodSignature,
        };

        if (fn_info.params.len < 2) {
            return error.InvalidMethodSignature;
        }

        const sel_val = names.normalizeSelector(selector);
        const sel_name = names.selectorName(selector);
        const explicit_args = fn_info.params.len - 2;

        names.validateSelectorArity(sel_name, explicit_args) catch {
            return error.SelectorArityMismatch;
        };

        const types_sig = comptime encoding.methodEncoding(F);

        raw.runtime.protocol_addMethodDescription(
            self.proto_val.?.ptr,
            sel_val.toRaw(),
            &types_sig,
            raw.boolParam(options.required),
            raw.boolParam(options.instance),
        );
    }

    /// Adds an adopted protocol to the protocol being constructed.
    pub fn inherit(
        self: *ProtocolBuilder,
        parent: Protocol,
    ) ProtocolBuilderError!void {
        try self.requireAllocated();
        raw.runtime.protocol_addProtocol(self.proto_val.?.ptr, parent.toRaw());
    }

    /// Adds a declared property to the protocol being constructed.
    pub fn addProperty(
        self: *ProtocolBuilder,
        comptime T: type,
        name: [:0]const u8,
        property_options: PropertyOptions,
        protocol_options: ProtocolPropertyOptions,
    ) ProtocolBuilderError!void {
        try self.requireAllocated();
        return property.addPropertyToProtocol(
            self.proto_val.?,
            T,
            name,
            property_options,
            protocol_options,
        );
    }
};
