#!/usr/bin/env python3
"""Check the regression tests in single and double precision, across sample rates.

`make check` compares each test with a stored reference computed in double
precision at 48 kHz. This script asks a different question, which needs no
reference: does the test behave at every rate from 44.1 to 192 kHz, and does
its single-precision build stay close to its double-precision build?

For every `*_test` of `tests/*.dsp`, it compiles a -single and a -double build
with `arch/precision_arch.cpp`, renders SECONDS of audio at each rate, and
measures, over all output channels:

- finite: both builds produce finite samples;
- gap:    max |single - double| / peak of double (the metric of
          doc/docs/contributing.md, section "Precision and sample rate");
- level:  max over channels of |rms single - rms double| / rms double, which
          ignores a slow phase drift (os.osc in float) that `gap` does not;
- growth: peak at this rate / peak at the lowest rate (a blow-up at high
          rates shows here).

A test fails when an output is not finite, or when its level gap exceeds the
threshold (1e-3), unless tests/precision-baseline.json accepts it. That file
pins the accepted debt, the way tests/doc-baseline.json does for the
documentation: `nonfinite` lists the rates at which a test may be non-finite
in single precision, `level` the worst level gap it may reach (times
`margin`, since the last bits of a single-precision result depend on the
compiler and its libm), and `expected` the tests whose single and double
outputs differ by definition (ma.EPSILON...), which are not checked. A
baseline entry that is no longer needed is reported so that it can be
removed: a level entry once the gap is below threshold / margin, so that a
gap that is under the threshold on one platform but not on another keeps its
entry. Never add an entry to silence a failure you caused.

`gap` is reported, not checked: a sine input (os.osc) drifts in phase in
single precision, so most tests exceed any useful sample-level threshold
without being wrong.
"""

import argparse
import concurrent.futures as cf
import glob
import json
import os
import re
import subprocess
import sys
import time

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARCH = os.path.join(ROOT, "arch", "precision_arch.cpp")
DEFAULT_RATES = [44100, 48000, 88200, 96000, 176400, 192000]
TEST_RE = re.compile(r"^\s*([A-Za-z0-9_]+_test)\s*=", re.M)


def test_specs(dsp_files):
    specs = []
    for path in dsp_files:
        with open(path) as f:
            for name in TEST_RE.findall(f.read()):
                specs.append((path, name))
    return specs


def default_dsp_files():
    try:
        out = subprocess.run(["git", "ls-files", "tests/*.dsp"], cwd=ROOT,
                             capture_output=True, text=True, check=True).stdout
        files = [os.path.join(ROOT, p) for p in out.split() if p.count("/") == 1]
    except (OSError, subprocess.CalledProcessError):
        files = glob.glob(os.path.join(ROOT, "tests", "*.dsp"))
    return sorted(files)


def newest_source(dsp):
    libs = glob.glob(os.path.join(ROOT, "*.lib"))
    return max(os.path.getmtime(p) for p in libs + [dsp, ARCH])


def build(dsp, name, precision, build_dir, args):
    exe = os.path.join(build_dir, f"{name}.{precision}")
    if os.path.exists(exe) and os.path.getmtime(exe) >= newest_source(dsp):
        return exe, None
    cpp = exe + ".cpp"
    cmd = [args.faust, f"-{precision}", "-t", "0", "-I", ROOT, "-a", ARCH,
           "-pn", name, dsp, "-o", cpp]
    # faust looks for libraries in the current directory before the -I ones:
    # compile from ROOT so that the libraries under test are the ones used.
    r = subprocess.run(cmd, capture_output=True, text=True, cwd=ROOT)
    if r.returncode != 0:
        return None, "faust: " + (r.stderr.strip().splitlines() or ["?"])[-1]
    r = subprocess.run([args.cxx, "-O2", "-std=c++17", cpp, "-o", exe],
                       capture_output=True, text=True)
    if r.returncode != 0:
        return None, "c++: " + (r.stderr.strip().splitlines() or ["?"])[0]
    return exe, None


def render(exe, sr, frames, path):
    r = subprocess.run([exe, str(frames), str(sr), path], capture_output=True, text=True,
                       timeout=600)
    if r.returncode != 0:
        raise RuntimeError(f"{os.path.basename(exe)} exited with {r.returncode} at {sr} Hz")
    with open(path, "rb") as f:
        channels = int(np.frombuffer(f.read(4), dtype=np.int32)[0])
        data = np.frombuffer(f.read(), dtype=np.float64)
    os.remove(path)
    return data.reshape(-1, channels) if channels else np.zeros((frames, 0))


