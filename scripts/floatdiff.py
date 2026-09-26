#!/usr/bin/env python3
"""Compare two test outputs line by line, numbers within a tolerance.

This is the comparator of `make check`: for each test, it compares the
reference `tests/reference/<name>.ref` with the fresh output
`tests/output/<name>.out`, both written by `arch/print_arch.cpp` (one line per
frame: the frame index, then one sample per output channel, separated by
whitespace).

Two files match when they have the same number of lines, every line has the
same number of whitespace-separated tokens, and each pair of tokens either
parses as two numbers `a`, `b` with

    math.isclose(a, b, rel_tol=tol, abs_tol=tol)

that is, |a - b| <= max(tol * max(|a|, |b|), tol), or is the same string. So
`tol` acts as an absolute tolerance for samples below 1 in magnitude and as a
relative one above. `make check` uses tol = FLOAT_TOL (1e-5 by default).

Every mismatch is printed, with its line number and both values, followed by
"Differences found."; otherwise "No differences within tolerance <tol>".

Usage:
    scripts/floatdiff.py REFERENCE OUTPUT [-t TOL]
    scripts/floatdiff.py REFERENCE OUTPUT TOL     # positional form, used by the Makefile

Exit status: 0 when the files match, 1 otherwise.
"""
import sys
import math
import argparse


def compare_files(file1, file2, tol=1e-6):
    """Print every mismatch between file1 and file2; return True if any."""
    with open(file1) as f1, open(file2) as f2:
        lines1 = f1.readlines()
        lines2 = f2.readlines()

    maxlen = max(len(lines1), len(lines2))
    diff_found = False

    for i in range(maxlen):
        if i >= len(lines1) or i >= len(lines2):
            print(f"Line {i+1}: file length mismatch")
            diff_found = True
            continue

        tokens1 = lines1[i].split()
        tokens2 = lines2[i].split()

        if len(tokens1) != len(tokens2):
            print(
                f"Line {i+1}: token count mismatch ({len(tokens1)} vs {len(tokens2)})"
            )
            diff_found = True
            continue

        for j, (a, b) in enumerate(zip(tokens1, tokens2), start=1):
            try:
                fa, fb = float(a), float(b)
                diff = fa - fb
                if not math.isclose(fa, fb, rel_tol=tol, abs_tol=tol):
                    print(f"(Line {i+1}, fa = {fa}, fb = {fb}, Δ = {diff:.4g}, tol = {tol})")
                    diff_found = True
            except ValueError:
                if a != b:
                    print(f"Line {i+1}, token {j}: '{a}' != '{b}'")
                    diff_found = True

    if not diff_found:
        print(f"No differences within tolerance {tol}")
    else:
        print("Differences found.")
    return diff_found


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description=__doc__.split("\n")[0],
        epilog="Exit status: 0 when the files match within the tolerance, 1 otherwise.",
    )
    parser.add_argument("file1", help="reference file (tests/reference/<name>.ref)")
    parser.add_argument("file2", help="output file to compare (tests/output/<name>.out)")
    parser.add_argument(
        "-t", "--tol", type=float, default=1e-6,
        help="relative and absolute tolerance (default: 1e-6; make check passes FLOAT_TOL, 1e-5)"
    )
    parser.add_argument(
        "pos_tol", nargs="?", default=None, help=argparse.SUPPRESS
    )  # Backward compat
    args = parser.parse_args()

    tol = args.tol
    if args.pos_tol is not None:
        try:
            tol = float(args.pos_tol)
        except ValueError:
            pass

    sys.exit(1 if compare_files(args.file1, args.file2, tol) else 0)
