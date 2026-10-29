#!/usr/bin/env python3
"""Check that every test renders the same after a second init() as when fresh.

Every other check renders an instance initialized once. A host initializes
it again when the sample rate changes, or to reset it (init() calls
classInit(), instanceConstants(), instanceResetUserInterface() and
instanceClear()). A state that instanceClear() does not reset, a table filled
at the first rate and not at the second, a constant computed from the first
rate, gives another output after the second init() than in a fresh instance,
and nothing else sees it.

For every test of `tests/*.dsp`, this script renders with
`arch/precision_arch.cpp`, in blocks of 512 frames (`block=512`), one second
at each rate R of the pairs below:

- a fresh instance, initialized at R;
- an instance initialized at R0, run one second with the same schedule, then
  initialized again at R (`reinit=R0`).

The pairs are 48000 after 48000 (a reset at the same rate), 192000 after
44100 and 44100 after 192000 (a rate change, both ways). The two renders
come from the same binary and compute the same operations: they must be
identical, sample for sample (non-finite samples included, at the same
places). A test fails on the first difference, reported with its frame and
size. `tests/reinit-baseline.json` lists the accepted cases, per test and
pair, with the reason; an entry that no longer fails is reported, to be
removed.

    scripts/check_reinit.py [-k REGEX] [FILE.dsp ...]
    make check-reinit [REINIT_ARGS="tests/delays_tests.dsp"]

The builds are those of check_precision.py (`-single` by default, in
tests/build-precision), so a run after check-precision rebuilds nothing.
Exit status: 0, or 1 on a failure.
"""

import argparse
import concurrent.futures as cf
import json
import os
import re
import subprocess
import sys
import time

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_precision as cp  # noqa: E402

BASELINE = os.path.join(cp.ROOT, "tests", "reinit-baseline.json")
PAIRS = [(48000, 48000), (44100, 192000), (192000, 44100)]


def pair_key(first, then):
    return f"{then}after{first}"


def difference(fresh, again):
    """None when the renders are identical, else a description of the first difference."""
    if fresh.shape != again.shape:
        return f"shape {again.shape} instead of {fresh.shape}"
    if np.array_equal(fresh, again, equal_nan=True):
        return None
    diff = ~((fresh == again) | (np.isnan(fresh) & np.isnan(again)))
    frame, channel = (int(v) for v in np.argwhere(diff)[0])
    with np.errstate(invalid="ignore"):
        gap = np.abs(np.where(diff, fresh - again, 0.0))
    peak = float(np.nanmax(np.abs(np.where(np.isfinite(fresh), fresh, 0.0)))) if fresh.size else 0.0
    size = float(np.nanmax(gap)) if np.isfinite(gap).any() else float("nan")
    rel = f", {size / peak:.1e} of the fresh peak" if peak > 0 and np.isfinite(size) else ""
    return (f"differs from frame {frame} (channel {channel}): {fresh[frame, channel]:.9g} fresh, "
            f"{again[frame, channel]:.9g} after init again; largest difference {size:.3g}{rel}, "
            f"{int(diff.any(axis=1).sum())} frames differ")


