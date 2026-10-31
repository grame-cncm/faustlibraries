#!/usr/bin/env python3
"""Check that every test sounds the same at 44.1, 96 and 192 kHz.

A parameter in Hz or in seconds must not move with the sample rate. Nothing
general checks it: `make check` runs at 48 kHz only, against references made
by the same code; `make check-precision` renders every rate but compares float
with double at each one; check_filter_claims.py and check_tuning.py measure
the rate independence of the filters and of the pitched instruments only, and
check_osc_claims.py that of the oscillators. In 2026, seven models of
physmodels.lib played up to 196 cents sharp at 192 kHz (issue #323), and
os.polyblep_triangle leaked through a pole fixed at 0.999: both were right at
48 kHz.

Digital white noise is another sequence at each rate: the spectrum of a
noise burst through a resonator, measured on two seconds, moves by 2 to 3 dB
from one rate to another by chance alone. So the tests are built against a
copy of the libraries (tests/build-sr/lib) where `no.noise`, `no.multinoise`
and `no.noises` (and their `r` variants) are sums of TONES sines at fixed
frequencies, a semitone apart from 20 Hz to 19.3 kHz, under Nyquist at every
rate of the check, so that none folds at 44.1 kHz, with the amplitudes of a
white density and the RMS level of `no.noise`, each channel with its own
phases: the same signal at every rate. The other generators of noises.lib
are built on these.

For every test of `tests/*.dsp`, this script renders that build in double
precision (`arch/precision_arch.cpp`, inputs at zero, buttons pressed then
released at the middle), SECONDS seconds at each rate of RATES, and
compares, for each output loud enough (within 40 dB of the loudest, its
bands within 20 dB of its power at every rate: `os.tosc(12000)` lies above
them), what does not depend on the rate in a correct program:

- `spectrum`: the shape of the spectrum, the power in the octave bands of
  BANDS (125 Hz to 4 kHz) against their sum, over the bands within
  SHAPE_FLOOR_DB of their sum: a band moves by more than SHAPE_DB;
- `level`: the power of those bands follows none of three laws within
  LEVEL_DB: unchanged (a signal defined in time), lower by
  10 log10(SR / 44100) (white noise of fixed variance per sample, whose power
  spreads over 0 to SR/2: `ba.sAndH` of a counter, a hash), or lower by
  20 log10(SR / 44100) (impulses of one sample, and what a filter makes of
  them: an impulse train, `1 - 1'` into a filter);
- `onset`, `decay`: the envelope (RMS in FRAME seconds) first reaches
  -20 dB of its maximum, or stays for good below -20 and -40 dB of it, at
  times that differ by more than max(2 FRAME, 10 %) (a stationary output
  never stays below: it is not judged).

A test whose output is silent, not finite or does not build at one rate is
skipped (check_precision.py and check_weak.py report those). A `_jump_test`
is measured but not judged: the transient a jump leaves in the state of a
recursive filter depends on the rate, in a TPT form too (fi.highpass(4) and
fi.SVFTPT at 20 Hz and at 5 kHz, and a switch between their two outputs,
do not move; a jump of their cutoff between the two does). A function whose
parameter is a number of samples or a coefficient depends on the rate by
definition (`ba.pulse(p)`, `ba.slidingSum(n)`, `fi.pole(p)`): such symbols
are listed in `tests/sr-baseline.json` (`symbols`), each with the parameter
that binds it, and their tests (the export's `testCode`) are measured but not
judged (--list-bound lists them). Any other test built to depend on the rate
(a reset every 32 samples, a ratio of the rate) is accepted there by test and
key (`accepted`), with the reason. An entry that no longer fails, or a symbol
none of whose tests moves, is reported, to be removed. --write-baseline
proposes, for a test that moves, the symbol whose Usage parameter matches
IN_SAMPLES: proposals to check against the doc, not reasons.

    scripts/check_sr.py [-k REGEX] [--seconds 2] [--export DIR] [--list-bound] [FILE.dsp ...]
    make check-sr [SR_ARGS="tests/oscillators_tests.dsp"]

The export is the split export of the documentation (`make doc-index-split`,
which the make target runs first; default tests/faust-doc).

The builds (`-double`, against the copied libraries) are kept in
tests/build-sr and redone when a library or the test changes. Exit status:
0, or 1 on a failure.
"""

