#!/usr/bin/env python3
"""Measure the filters of filters.lib and vaeffects.lib against their documentation.

For each documented `fi.*` / `ve.*` symbol that has a frequency parameter and
at least one input, the Usage call is valued with the parameter values of its
`#### Test` section (the export's `io.parameterValues`), compiled and measured
with faustprobe's `--freqresp` (a linear, time-invariant check comes with it).

Two checks:

- SR independence: the magnitude response at 44.1 and 96 kHz, on a log grid
  from 20 Hz to 6 kHz, must agree wherever both are above -40 dB. A parameter
  in Hz or seconds must not move with the sample rate; a small deviation near
  the top of the grid is the bilinear transform's frequency warping.
- Claims: the filter type is read from the name and summary (lowpass,
  highpass, bandpass, notch, allpass...). The DC gain, the gain near
  Nyquist, the gain at the nominal frequency and the peak or dip location are
  measured and compared with what the documentation states ("-3dB",
  "unity", "allpass", "center"...).

Usage:
  scripts/check_filter_claims.py [--export DIR] [--faustprobe PATH] [--jobs N]
                                 [--json OUT] [--only fi.lowpass ...] [--write-baseline]
  make check-filter-claims

The export is a split export with measured io (`make doc-index-split`, or
build_faust_doc_index.py --split-output-dir DIR --measure-io); the default is
tests/faust-doc. It needs faustprobe, the offline probe of faust-rs
(crates/cranelift-ffi): --faustprobe, $FAUSTPROBE, or `faustprobe` in PATH.

Each deviation has a key: `sr` (the response moves with the sample rate),
`-3dB`, `allpass`, `unity`, `peak` or `dip`. tests/filter-claims-baseline.json
lists the accepted ones, each with its reason (frequency warping of a
filterbank, a -3 dB point the doc places elsewhere on purpose...). Exit
status: 0, 1 on a deviation the baseline does not accept, 2 when faustprobe
is missing. Entries the run no longer needs are listed for removal.
--write-baseline records the current deviations (all symbols, maintainers
only), keeping the reasons already written. The script only measures: it
never edits a library.
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

REPO = Path(__file__).resolve().parent.parent
BASELINE = REPO / "tests" / "filter-claims-baseline.json"
MODULES = ("filters", "vaeffects")
SRS = (44100, 96000)
GRID = (60, 20.0, 6000.0)          # log grid of the SR-independence check
FLOOR_DB = -40.0                    # below this, the curves are not compared
SR_TOL_DB = 3.0                     # over the whole grid, where warping may add some
LOW_BAND_HZ, LOW_TOL_DB = 1500.0, 0.5   # below it, warping is negligible
CLAIM_SR = 48000

# A parameter whose description or name says it is a frequency
FREQ_DESC = re.compile(r"freq|cutoff|hz\b|corner|center", re.I)
FREQ_NAMES = ("fc", "freq", "freqs", "normFreq", "f0", "fx", "cf", "fb", "f", "fr")
# Test values that cannot be valued in a standalone program
SIGNAL_VALUE = re.compile(r"^_$|\b(os|no|ba\.time|button|checkbox|sig|src|x)\b")
NUMBER = re.compile(r"^-?(\d+\.?\d*|\.\d+)(e-?\d+)?$")


def load_symbols(export: Path) -> list[dict]:
    out = []
    for mod in MODULES:
        out += json.loads((export / "modules" / f"{mod}.json").read_text())["symbols"]
    return out


def freq_params(sym: dict) -> list[str]:
    return [p["name"] for p in sym.get("params", [])
            if FREQ_DESC.search(p.get("description", "")) or p["name"] in FREQ_NAMES]


def usage_call(sym: dict) -> tuple[str, list[str]] | None:
    """The first `name(args)` call of the Usage, and its argument names."""
    m = re.search(r"\b" + re.escape(sym["name"]) + r"\(([^()]*)\)", sym.get("usage") or "")
    if not m:
        return None
    return m.group(0), [a.strip() for a in m.group(1).split(",")]


def nominal_frequency(sym: dict, values: dict[str, str], sr: float) -> tuple[str, float] | None:
    """The parameter that sets the filter's frequency, and that frequency in Hz."""
    names = freq_params(sym)
    for pref in ("normFreq", "fc", "freq", "cf", "f0", "f", "fx", "fr"):
        if pref in names and pref in values:
            try:
                v = float(eval_const(values[pref], sr))
            except ValueError:
                return None
            return pref, (20 * 1000 ** v if pref == "normFreq" else v)
    return None


def eval_const(expr: str, sr: float) -> float:
    """A Test value as a number (it may use ma.SR, ma.PI)."""
    if NUMBER.match(expr.strip()):
        return float(expr)
    safe = expr.replace("ma.SR", f"({sr})").replace("ma.PI", f"({math.pi})").replace("^", "**")
    if not re.fullmatch(r"[\d\s.+\-*/()e]+", safe):
        raise ValueError(expr)
    return float(eval(safe, {"__builtins__": {}}))  # digits and operators only


