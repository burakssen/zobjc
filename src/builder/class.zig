//! Stateful Objective-C dynamic class construction.

const std = @import("std");
const raw = @import("../raw/root.zig");
const runtime = @import("../runtime/root.zig");
const errors = @import("errors.zig");
const state_mod = @import("state.zig");
const ivar = @import("ivar.zig");
const method = @import("method.zig");
const property = @import("property.zig");
const Class = runtime.Class;
const Protocol = runtime.Protocol;
const State = state_mod.State;
const ClassBuilderError = errors.ClassBuilderError;
const PropertyOptions = property.PropertyOptions;

/// Stateful builder for dynamically constructing and registering Objective-C classes.
pub const ClassBuilder = struct {
    class_val: ?Class,
    state: State,
    name: [:0]const u8,
    superclass: Class,

    /// Options for dynamic class pair allocation.
    pub const Options = struct {
        extra_bytes: usize = 0,
    };

    /// Allocates a new class pair with the given name and superclass.
    ///
    /// Fails with `error.ClassAlreadyExists` if a class with `name` is already registered.
    pub fn init(
        name: [:0]const u8,
        superclass: Class,
    ) ClassBuilderError!ClassBuilder {
        return initWithOptions(name, superclass, .{});
    }

    /// Allocates a new class pair with additional extra bytes.
    pub fn initWithOptions(
        name: [:0]const u8,
        superclass: Class,
        options: Options,
    ) ClassBuilderError!ClassBuilder {
        // Detect existing class name collisions early for clear diagnostics.
        if (runtime.getClass(name) != null) {
            return error.ClassAlreadyExists;
        }

        const raw_cls = raw.runtime.objc_allocateClassPair(
            superclass.ptr,
            name.ptr,
            options.extra_bytes,
        );

        if (raw_cls == null) {
            return error.ClassAllocationFailed;
        }

        return .{
            .class_val = Class.fromRawNonNull(raw_cls.?),
            .state = .allocated,
            .name = name,
            .superclass = superclass,
        };
    }

    /// Aborts construction, disposing of the allocated class pair.
    ///
    /// Safe to call repeatedly and in `errdefer builder.abort()`. If called after
    /// registration or when already aborted, this is a safe no-op.
    pub fn abort(self: *ClassBuilder) void {
        if (self.state == .allocated) {
            if (self.class_val) |c| {
                raw.runtime.objc_disposeClassPair(c.ptr);
            }
            self.class_val = null;
            self.state = .aborted;
        }
    }

    /// Registers the class pair with the Objective-C runtime system and returns the Class handle.
    ///
    /// Transitions state to `.registered` and consumes the internal builder reference.
    pub fn register(self: *ClassBuilder) Class {
        std.debug.assert(self.state == .allocated);
        const cls = self.class_val.?;
        raw.runtime.objc_registerClassPair(cls.ptr);
        self.class_val = null;
        self.state = .registered;
        return cls;
    }

    /// Validates that the builder is currently in the `.allocated` state.
    pub fn requireAllocated(self: *const ClassBuilder) ClassBuilderError!void {
        if (self.state != .allocated) {
            return error.InvalidState;
        }
    }

    /// Borrows the under-construction `Class` handle for inspection or advanced escape hatches.
    pub fn class(self: *const ClassBuilder) Class {
        std.debug.assert(self.state == .allocated);
        return self.class_val.?;
    }

    /// Adds a typed instance variable to the class.
    pub fn addIvar(
        self: *ClassBuilder,
        comptime T: type,
        name: [:0]const u8,
    ) ClassBuilderError!void {
        try self.requireAllocated();
        return ivar.addIvar(self.class_val.?, T, name);
    }

    /// Adds an instance variable with explicit byte size, log2 alignment, and encoding.
    pub fn addIvarEncoded(
        self: *ClassBuilder,
        name: [:0]const u8,
        size: usize,
        alignment_log2: u8,
        encoding_str: [:0]const u8,
    ) ClassBuilderError!void {
        try self.requireAllocated();
        return ivar.addIvarEncoded(self.class_val.?, name, size, alignment_log2, encoding_str);
    }

    /// Adds an instance method to the class.
    ///
    /// Accepts raw C-ABI callbacks or ergonomic Zig functions, automatically
    /// validating arguments and generating method encodings.
    pub fn addMethod(
        self: *ClassBuilder,
        selector: anytype,
        comptime callback: anytype,
    ) ClassBuilderError!void {
        try self.requireAllocated();
        return method.addMethodToClass(self.class_val.?, selector, callback);
    }

    /// Adds a class method to the metaclass of the class.
    pub fn addClassMethod(
        self: *ClassBuilder,
        selector: anytype,
        comptime callback: anytype,
    ) ClassBuilderError!void {
        try self.requireAllocated();
        const meta = self.class_val.?.metaClass();
        return method.addMethodToClass(meta, selector, callback);
    }

    /// Adds an adopted protocol to the class.
    pub fn addProtocol(
        self: *ClassBuilder,
        protocol: Protocol,
    ) ClassBuilderError!void {
        try self.requireAllocated();
        const ok = raw.boolResult(raw.runtime.class_addProtocol(self.class_val.?.ptr, protocol.toRaw()));
        if (!ok) {
            return error.CannotAddProtocol;
        }
    }

    /// Adds a declared property to the class.
    pub fn addProperty(
        self: *ClassBuilder,
        comptime T: type,
        name: [:0]const u8,
        options: PropertyOptions,
    ) ClassBuilderError!void {
        try self.requireAllocated();
        return property.addPropertyToClass(self.class_val.?, T, name, options);
    }
};