def check_test(spec, args):
    dsp, name = spec
    res = {"test": name, "file": os.path.relpath(dsp, cp.ROOT), "runs": {}}
    exe, err = cp.build(dsp, name, args.precision, args.cfg, args)
    if err:
        res["error"] = err
        return res
    fresh = {}
    for first, then in PAIRS:
        key = pair_key(first, then)
        frames = int(round(then * args.seconds))
        path = exe + f".{key}.reinit.raw"
        try:
            if then not in fresh:
                fresh[then] = cp.render(exe, then, frames, path, f"block={args.block}")
            again = cp.render(exe, then, frames, path, f"block={args.block},reinit={first}")
        except (RuntimeError, subprocess.TimeoutExpired) as e:
            res["runs"][key] = {"error": str(e)}
            continue
        why = difference(fresh[then], again)
        res["runs"][key] = {"fail": why} if why else {}
    return res


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("dsp", nargs="*", help="test files (default: the tracked tests/*.dsp)")
    p.add_argument("-k", "--filter", help="regex on test names")
    p.add_argument("-j", "--jobs", type=int, default=os.cpu_count())
    p.add_argument("--seconds", type=float, default=1.0,
                   help="duration of each run (default: %(default)s)")
    p.add_argument("--block", type=int, default=512,
                   help="frames per compute() (default: %(default)s)")
    p.add_argument("--precision", choices=("single", "double"), default="single",
                   help="the build rendered (default: %(default)s)")
    p.add_argument("--baseline", default=BASELINE)
    p.add_argument("--write-baseline", action="store_true",
                   help="record the current failures as accepted (all tests, maintainers only)")
    p.add_argument("--build-dir", default=os.path.join(cp.ROOT, "tests", "build-precision"))
    p.add_argument("--json", help="write every run to this file")
    p.add_argument("--faust", default=os.environ.get("FAUST", "faust"))
    p.add_argument("--cxx", default=os.environ.get("CXX", "c++"))
    args = p.parse_args()
    if args.write_baseline and (args.dsp or args.filter):
        p.error("--write-baseline needs a run over all tests")
    args.cfg = cp.Config("default", *cp.CONFIGS["default"], args.build_dir)
    os.makedirs(args.build_dir, exist_ok=True)
    baseline = {}
    if os.path.exists(args.baseline):
        with open(args.baseline) as f:
            baseline = json.load(f)
    accepted = baseline.get("accepted", {})

    specs = cp.test_specs([os.path.abspath(f) for f in args.dsp] or cp.default_dsp_files())
    if args.filter:
        specs = [s for s in specs if re.search(args.filter, s[1])]
    t0 = time.time()
    results, failures, stale = [], [], []
    with cf.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        for res in pool.map(lambda s: check_test(s, args), specs):
            results.append(res)
            name = res["test"]
            if "error" in res:
                failures.append(name)
                print(f"[fail] {name} ({res['file']}): {res['error']}", flush=True)
                continue
            ok_here = accepted.get(name, {})
            for key, run in sorted(res["runs"].items()):
                why = run.get("fail") or run.get("error")
                if why and key not in ok_here:
                    failures.append(name)
                    first, then = key.split("after")[1], key.split("after")[0]
                    print(f"[fail] {name} ({res['file']}) at {then} Hz after {first} Hz: {why}",
                          flush=True)
            failed = {k for k, r in res["runs"].items() if r.get("fail") or r.get("error")}
            stale += [f"{name}: {k}" for k in ok_here if k not in failed]

    if args.json:
        with open(args.json, "w") as f:
            json.dump({"pairs": PAIRS, "seconds": args.seconds, "block": args.block,
                       "precision": args.precision, "results": results}, f, indent=1)
    if args.write_baseline:
        new = {}
        for res in results:
            for key, run in res.get("runs", {}).items():
                why = run.get("fail") or run.get("error")
                if why:
                    old = accepted.get(res["test"], {}).get(key)
                    new.setdefault(res["test"], {})[key] = old or why
        with open(args.baseline, "w") as f:
            json.dump({"comment": "Accepted differences between a fresh instance and one "
                                  "initialized again (KEY: rate after first rate), see "
                                  "scripts/check_reinit.py; each entry gives the reason.",
                       "accepted": dict(sorted(new.items()))}, f, indent=1)
            f.write("\n")
        print(f"[baseline] written to {os.path.relpath(args.baseline, cp.ROOT)}")
    if stale:
        print(f"\nBaseline entries no longer needed (remove them from "
              f"{os.path.relpath(args.baseline, cp.ROOT)}):")
        for line in sorted(stale):
            print("  " + line)
    runs = sum(len(r.get("runs", {})) for r in results)
    print(f"\n[reinit] {len(specs)} tests, {runs} runs ("
          f"{', '.join(f'{b} Hz after {a} Hz' for a, b in PAIRS)}) in {time.time() - t0:.0f} s: "
          f"{len(set(failures))} failed")
    return 1 if failures and not args.write_baseline else 0


if __name__ == "__main__":
    sys.exit(main())