def build_program(sym: dict) -> tuple[str | None, str]:
    """The .dsp of the valued Usage call, or None and why it is skipped."""
    call = usage_call(sym)
    if call is None:
        return None, "no name(args) call in the Usage"
    text, args = call
    io = sym.get("io") or {}
    values = {**(io.get("assumedValues") or {}), **(io.get("parameterValues") or {})}
    valued = []
    for a in args:
        if a not in values:
            return None, f"no Test value for `{a}`"
        v = str(values[a]).strip()
        if SIGNAL_VALUE.search(v):
            return None, f"`{a}` is valued by a signal ({v})"
        valued.append(v)
    prefix = sym["qualifiedName"].split(".")[0]
    call_text = f"{prefix}.{sym['name']}({', '.join(valued)})"
    return f'import("stdfaust.lib");\nprocess = {call_text};\n', call_text


def probe(faustprobe: str, dsp: Path, sr: int, grid: str, frames: int) -> dict:
    """Run --freqresp; rows of (hz, [mag_db per output]) or an error."""
    cmd = [faustprobe, str(dsp), "-I", str(REPO), "--double", "--sr", str(sr),
           "-n", str(frames), "--freqresp", grid]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        first = (res.stderr.strip() or res.stdout.strip()).split("\n")
        why = " / ".join(line.strip() for line in first[:2])
        return {"error": why}
    rows, ringing = [], "still ringing" in res.stdout
    for line in res.stdout.split("\n"):
        if not line or line.startswith("#") or line.startswith("hz"):
            continue
        cols = [float(c) for c in line.split(",")]
        rows.append((cols[0], cols[1::2]))  # hz, mag_db_out0, phase_out0, mag_db_out1...
    return {"rows": rows, "ringing": ringing}


def probe_settled(faustprobe: str, dsp: Path, sr: int, grid: str) -> dict:
    """probe() with more frames while the response is still ringing."""
    frames = 1 << 17 if sr < 60000 else 1 << 18
    while True:
        r = probe(faustprobe, dsp, sr, grid, frames)
        if "error" in r or not r["ringing"] or frames >= 1 << 22:
            r["frames"] = frames
            return r
        frames <<= 2


def classify(sym: dict) -> set[str]:
    text = f"{sym['name']} {sym.get('summary', '')}".lower()
    kinds = set()
    for kind, pat in (("lowpass", r"lowpass|low-pass|lpf\b|lowpass"), ("highpass", r"highpass|high-pass|hpf\b"),
                      ("bandpass", r"bandpass|band-pass|bpf\b|resonbp|resonator"), ("notch", r"notch|bandstop|band-stop|bsf\b"),
                      ("allpass", r"allpass|all-pass"), ("shelf", r"shelf"), ("peak", r"peak|peq|peaking")):
        if re.search(pat, sym["name"].lower()):
            kinds.add(kind)
    if not kinds:  # the name says nothing: try the first sentence of the summary
        first = text.split(". ")[0]
        for kind, pat in (("lowpass", r"lowpass|low-pass"), ("highpass", r"highpass|high-pass"),
                          ("bandpass", r"bandpass|band-pass"), ("notch", r"notch"), ("allpass", r"allpass|all-pass")):
            if re.search(pat, first):
                kinds.add(kind)
    return kinds


def doc_text(sym: dict) -> str:
    params = " ".join(f"{p['name']}: {p.get('description', '')}" for p in sym.get("params", []))
    return f"{sym.get('summary', '')} {params} {' '.join(map(str, sym.get('notes', [])))}"


def interp(rows, hz: float, out: int) -> float:
    for (f0, m0), (f1, m1) in zip(rows, rows[1:]):
        if f0 <= hz <= f1:
            t = (math.log(hz) - math.log(f0)) / (math.log(f1) - math.log(f0))
            return m0[out] + t * (m1[out] - m0[out])
    return float("nan")


