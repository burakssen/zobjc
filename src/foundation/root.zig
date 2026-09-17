//! Foundation framework convenience layer for zobjc.
//!
//! Provides idiomatic Zig bindings for fundamental Apple Foundation types,
//! NSString, and collection enumeration protocols.
//!
//! Requires linking Foundation.framework.

pub const types = @import("types.zig");
pub const NSInteger = types.NSInteger;
pub const NSUInteger = types.NSUInteger;
pub const NSTimeInterval = types.NSTimeInterval;
pub const NSComparisonResult = types.NSComparisonResult;
pub const StringEncoding = types.StringEncoding;
pub const NSRange = types.NSRange;

pub const string = @import("string.zig");
pub const NSString = string.NSString;

pub const fast_enumeration = @import("fast_enumeration.zig");
pub const NSFastEnumerationState = fast_enumeration.NSFastEnumerationState;
pub const FastEnumerationIterator = fast_enumeration.FastEnumerationIterator;
pub const fastIterate = fast_enumeration.fastIterate;

pub const enumerator = @import("enumerator.zig");
pub const NSEnumerator = enumerator.NSEnumerator;
