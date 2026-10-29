#!/usr/bin/env python3
"""Flag the tests whose reference validates little: silent, constant, settled, inputs unused.

`make check` compares each test with its reference within FLOAT_TOL (1e-5),
an absolute tolerance below 1 in magnitude (scripts/floatdiff.py). What the
comparison cannot tell apart, it does not check: a channel that stays within
the tolerance of zero is a silent channel to it, and frames that stay within
the tolerance of a constant are that constant. Rule 1 of AGENTS.md asks to
check every generated reference by hand; this script does it for all of
them. It reads the references of tests/reference/ (make reference), one line
per frame, and the C++ faust generates for each test, and flags:

- silent: every channel stays within the tolerance of zero: `make check`
  accepts a silent output (a gate that never opens, a slider at a
  silent default, an excitation that never reaches the output);
- below-tolerance: a channel carries values, but all of them within the
  tolerance of zero (the others do not): `make check` sees it as 0, not as
  the value the test computes (a precision test at 1e-9);
- constant: every channel stays within the tolerance of a single value,
  although the program has state (a delay, a recursion): a smoothing of a
  constant, a counter whose trigger is pressed once. A program without
  state and without inputs computes a constant by definition (ma.PI, a
  function at constant arguments): it is not flagged;
- settles: every channel stays within the tolerance of its last value over
  the second half of the render: an envelope or an impulse response that
  ends early, after which the frames check nothing but a constant;
- dead-input: the test has inputs, which the harnesses feed with zeros:
  whatever reads them is never exercised.

The accepted cases are in tests/weak-baseline.json, {test: {"kinds": [...],
"reason": "..."}}, under the rule of the other baselines: a new kind fails,
an entry that no longer happens is reported stale and is removed in the
same commit, --write-baseline records the current findings (each needs its
reason). A new test passes without an entry. A missing reference fails
(make reference), except with --skip-missing, which reports their number;
a reference left by a test that no longer exists is reported.

The C++ (faust -double, no architecture) is compiled from the repository
root into tests/build-weak/ and reused while it is newer than the test file
and the libraries: about 12 s for the whole suite, then 3 s.

    scripts/check_weak.py                      # every tracked test
    scripts/check_weak.py tests/basics_tests.dsp -k counter
    scripts/check_weak.py --changed --skip-missing   # what make check-doc runs
"""
import argparse
import concurrent.futures as cf
import functools
import glob
import json
import os
import re
import shutil
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_precision as cp  # noqa: E402

ROOT = cp.ROOT
REFERENCE_DIR = os.path.join(ROOT, "tests", "reference")
BASELINE = os.path.join(ROOT, "tests", "weak-baseline.json")
# the state of a program: its delay lines and recursions, members of the mydsp
# class (the classes filling the tables at init have their own, not counted)
STATE_RE = re.compile(r"^\s+(?:double|float|int|FAUSTFLOAT)\s+(?:fRec|iRec|fVec|iVec|IOTA)\w*", re.M)
INPUTS_RE = re.compile(r"getNumInputs\(\)\s*\{\s*return\s+(\d+);")


def float_tol():
    """FLOAT_TOL of the Makefile, the tolerance of `make check`."""
    m = re.search(r"^FLOAT_TOL\s*\?=\s*(\S+)", open(os.path.join(ROOT, "Makefile")).read(), re.M)
    return float(m.group(1)) if m else 1e-5


def newest_source(dsp):
    return max(os.path.getmtime(p) for p in glob.glob(os.path.join(ROOT, "*.lib")) + [dsp])


def program(spec, args):
    """(number of inputs, has state), or an error string."""
    dsp, name = spec
    cpp = os.path.join(args.build_dir, name + ".cpp")
    if not (os.path.exists(cpp) and os.path.getmtime(cpp) >= newest_source(dsp)):
        # faust looks for libraries in the current directory before the -I ones:
        # compile from ROOT so that the libraries are this checkout's
        r = subprocess.run([args.faust, "-double", "-t", "0", "-I", ROOT, "-pn", name, dsp,
                            "-o", cpp], capture_output=True, text=True, cwd=ROOT)
        if r.returncode != 0:
            if os.path.exists(cpp):
                os.remove(cpp)  # not reused as up to date next time
            return "faust: " + (r.stderr.strip().splitlines() or ["?"])[-1]
    src = open(cpp).read()
    m = INPUTS_RE.search(src)
    start = src.find("class mydsp : public dsp")
    members = src[start:src.find("public:", start)]
    return (int(m.group(1)) if m else 0), bool(STATE_RE.search(members))