def measure(sym: dict, faustprobe: str, workdir: Path) -> dict:
    res = {"symbol": sym["qualifiedName"], "kinds": sorted(classify(sym)),
           "io": f"{(sym.get('io') or {}).get('inSignals')}->{(sym.get('io') or {}).get('outSignals')}"}
    program, info = build_program(sym)
    if program is None:
        res["skipped"] = info
        return res
    res["call"] = info
    dsp = workdir / (re.sub(r"\W", "_", sym["qualifiedName"]) + ".dsp")
    dsp.write_text(program)

    # 1. SR independence on the log grid
    grid = f"{GRID[0]}:{GRID[1]}:{GRID[2]}"
    curves = {}
    for sr in SRS:
        r = probe_settled(faustprobe, dsp, sr, grid)
        if "error" in r:
            res["skipped"] = r["error"]
            return res
        curves[sr] = r
    a, b = curves[SRS[0]]["rows"], curves[SRS[1]]["rows"]
    nout = len(a[0][1])
    worst, low = (0.0, None, None), (0.0, None, None)
    for (hz, ma_), (_, mb) in zip(a, b):
        for o in range(nout):
            if ma_[o] > FLOOR_DB and mb[o] > FLOOR_DB:
                d = abs(ma_[o] - mb[o])
                if d > worst[0]:
                    worst = (d, hz, o)
                if hz <= LOW_BAND_HZ and d > low[0]:
                    low = (d, hz, o)
    res["sr_maxdiff_db"] = round(worst[0], 3)
    res["sr_maxdiff_at"] = None if worst[1] is None else (round(worst[1], 1), worst[2])
    res["sr_lowband_db"] = round(low[0], 3)
    res["sr_lowband_at"] = None if low[1] is None else (round(low[1], 1), low[2])
    res["sr_flag"] = worst[0] > SR_TOL_DB or low[0] > LOW_TOL_DB
    res["still_ringing"] = any(c["ringing"] for c in curves.values())

    # 2. Claims, at CLAIM_SR: DC, near Nyquist, nominal frequency, extremum
    io = sym.get("io") or {}
    values = {**(io.get("assumedValues") or {}), **(io.get("parameterValues") or {})}
    nom = nominal_frequency(sym, values, CLAIM_SR)
    fine = probe_settled(faustprobe, dsp, CLAIM_SR, f"241:5:{0.49 * CLAIM_SR}")
    if "error" in fine:
        res["claims_error"] = fine["error"]
        return res
    rows = fine["rows"]
    claims = {"dc_db": [round(rows[0][1][o], 3) for o in range(nout)],
              "nyq_db": [round(rows[-1][1][o], 3) for o in range(nout)]}
    if nom:
        claims["nominal"] = {"param": nom[0], "hz": round(nom[1], 3)}
        if 5 < nom[1] < 0.49 * CLAIM_SR:
            exact = probe_settled(faustprobe, dsp, CLAIM_SR, f"1:{nom[1]}:{nom[1]}")
            if "error" not in exact:
                claims["at_nominal_db"] = [round(exact["rows"][0][1][o], 3) for o in range(nout)]
    peaks, dips = [], []
    for o in range(nout):
        mags = [m[o] for _, m in rows]
        i, j = max(range(len(mags)), key=mags.__getitem__), min(range(len(mags)), key=mags.__getitem__)
        peaks.append((round(rows[i][0], 1), round(mags[i], 2)))
        dips.append((round(rows[j][0], 1), round(mags[j], 2)))
    claims["peak"], claims["dip"] = peaks, dips
    claims["ripple_db"] = [round(max(m[o] for _, m in rows) - min(m[o] for _, m in rows), 3) for o in range(nout)]
    res["claims"] = claims
    res["flags"] = claim_flags(sym, res["kinds"], claims)
    return res


def claim_flags(sym: dict, kinds: list[str], c: dict) -> list[tuple[str, str]]:
    """Measured facts that contradict what the documentation states, as (key, message)."""
    flags, doc = [], doc_text(sym).lower()
    out0 = 0
    if "allpass" in kinds and c["ripple_db"][out0] > 0.1:
        flags.append(("allpass", f"allpass but the magnitude varies by {c['ripple_db'][out0]} dB"))
    says_3db = bool(re.search(r"-\s?3\s?db", doc))
    if says_3db and "at_nominal_db" in c:
        ref = c["dc_db"][out0] if "lowpass" in kinds else c["nyq_db"][out0] if "highpass" in kinds else None
        if ref is not None:
            d = c["at_nominal_db"][out0] - ref
            if abs(d + 3.0103) > 0.5:
                flags.append(("-3dB", f"doc says -3 dB, measured {d:+.2f} dB relative to the passband "
                                       "at the nominal frequency"))
    if "lowpass" in kinds and "highpass" not in kinds and abs(c["dc_db"][out0]) > 0.5 \
            and re.search(r"unity|dc gain|unity-gain", doc):
        flags.append(("unity", f"doc mentions unity/DC gain, DC is {c['dc_db'][out0]} dB"))
    if c.get("nominal") and set(kinds) & {"bandpass", "peak", "notch"} and not set(kinds) & {"lowpass", "highpass", "shelf"}:
        f_nom = c["nominal"]["hz"]
        key = "dip" if "notch" in kinds else "peak"
        f_ext = c[key][out0][0]
        if f_nom > 0 and abs(math.log2(f_ext / f_nom)) > 0.1:  # more than ~7 %
            flags.append((key, f"{key} at {f_ext} Hz, nominal {f_nom} Hz"))
    return flags