import argparse
import concurrent.futures as cf
import glob
import json
import math
import os
import re
import shlex
import subprocess
import sys
import time

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_precision as cp  # noqa: E402

BASELINE = os.path.join(cp.ROOT, "tests", "sr-baseline.json")
BUILD_DIR = os.path.join(cp.ROOT, "tests", "build-sr")
EXPORT = os.path.join(cp.ROOT, "tests", "faust-doc")
# A parameter that ties a function to the rate: a number of samples or values, a coefficient,
# a location in the z-plane, an integer delay. A maximum size does not (MAXIMUM).
IN_SAMPLES = re.compile(r"\bin samples\b|\bnumber of (samples|values)\b|\bper sample\b|comb-filter delay|"
                        r"\b(feedback|feedforward|allpass|reflection|numerator|denominator)\s+coefficients?\b|"
                        r"\bcoefficients? of (the |`?z)|\bpole location|location of zero|z-plane", re.I)
MAXIMUM = re.compile(r"^\s*(the\s+)?max(imum)?\b", re.I)
TONES = 120
NOISE_CHANNELS = 33  # the patterns _sr_noise(0) .. _sr_noise(32): noise, then multinoise(N <= 32)
RATES = (44100, 96000, 192000)
SECONDS = 2.0
BANDS = (125, 250, 500, 1000, 2000, 4000)  # octave centres (Hz), edges at c/sqrt(2) and c*sqrt(2)
SHAPE_FLOOR_DB = -30.0
SHAPE_DB = 1.0
LEVEL_DB = 1.0
FRAME = 0.02
CHANNEL_FLOOR_DB = -40.0
OUT_OF_BAND_DB = -20.0  # an output whose bands hold less of its power is not judged
SILENT_RMS = 1e-7


NOISE_ENV = """    noise = random / RANDMAX
    with {
        random = +(seed) ~ *(1103515245); // "linear congruential"
    };    
"""
MULTINOISE = "    multinoise(N) = multirandom(N) : par(i, N, /(RANDMAX)) : par(i, N, float);\n"


def noise_code():
    """Faust definitions of _sr_noise(k): TONES sines a semitone apart from 20 Hz, white density,
    the RMS level of no.noise (1/sqrt(3)), phases drawn per k."""
    f = 20.0 * 2 ** (np.arange(TONES) / 12)
    a = np.sqrt(f) * math.sqrt(2 / (3 * f.sum()))   # sum of a^2/2 = 1/3
    rng = np.random.default_rng(20261029)
    lines = ["// check_sr.py: a noise that is the same signal at every rate",
             "_sr_t = ba.time / ma.SR;"]
    for k in range(NOISE_CHANNELS):
        ph = rng.uniform(0, 2 * np.pi, TONES)
        terms = " + ".join(f"{ai:.9g}*sin({2 * np.pi * fi:.12g}*_sr_t + {pi:.9g})"
                           for fi, ai, pi in zip(f, a, ph))
        lines.append(f"_sr_noise({k}) = {terms};")
    return "\n".join(lines) + "\n"


