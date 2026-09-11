//! Error sets for dynamic class and protocol builders.

/// Errors that can occur during dynamic class construction and registration.
pub const ClassBuilderError = error{
    ClassAlreadyExists,
    ClassAllocationFailed,
    InvalidState,
    CannotAddIvar,
    IvarAlreadyExists,
    CannotAddMethod,
    CannotAddProtocol,
    CannotAddProperty,
    InvalidMethodSignature,
    SelectorArityMismatch,
    InvalidPropertyAttributes,
};

/// Errors that can occur during dynamic protocol construction and registration.
pub const ProtocolBuilderError = error{
    ProtocolAlreadyExists,
    ProtocolAllocationFailed,
    InvalidState,
    CannotAddMethod,
    CannotAddProtocol,
    CannotAddProperty,
    InvalidMethodSignature,
    SelectorArityMismatch,
    InvalidPropertyAttributes,
};