def read_reference(path):
    """The samples of a reference, one row per frame (the frame index dropped)."""
    with open(path) as f:
        text = f.read()
    ncol = len(text.split("\n", 1)[0].split())
    data = np.array(text.split(), dtype=np.float64) if ncol else np.zeros(0)
    return data.reshape(-1, ncol)[:, 1:] if ncol else np.zeros((0, 0))


def close(a, b, tol):
    """floatdiff's comparison: |a - b| <= max(tol * max(|a|, |b|), tol)."""
    return np.abs(a - b) <= np.maximum(tol * np.maximum(np.abs(a), np.abs(b)), tol)


def analyse(data, inputs, state, tol):
    """{kind: description} of one test, from its reference samples."""
    found = {}
    frames, nch = data.shape
    if frames == 0 or nch == 0:
        return {"silent": "the reference has no sample"}
    # a channel with a non-finite sample is check_precision's (ma.MAX, ma.INFINITY
    # print as inf through the float outputs of the harness): left out
    channels = [c for c in range(nch) if np.isfinite(data[:, c]).all()]
    if channels:
        found.update(analyse_channels(data, channels, state, tol))
    if inputs:
        found["dead-input"] = (f"{inputs} input{'s' if inputs > 1 else ''}, fed with zeros by"
                               " the harnesses")
    return found


def analyse_channels(data, channels, state, tol):
    found = {}
    frames, nch = data.shape
    peaks = {c: float(np.max(np.abs(data[:, c]))) for c in channels}
    silent = {c for c in channels if peaks[c] <= tol}
    if len(silent) == len(channels):
        found["silent"] = (f"every channel within {tol:g} of zero (peak {max(peaks.values()):.3g}):"
                           " make check accepts a silent output")
        return found
    low = [c for c in channels if 0 < peaks[c] <= tol]
    if low:
        found["below-tolerance"] = (
            f"channel{'s' if len(low) > 1 else ''} {', '.join(str(c) for c in low)} of {nch}"
            f" within {tol:g} of zero (peak {max(peaks[c] for c in low):.3g}):"
            " make check sees 0, not the value computed")
    # the last frame at which each channel differs from its last value beyond the tolerance
    last = -1
    for c in channels:
        if c not in silent:
            diff = np.nonzero(~close(data[:, c], data[-1, c], tol))[0]
            last = max(last, int(diff[-1]) if len(diff) else -1)
    if last < 0:
        if state:
            found["constant"] = ("every channel constant within the tolerance, although the"
                                 " program has state")
    elif last < frames // 2:
        found["settles"] = (f"every channel within the tolerance of its last value after"
                            f" frame {last} of {frames}")
    return found


def check_test(spec, args):
    name = spec[1]
    ref = os.path.join(args.reference_dir, name + ".ref")
    if not os.path.exists(ref):
        return name, None
    info = program(spec, args)
    if isinstance(info, str):
        return name, {"build": info}
    return name, analyse(read_reference(ref), *info, args.tol)


