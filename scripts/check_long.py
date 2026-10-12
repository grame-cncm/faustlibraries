#!/usr/bin/env python3
"""Render every test for minutes, in single and double precision, without references.

`make check` renders one second, `check-precision` one second at each rate:
what only shows after minutes is never rendered. A time or a phase held in a
float loses its integer precision after 2^24 frames (87 s at 192 kHz, 349 s
at 48 kHz), a slow instability takes its time to grow, a decaying recursion
ends in denormals. This check compiles each test in -single and in -double
and renders it for SECONDS at RATE (default: 120 s at 192 kHz, 23 million frames) through
arch/long_arch.cpp, which writes no samples but analyses them per second,
with the control schedule of the other harnesses (buttons pressed for the
first half). A test fails on:

- nonfinite: a non-finite sample (the frame of the first one);
- growth: a peak beyond GROWTH (100) times the peak of the first WARMUP
  seconds (2), the threshold of check_extremes.py. A decay is not a failure:
  released gates, envelopes, impulses and sweeps decay legitimately;
- subnormal: subnormal output samples after the first WARMUP seconds,
  counted, not timed (a timing is noisy, and Apple Silicon computes
  subnormals at little or no cost);
- drift: the RMS of a second differing from the -double render's by more
  than DRIFT (1e-2, relative) and by more than 10 times the gap of the
  EARLY (8) seconds after the warm-up, the seconds below FLOOR (1e-5, about
  -100 dB) left out. A float time or phase losing its precision, a sum
  accumulating its rounding, give finite samples that neither grow nor go
  subnormal: only the comparison with a double render sees them; a gap
  that does not grow is a float/double difference, check_precision's.

The wrap of an int32 counter (ba.time), 12.4 h away at 48 kHz, is out of
reach. The accepted debt is in tests/long-baseline.json, {test: {"kinds":
[...], "reason": "..."}}, under the rule of the other baselines: a new kind
fails, an entry that no longer happens is reported stale and is removed in
the same commit, --write-baseline records the current failures (each needs
its reason).

    scripts/check_long.py                     # every tracked test
    scripts/check_long.py tests/filters_tests.dsp -k lowpass
    scripts/check_long.py --rate 48000 --seconds 600
"""
import argparse
import concurrent.futures as cf
import json
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_precision as cp  # noqa: E402

ROOT = cp.ROOT
LONG_ARCH = os.path.join(ROOT, "arch", "long_arch.cpp")


def analyse(rows, double_rows, args):
    """{kind: description} of the failures of one render (rows: per-second tuples
    (second, peak, rms, nonfinite, first nonfinite frame, subnormal)), double_rows those
    of the -double render."""
    found = {}
    nonfinite = [(s, first) for s, _, _, n, first, _ in rows if n]
    if nonfinite:
        s, first = nonfinite[0]
        found["nonfinite"] = f"non-finite sample at frame {first} (second {s})"
    ref = max([peak for s, peak, *_ in rows if s < args.warmup] or [0.0])
    if ref > 0:
        later = [(peak, s) for s, peak, *_ in rows if s >= args.warmup]
        if later:
            peak, s = max(later)
            if peak > args.growth * ref:
                found["growth"] = (f"peak {peak:.3g} at second {s}, {peak / ref:.3g} times the"
                                   f" peak of the first {args.warmup} s ({ref:.3g})")
    sub = [(s, k) for s, _, _, _, _, k in rows if s >= args.warmup and k]
    if sub:
        found["subnormal"] = (f"{sum(k for _, k in sub)} subnormal output samples after"
                              f" {args.warmup} s, the first in second {sub[0][0]}")
    if "nonfinite" not in found:
        # the relative RMS gap of each second above the floor, after the warm-up: a drift is a
        # gap beyond DRIFT that also grew, beyond 10 times the gap of the first seconds after
        # the warm-up; a constant float/double offset is check_precision's
        d = {s: rms for s, _, rms, *_ in double_rows}
        gaps = []
        for s, _, rms, *_ in rows:
            ref = max(rms, d.get(s, 0.0))
            if s >= args.warmup and s in d and ref > args.floor:
                gaps.append((s, abs(rms - d[s]) / ref, rms, d[s]))
        early = max([g for s, g, *_ in gaps if s < args.warmup + args.early] or [0.0])
        for s, g, rms, drms in gaps:
            if s >= args.warmup + args.early and g > args.drift and g > 10 * max(early, 1e-4):
                found["drift"] = (f"second {s}: RMS {rms:.6g} in single precision, {drms:.6g} in"
                                  f" double ({g:.3g} relative, {early:.2g} in the first"
                                  f" {args.early} s after the warm-up)")
                break
    return found


