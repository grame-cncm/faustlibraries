#!/usr/bin/env python3
"""Render every test with its sliders and number entries jumping between their bounds.

check_extremes.py renders the controls held at their bounds for the whole
run, and only the tests named `_jump_test` move a parameter while the
program runs, for the functions someone thought of. A recursive filter, an
interpolated delay or a smoother can be stable at every fixed setting and
blow up when the setting moves: the state left by one setting is a wrong
starting point for the other.

For every test of `tests/*.dsp` that has sliders or number entries, this
script renders with `arch/precision_arch.cpp` (`jump`, in blocks of 512
frames), one second at each rate, the controls moving at the eighths of the
run: default, max, min, max, min, max, min, default:

- all of them together (`jump`);
- each one alone, the others at their default (`jump:I`; skipped when the
  test has a single control: same as all).

Buttons and checkboxes keep their schedule (pressed, then released at the
middle). A run fails when its output is not finite, or when its peak exceeds
GROWTH times the largest of 1 and the peaks of the default render and of the
renders held at the same bounds (`min`, `max`, or `min:I`, `max:I`): a jump
to a gain at its maximum raises the level as much as the held maximum does,
an instability by orders of magnitude. A run whose held bounds are already
not finite is not judged: check_extremes.py reports it. No reference is
stored. `tests/jumps-baseline.json` lists the accepted cases, per test and
setting, with the reason; an entry that no longer fails is reported, to be
removed.

    scripts/check_jumps.py [-k REGEX] [--rates 44100,192000] [FILE.dsp ...]
    make check-jumps [JUMPS_ARGS="tests/filters_resonator_tests.dsp"]

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
import check_extremes as ce  # noqa: E402

BASELINE = os.path.join(cp.ROOT, "tests", "jumps-baseline.json")


def settings(ctrls):
    """(jump setting, the held settings of the same bounds, readable name)."""
    s = [("jump", ("min", "max"), "all jumping")]
    if len(ctrls) > 1:
        for i, lo, hi, _, label in ctrls:
            s.append((f"jump:{i}", (f"min:{i}", f"max:{i}"), f"{label} jumping {lo:g} .. {hi:g}"))
    return s


def check_test(spec, args):
    dsp, name = spec
    res = {"test": name, "file": os.path.relpath(dsp, cp.ROOT), "runs": {}}
    exe, err = cp.build(dsp, name, args.precision, args.cfg, args)
    if err:
        res["error"] = err
        return res
    try:
        ctrls = ce.controls(exe)
    except (RuntimeError, subprocess.TimeoutExpired) as e:
        res["error"] = str(e)
        return res
    res["controls"] = len(ctrls)
    if not ctrls:
        return res
    for sr in args.rates:
        frames = int(round(sr * args.seconds))
        path = exe + f".{sr}.jump.raw"
        peaks = {}

        def peak(setting):
            """Peak of a held render (None when it is not finite), cached."""
            if setting not in peaks:
                out = cp.render(exe, sr, frames, path, setting)
                peaks[setting] = float(np.abs(out).max()) if np.isfinite(out).all() and out.size else None
            return peaks[setting]

        try:
            default = peak("")
        except (RuntimeError, subprocess.TimeoutExpired) as e:
            res["error"] = str(e)
            return res
        if default is None:
            continue  # check_precision.py judges the default render
        for key, held, what in settings(ctrls):
            run = {"what": what}
            try:
                bounds = [peak(h) for h in held]
                out = cp.render(exe, sr, frames, path, f"{key},block={args.block}")
            except (RuntimeError, subprocess.TimeoutExpired) as e:
                res["runs"][f"{key}@{sr}"] = {"what": what, "error": str(e)}
                continue
            if any(b is None for b in bounds):
                run["skip"] = "a held bound is not finite (check_extremes.py)"
            elif not np.isfinite(out).all():
                bad = np.argwhere(~np.isfinite(out))[0]
                run["fail"] = f"not finite from frame {int(bad[0])} (segment {int(bad[0]) * 8 // frames})"
            else:
                top = float(np.abs(out).max())
                ref = max([1.0, default] + bounds)
                run["peak"] = top
                if top > args.growth * ref:
                    at = int(np.abs(out).max(axis=1).argmax())
                    run["fail"] = (f"peak {top:.3g} (segment {at * 8 // frames}) > {args.growth:g} x "
                                   f"max(1, default {default:.3g}, held bounds "
                                   f"{', '.join(f'{b:.3g}' for b in bounds)})")
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
    p.add_argument("--block", type=int, default=512,
                   help="frames per compute() (default: %(default)s)")
    p.add_argument("--precision", choices=("single", "double"), default="single",
                   help="the build rendered (default: %(default)s)")
    p.add_argument("--growth", type=float, default=100.0,
                   help="largest peak accepted, as a multiple of max(1, default peak, held "
                        "bounds' peaks) (default: %(default)g)")
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
                       "block": args.block, "precision": args.precision, "results": results},
                      f, indent=1)
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
            json.dump({"comment": "Accepted results of controls jumping between their bounds, "
                                  "see scripts/check_jumps.py; each entry gives the reason.",
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
    skipped = sum(1 for r in results for run in r.get("runs", {}).values() if "skip" in run)
    print(f"\n[jumps] {len(specs)} tests, {tested} with controls, {runs} runs at "
          f"{', '.join(map(str, args.rates))} Hz ({skipped} not judged: a held bound not finite) "
          f"in {time.time() - t0:.0f} s: {len(set(failures))} failed")
    return 1 if failures and not args.write_baseline else 0


if __name__ == "__main__":
    sys.exit(main())
