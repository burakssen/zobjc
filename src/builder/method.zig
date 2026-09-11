//! Dynamic method registration for classes and metaclasses.

const std = @import("std");
const raw = @import("../raw/root.zig");
const runtime = @import("../runtime/root.zig");
const errors = @import("errors.zig");
const names = @import("internal/names.zig");
const callback_internal = @import("internal/callback.zig");
const Class = runtime.Class;
const ClassBuilderError = errors.ClassBuilderError;

/// Adds a method implementation to a class or metaclass.
///
/// Validates callback arguments, selector arity, generates method encodings automatically,
/// creates static trampolines when needed, and registers the method via `class_addMethod`.
pub fn addMethodToClass(
    target_class: Class,
    selector: anytype,
    comptime callback: anytype,
) ClassBuilderError!void {
    callback_internal.validateCallbackSignature(callback);

    const sel_val = names.normalizeSelector(selector);
    const sel_name = names.selectorName(selector);
    const explicit_args = callback_internal.explicitArgCount(callback);

    names.validateSelectorArity(sel_name, explicit_args) catch {
        return error.SelectorArityMismatch;
    };

    const imp = callback_internal.resolveImp(callback);
    const types_sig = callback_internal.resolveMethodEncoding(callback);

    const ok = raw.boolResult(raw.runtime.class_addMethod(
        target_class.ptr,
        sel_val.toRaw(),
        imp.toRaw(),
        types_sig.ptr,
    ));

    if (!ok) {
        return error.CannotAddMethod;
    }
}