def render(spec, precision, cfg, args):
    """(rows, None) of a render in `precision`, or (None, {kind: error})."""
    dsp, name = spec
    exe, err = cp.build(dsp, name, precision, cfg, args)
    if err:
        return None, {"build": err}
    r = subprocess.run([exe, str(args.seconds), str(args.rate), precision],
                       capture_output=True, text=True, timeout=args.timeout)
    if r.returncode != 0:
        return None, {"run": f"exit {r.returncode}: " + (r.stderr.strip().splitlines() or [""])[-1]}
    rows = []
    for line in r.stdout.split("\n"):
        f = line.split()
        if len(f) == 6:
            rows.append((int(f[0]), float(f[1]), float(f[2]), int(f[3]), int(f[4]), int(f[5])))
    return rows, None


def check_test(spec, cfg, args):
    rows, err = render(spec, "single", cfg, args)
    if err:
        return spec[1], err
    double_rows, err = render(spec, "double", cfg, args)
    if err:
        return spec[1], err
    return spec[1], analyse(rows, double_rows, args)


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("dsp", nargs="*", help="test files (default: the tracked tests/*.dsp)")
    p.add_argument("-k", "--filter", help="regex on test names")
    p.add_argument("-j", "--jobs", type=int, default=os.cpu_count())
    p.add_argument("--rate", type=int, default=192000)
    p.add_argument("--seconds", type=int, default=120)
    p.add_argument("--warmup", type=int, default=2, help="seconds of the reference peak")
    p.add_argument("--growth", type=float, default=100.0)
    p.add_argument("--drift", type=float, default=1e-2,
                   help="relative RMS gap per second between -single and -double")
    p.add_argument("--early", type=int, default=8,
                   help="seconds after the warm-up whose gap the later ones are compared with")
    p.add_argument("--floor", type=float, default=1e-5,
                   help="RMS below which a second is silence, not compared")
    p.add_argument("--timeout", type=int, default=1800, help="seconds per render")
    p.add_argument("--baseline", default=os.path.join(ROOT, "tests", "long-baseline.json"))
    p.add_argument("--write-baseline", action="store_true",
                   help="record the current failures (give each a reason)")
    p.add_argument("--build-dir", default=os.path.join(ROOT, "tests", "build-long"))
    p.add_argument("--faust", default=os.environ.get("FAUST", "faust"))
    p.add_argument("--cxx", default=os.environ.get("CXX", "c++"))
    p.add_argument("--cxx-options", default=cp.DEFAULT_CXX_OPTIONS)
    p.add_argument("--json", help="write every result to this file")
    args = p.parse_args()

    cp.ARCH = LONG_ARCH  # cp.build reads it at each call
    os.makedirs(args.build_dir, exist_ok=True)
    cfg = cp.Config("long", "", args.cxx_options, args.build_dir)
    files = [os.path.abspath(f) for f in args.dsp] or cp.default_dsp_files()
    specs = [s for s in cp.test_specs(files) if not args.filter or re.search(args.filter, s[1])]
    print(f"[long] {len(specs)} tests, -single and -double, {args.seconds} s at {args.rate} Hz",
          flush=True)

    results = {}
    with cf.ThreadPoolExecutor(args.jobs) as pool:
        for name, found in pool.map(lambda s: check_test(s, cfg, args), specs):
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
        print(f"[long] baseline written: {len(new)} entries ({args.baseline})")
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
        print(f"[long] {line}")
    failed = sum(1 for f in results.values() if f)
    if problems or stale:
        print(f"[long] FAILED ({len(problems)} new, {len(stale)} stale; {len(specs)} tests,"
              f" {failed} with a failure, accepted {sum(len(e['kinds']) for e in baseline.values())})")
        return 1
    print(f"[long] OK ({len(specs)} tests, {failed} accepted failures)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
