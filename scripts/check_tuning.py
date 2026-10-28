#!/usr/bin/env python3
"""Measure the pitch of the pitched instruments of physmodels.lib at every sample rate.

A model given `f2l(freq)` and a MIDI instrument given its `freq` slider must
sound at `freq`, at 44.1 kHz as at 192 kHz. Nothing else checks it: `make
check` runs at 48 kHz against references made by the same code, and
`make check-precision` compares float and double at one rate. Issue #323 (2026):
seven models corrected their loop delay, a number of samples, by a length in
meters, and played up to 196 cents sharp at 192 kHz.

The cases are the models listed in MODELS (an impulse, or a constant pressure
or bow, as excitation) and every `*_ui_MIDI` of physmodels.lib, found in the
library (its `freq` slider set, its `gate` button pressed, its vibrato gain
at 0: a deep vibrato puts the spectral peak on a sideband). Each one is
rendered by faustprobe in double precision at the six rates of
`make check-precision`, for the notes of NOTES within the slider's range, and
its fundamental is read from the spectrum of one second of output (Hann
window, zero-padded 8 times, peak within six semitones of the note,
interpolated on the log magnitude). Keys:

- `sr`: for one note, the pitches at the six rates spread over more than
  SR_CENTS: something in the instrument is counted in samples where it should
  be in seconds (or the reverse);
- `tune`: a pitch more than TUNE_CENTS from the note, or no peak within six
  semitones of it;
- `silent`, `nonfinite`: the window is silent (RMS below 1e-7) or not finite.

tests/tuning-baseline.json accepts deviations by case and key, each with its
reason. Exit status: 0, 1 on a deviation the baseline does not accept, 2 when
faustprobe is missing. Entries the run no longer needs are listed for removal.

Usage:
  scripts/check_tuning.py [--faustprobe PATH] [--jobs N] [--only pm.ks ...]
                          [--json OUT] [--write-baseline]
  make check-tuning [TUNING_ARGS="--only pm.ks pm.violin_ui_MIDI"]

It needs faustprobe, the offline probe of faust-rs (crates/cranelift-ffi):
--faustprobe, $FAUSTPROBE, or `faustprobe` in PATH. The script only measures:
it never edits a library.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parent.parent
BASELINE = REPO / "tests" / "tuning-baseline.json"
SRS = (44100, 48000, 88200, 96000, 176400, 192000)
NOTES = (110.0, 220.0, 440.0, 880.0)
WINDOW = 1.0            # seconds analysed, after the case's skip
TUNE_CENTS = 1.0        # largest error accepted at any rate
SR_CENTS = 1.0          # largest spread of one note over the rates (a bowed string below its
                        # range, violin_ui_MIDI at 110 Hz, moves by 0.8 cent with the rate)
SILENT_RMS = 1e-7
BAND = 2 ** (6 / 12)    # the fundamental is searched within six semitones

# Models: (expression of freq, seconds skipped before the window). An impulse
# plucks the strings; the blown and bowed models get a constant excitation.
PLUCK = "(1 : pm.impulseExcitation)"
MODELS = {
    "pm.ks": (f"{PLUCK} : pm.ks(L, 0.5)", 0.05),
    "pm.idealString": (f"pm.endChain(pm.idealString(L, 0.2, {PLUCK}))", 0.05),
    "pm.elecGuitarModel": (f"pm.elecGuitarModel(L, 0.5, 1, {PLUCK})", 0.05),
    "pm.guitarModel": (f"pm.guitarModel(L, 0.5, {PLUCK})", 0.05),
    "pm.nylonGuitarModel": (f"pm.nylonGuitarModel(L, 0.5, {PLUCK})", 0.05),
    "pm.modularInterpStringModel": (f"pm.modularInterpStringModel(L, 0.5, 0.5, 0.5, 0, {PLUCK})", 0.05),
    "pm.marimbaResTube": (f"pm.marimbaResTube(L, {PLUCK})", 0.05),
    "pm.violinModel": ("pm.violinModel(L, 0.5, 0.6, 0.7)", 0.5),
    "pm.clarinetModel": ("pm.clarinetModel(L, 0.8, 0.5, 0.5)", 0.5),
    "pm.fluteModel": ("pm.fluteModel(L, 0.5, 0.8)", 0.5),
    "pm.brassModel": ("pm.brassModel(L, 0.5, 0.5, 0.8)", 0.5),
}
MIDI_SKIP = 0.5         # seconds of attack skipped for a MIDI instrument,
MIDI_SKIP_OF = {"marimba_ui_MIDI": 0.01}  # except a struck one, silent after 0.5 s


def midi_instruments() -> list[str]:
    text = (REPO / "physmodels.lib").read_text(errors="replace")
    return sorted(set(re.findall(r"^(\w+_ui_MIDI)\s*=", text, re.M)))


def cases() -> list[dict]:
    out = []
    for name, (expr, skip) in MODELS.items():
        out.append({"case": name, "skip": skip,
                    "source": 'freq = hslider("freq", 440, 20, 4000, 0.01);\n'
                              f"L = pm.f2l(freq);\nprocess = {expr};\n"})
    for name in midi_instruments():
        out.append({"case": f"pm.{name}", "skip": MIDI_SKIP_OF.get(name, MIDI_SKIP),
                    "source": f"process = pm.{name};\n"})
    return out


def run(faustprobe: str, args: list[str], cwd: Path) -> subprocess.CompletedProcess:
    # faustprobe also imports from its current directory, ahead of -I: run it
    # where no library lies, so that the libraries measured are those of REPO
    return subprocess.run([faustprobe, "--double", "-I", str(REPO), *args],
                          capture_output=True, text=True, timeout=600, cwd=cwd)


def controls(faustprobe: str, dsp: Path) -> dict:
    """The freq slider (path, min, max), the gate button and the vibrato gain sliders of a program."""
    r = run(faustprobe, ["--list-params", str(dsp)], dsp.parent)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.strip())
    found = {"vibrato": []}
    for line in r.stdout.splitlines()[1:]:
        f = line.split()
        if len(f) < 6:
            continue
        leaf = f[0].rsplit("/", 1)[-1]
        if leaf == "freq" and f[1] == "slider":
            found["freq"] = (f[0], float(f[3]), float(f[4]))
        elif leaf == "gate" and f[1] == "button":
            found["gate"] = f[0]
        elif re.fullmatch(r"vibrato_?gain", leaf, re.I) and f[1] == "slider":
            found["vibrato"].append((f[0], float(f[3])))
    return found


def fundamental(y: np.ndarray, sr: int, note: float) -> float | None:
    """The spectral peak within six semitones of the note, or None when it lies on the band's edge."""
    x = y - y.mean()
    n = 8 * len(x)
    mag = np.abs(np.fft.rfft(x * np.hanning(len(x)), n))
    hz = np.arange(len(mag)) * sr / n
    band = np.flatnonzero((hz > note / BAND) & (hz < note * BAND))
    k = band[np.argmax(mag[band])]
    if k in (band[0], band[-1]):
        return None
    a, b, c = np.log(mag[k - 1:k + 2] + 1e-300)
    return (k + 0.5 * (a - c) / (a - 2 * b + c)) * sr / n