def changed():
    """True when a tracked library, test file or this check's baseline differs from HEAD."""
    out = subprocess.run(["git", "diff", "--name-only", "HEAD", "--", "*.lib", "tests/*.dsp",
                          os.path.relpath(BASELINE, ROOT)],
                         cwd=ROOT, capture_output=True, text=True).stdout.split()
    return bool(out)


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("dsp", nargs="*", help="test files (default: the tracked tests/*.dsp)")
    p.add_argument("-k", "--filter", help="regex on test names")
    p.add_argument("-j", "--jobs", type=int, default=os.cpu_count())
    p.add_argument("--tol", type=float, default=float_tol(),
                   help="the tolerance of make check (default: the Makefile's FLOAT_TOL)")
    p.add_argument("--changed", action="store_true",
                   help="do nothing unless a tracked .lib, tests/*.dsp or the baseline differs from HEAD")
    p.add_argument("--skip-missing", action="store_true",
                   help="report the tests without reference instead of failing on them")
    p.add_argument("--baseline", default=BASELINE)
    p.add_argument("--write-baseline", action="store_true",
                   help="record the current findings (give each a reason)")
    p.add_argument("--reference-dir", default=REFERENCE_DIR)
    p.add_argument("--build-dir", default=os.path.join(ROOT, "tests", "build-weak"))
    p.add_argument("--faust", default=os.environ.get("FAUST", "faust"))
    p.add_argument("--json", help="write every result to this file")
    args = p.parse_args()

    if args.changed and not changed():
        print("[weak] skipped: no library, test file or baseline differs from HEAD")
        return 0
    if not os.path.isdir(args.reference_dir):
        print(f"[weak] no references in {os.path.relpath(args.reference_dir, ROOT)}: run make reference")
        return 0 if args.skip_missing else 1
    if not shutil.which(args.faust):
        print(f"[weak] {args.faust} not found")
        return 2
    os.makedirs(args.build_dir, exist_ok=True)
    files = [os.path.abspath(f) for f in args.dsp] or cp.default_dsp_files()
    specs = [s for s in cp.test_specs(files) if not args.filter or re.search(args.filter, s[1])]
    print(f"[weak] {len(specs)} tests, tolerance {args.tol:g}", flush=True)

    results, missing = {}, []
    # processes, not threads: reading the references is Python work (1.4 GB of text)
    with cf.ProcessPoolExecutor(args.jobs) as pool:
        for name, found in pool.map(functools.partial(check_test, args=args), specs, chunksize=8):
            if found is None:
                missing.append(name)
            else:
                results[name] = found
    if args.json:
        with open(args.json, "w") as f:
            json.dump(results, f, indent=1, sort_keys=True)

    baseline = {}
    if os.path.exists(args.baseline):
        with open(args.baseline) as f:
            baseline = json.load(f)
    if args.write_baseline:
        scanned = set(results)
        new = {t: e for t, e in baseline.items() if t not in scanned}
        for t, found in results.items():
            if found:
                old = baseline.get(t, {})
                new[t] = {"kinds": sorted(found), "reason": old.get("reason", "TODO")}
        with open(args.baseline, "w") as f:
            json.dump(dict(sorted(new.items())), f, indent=1)
            f.write("\n")
        print(f"[weak] baseline written: {len(new)} entries ({args.baseline})")
        return 0

    problems, stale = [], []
    for t, found in sorted(results.items()):
        accepted = set(baseline.get(t, {}).get("kinds", []))
        for kind, text in sorted(found.items()):
            if kind not in accepted:
                problems.append(f"{t}: {kind}: {text}")
        for kind in sorted(accepted - set(found)):
            stale.append(f"{t}: {kind} no longer happens: remove it from {os.path.basename(args.baseline)}")
    for line in problems + stale:
        print(f"[weak] {line}")
    if missing and not args.skip_missing:
        problems += missing
        for t in missing:
            print(f"[weak] {t}: no reference: run make reference")
    if not args.dsp and not args.filter:
        tested = {name for _, name in specs}
        orphans = sorted(os.path.basename(r)[:-4]
                         for r in glob.glob(os.path.join(args.reference_dir, "*.ref"))
                         if os.path.basename(r)[:-4] not in tested)
        if orphans:
            print(f"[weak] note: {len(orphans)} references of tests that no longer exist,"
                  f" to delete: {', '.join(orphans)}")
    note = f", {len(missing)} without reference not checked" if missing and args.skip_missing else ""
    flagged = sum(1 for f in results.values() if f)
    if problems or stale:
        print(f"[weak] FAILED ({len(problems)} new, {len(stale)} stale; {len(specs)} tests,"
              f" {flagged} flagged, accepted {sum(len(e['kinds']) for e in baseline.values())}{note})")
        return 1
    print(f"[weak] OK ({len(specs)} tests, {flagged} accepted{note})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
