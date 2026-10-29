#!/usr/bin/env python3
"""Measure the oscillators of oscillators.lib and the antialiased functions of aanl.lib.

An oscillator given `freq` must sound at `freq` with the same waveform at
44.1 kHz as at 192 kHz, and an aliasing-suppressed one must alias less than
the naive waveform it replaces. Nothing else checks it: `make check` runs at
48 kHz against references made by the same code, its tests play at 220 or
440 Hz where aliasing is too low to see, and `make check-precision` compares
float and double at one rate. In October 2026, `os.polyblep_triangle` leaked
through a pole fixed at 0.999 (7 Hz at 44.1 kHz, 31 Hz at 192 kHz): its
triangle at 20 Hz had a peak of 0.91 at 44.1 kHz and 0.41 at 192 kHz, and was
identical to the fixed version at 48 kHz, the only rate of the references.

Oscillators. Every symbol of oscillators.lib whose Usage is a call
`name(args)` without input, with a frequency parameter (`freq`, or `fund`
given `lf_sawpos(freq)`), is valued with the parameters of its `#### Test`
section (the export's `io.parameterValues`; a `reset` is held at 0) and
rendered by faustprobe in double precision at the six rates of
`make check-precision`, for the notes of NOTES. One second is analysed after
SKIP seconds (Hann window). Keys:

- `tune`: the fundamental more than TUNE_CENTS from the note;
- `sr`: for one note, the harmonics up to HARM_MAX_HZ spread over more than
  SR_DB across the rates, or the mean moves by more than DC_SPREAD of the
  peak: something is counted in samples where it should be in seconds. The
  harmonics compared stand within HARM_FLOOR_DB of the fundamental and 10 dB
  above the aliasing of the render (aliases land on the weak harmonics of a
  naive waveform), and the mean is allowed a quarter of note/SR more (a
  naive waveform sampled on another grid: `lf_saw` at 880 Hz has a mean of
  -1/600 at 48 kHz, where its period is 600/11 samples);
- `alias`: a symbol whose summary says it suppresses aliasing, at
  ALIAS_NOTE (not a divisor of any rate, so that the aliases fall between the
  harmonics), at 44.1 kHz, does not put ALIAS_GAIN_DB more energy in its
  harmonics against the rest of the spectrum than the naive `lf_` waveform
  of its family (`lf_saw`, `lf_squarewave`, `lf_triangle`, `lf_pulsetrain`
  with the same duty, `lf_imptrain`);
- `order`: an `N` family (sawN, squareN, ...) whose order N+1 does not alias
  ORDER_GAIN_DB less than order N, N = 1 .. 4;
- `level`: the aliasing at 44.1 or 96 kHz is LEVEL_TOL_DB worse than the
  level recorded in the baseline (`levels`): a change made the suppression
  worse. A level that improved by as much is reported, to be recorded.

Antialiased nonlinearities. Every first- and second-order function of
aanl.lib listed in NONLINEAR is driven by a sine at NL_NOTE, scaled into its
domain and past its knee, and its alias ratio measured the same way at 44.1
and 96 kHz. Keys `alias` (against the naive static function, when NONLINEAR
gives it, by NL_GAIN_DB), `order` (the second order against the first, by
ORDER_GAIN_DB) and `level`.

Both, in single precision: `noise`, the aliasing of a render in `-single` at
44.1, 96 or 192 kHz stands above NOISE_FLOOR_DB and NOISE_DB above the same
render in `-double`, at the lowest note and at ALIAS_NOTE (NL_NOTE): the
computation loses its suppression to rounding, as the differences of large
polynomials of a high-order DPW or the divided differences of a second-order
ADAA do when consecutive inputs come closer at a higher rate; and, for an
oscillator, `tune-single`, the same render more than TUNE_CENTS from the
note (the coefficient of a recursive oscillator rounded to float sets its
frequency). And
`nonfinite`, `silent` (RMS below 1e-7) and `error` (no render).

tests/osc-claims-baseline.json accepts deviations by case and key, each with
its reason (`accepted`), and records the aliasing levels (`levels`, in dB at
44.1 and 96 kHz). Exit status: 0, 1 on a deviation the baseline does not
accept, 2 when faustprobe is missing. Entries the run no longer needs are
listed for removal.

Usage:
  scripts/check_osc_claims.py [--export DIR] [--faustprobe PATH] [--jobs N]
                              [--only os.sawN aa.tanh1 ...] [--table]
                              [--json OUT] [--write-baseline]
  make check-osc-claims [OSC_CLAIMS_ARGS="--only os.sawN"]

The export is a split export with measured io (`make doc-index-split`); the
default is tests/faust-doc. It needs faustprobe, the offline probe of
faust-rs (crates/cranelift-ffi): --faustprobe, $FAUSTPROBE, or `faustprobe`
in PATH. --write-baseline records the current deviations (all cases,
maintainers only), keeping the reasons already written, and the current
aliasing levels: run it after a deliberate change of the suppression, never
to silence a degradation. The script only measures: it never edits a
library.
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
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parent.parent
BASELINE = REPO / "tests" / "osc-claims-baseline.json"
EXPORT = REPO / "tests" / "faust-doc"
SRS = (44100, 48000, 88200, 96000, 176400, 192000)
NOTES = (55.0, 220.0, 880.0, 3520.37)
SKIP = 0.25             # seconds before the window: a leaky integrator settles
WINDOW = 1.0            # seconds analysed
TUNE_CENTS = 1.0
HARM_MAX_HZ = 4000.0    # harmonics compared over the rates
HARM_FLOOR_DB = -40.0   # relative to the fundamental
SR_DB = 0.5
DC_SPREAD = 2e-3        # of the peak
SILENT_RMS = 1e-7
ALIAS_NOTE = 3520.37
ALIAS_SRS = (44100, 96000)
ALIAS_GAIN_DB = 6.0
ORDER_GAIN_DB = 1.0
ORDERS = (1, 2, 3, 4)
LEVEL_TOL_DB = 1.0
NL_NOTE = 2637.13
NL_GAIN_DB = 3.0
NOISE_SRS = (44100, 96000, 192000)
NOISE_FLOOR_DB = -80.0
NOISE_DB = 6.0
BAND = 2 ** (6 / 12)    # the fundamental is searched within six semitones

FREQ_ARGS = ("freq", "fund")
SIGNAL_VALUE = re.compile(r"\b(os|no|ba|button|checkbox|hslider|vslider|nentry|sig)\b")
SUPPRESSED = re.compile(r"alias", re.I)
NAIVE = {"saw": "os.lf_saw(@F)", "square": "os.lf_squarewave(@F)", "triangle": "os.lf_triangle(@F)",
         "pulse": "os.lf_pulsetrain(@F, @D)", "imptrain": "os.lf_imptrain(@F)"}

# aanl.lib: name -> (input, the naive static function of x or None). The
# input is a sine S at NL_NOTE, driven past the knee within the domain.
S = "os.tosc(@F)"
NONLINEAR = {
    "hardclip": (f"4*{S}", "max(-1, min(1, x))"), "hardclip2": (f"4*{S}", "max(-1, min(1, x))"),
    "cubic1": (f"4*{S}", None),
    "parabolic": (f"4*{S}", None), "parabolic2": (f"4*{S}", None),
    "hyperbolic": (f"4*{S}", "x/(1 + abs(x))"), "hyperbolic2": (f"4*{S}", "x/(1 + abs(x))"),
    "sinarctan": (f"4*{S}", "x/sqrt(1 + x*x)"), "sinarctan2": (f"4*{S}", "x/sqrt(1 + x*x)"),
    "sinarctanStable": (f"5*{S}", "x/sqrt(1 + x*x)"),
    "sinarctanTransparent": (f"5*{S}", None),
    "softclipQuadratic1": (f"4*{S}", None), "softclipQuadratic2": (f"4*{S}", None),
    "tanh1": (f"4*{S}", "ma.tanh(x)"),
    "arctan": (f"4*{S}", "atan(x)"), "arctan2": (f"4*{S}", "atan(x)"),
    "asinh1": (f"4*{S}", "ma.asinh(x)"), "asinh2": (f"4*{S}", "ma.asinh(x)"),
    "triangleFold1": (f"4*{S}", None), "triangleFold2": (f"4*{S}", None),
    "sineFold1": (f"4*{S}", None), "sineFold2": (f"4*{S}", None),
    # sin(4 S) has harmonics up to about 5 f0 and hardly aliases: driven further
    "cosine1": (f"8*{S}", "cos(x)"), "cosine2": (f"8*{S}", "cos(x)"),
    "sine": (f"8*{S}", "sin(x)"), "sine2": (f"8*{S}", "sin(x)"),
    "arccos": (f"0.99*{S}", "acos(x)"), "arccos2": (f"0.99*{S}", "acos(x)"),
    "arcsin": (f"0.99*{S}", "asin(x)"), "arcsin2": (f"0.99*{S}", "asin(x)"),
    "acosh1": (f"3 + 2*{S}", "ma.acosh(x)"), "acosh2": (f"3 + 2*{S}", "ma.acosh(x)"),
    "tangent": (f"0.45*ma.PI*{S}", "tan(x)"),
    "atanh1": (f"0.95*{S}", "ma.atanh(x)"), "atanh2": (f"0.95*{S}", "ma.atanh(x)"),
}


def first_order_of(name: str) -> str | None:
    """The first-order sibling of a second-order aanl function (`arctan` for `arctan2`)."""
    if not name.endswith("2"):
        return None
    base = name[:-1]
    for cand in (base, base + "1"):
        if cand in NONLINEAR:
            return cand
    return None


def usage_call(sym: dict) -> tuple[str, list[str]] | None:
    m = re.search(r"(?<![.\w])" + re.escape(sym["name"]) + r"\(([^()]*)\)", sym.get("usage") or "")
    if not m:
        return None
    return m.group(0), [a.strip() for a in m.group(1).split(",")]


def family(name: str) -> str | None:
    n = name.lower()
    for fam, pat in (("imptrain", "imptrain"), ("pulse", "pulsetrain"), ("square", "square"),
                     ("triangle", "triangle"), ("saw", "saw")):
        if pat in n:
            return fam
    return None


def load(export: Path, module: str) -> list[dict]:
    return json.loads((export / "modules" / f"{module}.json").read_text())["symbols"]


def osc_cases(export: Path) -> tuple[list[dict], list[tuple[str, str]]]:
    """The oscillator cases, and the symbols skipped with the reason."""
    cases, skipped = [], []
    for sym in load(export, "oscillators"):
        name, io = sym["qualifiedName"], sym.get("io") or {}
        call = usage_call(sym)
        if call is None:
            skipped.append((name, "no name(args) call in the Usage"))
            continue
        if io.get("inSignals") != 0:
            skipped.append((name, f"{io.get('inSignals')} input(s)"))
            continue
        args = call[1]
        if not any(a in FREQ_ARGS for a in args):
            skipped.append((name, "no frequency parameter"))
            continue
        values = {**(io.get("assumedValues") or {}), **(io.get("parameterValues") or {})}
        valued, why = [], None
        for a in args:
            if a == "freq":
                valued.append("@F")
            elif a == "fund":
                valued.append("os.lf_sawpos(@F)")
            elif a == "N":
                valued.append("@N")
            elif a == "reset":
                valued.append("0")
            elif a not in values:
                why = f"no Test value for `{a}`"
            elif SIGNAL_VALUE.search(str(values[a])):
                why = f"`{a}` is valued by a signal ({values[a]})"
            else:
                valued.append(str(values[a]).strip())
        if why:
            skipped.append((name, why))
            continue
        fam = family(sym["name"])
        claims = bool(SUPPRESSED.search(sym.get("summary") or "")) and not sym["name"].startswith("lf_")
        cases.append({"case": name, "kind": "osc",
                      "expr": f"os.{sym['name']}({', '.join(valued)})",
                      "N": str(values.get("N", "3")).strip() if "N" in args else None,
                      "naive": NAIVE[fam].replace("@D", str(values.get("duty", "0.5")))
                      if claims and fam else None})
    return cases, skipped


def nl_cases(export: Path) -> tuple[list[dict], list[tuple[str, str]]]:
    cases, skipped = [], []
    syms = {s["name"]: s for s in load(export, "aanl")}
    for name, (drive, naive) in NONLINEAR.items():
        sym = syms.get(name)
        call = usage_call(sym) if sym else None
        if call is None:
            skipped.append((f"aa.{name}", "not in the export, or no name(args) call in its Usage"))
            continue
        io = sym.get("io") or {}
        values = io.get("parameterValues") or {}
        valued = [f"({drive})" if a == "x" else str(values.get(a, "")).strip() for a in call[1]]
        if "" in valued:
            skipped.append((f"aa.{name}", "a parameter without Test value"))
            continue
        cases.append({"case": f"aa.{name}", "kind": "nl", "expr": f"aa.{name}({', '.join(valued)})",
                      "naive": f"({drive}) : \\(x).({naive})" if naive else None,
                      "first": f"aa.{first_order_of(name)}" if first_order_of(name) else None})
    return cases, skipped


def run(faustprobe: str, args: list[str], cwd: Path, precision: str = "double") -> subprocess.CompletedProcess:
    # faustprobe also imports from its current directory, ahead of -I: run it
    # where no library lies, so that the libraries measured are those of REPO
    return subprocess.run([faustprobe, f"--{precision}", "-I", str(REPO), *args],
                          capture_output=True, text=True, timeout=600, cwd=cwd)


def render(faustprobe: str, expr: str, sr: int, tmp: Path, precision: str = "double") -> np.ndarray:
    """Output 0 of `expr`, the WINDOW seconds after SKIP."""
    stub = tmp / "stub.dsp"
    if not stub.is_file():
        stub.write_text('import("stdfaust.lib");\nprocess = 0;\n')
    out = tmp / f"{uuid.uuid4().hex}.npy"
    skip, frames = int(round(SKIP * sr)), int(round(WINDOW * sr))
    r = run(faustprobe, ["--eval", expr, "--sr", str(sr), "-n", str(skip + frames), "--skip", str(skip),
                         "--in", "zero", "--quiet", "--out", str(out), str(stub)], tmp, precision)
    if not out.is_file():
        raise RuntimeError((r.stderr.strip() or r.stdout.strip())[:400])
    y = np.load(out)[:, 0].astype(np.float64)
    out.unlink()
    return y


def fundamental(mag: np.ndarray, hz: np.ndarray, note: float) -> float | None:
    band = np.flatnonzero((hz > note / BAND) & (hz < note * BAND))
    k = band[np.argmax(mag[band])]
    if k in (band[0], band[-1]):
        return None
    a, b, c = np.log(mag[k - 1:k + 2] + 1e-300)
    return hz[k] + 0.5 * (a - c) / (a - 2 * b + c) * (hz[1] - hz[0])


def blackman_harris(n: int) -> np.ndarray:
    """4-term Blackman-Harris window: sidelobes at -92 dB, main lobe 4 bins wide each side."""
    t = 2 * np.pi * np.arange(n) / (n - 1)
    return 0.35875 - 0.48829 * np.cos(t) + 0.14128 * np.cos(2 * t) - 0.01168 * np.cos(3 * t)


def alias_db(y: np.ndarray, sr: int, f0: float) -> float:
    """Energy outside the harmonics of f0 against the energy in them (dB), above 20 Hz.

    A Hann window would leak -55 dB of a pure sine past the mask, more than the
    best antialiased functions alias: Blackman-Harris, masked 8 bins each side."""
    x = y - y.mean()
    n = len(x)
    p = np.abs(np.fft.rfft(x * blackman_harris(n))) ** 2
    hz = np.fft.rfftfreq(n, 1 / sr)
    harm = np.zeros(len(p), bool)
    for k in range(1, int(sr / 2 / f0) + 1):
        harm |= np.abs(hz - k * f0) < 8 * sr / n
    above = hz > 20
    inside = p[above & harm].sum()
    return 10 * math.log10(max(p[above & ~harm].sum(), 1e-300) / max(inside, 1e-300))


def analyse(y: np.ndarray, sr: int, note: float, exact: bool = False) -> dict | str:
    """Peak, mean, pitch, harmonics and aliasing of a render. The harmonics are those of the
    fundamental measured, or of `note` when `exact` (a nonlinearity may have no fundamental:
    cos(8 sin) has only even harmonics)."""
    if not np.all(np.isfinite(y)):
        return "nonfinite"
    if np.sqrt(np.mean(y ** 2)) < SILENT_RMS:
        return "silent"
    periods = int(len(y) * note / sr)
    whole = int(round(periods * sr / note)) if periods else len(y)
    res = {"peak": float(np.abs(y).max()), "mean": float(y[:whole].mean())}
    x = (y - y.mean()) * np.hanning(len(y))
    pad = 4 * len(y)
    mag = np.abs(np.fft.rfft(x, pad))
    hz = np.arange(len(mag)) * sr / pad
    f0 = fundamental(mag, hz, note)
    res["cents"] = None if f0 is None else round(1200 * math.log2(f0 / note), 3)
    f = note if exact or f0 is None else f0
    harm = []
    for k in range(1, int(HARM_MAX_HZ / f) + 1):
        near = np.abs(hz - k * f) < 2 * sr / len(y)
        harm.append(round(20 * math.log10(mag[near].max() * 2 / np.hanning(len(y)).sum() + 1e-300), 3))
    res["harm"] = harm
    res["alias"] = round(alias_db(y, sr, f), 2)
    return res


def measure(case: dict, faustprobe: str, tmp: Path) -> dict:
    res = {**case, "renders": {}}
    try:
        if case["kind"] == "osc":
            n = case["N"]
            expr = case["expr"].replace("@N", n) if n else case["expr"]
            for sr in SRS:
                for note in NOTES:
                    res["renders"][f"{sr}/{note:g}"] = analyse(
                        render(faustprobe, expr.replace("@F", repr(note)), sr, tmp), sr, note)
            if case["naive"]:
                res["naive"] = {str(sr): round(alias_db(render(faustprobe, case["naive"].replace("@F", repr(ALIAS_NOTE)),
                                                               sr, tmp), sr, ALIAS_NOTE), 2) for sr in ALIAS_SRS}
            if n:
                res["orders"] = {}
                for order in ORDERS:
                    e = case["expr"].replace("@N", str(order)).replace("@F", repr(ALIAS_NOTE))
                    res["orders"][str(order)] = round(alias_db(render(faustprobe, e, 44100, tmp), 44100, ALIAS_NOTE), 2)
            notes = (NOTES[0], ALIAS_NOTE)
        else:
            for sr in NOISE_SRS:
                res["renders"][f"{sr}/{NL_NOTE:g}"] = analyse(
                    render(faustprobe, case["expr"].replace("@F", repr(NL_NOTE)), sr, tmp), sr, NL_NOTE, True)
            if case["naive"]:
                res["naive"] = {str(sr): round(alias_db(render(faustprobe, case["naive"].replace("@F", repr(NL_NOTE)),
                                                               sr, tmp), sr, NL_NOTE), 2) for sr in ALIAS_SRS}
            notes = (NL_NOTE,)
        expr = case["expr"].replace("@N", case["N"]) if case.get("N") else case["expr"]
        res["single"] = {}
        for sr in NOISE_SRS:
            for note in notes:
                y = render(faustprobe, expr.replace("@F", repr(note)), sr, tmp, "single")
                res["single"][f"{sr}/{note:g}"] = analyse(y, sr, note, case["kind"] == "nl")
    except (RuntimeError, subprocess.TimeoutExpired) as e:
        res["error"] = str(e)[:400]
    return res


def alias_levels(r: dict) -> dict[str, float]:
    """The aliasing of a case at the rates of ALIAS_SRS (dB)."""
    note = ALIAS_NOTE if r["kind"] == "osc" else NL_NOTE
    out = {}
    for sr in ALIAS_SRS:
        a = r["renders"].get(f"{sr}/{note:g}")
        if isinstance(a, dict):
            out[str(sr)] = a["alias"]
    return out


def deviations(r: dict, levels: dict, results: dict) -> list[tuple[str, str]]:
    """Every deviation of one measured case, as (key, message)."""
    if "error" in r:
        return [("error", r["error"])]
    out, rr = [], r["renders"]
    for kind in ("nonfinite", "silent"):
        at = [k for k, v in rr.items() if v == kind]
        if at:
            out.append((kind, f"{len(at)} of {len(rr)} renders, first at {at[0]} (Hz/Hz)"))
    ok = {k: v for k, v in rr.items() if isinstance(v, dict)}
    if r["kind"] == "osc":
        cents = {k: v["cents"] for k, v in ok.items()}
        lost = [k for k, c in cents.items() if c is None]
        worst = max((k for k in cents if cents[k] is not None), key=lambda k: abs(cents[k]), default=None)
        if lost or (worst and abs(cents[worst]) > TUNE_CENTS):
            msg = f"{cents[worst]:+.2f} cents at {worst}" if worst else ""
            if lost:
                msg += f"{'; ' if msg else ''}no peak within 6 semitones at {len(lost)} render(s), first at {lost[0]}"
            out.append(("tune", msg))
        spreads = []
        for note in NOTES:
            row = [ok.get(f"{sr}/{note:g}") for sr in SRS]
            if any(v is None for v in row):
                continue
            ref = max(row[0]["harm"][:1] or [-300])
            floor = ref + max(HARM_FLOOR_DB, max(v["alias"] for v in row) + 10)
            ks = min(len(v["harm"]) for v in row)
            for k in range(ks):
                vals = [v["harm"][k] for v in row]
                if min(vals) > floor:
                    spreads.append((max(vals) - min(vals), f"harmonic {k + 1} of {note:g} Hz",
                                    " ".join(f"{v:.2f}" for v in vals) + " dB"))
            means = [v["mean"] for v in row]
            peak = max(v["peak"] for v in row)
            if max(means) - min(means) > (DC_SPREAD + 0.25 * note / SRS[0]) * peak:
                out.append(("sr", f"the mean at {note:g} Hz moves with the rate: "
                                  + " ".join(f"{m:+.4f}" for m in means) + f" (peak {peak:.3g})"))
        if spreads:
            s, what, vals = max(spreads)
            if s > SR_DB:
                out.append(("sr", f"{what} spreads over {s:.2f} dB from 44.1 to 192 kHz: {vals}"))
        if "orders" in r:
            o = r["orders"]
            for a, b in zip(ORDERS, ORDERS[1:]):
                if o[str(b)] > o[str(a)] - ORDER_GAIN_DB:
                    out.append(("order", f"order {b} aliases at {o[str(b)]:.1f} dB, order {a} at "
                                         f"{o[str(a)]:.1f} dB ({ALIAS_NOTE:g} Hz at 44.1 kHz)"))
                    break
        gain = ALIAS_GAIN_DB
    else:
        first = results.get(r["first"]) if r.get("first") else None
        mine = alias_levels(r).get("44100")
        theirs = alias_levels(first).get("44100") if first and "error" not in first else None
        if mine is not None and theirs is not None and mine > theirs - ORDER_GAIN_DB:
            out.append(("order", f"aliases at {mine:.1f} dB, its first order {r['first']} at {theirs:.1f} dB "
                                 f"({NL_NOTE:g} Hz at 44.1 kHz)"))
        gain = NL_GAIN_DB
    single = r.get("single") or {}
    for key, v in single.items():
        d = rr.get(key)
        if not isinstance(v, dict):
            out.append(("noise", f"{v} in -single at {key} (Hz/Hz)"))
            break
        if isinstance(d, dict) and v["alias"] > max(NOISE_FLOOR_DB, d["alias"] + NOISE_DB):
            sr, note = key.split("/")
            out.append(("noise", f"aliases at {v['alias']:.1f} dB in -single, {d['alias']:.1f} dB in -double "
                                 f"({note} Hz at {int(sr) / 1000:g} kHz)"))
            break
    if r["kind"] == "osc":
        cents = {k: v["cents"] for k, v in single.items() if isinstance(v, dict) and v["cents"] is not None}
        worst = max(cents, key=lambda k: abs(cents[k]), default=None)
        if worst and abs(cents[worst]) > TUNE_CENTS:
            out.append(("tune-single", f"{cents[worst]:+.2f} cents in -single at {worst} (Hz/Hz)"))
    mine = alias_levels(r)
    if r.get("naive") and "44100" in mine and mine["44100"] > r["naive"]["44100"] - gain:
        out.append(("alias", f"aliases at {mine['44100']:.1f} dB, the naive waveform at "
                             f"{r['naive']['44100']:.1f} dB: less than {gain:g} dB better"))
    for sr, v in mine.items():
        old = levels.get(r["case"], {}).get(sr)
        if old is not None and v > old + LEVEL_TOL_DB:
            out.append(("level", f"aliases at {v:.1f} dB at {int(sr) / 1000:g} kHz, {old:.1f} dB recorded"))
    return out


def find_faustprobe(given: str | None) -> str | None:
    for cand in (given, os.environ.get("FAUSTPROBE"), shutil.which("faustprobe")):
        if cand and Path(cand).expanduser().is_file():
            return str(Path(cand).expanduser())
    return None


def table(results: list[dict]) -> None:
    print(f"{'case':26s} {'alias 44.1k':>11s} {'96k':>7s} {'naive':>7s} "
          f"{'worst cents':>11s} {'mean@220':>9s} {'peak@220':>9s}  orders")
    for r in results:
        if "error" in r:
            print(f"{r['case']:26s} error: {r['error'][:80]}")
            continue
        lv = alias_levels(r)
        ok = [v for v in r["renders"].values() if isinstance(v, dict)]
        cents = [abs(v["cents"]) for v in ok if v.get("cents") is not None]
        at = r["renders"].get("48000/220")
        mid = f"{at['mean']:+9.4f} {at['peak']:9.3f}" if isinstance(at, dict) else f"{'':9s} {'':9s}"
        print(f"{r['case']:26s} {lv.get('44100', float('nan')):11.1f} {lv.get('96000', float('nan')):7.1f} "
              f"{(r.get('naive') or {}).get('44100', float('nan')):7.1f} "
              f"{max(cents) if cents else float('nan'):11.3f} {mid}  "
              + " ".join(f"{k}:{v:.1f}" for k, v in (r.get("orders") or {}).items()))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--export", type=Path, default=EXPORT, help="split export with measured io")
    ap.add_argument("--faustprobe", help="faustprobe binary (default: $FAUSTPROBE, then PATH)")
    ap.add_argument("--jobs", type=int, default=os.cpu_count())
    ap.add_argument("--json", type=Path, help="write every measurement to this file")
    ap.add_argument("--only", nargs="*", help="measure these cases only (os.sawN aa.tanh1 ...)")
    ap.add_argument("--table", action="store_true", help="print the measurements of every case")
    ap.add_argument("--baseline", type=Path, default=BASELINE)
    ap.add_argument("--write-baseline", action="store_true",
                    help="record the current deviations as accepted and the current aliasing levels "
                         "(all cases, maintainers only)")
    args = ap.parse_args()
    if args.write_baseline and args.only:
        ap.error("--write-baseline needs a run over all cases")
    args.faustprobe = find_faustprobe(args.faustprobe)
    if not args.faustprobe:
        print("check_osc_claims: faustprobe not found (--faustprobe, $FAUSTPROBE or PATH); "
              "build it in faust-rs: cargo build --release -p cranelift-ffi --bin faustprobe",
              file=sys.stderr)
        return 2
    if not (args.export / "modules" / "oscillators.json").is_file():
        print(f"check_osc_claims: no export in {args.export} (make doc-index-split)", file=sys.stderr)
        return 2
    base = json.loads(args.baseline.read_text()) if args.baseline.is_file() else {}
    accepted, levels = base.get("accepted", {}), base.get("levels", {})

    oc, osk = osc_cases(args.export)
    nc, nsk = nl_cases(args.export)
    todo, skipped = oc + nc, osk + nsk
    if args.only:
        unknown = set(args.only) - {c["case"] for c in todo}
        if unknown:
            ap.error(f"unknown case(s): {' '.join(sorted(unknown))}")
        # a second order is judged against its first: measure both
        want = set(args.only) | {c["first"] for c in nc if c["case"] in args.only and c.get("first")}
        todo = [c for c in todo if c["case"] in want]
        skipped = []
    with tempfile.TemporaryDirectory(prefix="osc-claims-") as tmp, ThreadPoolExecutor(args.jobs) as pool:
        results = list(pool.map(lambda c: measure(c, args.faustprobe, Path(tmp)), todo))
    by_case = {r["case"]: r for r in results}
    if args.table:
        table(results)
        print()

    failures, found, improved = 0, {}, []
    for r in results:
        if args.only and r["case"] not in args.only:
            continue
        for key, msg in deviations(r, levels, by_case):
            found.setdefault(r["case"], {})[key] = msg
            reason = accepted.get(r["case"], {}).get(key)
            if reason:
                print(f"[accepted] {r['case']} {key}: {msg} -- {reason}")
            else:
                failures += 1
                print(f"[fail] {r['case']} {key}: {msg}")
        for sr, v in alias_levels(r).items():
            old = levels.get(r["case"], {}).get(sr)
            if old is None:
                improved.append(f"{r['case']}: no level recorded at {int(sr) / 1000:g} kHz ({v:.1f} dB)")
            elif v < old - LEVEL_TOL_DB:
                improved.append(f"{r['case']}: {v:.1f} dB at {int(sr) / 1000:g} kHz, {old:.1f} dB recorded")
    for name, why in skipped:
        print(f"[skipped] {name}: {why}")
    stale = [f"{c}: {k}" for c, keys in accepted.items() for k in keys if k not in found.get(c, {})]
    if args.only:  # a partial run cannot tell what is stale
        stale = [line for line in stale if line.split(":")[0] in args.only]
    if args.json:
        args.json.write_text(json.dumps(results, indent=1))
    if args.write_baseline:
        new = {c: {k: accepted.get(c, {}).get(k) or f"TODO: why is this accepted? ({msg})"
                   for k, msg in sorted(keys.items())} for c, keys in sorted(found.items())}
        lv = {r["case"]: alias_levels(r) for r in results if alias_levels(r)}
        args.baseline.write_text(json.dumps(
            {"comment": "Accepted deviations of the oscillators of oscillators.lib and the antialiased "
                        "functions of aanl.lib, see scripts/check_osc_claims.py; each entry gives the "
                        "reason. `levels`: the aliasing measured, in dB at 44.1 and 96 kHz.",
             "accepted": new, "levels": dict(sorted(lv.items()))}, indent=1) + "\n")
        print(f"[baseline] written to {os.path.relpath(args.baseline, REPO)}")
    else:
        if stale:
            print(f"\nBaseline entries no longer needed (remove them from {os.path.relpath(args.baseline, REPO)}):")
            for line in sorted(stale):
                print("  " + line)
        if improved:
            print(f"\nAliasing levels to record (--write-baseline, after checking the change is deliberate):")
            for line in sorted(improved):
                print("  " + line)
    renders = sum(len(r["renders"]) for r in results)
    print(f"\ncheck_osc_claims: {len(results)} cases ({len(skipped)} symbols skipped), {renders} renders; "
          + ("OK." if not failures or args.write_baseline else f"FAILED ({failures} deviation(s) not in the baseline)."))
    return 1 if failures and not args.write_baseline else 0


if __name__ == "__main__":
    sys.exit(main())
