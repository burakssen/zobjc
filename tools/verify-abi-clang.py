#!/usr/bin/env python3
"""
Automated differential verification script comparing Apple Clang's emitted
Objective-C messenger dispatch symbols against expected ReturnConvention values.
"""

import subprocess
import sys

FIXTURE_HEADER = "tests/fixtures/abi/fixtures.h"

METHODS = [
    ("call_void", "returnVoid", "normal", "normal"),
    ("call_int", "returnInt", "normal", "normal"),
    ("call_float", "returnFloat", "normal", "normal"),
    ("call_double", "returnDouble", "normal", "normal"),
    ("call_ldouble", "returnLongDouble", "normal", "fpret"),
    ("call_cldouble", "returnComplexLongDouble", "normal", "fp2ret"),
    ("call_s1", "returnSize1", "normal", "normal"),
    ("call_s2", "returnSize2", "normal", "normal"),
    ("call_s3", "returnSize3", "normal", "normal"),
    ("call_s4", "returnSize4", "normal", "normal"),
    ("call_s7", "returnSize7", "normal", "normal"),
    ("call_s8", "returnSize8", "normal", "normal"),
    ("call_s8m", "returnSize8Mixed", "normal", "normal"),
    ("call_s9", "returnSize9", "normal", "normal"),
    ("call_s12", "returnSize12", "normal", "normal"),
    ("call_s16i", "returnSize16Int", "normal", "normal"),
    ("call_s16f", "returnSize16Float", "normal", "normal"),
    ("call_s16m", "returnSize16Mixed", "normal", "normal"),
    ("call_s17", "returnSize17", "normal", "stret"),
    ("call_s24", "returnSize24", "normal", "stret"),
    ("call_s32", "returnSize32", "normal", "stret"),
    ("call_sld", "returnStructLongDouble", "normal", "normal"),
    ("call_smld", "returnStructMixedLongDouble", "normal", "stret"),
    ("call_pt", "returnPoint", "normal", "normal"),
    ("call_sz", "returnSize", "normal", "normal"),
    ("call_rc", "returnRect", "normal", "stret"),
    ("call_nested", "returnNested", "normal", "stret"),
    ("call_arr", "returnArrayInStruct", "normal", "normal"),
    ("call_union", "returnUnion8", "normal", "normal"),
]

def generate_caller_c():
    lines = [f'#import "{FIXTURE_HEADER}"']
    for fn, method, _, _ in METHODS:
        lines.append(f"void {fn}(ABIFixture *f) {{ [f {method}]; }}")
    return "\n".join(lines)

def test_target(target, expected_idx):
    c_code = generate_caller_c()
    cmd = ["xcrun", "clang", "-target", target, "-I.", "-x", "objective-c", "-", "-S", "-o", "-", "-fno-objc-arc"]
    proc = subprocess.run(cmd, input=c_code.encode(), capture_output=True)
    if proc.returncode != 0:
        print(f"Error invoking clang for {target}: {proc.stderr.decode()}")
        sys.exit(1)

    asm = proc.stdout.decode()
    results = {}
    current_fn = None
    for line in asm.splitlines():
        if line.startswith("_call_"):
            current_fn = line.split(":")[0][1:]
        elif current_fn and "objc_msgSend" in line and not line.strip().startswith("."):
            l = line.strip()
            if "objc_msgSend_stret" in l:
                results[current_fn] = "stret"
            elif "objc_msgSend_fp2ret" in l:
                results[current_fn] = "fp2ret"
            elif "objc_msgSend_fpret" in l:
                results[current_fn] = "fpret"
            elif "objc_msgSend" in l:
                results[current_fn] = "normal"
            current_fn = None

    passed = 0
    total = len(METHODS)
    print(f"\n--- Verifying Target: {target} ---")
    for fn, method, arm_exp, x86_exp in METHODS:
        expected = arm_exp if expected_idx == 2 else x86_exp
        actual = results.get(fn)
        if actual == expected:
            passed += 1
            print(f"  PASS: {fn:14} -> {actual:8} (expected {expected})")
        else:
            print(f"  FAIL: {fn:14} -> actual={actual}, expected={expected}")

    print(f"Result for {target}: {passed}/{total} passed")
    return passed == total

def main():
    ok1 = test_target("arm64-apple-macos", 2)
    ok2 = test_target("x86_64-apple-macos", 3)
    if ok1 and ok2:
        print("\nALL CLANG DIFFERENTIAL CHECKS PASSED.")
        sys.exit(0)
    else:
        print("\nDIFFERENTIAL CHECKS FAILED.")
        sys.exit(1)

if __name__ == "__main__":
    main()