def noise_libs(lib_dir):
    """Copy the libraries into lib_dir, noises.lib's noise and multinoise replaced by _sr_noise."""
    os.makedirs(lib_dir, exist_ok=True)
    for path in glob.glob(os.path.join(cp.ROOT, "*.lib")):
        with open(path) as f:
            text = f.read()
        if os.path.basename(path) == "noises.lib":
            for old in (NOISE_ENV, MULTINOISE):
                if text.count(old) != 1:
                    sys.exit("check_sr: noises.lib no longer defines noise or multinoise as this script "
                             "expects: update NOISE_ENV and MULTINOISE")
            text = text.replace(NOISE_ENV, "    noise = _sr_noise(0);\n")
            text = text.replace(MULTINOISE, "    multinoise(N) = par(i, N, _sr_noise(i + 1));\n")
            text += "\n" + noise_code()
        out = os.path.join(lib_dir, os.path.basename(path))
        if not os.path.exists(out) or open(out).read() != text:
            with open(out, "w") as f:
                f.write(text)


def build(dsp, name, args):
    """The -double build of a test against the libraries of args.lib_dir (check_precision.build,
    compiled from that directory: faust looks there before the -I ones)."""
    exe = os.path.join(args.build_dir, f"{name}.double")
    cpp = exe + ".cpp"
    faust_cmd = [args.faust, "-double", "-t", "0", "-I", args.lib_dir, "-I", os.path.join(cp.ROOT, "dx7"),
                 "-a", cp.ARCH, "-pn", name, dsp, "-o", cpp]
    cxx_cmd = [args.cxx, *shlex.split(cp.DEFAULT_CXX_OPTIONS), "-std=c++17", cpp, "-o", exe]
    stamp = exe + ".cmd"
    stamp_text = json.dumps([faust_cmd, cxx_cmd, cp.compiler_version(args.faust), cp.compiler_version(args.cxx)])
    # noise_libs rewrites the copy of noises.lib only when the multisine changes
    newest = max(cp.newest_source(dsp), os.path.getmtime(os.path.join(args.lib_dir, "noises.lib")))
    if (os.path.exists(exe) and os.path.getmtime(exe) >= newest
            and os.path.exists(stamp) and open(stamp).read() == stamp_text):
        return exe, None
    r = subprocess.run(faust_cmd, capture_output=True, text=True, cwd=args.lib_dir)
    if r.returncode != 0:
        return None, "faust: " + (r.stderr.strip().splitlines() or ["?"])[-1]
    r = subprocess.run(cxx_cmd, capture_output=True, text=True)
    if r.returncode != 0:
        return None, "c++: " + (r.stderr.strip().splitlines() or ["?"])[0]
    with open(stamp, "w") as f:
        f.write(stamp_text)
    return exe, None


def symbols_of(export):
    """{test name: [qualified names of the symbols whose Test section defines it]}."""
    out = {}
    for path in sorted(glob.glob(os.path.join(export, "modules", "*.json"))):
        with open(path) as f:
            for sym in json.load(f)["symbols"]:
                for t in re.findall(r"^\s*([A-Za-z0-9_]+_test)\s*=", sym.get("testCode") or "", re.M):
                    out.setdefault(t, []).append(sym["qualifiedName"])
    return out


def rate_bound(export):
    """{qualified name: the Usage parameter that seems to tie it to the rate}: proposals."""
    out = {}
    for path in sorted(glob.glob(os.path.join(export, "modules", "*.json"))):
        with open(path) as f:
            symbols = json.load(f)["symbols"]
        for sym in symbols:
            m = re.search(r"(?<![.\w])" + re.escape(sym["name"]) + r"\(([^()]*)\)", sym.get("usage") or "")
            args = {a.strip() for a in m.group(1).split(",")} if m else set()
            why = [f"{sym['qualifiedName']} `{p['name']}`: {p.get('description', '')}"
                   for p in sym.get("params", [])
                   if p["name"] in args and IN_SAMPLES.search(p.get("description", ""))
                   and not MAXIMUM.search(p.get("description", "")) and not p["name"].lower().startswith("max")]
            if why:
                out[sym["qualifiedName"]] = why[0]
    return out


def sum_db(levels, axis=None):
    """10 log10 of the sum of the powers given in dB, without overflow (an output of ma.MAX)."""
    top = np.max(levels, axis=axis, keepdims=True)
    return np.squeeze(top + 10 * np.log10(np.sum(10 ** ((levels - top) / 10), axis=axis, keepdims=True)))