def measure(case: dict, faustprobe: str, tmp: Path) -> dict:
    stem = re.sub(r"\W", "_", case["case"])
    dsp = tmp / f"{stem}.dsp"
    dsp.write_text('import("stdfaust.lib");\n' + case["source"])
    res = {"case": case["case"], "source": case["source"], "skip": case["skip"], "pitch": {}}
    try:
        ctl = controls(faustprobe, dsp)
    except RuntimeError as e:
        res["error"] = str(e)[:400]
        return res
    if "freq" not in ctl:
        res["error"] = "no freq slider"
        return res
    path, lo, hi = ctl["freq"]
    res["notes"] = [f for f in NOTES if lo <= f <= hi]
    sets = ["--set", f"{ctl['gate']}=1"] if "gate" in ctl else []
    for vib, vmin in ctl["vibrato"]:
        sets += ["--set", f"{vib}={vmin:g}"]
    if not res["notes"]:
        res["skipped"] = f"no note of {', '.join(f'{f:g}' for f in NOTES)} Hz within freq's range [{lo:g}, {hi:g}]"
        return res
    for sr in SRS:
        frames = int(round((case["skip"] + WINDOW) * sr))
        for note in res["notes"]:
            out = tmp / f"{stem}_{sr}_{note:g}.npy"
            r = run(faustprobe, ["--sr", str(sr), "-n", str(frames), "--in", "zero", "--quiet",
                                 "--set", f"{path}={note}", *sets, "--out", str(out), str(dsp)], tmp)
            key = f"{sr}/{note:g}"
            if not out.is_file():
                res["error"] = r.stderr.strip()[:400]
                return res
            y = np.load(out)[:, 0][int(round(case["skip"] * sr)):]
            out.unlink()
            if not np.all(np.isfinite(y)):
                res["pitch"][key] = "nonfinite"
            elif np.sqrt(np.mean(y ** 2)) < SILENT_RMS:
                res["pitch"][key] = "silent"
            else:
                f0 = fundamental(y, sr, note)
                res["pitch"][key] = None if f0 is None else round(1200 * math.log2(f0 / note), 3)
    return res


