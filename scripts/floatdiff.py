#!/usr/bin/env python3
import sys
import math
import argparse


def compare_files(file1, file2, tol=1e-6):
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


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Compare two text files allowing float tolerance."
    )
    parser.add_argument("file1", help="Reference file")
    parser.add_argument("file2", help="Output file to compare")
    parser.add_argument(
        "-t", "--tol", type=float, default=1e-6, help="Tolerance (default: 1e-6)"
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

    compare_files(args.file1, args.file2, tol)