def bands_db(y, sr):
    """Power (dB) of y in each octave band of BANDS, and its total power (dB), from a periodogram
    without window: a window would hide the start of the render, where an impulse response
    lies, and the leakage of the rectangular one is the same function of time at every rate."""
    peak = float(np.abs(y).max()) or 1.0
    x = y / peak  # ma.MAX_test outputs 1.8e308: its mean would overflow
    x = x - x.mean()
    p = np.abs(np.fft.rfft(x)) ** 2 / len(y) ** 2
    hz = np.fft.rfftfreq(len(y), 1 / sr)
    out = []
    for c in BANDS:
        sel = (hz >= c / math.sqrt(2)) & (hz < c * math.sqrt(2))
        out.append(10 * math.log10(p[sel].sum() + 1e-300))
    power = np.mean(x ** 2)
    if power < 1e-20:
        return None, None  # constant: nothing in the bands (ma.SR_test)
    gain = 20 * math.log10(peak)
    return np.array(out) + gain, 10 * math.log10(power) + gain


def envelope_times(y, sr):
    """(onset, last time above -20 dB, last time above -40 dB) of the envelope, in seconds;
    a 'last time' is None when the envelope ends above the threshold."""
    n = max(1, int(round(FRAME * sr)))
    frames = len(y) // n
    peak = np.abs(y).max()
    env = 10 * np.log10(np.mean((y[:frames * n] / peak).reshape(frames, n) ** 2, axis=1) + 1e-300)
    env -= env.max()
    onset = float(np.argmax(env > -20) * FRAME)
    last = []
    for th in (-20, -40):
        above = np.flatnonzero(env > th)
        last.append(None if above[-1] >= frames - 1 else float((above[-1] + 1) * FRAME))
    return onset, last[0], last[1]


def describe(out, sr):
    """Per output: band levels and envelope times; None for an output too quiet to judge."""
    scale = np.maximum(np.abs(out).max(axis=0), 1e-300)
    rms = scale * np.sqrt(np.mean((out / scale) ** 2, axis=0))
    loud = rms.max()
    res = []
    for ch in range(out.shape[1]):
        if rms[ch] < SILENT_RMS or 20 * math.log10(rms[ch] / loud) < CHANNEL_FLOOR_DB:
            res.append(None)
            continue
        y = out[:, ch]
        bands, total = bands_db(y, sr)
        if bands is None or sum_db(bands) < total + OUT_OF_BAND_DB:
            res.append(None)  # the output lies above or below the bands: tosc(12000), a DC
            continue
        res.append({"bands": bands.round(3).tolist(), "times": envelope_times(y, sr)})
    return res


