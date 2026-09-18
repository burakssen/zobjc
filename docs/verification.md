# Verification

- `send` performs comptime validation of the caller-supplied signature
  (receiver/selector/argument/return shapes, selector colon count) and exact
  C function-type construction, but cannot prove the Zig signature matches
  the Objective-C method.
- `sendChecked` (safety builds only) additionally:
  1. returns null-object results without touching the runtime,
  2. panics if the target does not respond to the selector,
  3. looks up the `Method`, parses `method_getTypeEncoding()`, rebuilds the
     expected `return + self + _cmd + args` encoding from the Zig signature,
     and panics on mismatch (offsets/frame size ignored).
  4. forwards to `send` (zero extra cost in release-fast; no check at all).
- Differential gates that must stay green:
  - `encoding`: `checkDifferential(raw.BOOL, fixture_encode_bool)` pins the
    platform `BOOL` encoding per toolchain (`B` on macOS arm64 and 64-bit
    iOS-family with current Clang, which predefines
    `__OBJC_BOOL_IS_BOOL=1`; `c` on macOS x86_64). If this test fails after
    touching `objc_bool_is_bool`, trust the fixture: it is compiled by the
    same C toolchain whose ABI the library must match.
  - `messaging`/`abi`: `ABIFixture` aggregate/pressure suites on both arm64
    and x86_64 runners.
  - `block`: Clang ↔ Zig interop tests.
