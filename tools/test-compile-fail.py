#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path

ZIG_EXE = sys.argv[1] if len(sys.argv) > 1 else "zig"

CASES = [
    {
        "name": "comptime_int argument rejected",
        "file": "tests/compile_fail/cases/comptime_int_arg.zig",
        "expected": "has type 'comptime_int'",
    },
    {
        "name": "callback missing _cmd rejected",
        "file": "tests/compile_fail/cases/missing_cmd.zig",
        "expected": "must take at least 2 arguments (self, _cmd)",
    },
    {
        "name": "non-extern struct argument rejected",
        "file": "tests/compile_fail/cases/zig_struct_arg.zig",
        "expected": "Only 'extern struct' types are C ABI compatible",
    },
    {
        "name": "Retained(non_retainable) rejected",
        "file": "tests/compile_fail/cases/retained_non_retainable.zig",
        "expected": "is not an Objective-C retainable object type",
    },
    {
        "name": "slice argument rejected",
        "file": "tests/compile_fail/cases/slice_arg.zig",
        "expected": "A Zig slice is not a C string",
    },
]

def main():
    print("=== Running Compile-Fail Verification Suite ===")
    passed = 0
    failed = 0

    for case in CASES:
        cmd = [
            ZIG_EXE,
            "build-obj",
            "--dep", "objc",
            f"-Mroot={case['file']}",
            "-Mobjc=src/objc.zig",
            "-fno-emit-bin",
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode == 0:
            print(f"FAIL: {case['name']} (compilation succeeded unexpectedly!)")
            failed += 1
            continue
        
        output = res.stderr + res.stdout
        if case["expected"] not in output:
            print(f"FAIL: {case['name']}")
            print(f"  Expected substring: {case['expected']}")
            print(f"  Actual compiler output:\n{output}")
            failed += 1
            continue

        print(f"PASS: {case['name']} (caught: \"{case['expected']}\")")
        passed += 1

    print("-" * 50)
    print(f"Compile-Fail Results: {passed}/{len(CASES)} passed")
    if failed > 0:
        sys.exit(1)

if __name__ == "__main__":
    main()