def compare(desc):
    """The deviations of one test, as {key: message}; desc maps a rate to describe()."""
    found = {}
    rates = list(desc)
    for ch in range(len(desc[rates[0]])):
        per = [desc[r][ch] for r in rates]
        if any(d is None for d in per):
            continue
        tag = f" (output {ch})" if len(desc[rates[0]]) > 1 else ""
        b = np.array([d["bands"] for d in per])               # rates x bands
        total = sum_db(b, axis=1)
        shape = b - total[:, None]
        judged = np.all(shape > SHAPE_FLOOR_DB, axis=0)  # against the sum of the bands
        if judged.any():
            spread = shape[:, judged].max(axis=0) - shape[:, judged].min(axis=0)
            k = int(np.argmax(spread))
            if spread[k] > SHAPE_DB and "spectrum" not in found:
                band = [c for c, j in zip(BANDS, judged) if j][k]
                vals = shape[:, judged][:, k]
                found["spectrum"] = (f"the {band} Hz octave moves by {spread[k]:.2f} dB against the others"
                                     f"{tag}: " + " ".join(f"{v:+.2f}" for v in vals) + " dB at "
                                     + ", ".join(f"{r / 1000:g}" for r in rates) + " kHz")
            delta = total - total[0]
            law = -10 * np.log10(np.array(rates) / rates[0])
            if (min(np.abs(delta - m * law).max() for m in (0, 1, 2)) > LEVEL_DB
                    and "level" not in found):
                found["level"] = (f"the level from 88 Hz to 5.7 kHz moves by "
                                  + " ".join(f"{d:+.2f}" for d in delta) + f" dB{tag}, neither unchanged nor "
                                  + " ".join(f"{d:+.2f}" for d in law) + " (white noise) nor "
                                  + " ".join(f"{2 * d:+.2f}" for d in law) + " (impulses)")
        times = [d["times"] for d in per]
        for i, (key, what) in enumerate((("onset", "reaches -20 dB"), ("decay", "stays below -20 dB"),
                                         ("decay", "stays below -40 dB"))):
            vals = [t[i] for t in times]
            if any(v is None for v in vals) or key in found:
                continue
            tol = max(2 * FRAME, 0.1 * max(vals))
            if max(vals) - min(vals) > tol:
                found[key] = (f"the envelope {what} at " + ", ".join(f"{v:.2f}" for v in vals)
                              + f" s{tag} at " + ", ".join(f"{r / 1000:g}" for r in rates) + " kHz")
    return found