def deviations(r: dict) -> list[tuple[str, str]]:
    """Every deviation of one measured case, as (key, message)."""
    if "error" in r:
        return [("error", r["error"])]
    if "skipped" in r:
        return []
    out, p = [], r["pitch"]
    for kind in ("nonfinite", "silent"):
        at = [k for k, v in p.items() if v == kind]
        if at:
            out.append((kind, f"{len(at)} of {len(p)} renders, first at {at[0]} (Hz/Hz)"))
    lost = [k for k, v in p.items() if v is None]
    cents = {k: v for k, v in p.items() if isinstance(v, float)}
    worst = max(cents, key=lambda k: abs(cents[k]), default=None)
    if lost or (worst and abs(cents[worst]) > TUNE_CENTS):
        msg = f"{cents[worst]:+.2f} cents at {worst}" if worst else ""
        if lost:
            msg += f"{'; ' if msg else ''}no peak within 6 semitones at {len(lost)} render(s), first at {lost[0]}"
        out.append(("tune", msg))
    spread = []
    for note in r["notes"]:
        row = [cents.get(f"{sr}/{note:g}") for sr in SRS]
        if all(v is not None for v in row):
            spread.append((max(row) - min(row), note, row))
    if spread:
        s, note, row = max(spread)
        if s > SR_CENTS:
            out.append(("sr", f"{note:g} Hz spreads over {s:.2f} cents from 44.1 to 192 kHz: "
                              + " ".join(f"{v:+.2f}" for v in row)))
    return out


def find_faustprobe(given: str | None) -> str | None:
    for cand in (given, os.environ.get("FAUSTPROBE"), shutil.which("faustprobe")):
        if cand and Path(cand).expanduser().is_file():
            return str(Path(cand).expanduser())
    return None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--faustprobe", help="faustprobe binary (default: $FAUSTPROBE, then PATH)")
    ap.add_argument("--jobs", type=int, default=os.cpu_count())
    ap.add_argument("--json", type=Path, help="write every measurement to this file")
    ap.add_argument("--only", nargs="*", help="measure these cases only (pm.ks pm.violin_ui_MIDI ...)")
    ap.add_argument("--baseline", type=Path, default=BASELINE)
    ap.add_argument("--write-baseline", action="store_true",
                    help="record the current deviations as accepted (all cases, maintainers only)")
    args = ap.parse_args()
    if args.write_baseline and args.only:
        ap.error("--write-baseline needs a run over all cases")
    args.faustprobe = find_faustprobe(args.faustprobe)
    if not args.faustprobe:
        print("check_tuning: faustprobe not found (--faustprobe, $FAUSTPROBE or PATH); "
              "build it in faust-rs: cargo build --release -p cranelift-ffi --bin faustprobe",
              file=sys.stderr)
        return 2
    accepted = json.loads(args.baseline.read_text()).get("accepted", {}) if args.baseline.is_file() else {}

    todo = cases()
    if args.only:
        unknown = set(args.only) - {c["case"] for c in todo}
        if unknown:
            ap.error(f"unknown case(s): {' '.join(sorted(unknown))}")
        todo = [c for c in todo if c["case"] in args.only]
    with tempfile.TemporaryDirectory(prefix="tuning-") as tmp, ThreadPoolExecutor(args.jobs) as pool:
        results = list(pool.map(lambda c: measure(c, args.faustprobe, Path(tmp)), todo))

    failures, found = 0, {}
    for r in results:
        for key, msg in deviations(r):
            found.setdefault(r["case"], {})[key] = msg
            reason = accepted.get(r["case"], {}).get(key)
            if reason:
                print(f"[accepted] {r['case']} {key}: {msg} -- {reason}")
            else:
                failures += 1
                print(f"[fail] {r['case']} {key}: {msg}")
    for r in results:
        if "skipped" in r:
            print(f"[skipped] {r['case']}: {r['skipped']}")
    stale = [f"{c}: {k}" for c, keys in accepted.items() for k in keys if k not in found.get(c, {})]
    if args.only:  # a partial run cannot tell what is stale
        stale = [line for line in stale if line.split(":")[0] in args.only]
    if args.json:
        args.json.write_text(json.dumps(results, indent=1))
    if args.write_baseline:
        new = {c: {k: accepted.get(c, {}).get(k) or f"TODO: why is this accepted? ({msg})"
                   for k, msg in sorted(keys.items())} for c, keys in sorted(found.items())}
        args.baseline.write_text(json.dumps(
            {"comment": "Accepted pitch deviations of the physmodels.lib instruments, see "
                        "scripts/check_tuning.py; each entry gives the reason.",
             "accepted": new}, indent=1) + "\n")
        print(f"[baseline] written to {os.path.relpath(args.baseline, REPO)}")
    elif stale:
        print(f"\nBaseline entries no longer needed (remove them from {os.path.relpath(args.baseline, REPO)}):")
        for line in sorted(stale):
            print("  " + line)
    renders = sum(len(r["pitch"]) for r in results)
    print(f"\ncheck_tuning: {len(results)} cases, {renders} renders; "
          + ("OK." if not failures or args.write_baseline else f"FAILED ({failures} deviation(s) not in the baseline)."))
    return 1 if failures and not args.write_baseline else 0


if __name__ == "__main__":
    sys.exit(main())