def measure(s, d):
    finite_s = bool(np.isfinite(s).all())
    finite_d = bool(np.isfinite(d).all())
    m = {"finite_single": finite_s, "finite_double": finite_d}
    if not (finite_s and finite_d) or d.shape[1] == 0:
        m.update(peak=None, gap=None, level=None)
        return m
    peak = float(np.abs(d).max())
    diff = float(np.abs(s - d).max())
    m["peak"] = peak
    m["gap"] = diff / peak if peak > 1e-12 else (0.0 if diff <= 1e-12 else float("inf"))
    # Scaled by each channel's peak so that large signals do not overflow.
    scale = np.maximum(np.abs(d).max(axis=0), 1e-300)
    rms_s = scale * np.sqrt(((s / scale) ** 2).mean(axis=0))
    rms_d = scale * np.sqrt(((d / scale) ** 2).mean(axis=0))
    level = 0.0
    for a, b in zip(rms_s, rms_d):
        if b > 1e-12:
            level = max(level, abs(a - b) / b)
        elif a > 1e-12:
            level = float("inf")
    m["level"] = float(level)
    return m


def check_test(spec, args):
    dsp, name = spec
    res = {"test": name, "file": os.path.relpath(dsp, ROOT), "rates": {}}
    exes = {}
    for precision in ("single", "double"):
        exe, err = build(dsp, name, precision, args.build_dir, args)
        if err:
            res["error"] = f"{precision} build: {err}"
            return res
        exes[precision] = exe
    base_peak = None
    for sr in args.rates:
        frames = int(round(sr * args.seconds))
        try:
            s = render(exes["single"], sr, frames, exes["single"] + f".{sr}.raw")
            d = render(exes["double"], sr, frames, exes["double"] + f".{sr}.raw")
        except (RuntimeError, subprocess.TimeoutExpired) as e:
            res["rates"][sr] = {"error": str(e)}
            continue
        m = measure(s, d)
        if m["peak"] is not None:
            if base_peak is None:
                base_peak = m["peak"]
            m["growth"] = m["peak"] / base_peak if base_peak > 1e-12 else None
        res["rates"][sr] = m
    return res


def worst(res, key):
    vals = [m.get(key) for m in res["rates"].values() if m.get(key) is not None]
    return max(vals) if vals else None


def verdict(res, args, baseline):
    """Return (verdict, reason); a verdict other than ok or expected fails."""
    name = res["test"]
    if name in baseline.get("expected", {}):
        return "expected", baseline["expected"][name]
    if "error" in res:
        return "build-error", res["error"]
    rates = res["rates"]
    errors = [sr for sr, m in rates.items() if "error" in m]
    if errors:
        return "run-error", rates[errors[0]]["error"]
    bad = [str(sr) for sr, m in rates.items() if not m["finite_double"]]
    if bad:
        return "nonfinite-double", "at " + ", ".join(bad) + " Hz"
    bad = [str(sr) for sr, m in rates.items() if not m["finite_single"]]
    allowed = set(map(str, baseline.get("nonfinite", {}).get(name, [])))
    if set(bad) - allowed:
        return "nonfinite-single", "at " + ", ".join(sorted(set(bad) - allowed, key=int)) + " Hz"
    level = worst(res, "level")
    if level is not None and level > args.threshold:
        limit = baseline.get("level", {}).get(name)
        if limit is None:
            return "level", f"level gap {level:.1e} > {args.threshold:g}"
        if level > limit * baseline.get("margin", 2.0):
            return "level", f"level gap {level:.1e} > baseline {limit:.1e} x {baseline.get('margin', 2.0):g}"
    return "ok", ""


def stale_baseline(res, baseline):
    """Baseline entries of this test that it no longer needs."""
    name, stale = res["test"], []
    if "error" in res or any("error" in m for m in res["rates"].values()):
        return stale
    allowed = set(map(str, baseline.get("nonfinite", {}).get(name, [])))
    bad = {str(sr) for sr, m in res["rates"].items() if not m["finite_single"]}
    if allowed - bad:
        stale.append("nonfinite at " + ", ".join(sorted(allowed - bad, key=int)))
    # A level entry is reported only once the gap is below the threshold by the
    # same margin that the baseline allows above its entries: a gap just under
    # the threshold on this platform may still be just over it on another one.
    limit = baseline.get("level", {}).get(name)
    level = worst(res, "level")
    below = baseline.get("threshold", 1e-3) / baseline.get("margin", 2.0)
    if limit is not None and level is not None and level <= below:
        stale.append(f"level (now {level:.1e}, below {below:g})")
    return stale


