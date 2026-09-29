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
- rel_max, onset_1e-4, onset_1e-3, growth_exp, error_class : the error
          relative to the LOCAL level of the double render (see error_profile) ;
          reported, not checked.

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

The builds use `faust -single|-double` and `c++ -O2` by default. A precision
fix can depend on how the code is compiled: the Faust normalizer and a C++
`-ffast-math` both reassociate floating-point expressions. Two ways to check
other compilations:

- --faust-options and --cxx-options set the flags of one run, for instance
  --faust-options=-vec or --cxx-options="-O3 -ffast-math" (with "=", since the
  value starts with a dash);
- --matrix runs several named configurations in turn (see CONFIGS below,
  --matrix all for every one), each against the same baseline, and fails if
  any of them fails.

Each configuration builds in its own subdirectory of the build directory
(the default one directly in it), and a build is also redone when its
compiler command changes.
"""

import argparse
import concurrent.futures as cf
import glob
import json
import os
import re
import shlex
import subprocess
import sys
import time

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARCH = os.path.join(ROOT, "arch", "precision_arch.cpp")
DEFAULT_RATES = [44100, 48000, 88200, 96000, 176400, 192000]
DEFAULT_CXX_OPTIONS = "-O2"
# Named compilations for --matrix: (Faust options, C++ options).
CONFIGS = {
    "default": ("", DEFAULT_CXX_OPTIONS),
    "fast-math": ("", "-O3 -ffast-math"),
    "vec": ("-vec", DEFAULT_CXX_OPTIONS),
    "ocpp": ("-lang ocpp", DEFAULT_CXX_OPTIONS),
}
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


class Config:
    """One way of compiling the tests: its Faust and C++ options, its build dir."""

    def __init__(self, name, faust_options, cxx_options, build_dir):
        self.name = name
        self.faust_options = shlex.split(faust_options)
        self.cxx_options = shlex.split(cxx_options)
        self.build_dir = build_dir

    def describe(self):
        return (f"faust {' '.join(self.faust_options) or '(no option)'}, "
                f"c++ {' '.join(self.cxx_options)}")


def build(dsp, name, precision, cfg, args):
    exe = os.path.join(cfg.build_dir, f"{name}.{precision}")
    cpp = exe + ".cpp"
    faust_cmd = [args.faust, *cfg.faust_options, f"-{precision}", "-t", "0", "-I", ROOT,
                 "-a", ARCH, "-pn", name, dsp, "-o", cpp]
    cxx_cmd = [args.cxx, *cfg.cxx_options, "-std=c++17", cpp, "-o", exe]
    # The commands are stored next to the build: a build made with other
    # options is redone, not silently reused.
    stamp = exe + ".cmd"
    stamp_text = json.dumps([faust_cmd, cxx_cmd])
    if (os.path.exists(exe) and os.path.getmtime(exe) >= newest_source(dsp)
            and os.path.exists(stamp) and open(stamp).read() == stamp_text):
        return exe, None
    # faust looks for libraries in the current directory before the -I ones:
    # compile from ROOT so that the libraries under test are the ones used.
    r = subprocess.run(faust_cmd, capture_output=True, text=True, cwd=ROOT)
    if r.returncode != 0:
        return None, "faust: " + (r.stderr.strip().splitlines() or ["?"])[-1]
    r = subprocess.run(cxx_cmd, capture_output=True, text=True)
    if r.returncode != 0:
        return None, "c++: " + (r.stderr.strip().splitlines() or ["?"])[0]
    with open(stamp, "w") as f:
        f.write(stamp_text)
    return exe, None


def config_dir(faust_options, cxx_options):
    """Build subdirectory of a non-default compilation, named after its options."""
    slug = re.sub(r"[^A-Za-z0-9.+-]+", "_", f"{faust_options} {cxx_options}".strip())
    return "cfg_" + slug.strip("_")


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


def measure(s, d, sr):
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
    m.update(error_profile(s, d, sr))
    return m


def error_profile(s, d, sr, env_window=0.010, trend_window=0.050, floor=1e-6):
    """The error relative to the local level of the double render, and its trend.

    A pointwise relative error (s - d) / d explodes at every zero crossing of d ;
    the error is divided instead by the RMS of d over env_window around each
    sample, floored at floor x the channel's peak (silences). Meaningful only when
    the single and double renders are in phase (an input without phase drift).

    - rel_max    : the largest relative error, any channel, any sample ;
    - onset_1e-4, onset_1e-3 : the first time (seconds) it exceeds the threshold ;
    - growth_exp : p such that the error grows like t^p, fitted on the relative
                   RMS error of trend_window windows (the first one skipped) ;
    - error_class: exact (no error) ; flat (p < 0.25 : a rounding that does not
                   accumulate, or a fixed gain error) ; random-walk (0.25 <= p < 0.75 :
                   unbiased roundings accumulated by a recurrence, which grow like
                   sqrt(t)) ; linear (0.75 <= p < 1.5 : a bias, a frequency or a rate
                   off, whose phase or amplitude error grows like t) ; fast (p >= 1.5 :
                   an instability, a chaotic system) ; saturated (the windowed error
                   reaches 0.1 : diverged).
    """
    n, ch = d.shape
    err = np.abs(s - d)
    peak = np.abs(d).max(axis=0)
    rel = np.zeros(n)
    w = max(1, int(round(env_window * sr)))
    c2 = np.concatenate([np.zeros((1, ch)), np.cumsum(d * d, axis=0)])
    lo = np.clip(np.arange(n) - w // 2, 0, n)
    hi = np.clip(np.arange(n) + w - w // 2, 0, n)
    env = np.sqrt((c2[hi] - c2[lo]) / np.maximum(hi - lo, 1)[:, None])
    for c in range(ch):
        if peak[c] <= 1e-12:
            continue
        rel = np.maximum(rel, err[:, c] / np.maximum(env[:, c], floor * peak[c]))
    out = {"rel_max": float(rel.max()) if n else 0.0}
    for thr in (1e-4, 1e-3):
        idx = np.flatnonzero(rel > thr)
        out[f"onset_{thr:g}"] = float(idx[0] / sr) if idx.size else None
    tw = max(1, int(round(trend_window * sr)))
    k = n // tw
    if k < 3:
        out.update(growth_exp=None, error_class=None)
        return out
    e2 = (err[: k * tw] ** 2).reshape(k, tw, ch).sum(axis=1)
    d2 = (d[: k * tw] ** 2).reshape(k, tw, ch).sum(axis=1)
    d2 = np.maximum(d2, (floor * peak) ** 2 * tw)
    ew = np.where(peak > 1e-12, np.sqrt(e2 / d2), 0.0).max(axis=1)
    if not ew.any():
        out.update(growth_exp=0.0, error_class="exact")
        return out
    t = (np.arange(k) + 0.5) * tw / sr
    y = np.log(np.maximum(ew[1:], 1e-15))
    x = np.log(t[1:])
    p = float(np.polyfit(x, y, 1)[0])
    out["growth_exp"] = p
    out["error_class"] = ("saturated" if ew.max() >= 0.1 else "flat" if p < 0.25 else
                          "random-walk" if p < 0.75 else "linear" if p < 1.5 else "fast")
    return out


def check_test(spec, cfg, args):
    dsp, name = spec
    res = {"test": name, "file": os.path.relpath(dsp, ROOT), "config": cfg.name, "rates": {}}
    exes = {}
    for precision in ("single", "double"):
        exe, err = build(dsp, name, precision, cfg, args)
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
        m = measure(s, d, sr)
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
    p.add_argument("-j", "--jobs", type=int, default=os.cpu_count(),
                   help="tests built and rendered in parallel (default: number of CPUs)")
    p.add_argument("--rates", default=",".join(map(str, DEFAULT_RATES)),
                   help="comma-separated sample rates (default: %(default)s)")
    p.add_argument("--seconds", type=float, default=1.0,
                   help="duration rendered at each rate (default: %(default)s)")
    p.add_argument("--threshold", type=float, default=1e-3,
                   help="largest level gap accepted without a baseline entry (default: %(default)g)")
    p.add_argument("--baseline", default=os.path.join(ROOT, "tests", "precision-baseline.json"),
                   help="accepted debt (default: tests/precision-baseline.json)")
    p.add_argument("--write-baseline", action="store_true",
                   help="rewrite the baseline from this run (all tests, maintainers only)")
    p.add_argument("--build-dir", default=os.path.join(ROOT, "tests", "build-precision"),
                   help="where the builds are cached; a build is redone when a .lib, its "
                        "test file or the architecture is newer, or when its compiler "
                        "command changed (default: tests/build-precision)")
    p.add_argument("--json", help="write every measurement to this file")
    p.add_argument("--faust", default=os.environ.get("FAUST", "faust"),
                   help="Faust compiler (default: $FAUST, else faust)")
    p.add_argument("--cxx", default=os.environ.get("CXX", "c++"),
                   help="C++ compiler (default: $CXX, else c++)")
    p.add_argument("--faust-options", default="",
                   help='extra Faust options, e.g. --faust-options=-vec or '
                        '--faust-options="-lang ocpp" (default: none)')
    p.add_argument("--cxx-options", default=DEFAULT_CXX_OPTIONS,
                   help='C++ optimization options, e.g. --cxx-options="-O3 -ffast-math" '
                        '(default: %(default)s)')
    p.add_argument("--matrix", metavar="NAMES",
                   help="run the named configurations in turn, comma-separated, or all: "
                        + "; ".join(f"{n} = faust {f or '(no option)'}, c++ {c}"
                                    for n, (f, c) in CONFIGS.items()))
    args = p.parse_args()
    args.rates = [int(r) for r in args.rates.split(",")]
    baseline = {}
    if os.path.exists(args.baseline):
        with open(args.baseline) as f:
            baseline = json.load(f)
    if args.write_baseline and (args.dsp or args.filter):
        p.error("--write-baseline needs a run over all tests")

    custom = args.faust_options or args.cxx_options != DEFAULT_CXX_OPTIONS
    if args.matrix:
        if custom:
            p.error("--matrix and --faust-options/--cxx-options are exclusive")
        names = list(CONFIGS) if args.matrix == "all" else args.matrix.split(",")
        unknown = [n for n in names if n not in CONFIGS]
        if unknown:
            p.error(f"unknown configuration {', '.join(unknown)} (known: {', '.join(CONFIGS)})")
        configs = [(n, *CONFIGS[n]) for n in names]
    elif custom:
        configs = [("custom", args.faust_options, args.cxx_options)]
    else:
        configs = [("default", *CONFIGS["default"])]
    if args.write_baseline and [c[0] for c in configs] != ["default"]:
        p.error("--write-baseline needs the default compilation")
    configs = [Config(n, f, c, args.build_dir if (f, c) == CONFIGS["default"]
                      else os.path.join(args.build_dir, config_dir(f, c)))
               for n, f, c in configs]
    for cfg in configs:
        os.makedirs(cfg.build_dir, exist_ok=True)

    specs = test_specs([os.path.abspath(f) for f in args.dsp] or default_dsp_files())
    if args.filter:
        specs = [s for s in specs if re.search(args.filter, s[1])]
    t0 = time.time()
    results, failures, stale, summary = [], [], [], []
    several = len(configs) > 1
    for cfg in configs:
        if several or cfg.name != "default":
            print(f"[{cfg.name}] {cfg.describe()}", flush=True)
        tag = f"[{cfg.name}] " if several else ""
        failed = 0
        with cf.ThreadPoolExecutor(max_workers=args.jobs) as pool:
            futures = {pool.submit(check_test, s, cfg, args): s for s in specs}
            for fut in cf.as_completed(futures):
                try:
                    res = fut.result()
                except Exception as e:  # report it, keep going
                    dsp, name = futures[fut]
                    res = {"test": name, "file": os.path.relpath(dsp, ROOT), "config": cfg.name,
                           "error": repr(e), "rates": {}}
                res["verdict"], res["reason"] = verdict(res, args, baseline)
                results.append(res)
                if res["verdict"] not in ("ok", "expected"):
                    failures.append(res)
                    failed += 1
                    print(f"[fail] {tag}{res['test']} ({res['file']}): {res['verdict']}, "
                          f"{res['reason']}", flush=True)
                elif res["verdict"] == "ok" and cfg.name == "default":
                    # The baseline is measured with the default compilation:
                    # only that one tells which entries are no longer needed.
                    for what in stale_baseline(res, baseline):
                        stale.append(f"{res['test']}: {what}")
        summary.append(f"{cfg.name}: {failed} failed")
    results.sort(key=lambda r: (r["test"], r["config"]))
    if args.json:
        with open(args.json, "w") as f:
            json.dump({"rates": args.rates, "seconds": args.seconds,
                       "threshold": args.threshold,
                       "configs": {c.name: {"faust_options": c.faust_options,
                                            "cxx_options": c.cxx_options} for c in configs},
                       "results": results}, f, indent=1)
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
    runs = f" x {len(configs)} configurations ({', '.join(summary)})" if several else ""
    print(f"\n[precision] {len(specs)} tests{runs} at {', '.join(str(r) for r in args.rates)} Hz "
          f"in {time.time() - t0:.0f} s: {len(failures)} failed")
    return 1 if failures and not args.write_baseline else 0


if __name__ == "__main__":
    sys.exit(main())
