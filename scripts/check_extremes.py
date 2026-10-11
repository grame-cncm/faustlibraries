#!/usr/bin/env python3
"""Render every test with its sliders and number entries at their extremes.

Every other check renders the controls at their default value. Rule 9 of
AGENTS.md asks to "also try the controls at their extremes", by hand: a
division by zero, an instability at a bound of the documented range (Q = 0,
a cutoff at 0 Hz or at Nyquist, a feedback gain of 1, a zero-length delay)
passes the whole suite as long as the default value is inside the range.

For every test of `tests/*.dsp` that has sliders or number entries, this
script renders, with `arch/precision_arch.cpp`:

- all of them at their minimum, then all at their maximum;
- each one alone at its minimum and at its maximum, the others at their
  default (skipped when the test has a single control: same as all).

Buttons and checkboxes keep their schedule (pressed, then released). A run
fails when its output is not finite, or when its peak exceeds GROWTH times
the larger of 1 and the peak of the default render (a gain at its maximum
may raise the level; an instability raises it by orders of magnitude). No
reference is stored. `tests/extremes-baseline.json` lists the accepted
cases, per test and setting, with the reason; an entry that no longer fails
is reported, to be removed.

    scripts/check_extremes.py [-k REGEX] [--rates 44100,192000] [FILE.dsp ...]
    make check-extremes [EXTREMES_ARGS="tests/filters_resonator_tests.dsp"]

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

BASELINE = os.path.join(cp.ROOT, "tests", "extremes-baseline.json")


def controls(exe):
    """The sliders and number entries: (index, min, max, init, label)."""
    r = subprocess.run([exe, "1", "48000", os.devnull, "list"], capture_output=True, text=True,
                       timeout=60)
    if r.returncode != 0:
        raise RuntimeError(f"{os.path.basename(exe)} list exited with {r.returncode}")
    out = []
    for line in r.stdout.splitlines():
        i, lo, hi, init, label = line.split("\t", 4)
        out.append((int(i), float(lo), float(hi), float(init), label))
    return out


def settings(ctrls):
    """The control settings to render, with a readable name for each."""
    s = [("min", "all at min"), ("max", "all at max")]
    if len(ctrls) > 1:
        for i, lo, hi, _, label in ctrls:
            s.append((f"min:{i}", f"{label} = {lo:g}"))
            s.append((f"max:{i}", f"{label} = {hi:g}"))
    return s


def check_test(spec, args):
    dsp, name = spec
    res = {"test": name, "file": os.path.relpath(dsp, cp.ROOT), "runs": {}}
    exe, err = cp.build(dsp, name, args.precision, args.cfg, args)
    if err:
        res["error"] = err
        return res
    try:
        ctrls = controls(exe)
    except (RuntimeError, subprocess.TimeoutExpired) as e:
        res["error"] = str(e)
        return res
    res["controls"] = len(ctrls)
    if not ctrls:
        return res
    for sr in args.rates:
        frames = int(round(sr * args.seconds))
        path = exe + f".{sr}.ext.raw"
        try:
            ref = cp.render(exe, sr, frames, path)
        except (RuntimeError, subprocess.TimeoutExpired) as e:
            res["error"] = str(e)
            return res
        if not np.isfinite(ref).all() or ref.shape[1] == 0:
            continue  # check_precision.py judges the default render
        limit = args.growth * max(float(np.abs(ref).max()), 1.0)
        for key, what in settings(ctrls):
            try:
                out = cp.render(exe, sr, frames, path, key)
            except (RuntimeError, subprocess.TimeoutExpired) as e:
                res["runs"][f"{key}@{sr}"] = {"what": what, "error": str(e)}
                continue
            run = {"what": what}
            if not np.isfinite(out).all():
                run["fail"] = "not finite"
            else:
                peak = float(np.abs(out).max())
                run["peak"] = peak
                if peak > limit:
                    run["fail"] = f"peak {peak:.3g} > {args.growth:g} x max(1, default {limit / args.growth:.3g})"
            res["runs"][f"{key}@{sr}"] = run
    return res


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("dsp", nargs="*", help="test files (default: the tracked tests/*.dsp)")
    p.add_argument("-k", "--filter", help="regex on test names")
    p.add_argument("-j", "--jobs", type=int, default=os.cpu_count())
    p.add_argument("--rates", default="44100,192000",
                   help="comma-separated sample rates (default: %(default)s)")
    p.add_argument("--seconds", type=float, default=1.0,
                   help="duration rendered for each setting (default: %(default)s)")
    p.add_argument("--precision", choices=("single", "double"), default="single",
                   help="the build rendered (default: %(default)s)")
    p.add_argument("--growth", type=float, default=100.0,
                   help="largest peak accepted, as a multiple of max(1, default peak) "
                        "(default: %(default)g)")
    p.add_argument("--baseline", default=BASELINE)
    p.add_argument("--write-baseline", action="store_true",
                   help="record the current failures as accepted (all tests, maintainers only)")
    p.add_argument("--build-dir", default=os.path.join(cp.ROOT, "tests", "build-precision"))
    p.add_argument("--json", help="write every run to this file")
    p.add_argument("--faust", default=os.environ.get("FAUST", "faust"))
    p.add_argument("--cxx", default=os.environ.get("CXX", "c++"))
    args = p.parse_args()
    args.rates = [int(r) for r in args.rates.split(",")]
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
                setting = key.split("@")[0]
                if why and setting not in ok_here:
                    failures.append(name)
                    print(f"[fail] {name} ({res['file']}) {run['what']} at {key.split('@')[1]} Hz: "
                          f"{why}", flush=True)
            failed_settings = {k.split("@")[0] for k, r in res["runs"].items()
                               if r.get("fail") or r.get("error")}
            stale += [f"{name}: {s}" for s in ok_here if s not in failed_settings]

    if args.json:
        with open(args.json, "w") as f:
            json.dump({"rates": args.rates, "seconds": args.seconds, "growth": args.growth,
                       "precision": args.precision, "results": results}, f, indent=1)
    if args.write_baseline:
        new = {}
        for res in results:
            for key, run in res.get("runs", {}).items():
                why = run.get("fail") or run.get("error")
                if why:
                    setting = key.split("@")[0]
                    old = accepted.get(res["test"], {}).get(setting)
                    new.setdefault(res["test"], {})[setting] = old or f"{run['what']}: {why}"
        with open(args.baseline, "w") as f:
            json.dump({"comment": "Accepted results of controls at their extremes, see "
                                  "scripts/check_extremes.py; each entry gives the reason.",
                       "accepted": dict(sorted(new.items()))}, f, indent=1)
            f.write("\n")
        print(f"[baseline] written to {os.path.relpath(args.baseline, cp.ROOT)}")
    if stale:
        print(f"\nBaseline entries no longer needed (remove them from "
              f"{os.path.relpath(args.baseline, cp.ROOT)}):")
        for line in sorted(stale):
            print("  " + line)
    tested = sum(1 for r in results if r.get("controls"))
    runs = sum(len(r.get("runs", {})) for r in results)
    print(f"\n[extremes] {len(specs)} tests, {tested} with controls, {runs} runs at "
          f"{', '.join(map(str, args.rates))} Hz in {time.time() - t0:.0f} s: "
          f"{len(set(failures))} failed")
    return 1 if failures and not args.write_baseline else 0


if __name__ == "__main__":
    sys.exit(main())