def deviations(r: dict) -> list[tuple[str, str]]:
    """Every deviation of one measured symbol, as (key, message)."""
    out = []
    if r.get("sr_flag"):
        at, lo = r["sr_maxdiff_at"], r["sr_lowband_at"]
        low = f"{r['sr_lowband_db']} dB at {lo[0]} Hz below {LOW_BAND_HZ:.0f} Hz, " if lo else ""
        out.append(("sr", f"44.1 vs 96 kHz: {low}{r['sr_maxdiff_db']} dB at {at[0]} Hz (out{at[1]})"))
    return out + r.get("flags", [])


def find_faustprobe(given: str | None) -> str | None:
    for cand in (given, os.environ.get("FAUSTPROBE"), shutil.which("faustprobe")):
        if cand and Path(cand).expanduser().is_file():
            return str(Path(cand).expanduser())
    return None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--export", type=Path, default=REPO / "tests" / "faust-doc",
                    help="split export with measured io (default: tests/faust-doc, make doc-index-split)")
    ap.add_argument("--faustprobe", help="faustprobe binary (default: $FAUSTPROBE, then PATH)")
    ap.add_argument("--jobs", type=int, default=os.cpu_count())
    ap.add_argument("--json", type=Path, help="write every measurement to this file")
    ap.add_argument("--only", nargs="*", help="measure these symbols only (fi.lowpass ...)")
    ap.add_argument("--baseline", type=Path, default=BASELINE)
    ap.add_argument("--write-baseline", action="store_true",
                    help="record the current deviations as accepted (all symbols, maintainers only)")
    args = ap.parse_args()
    if args.write_baseline and args.only:
        ap.error("--write-baseline needs a run over all symbols")
    args.faustprobe = find_faustprobe(args.faustprobe)
    if not args.faustprobe:
        print("check_filter_claims: faustprobe not found (--faustprobe, $FAUSTPROBE or PATH); "
              "build it in faust-rs: cargo build --release -p cranelift-ffi --bin faustprobe",
              file=sys.stderr)
        return 2
    if not (args.export / "index.json").is_file():
        print(f"check_filter_claims: no export in {args.export}; run make doc-index-split", file=sys.stderr)
        return 2
    accepted = json.loads(args.baseline.read_text()).get("accepted", {}) if args.baseline.is_file() else {}

    syms = [s for s in load_symbols(args.export)
            if freq_params(s) and ((s.get("io") or {}).get("inSignals") or 0) >= 1]
    if args.only:
        syms = [s for s in syms if s["qualifiedName"] in args.only]
    with tempfile.TemporaryDirectory(prefix="filter-claims-") as tmp, ThreadPoolExecutor(args.jobs) as pool:
        results = list(pool.map(lambda s: measure(s, args.faustprobe, Path(tmp)), syms))

    measured = [r for r in results if "skipped" not in r]
    failures, found = 0, {}
    for r in measured:
        for key, msg in deviations(r):
            found.setdefault(r["symbol"], {})[key] = msg
            reason = accepted.get(r["symbol"], {}).get(key)
            if reason:
                print(f"[accepted] {r['symbol']} {key}: {msg} -- {reason}")
            else:
                failures += 1
                print(f"[fail] {r['symbol']} {key}: {msg}   ({r['call']})")
    for r in results:
        if "skipped" in r:
            print(f"[skipped] {r['symbol']}: {r['skipped'][:120]}")
    stale = [f"{s}: {k}" for s, keys in accepted.items() for k in keys if k not in found.get(s, {})]
    if args.only:  # a partial run cannot tell what is stale
        stale = [line for line in stale if line.split(":")[0] in args.only]
    if args.json:
        args.json.write_text(json.dumps(results, indent=1))
    if args.write_baseline:
        new = {s: {k: accepted.get(s, {}).get(k) or f"TODO: why is this accepted? ({msg})"
                   for k, msg in sorted(keys.items())} for s, keys in sorted(found.items())}
        args.baseline.write_text(json.dumps(
            {"comment": "Accepted deviations of the filters from their documentation, see "
                        "scripts/check_filter_claims.py; each entry gives the reason.",
             "accepted": new}, indent=1) + "\n")
        print(f"[baseline] written to {os.path.relpath(args.baseline, REPO)}")
    elif stale:
        print(f"\nBaseline entries no longer needed (remove them from {os.path.relpath(args.baseline, REPO)}):")
        for line in sorted(stale):
            print("  " + line)
    print(f"\ncheck_filter_claims: {len(results)} candidates, {len(measured)} measured, "
          f"{len(results) - len(measured)} skipped; "
          + ("OK." if not failures or args.write_baseline else f"FAILED ({failures} deviation(s) not in the baseline)."))
    return 1 if failures and not args.write_baseline else 0


if __name__ == "__main__":
    sys.exit(main())
