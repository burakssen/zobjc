#!/usr/bin/env python3
"""
tools/audit-runtime-api.py

Audits the raw Objective-C ABI coverage in zobjc (src/raw/) against
the active Apple SDK C headers (<objc/*.h>).
"""

import os
import re
import sys
import subprocess
import argparse

SDK_OBJC_HEADERS = [
    "objc/objc.h",
    "objc/runtime.h",
    "objc/message.h",
    "objc/objc-sync.h",
    "objc/objc-exception.h",
]

RAW_ZIG_FILES = [
    "src/raw/objc.zig",
    "src/raw/runtime.zig",
    "src/raw/message.zig",
    "src/raw/compiler_runtime.zig",
    "src/raw/deprecated.zig",
    "src/raw/blocks.zig",
]

def get_sdk_path():
    try:
        out = subprocess.check_output(["xcrun", "--show-sdk-path"], text=True)
        return out.strip()
    except Exception as e:
        sys.stderr.write(f"Error running xcrun: {e}\n")
        sys.exit(1)

def extract_c_exports(header_path):
    if not os.path.isfile(header_path):
        return set()
    with open(header_path, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()
    
    # Match OBJC_EXPORT ... <name>(
    pattern = re.compile(r"OBJC_EXPORT\s+.*?\b([a-zA-Z0-9_]+)\s*\(", re.DOTALL)
    matches = pattern.findall(content)
    return set(matches)

def extract_zig_declarations(zig_file_path):
    if not os.path.isfile(zig_file_path):
        return set()
    with open(zig_file_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # Match pub extern "c" fn <name>
    fn_pattern = re.compile(r'pub\s+extern\s+"c"\s+fn\s+([a-zA-Z0-9_]+)\s*\(')
    # Match pub const <name> =
    const_pattern = re.compile(r'pub\s+const\s+([a-zA-Z0-9_]+)\s*=')
    
    fns = set(fn_pattern.findall(content))
    consts = set(const_pattern.findall(content))
    return fns.union(consts)

def main():
    parser = argparse.ArgumentParser(description="Audit zobjc raw ABI coverage against Apple SDK.")
    parser.add_argument("--sdk", help="Path to Apple macOS SDK", default=None)
    args = parser.parse_args()

    sdk_path = args.sdk or get_sdk_path()
    include_path = os.path.join(sdk_path, "usr", "include")

    print(f"=== Objective-C Runtime ABI Coverage Audit ===")
    print(f"SDK Location: {sdk_path}")
    print()

    # Collect SDK exports
    sdk_exports_by_header = {}
    total_sdk_exports = set()
    for rel_header in SDK_OBJC_HEADERS:
        header_full = os.path.join(include_path, rel_header)
        exports = extract_c_exports(header_full)
        sdk_exports_by_header[rel_header] = exports
        total_sdk_exports.update(exports)

    # Collect Zig declarations
    zig_decls_by_file = {}
    all_zig_decls = set()
    deprecated_zig_decls = set()

    for rel_file in RAW_ZIG_FILES:
        decls = extract_zig_declarations(rel_file)
        zig_decls_by_file[rel_file] = decls
        all_zig_decls.update(decls)
        if "deprecated.zig" in rel_file:
            deprecated_zig_decls.update(decls)

    # Load and verify manifest
    manifest_path = os.path.join(os.path.dirname(__file__), "runtime-api-manifest.json")
    manifest_symbols = set()
    manifest_by_symbol = {}
    if os.path.isfile(manifest_path):
        import json
        with open(manifest_path, "r", encoding="utf-8") as f:
            manifest_data = json.load(f)
        for entry in manifest_data:
            sym = entry["symbol"]
            manifest_symbols.add(sym)
            manifest_by_symbol[sym] = entry

    # Check for unclassified SDK symbols
    unclassified = total_sdk_exports - manifest_symbols
    if unclassified:
        print("UNCLASSIFIED SDK SYMBOLS (Not in tools/runtime-api-manifest.json):")
        for sym in sorted(unclassified):
            print(f"  - {sym}")
        print()
        sys.exit(1)

    # Calculate coverage
    covered = total_sdk_exports.intersection(all_zig_decls)
    missing = total_sdk_exports - all_zig_decls
    deprecated = total_sdk_exports.intersection(deprecated_zig_decls)
    active_covered = covered - deprecated
    compiler_rt = {s for s in covered if manifest_by_symbol.get(s, {}).get("compiler_runtime", False)}

    # Header breakdown
    print("Header-by-Header Coverage:")
    print("-" * 70)
    for rel_header in SDK_OBJC_HEADERS:
        exports = sdk_exports_by_header[rel_header]
        hdr_covered = exports.intersection(all_zig_decls)
        pct = (len(hdr_covered) / len(exports) * 100) if exports else 100.0
        print(f"  {rel_header:<28} {len(hdr_covered):>3} / {len(exports):>3} ({pct:5.1f}%)")
    print("-" * 70)

    print()
    print("Summary:")
    print(f"  Total SDK Exports:        {len(total_sdk_exports)}")
    print(f"  Covered:                  {len(covered)}")
    print(f"  Deprecated:               {len(deprecated)}")
    print(f"  Compiler-Runtime:         {len(compiler_rt)}")
    print(f"  Unclassified:             {len(unclassified)}")
    print(f"  Missing:                  {len(missing)}")
    
    coverage_pct = (len(covered) / len(total_sdk_exports) * 100) if total_sdk_exports else 100.0
    print(f"  Coverage Percentage:      {coverage_pct:.1f}%")
    print()

    if missing:
        print("Missing SDK Exports in src/raw/:")
        for sym in sorted(missing):
            print(f"  - {sym}")
        print()
        sys.exit(1)
    else:
        print("PASS: 100% of SDK declarations are classified in manifest and implemented in src/raw/.")
        sys.exit(0)

if __name__ == "__main__":
    main()