def check_test(spec, args):
    dsp, name = spec
    res = {"test": name, "file": os.path.relpath(dsp, cp.ROOT)}
    exe, err = build(dsp, name, args)
    if err:
        res["skip"] = err
        return res
    desc = {}
    for sr in args.rates:
        try:
            out = cp.render(exe, sr, int(round(sr * args.seconds)), exe + f".{sr}.sr.raw")
        except (RuntimeError, subprocess.TimeoutExpired) as e:
            res["skip"] = str(e)
            return res
        if out.shape[1] == 0 or not np.isfinite(out).all():
            res["skip"] = f"no output or not finite at {sr} Hz"
            return res
        if np.abs(out).max() < SILENT_RMS:
            res["skip"] = f"silent at {sr} Hz"
            return res
        desc[sr] = describe(out, sr)
    res["found"] = compare(desc)
    res["desc"] = desc
    return res


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("dsp", nargs="*", help="test files (default: the tracked tests/*.dsp)")
    p.add_argument("-k", "--filter", help="regex on test names")
    p.add_argument("-j", "--jobs", type=int, default=os.cpu_count())
    p.add_argument("--rates", default=",".join(map(str, RATES)),
                   help="comma-separated sample rates, the first one the reference (default: %(default)s)")
    p.add_argument("--seconds", type=float, default=SECONDS,
                   help="duration rendered at each rate (default: %(default)s)")
    p.add_argument("--baseline", default=BASELINE)
    p.add_argument("--export", default=EXPORT, help="split export of the documentation (make doc-index-split)")
    p.add_argument("--list-bound", action="store_true",
                   help="list the tests not judged, tied to the rate by a parameter in samples")
    p.add_argument("--write-baseline", action="store_true",
                   help="record the current failures as accepted (all tests, maintainers only)")
    p.add_argument("--build-dir", default=BUILD_DIR)
    p.add_argument("--json", help="write every measurement to this file")
    p.add_argument("--faust", default=os.environ.get("FAUST", "faust"))
    p.add_argument("--cxx", default=os.environ.get("CXX", "c++"))
    args = p.parse_args()
    args.rates = [int(r) for r in args.rates.split(",")]
    if args.write_baseline and (args.dsp or args.filter):
        p.error("--write-baseline needs a run over all tests")
    baseline = {}
    if os.path.exists(args.baseline):
        with open(args.baseline) as f:
            baseline = json.load(f)
    accepted = baseline.get("accepted", {})
    if not os.path.isdir(os.path.join(args.export, "modules")):
        print(f"check_sr: no export in {args.export} (make doc-index-split)", file=sys.stderr)
        return 2
    owners = symbols_of(args.export)
    bound_symbols = baseline.get("symbols", {})
    args.lib_dir = os.path.join(args.build_dir, "lib")
    noise_libs(args.lib_dir)

    specs = cp.test_specs([os.path.abspath(f) for f in args.dsp] or cp.default_dsp_files())
    if args.filter:
        specs = [s for s in specs if re.search(args.filter, s[1])]
    t0 = time.time()
    results, failures, stale = [], [], []
    with cf.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        for res in pool.map(lambda s: check_test(s, args), specs):
            results.append(res)
            name = res["test"]
            ok_here = accepted.get(name, {})
            found = res.get("found", {})
            res["symbols"] = owners.get(name, [])
            if name.endswith("_jump_test"):
                res["jump"] = True
                continue
            mine = [q for q in res["symbols"] if q in bound_symbols]
            if mine:
                res["bound"] = mine[0]
                if args.list_bound:
                    print(f"[bound] {name}: {mine[0]}, {bound_symbols[mine[0]]}"
                          + (f" ({', '.join(sorted(found))} moves)" if found else ""))
                continue
            for key, why in sorted(found.items()):
                if key not in ok_here:
                    failures.append(name)
                    print(f"[fail] {name} ({res['file']}) {key}: {why}", flush=True)
            if "skip" not in res:
                stale += [f"{name}: {k}" for k in ok_here if k not in found]

    if args.json:
        with open(args.json, "w") as f:
            json.dump({"rates": args.rates, "seconds": args.seconds, "results": results}, f, indent=1)
    moving_symbols = {res["bound"] for res in results if res.get("bound") and res.get("found")}
    if args.write_baseline:
        proposals = rate_bound(args.export)
        new, syms = {}, {q: bound_symbols[q] for q in moving_symbols}
        for res in results:
            if "bound" in res or "jump" in res or not res.get("found"):
                continue
            proposed = [q for q in res.get("symbols", []) if q in proposals]
            if proposed:
                syms.setdefault(proposed[0], f"TODO: check against the doc ({proposals[proposed[0]]})")
                continue
            for key, why in res["found"].items():
                old = accepted.get(res["test"], {}).get(key)
                new.setdefault(res["test"], {})[key] = old or f"TODO: why is this accepted? ({why})"
        with open(args.baseline, "w") as f:
            json.dump({"comment": "Rate dependence of the tests at 44.1, 96 and 192 kHz, see "
                                  "scripts/check_sr.py. `symbols`: functions tied to the rate by a parameter "
                                  "in samples or a coefficient, their tests not judged; `accepted`: other "
                                  "tests, by key. Each entry gives the reason.",
                       "symbols": dict(sorted(syms.items())),
                       "accepted": dict(sorted(new.items()))}, f, indent=1)
            f.write("\n")
        print(f"[baseline] written to {os.path.relpath(args.baseline, cp.ROOT)}")
    elif stale or set(bound_symbols) - moving_symbols:
        stale += [f"{q}: none of its tests moves" for q in bound_symbols
                  if q not in moving_symbols and not (args.dsp or args.filter)]
        print(f"\nBaseline entries no longer needed (remove them from "
              f"{os.path.relpath(args.baseline, cp.ROOT)}):")
        for line in sorted(stale):
            print("  " + line)
    skipped = sum(1 for r in results if "skip" in r)
    nbound = sum(1 for r in results if "bound" in r)
    njump = sum(1 for r in results if "jump" in r)
    print(f"\n[sr] {len(specs)} tests at {', '.join(map(str, args.rates))} Hz ({skipped} skipped: no build, "
          f"silent or not finite; not judged: {nbound} with a parameter in samples, --list-bound, "
          f"{njump} _jump tests) in "
          f"{time.time() - t0:.0f} s: {len(set(failures))} failed")
    return 1 if failures and not args.write_baseline else 0


if __name__ == "__main__":
    sys.exit(main())