def make_baseline(results, old, args):
    """The accepted debt, as measured now; `expected` is kept from the old file."""
    nonfinite, level = {}, {}
    for r in results:
        if r["test"] in old.get("expected", {}) or "error" in r:
            continue
        bad = [sr for sr, m in r["rates"].items() if not m.get("finite_single", True)]
        if bad:
            nonfinite[r["test"]] = sorted(int(sr) for sr in bad)
        lv = worst(r, "level")
        if lv is not None and lv > args.threshold:
            level[r["test"]] = float(f"{lv:.2e}")
    return {
        "comment": "Accepted single/double precision debt, see scripts/check_precision.py.",
        "threshold": args.threshold,
        "margin": old.get("margin", 2.0),
        "rates": args.rates,
        "seconds": args.seconds,
        "expected": old.get("expected", {}),
        "nonfinite": dict(sorted(nonfinite.items())),
        "level": dict(sorted(level.items())),
    }


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("dsp", nargs="*", help="test files (default: the tracked tests/*.dsp)")
    p.add_argument("-k", "--filter", help="regex on test names")
    p.add_argument("-j", "--jobs", type=int, default=os.cpu_count())
    p.add_argument("--rates", default=",".join(map(str, DEFAULT_RATES)))
    p.add_argument("--seconds", type=float, default=1.0)
    p.add_argument("--threshold", type=float, default=1e-3)
    p.add_argument("--baseline", default=os.path.join(ROOT, "tests", "precision-baseline.json"))
    p.add_argument("--write-baseline", action="store_true",
                   help="rewrite the baseline from this run (all tests, maintainers only)")
    p.add_argument("--build-dir", default=os.path.join(ROOT, "tests", "build-precision"))
    p.add_argument("--json", help="write every measurement to this file")
    p.add_argument("--faust", default=os.environ.get("FAUST", "faust"))
    p.add_argument("--cxx", default=os.environ.get("CXX", "c++"))
    args = p.parse_args()
    args.rates = [int(r) for r in args.rates.split(",")]
    os.makedirs(args.build_dir, exist_ok=True)
    baseline = {}
    if os.path.exists(args.baseline):
        with open(args.baseline) as f:
            baseline = json.load(f)
    if args.write_baseline and (args.dsp or args.filter):
        p.error("--write-baseline needs a run over all tests")

    specs = test_specs([os.path.abspath(f) for f in args.dsp] or default_dsp_files())
    if args.filter:
        specs = [s for s in specs if re.search(args.filter, s[1])]
    t0 = time.time()
    results, failures, stale = [], [], []
    with cf.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = {pool.submit(check_test, s, args): s for s in specs}
        for n, fut in enumerate(cf.as_completed(futures), 1):
            try:
                res = fut.result()
            except Exception as e:  # report it, keep going
                dsp, name = futures[fut]
                res = {"test": name, "file": os.path.relpath(dsp, ROOT), "error": repr(e), "rates": {}}
            res["verdict"], res["reason"] = verdict(res, args, baseline)
            results.append(res)
            if res["verdict"] not in ("ok", "expected"):
                failures.append(res)
                print(f"[fail] {res['test']} ({res['file']}): {res['verdict']}, {res['reason']}",
                      flush=True)
            elif res["verdict"] == "ok":
                for what in stale_baseline(res, baseline):
                    stale.append(f"{res['test']}: {what}")
    results.sort(key=lambda r: r["test"])
    if args.json:
        with open(args.json, "w") as f:
            json.dump({"rates": args.rates, "seconds": args.seconds,
                       "threshold": args.threshold, "results": results}, f, indent=1)
    if args.write_baseline:
        with open(args.baseline, "w") as f:
            json.dump(make_baseline(results, baseline, args), f, indent=1)
            f.write("\n")
        print(f"[baseline] written to {os.path.relpath(args.baseline, ROOT)}")
    if stale:
        print("\nBaseline entries no longer needed (remove them from "
              f"{os.path.relpath(args.baseline, ROOT)}):")
        for line in sorted(stale):
            print("  " + line)
    print(f"\n[precision] {len(results)} tests at {', '.join(str(r) for r in args.rates)} Hz "
          f"in {time.time() - t0:.0f} s: {len(failures)} failed")
    return 1 if failures and not args.write_baseline else 0


if __name__ == "__main__":
    sys.exit(main())
