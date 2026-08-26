#!/usr/bin/env python3
"""Generate documentation plots for the library families beyond aanl.lib.

Companion to `plot_lib.py` (the aanl.lib prototype, whose probe runner is
reused here). Each figure shows a property that prose cannot: a frequency
response, an envelope shape, a noise slope, a compression characteristic, a
noise-shaping transfer function. And each figure type embeds *property
assertions* — the lowpass must be -3 dB at its cutoff, the compressor slope
must match its ratio — so the script fails instead of publishing a figure
that contradicts the function's name.

Figures land in doc/docs/img/<prefix>_<name>.svg, where
doc/scripts/inject_plots.py picks them up by naming convention.

    scripts/plot_families.py [--out doc/docs/img] [--only STEM,STEM]
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
matplotlib.rcParams["svg.fonttype"] = "none"
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402

sys.path.insert(0, str(Path(__file__).resolve().parent))
from plot_lib import ROOT, SR, run_probe  # noqa: E402

COLORS = ["#1f6feb", "#cf222e", "#116329", "#8250df", "#9a6700", "#57606a"]

LIBS = """\
an = library("analyzers.lib");
ba = library("basics.lib");
co = library("compressors.lib");
ef = library("misceffects.lib");
en = library("envelopes.lib");
fi = library("filters.lib");
ma = library("maths.lib");
no = library("noises.lib");
os = library("oscillators.lib");
"""

failures: list[str] = []


def check(cond: bool, msg: str) -> None:
    if not cond:
        failures.append(msg)
        print(f"  ASSERTION FAILED: {msg}")


def spectrum_db(x: np.ndarray, nfft: int) -> tuple[np.ndarray, np.ndarray]:
    """Welch-averaged power spectrum in dB (max-normalized), hop nfft/2."""
    w = np.hanning(nfft)
    acc, count = np.zeros(nfft // 2 + 1), 0
    for start in range(0, len(x) - nfft + 1, nfft // 2):
        seg = x[start:start + nfft] * w
        acc += np.abs(np.fft.rfft(seg)) ** 2
        count += 1
    psd = acc / max(count, 1)
    db = 10 * np.log10(psd / max(psd.max(), 1e-30) + 1e-14)
    return np.fft.rfftfreq(nfft, 1 / SR), db


def db_at(freq: np.ndarray, db: np.ndarray, f: float) -> float:
    return float(np.interp(f, freq, db))


def new_axes(title: str):
    fig, ax = plt.subplots(figsize=(6.4, 3.4))
    ax.set_title(title, fontsize=10)
    ax.grid(alpha=0.25)
    return fig, ax


def save(fig, out: Path) -> None:
    fig.tight_layout()
    fig.savefig(out, format="svg")
    plt.close(fig)
    print(f"  {out.name}  ({out.stat().st_size // 1024} kB)")


# ---------------------------------------------------------------------------
# figure types
# ---------------------------------------------------------------------------

def freq_response(out: Path, stem: str, title: str, variants, checks=(),
                  nfft: int = 16384, ylim=(-80, 20)) -> None:
    """Impulse response -> FFT magnitude, one curve per (label, expr)."""
    body = ",\n          ".join(f"(imp : {expr})" for _, expr in variants)
    src = LIBS + f"imp = 1-1';\nprocess = {body};\n"
    data = run_probe(src, nfft)
    if data is None:
        failures.append(f"{stem}: probe did not compile")
        print(f"  PROBE FAILED: {stem}")
        return
    freq = np.fft.rfftfreq(nfft, 1 / SR)
    fig, ax = new_axes(title)
    curves = []
    for i, (label, _) in enumerate(variants):
        mag = np.abs(np.fft.rfft(data[:nfft, i]))
        db = 20 * np.log10(mag + 1e-12)
        curves.append(db)
        ax.semilogx(freq[1:], db[1:], lw=1.3, label=label,
                    color=COLORS[i % len(COLORS)])
    for i, f, expected, tol in checks:
        got = db_at(freq, curves[i], f)
        check(abs(got - expected) <= tol,
              f"{stem}: variant {i} at {f:.0f} Hz is {got:+.2f} dB, "
              f"expected {expected:+.1f} +/- {tol} dB")
        ax.plot([f], [expected], "o", ms=4, mfc="none", color="#333", zorder=5)
    ax.set_xlim(20, SR / 2)
    ax.set_ylim(*ylim)
    ax.set_xlabel("Hz")
    ax.set_ylabel("dB")
    if len(variants) > 1:
        ax.legend(fontsize=8, loc="lower left")
    save(fig, out)


def time_curve(out: Path, stem: str, title: str, expr: str, seconds: float,
               gate_expr: str | None = None, checks=()) -> None:
    """Output against time; optional dashed gate overlay."""
    n = int(seconds * SR)
    chans = f"({expr})" + (f", ({gate_expr})" if gate_expr else "")
    src = LIBS + f"process = {chans};\n"
    data = run_probe(src, n)
    if data is None:
        failures.append(f"{stem}: probe did not compile")
        print(f"  PROBE FAILED: {stem}")
        return
    t = np.arange(len(data)) / SR
    fig, ax = new_axes(title)
    dec = max(1, len(t) // 4000)
    ax.plot(t[::dec], data[::dec, 0], lw=1.4, color=COLORS[0])
    if gate_expr:
        ax.plot(t[::dec], data[::dec, 1], lw=0.9, ls="--", color="#999",
                label="gate")
        ax.legend(fontsize=8)
    for fn, msg in checks:
        check(bool(fn(data[:, 0])), f"{stem}: {msg}")
    ax.set_xlabel("s")
    ax.set_ylabel("value")
    save(fig, out)


def window_fig(out: Path, stem: str, name: str, expr: str,
               sidelobe_max_db: float | None) -> None:
    """Window shape over [0,1] plus its normalized spectrum (sidelobes)."""
    W = 2048
    src = LIBS + f"x = float(ba.time)/{W}.0;\nprocess = {expr};\n"
    data = run_probe(src, W + 1)
    if data is None:
        failures.append(f"{stem}: probe did not compile")
        print(f"  PROBE FAILED: {stem}")
        return
    w = data[:W, 0]
    peak = w[W // 2]
    check(abs(peak - 1.0) < 2e-3 or stem == "an_window_flattop",
          f"{stem}: peak at x=1/2 is {peak:.4f}, expected 1")
    pad = 64 * W
    mag = np.abs(np.fft.rfft(w, pad))
    db = 20 * np.log10(mag / max(mag.max(), 1e-30) + 1e-12)
    bins = np.arange(len(db)) * W / pad  # in DFT-bin units of the window

    fig, (ax_t, ax_f) = plt.subplots(1, 2, figsize=(9.0, 3.2))
    ax_t.plot(np.arange(W) / W, w, lw=1.5, color=COLORS[0])
    ax_t.set_title(f"an.{name} — shape", fontsize=10)
    ax_t.set_xlabel("x")
    ax_t.grid(alpha=0.25)
    ax_f.plot(bins[: len(bins) // 8], db[: len(db) // 8], lw=1.0,
              color=COLORS[1])
    ax_f.set_ylim(-140, 3)
    ax_f.set_xlim(0, 40)
    ax_f.set_title("spectrum (DFT bins)", fontsize=10)
    ax_f.set_xlabel("bins")
    ax_f.set_ylabel("dB")
    ax_f.grid(alpha=0.25)
    if sidelobe_max_db is not None:
        # highest peak outside the main lobe (first local minimum onwards)
        mins = np.where((db[1:-1] < db[:-2]) & (db[1:-1] < db[2:]))[0]
        if len(mins):
            sidelobe = db[mins[0] + 1:].max()
            check(sidelobe <= sidelobe_max_db,
                  f"{stem}: peak sidelobe {sidelobe:.1f} dB, "
                  f"expected <= {sidelobe_max_db} dB")
            ax_f.axhline(sidelobe_max_db, lw=0.7, ls=":", color="#333")
    save(fig, out)


def noise_psd(out: Path, stem: str, title: str, variants,
              slope_checks=()) -> None:
    """Welch PSD of each generator; optional dB/decade slope assertions."""
    n = 1 << 17
    body = ",\n          ".join(f"({expr})" for _, expr in variants)
    src = LIBS + f"process = {body};\n"
    data = run_probe(src, n)
    if data is None:
        failures.append(f"{stem}: probe did not compile")
        print(f"  PROBE FAILED: {stem}")
        return
    fig, ax = new_axes(title)
    slopes = []
    for i, (label, _) in enumerate(variants):
        freq, db = spectrum_db(data[:, i], 8192)
        sel = (freq >= 100) & (freq <= 10000)
        fit = np.polyfit(np.log10(freq[sel]), db[sel], 1)
        slopes.append(fit[0])
        dec = 4
        ax.semilogx(freq[1::dec], db[1::dec], lw=0.9,
                    label=f"{label} ({fit[0]:+.1f} dB/dec)",
                    color=COLORS[i % len(COLORS)])
    for i, expected, tol in slope_checks:
        check(abs(slopes[i] - expected) <= tol,
              f"{stem}: variant {i} slope {slopes[i]:+.1f} dB/dec, "
              f"expected {expected:+.1f} +/- {tol}")
    ax.set_xlim(20, SR / 2)
    ax.set_ylim(-70, 5)
    ax.set_xlabel("Hz")
    ax.set_ylabel("dB")
    ax.legend(fontsize=8, loc="lower left")
    save(fig, out)


def static_io(out: Path, stem: str, title: str, variants,
              slope_checks=()) -> None:
    """In/out static characteristic in dB, from a stepped-amplitude sine."""
    step, levels = 12000, 61  # 0.25 s per step, -60..0 dBFS
    src = LIBS + f"""\
n = min({levels - 1}, ba.time / {step}) : int;
amp = pow(10.0, (float(n) - 60.0)/20.0);
src = amp * os.osc(1000);
process = src <: _, {", ".join(f"({expr})" for _, expr in variants)};
"""
    data = run_probe(src, step * levels)
    if data is None:
        failures.append(f"{stem}: probe did not compile")
        print(f"  PROBE FAILED: {stem}")
        return
    xdb, ydb = [], [[] for _ in variants]
    for lv in range(levels):
        seg = slice(lv * step + step // 2, (lv + 1) * step)
        xdb.append(20 * np.log10(np.sqrt(np.mean(data[seg, 0] ** 2)) + 1e-12))
        for i in range(len(variants)):
            rms = np.sqrt(np.mean(data[seg, 1 + i] ** 2))
            ydb[i].append(20 * np.log10(rms + 1e-12))
    xdb = np.array(xdb)
    fig, ax = new_axes(title)
    ax.plot(xdb, xdb, lw=0.8, ls=":", color="#999", label="unity")
    for i, (label, _) in enumerate(variants):
        ax.plot(xdb, ydb[i], lw=1.4, label=label,
                color=COLORS[i % len(COLORS)])
    for i, above_db, expected_slope, tol in slope_checks:
        y = np.array(ydb[i])
        sel = xdb >= above_db
        if sel.sum() < 3:
            check(False, f"{stem}: fewer than 3 points above {above_db} dB "
                         f"(input axis is RMS dB, peaks at -3 dBFS)")
            continue
        fit = np.polyfit(xdb[sel], y[sel], 1)
        check(abs(fit[0] - expected_slope) <= tol,
              f"{stem}: variant {i} slope above {above_db} dB is "
              f"{fit[0]:.2f}, expected {expected_slope:.2f} +/- {tol}")
    ax.set_xlabel("input dBFS")
    ax.set_ylabel("output dBFS")
    ax.legend(fontsize=8, loc="upper left")
    save(fig, out)


def error_spectrum(out: Path, stem: str, title: str, variants,
                   tilt_checks=()) -> None:
    """PSD of (processed - input): dither/noise-shaping error spectra."""
    n = 1 << 17
    body = ",\n          ".join(f"(src : {expr}) - src" for _, expr in variants)
    src = LIBS + f"src = os.osc(997)*0.25;\nprocess = {body};\n"
    data = run_probe(src, n)
    if data is None:
        failures.append(f"{stem}: probe did not compile")
        print(f"  PROBE FAILED: {stem}")
        return
    fig, ax = new_axes(title)
    tilts = []
    for i, (label, _) in enumerate(variants):
        freq, db = spectrum_db(data[:, i], 8192)
        lo = np.mean(db[(freq >= 500) & (freq <= 3000)])
        hi = np.mean(db[(freq >= 16000) & (freq <= 22000)])
        tilts.append(hi - lo)
        dec = 4
        ax.semilogx(freq[1::dec], db[1::dec], lw=0.9,
                    label=f"{label} (HF-LF {hi - lo:+.0f} dB)",
                    color=COLORS[i % len(COLORS)])
    for i, min_tilt, max_tilt in tilt_checks:
        check(min_tilt <= tilts[i] <= max_tilt,
              f"{stem}: variant {i} HF-LF tilt {tilts[i]:+.1f} dB, "
              f"expected in [{min_tilt}, {max_tilt}]")
    ax.set_xlim(100, SR / 2)
    ax.set_ylim(-60, 5)
    ax.set_xlabel("Hz")
    ax.set_ylabel("dB (error PSD)")
    ax.legend(fontsize=8, loc="lower right")
    save(fig, out)


# ---------------------------------------------------------------------------
# phase A registry
# ---------------------------------------------------------------------------

def build_all(out_dir: Path, wanted: set[str]) -> None:
    def go(stem):
        return not wanted or stem in wanted

    # ---- filters.lib: frequency responses -------------------------------
    if go("fi_lowpass"):
        freq_response(out_dir / "fi_lowpass.svg", "fi_lowpass",
                      "fi.lowpass(N, 1000) — Butterworth orders",
                      [(f"N={n}", f"fi.lowpass({n}, 1000.0)") for n in (1, 2, 4, 8)],
                      checks=[(i, 1000.0, -3.01, 0.5) for i in range(4)])
    if go("fi_highpass"):
        freq_response(out_dir / "fi_highpass.svg", "fi_highpass",
                      "fi.highpass(N, 1000) — Butterworth orders",
                      [(f"N={n}", f"fi.highpass({n}, 1000.0)") for n in (1, 2, 4, 8)],
                      checks=[(i, 1000.0, -3.01, 0.5) for i in range(4)])
    if go("fi_lowpass3e"):
        freq_response(out_dir / "fi_lowpass3e.svg", "fi_lowpass3e",
                      "fi.lowpass3e(1000) — 3rd-order elliptic",
                      [("lowpass3e", "fi.lowpass3e(1000.0)")],
                      checks=[(0, 100.0, 0.0, 1.0), (0, 4000.0, -38.0, 8.0)])
    if go("fi_lowpass6e"):
        freq_response(out_dir / "fi_lowpass6e.svg", "fi_lowpass6e",
                      "fi.lowpass6e(1000) — 6th-order elliptic",
                      [("lowpass6e", "fi.lowpass6e(1000.0)")],
                      checks=[(0, 100.0, 0.0, 1.0), (0, 4000.0, -60.0, 25.0)],
                      ylim=(-100, 20))
    if go("fi_highpass3e"):
        freq_response(out_dir / "fi_highpass3e.svg", "fi_highpass3e",
                      "fi.highpass3e(1000) — 3rd-order elliptic",
                      [("highpass3e", "fi.highpass3e(1000.0)")],
                      checks=[(0, 10000.0, 0.0, 1.0), (0, 250.0, -38.0, 8.0)])
    if go("fi_highpass6e"):
        freq_response(out_dir / "fi_highpass6e.svg", "fi_highpass6e",
                      "fi.highpass6e(1000) — 6th-order elliptic",
                      [("highpass6e", "fi.highpass6e(1000.0)")],
                      checks=[(0, 10000.0, 0.0, 1.0), (0, 250.0, -80.0, 30.0)],
                      ylim=(-110, 20))
    if go("fi_bandpass"):
        freq_response(out_dir / "fi_bandpass.svg", "fi_bandpass",
                      "fi.bandpass(Nh, 500, 2000)",
                      [(f"Nh={n}", f"fi.bandpass({n}, 500.0, 2000.0)") for n in (1, 2, 4)],
                      checks=[(2, 1000.0, 0.0, 1.0), (2, 100.0, -60.0, 20.0)])
    if go("fi_bandstop"):
        freq_response(out_dir / "fi_bandstop.svg", "fi_bandstop",
                      "fi.bandstop(Nh, 500, 2000)",
                      [(f"Nh={n}", f"fi.bandstop({n}, 500.0, 2000.0)") for n in (1, 2, 4)],
                      checks=[(2, 50.0, 0.0, 1.0), (2, 1000.0, -70.0, 25.0)],
                      ylim=(-90, 20))
    if go("fi_resonlp"):
        freq_response(out_dir / "fi_resonlp.svg", "fi_resonlp",
                      "fi.resonlp(1000, Q, 1)",
                      [(f"Q={q}", f"fi.resonlp(1000.0, {q}.0, 1.0)") for q in (1, 4, 16)],
                      checks=[(2, 1000.0, 24.0, 3.0), (0, 100.0, 0.0, 1.0)],
                      ylim=(-60, 32))
    if go("fi_resonhp"):
        freq_response(out_dir / "fi_resonhp.svg", "fi_resonhp",
                      "fi.resonhp(1000, Q, 1)",
                      [(f"Q={q}", f"fi.resonhp(1000.0, {q}.0, 1.0)") for q in (1, 4, 16)],
                      checks=[(0, 10000.0, 0.0, 1.0)], ylim=(-60, 32))
    if go("fi_resonbp"):
        freq_response(out_dir / "fi_resonbp.svg", "fi_resonbp",
                      "fi.resonbp(1000, Q, 1)",
                      [(f"Q={q}", f"fi.resonbp(1000.0, {q}.0, 1.0)") for q in (1, 4, 16)],
                      ylim=(-60, 10))
    if go("fi_peak_eq"):
        freq_response(out_dir / "fi_peak_eq.svg", "fi_peak_eq",
                      "fi.peak_eq(L, 1000, 500)",
                      [("+12 dB", "fi.peak_eq(12.0, 1000.0, 500.0)"),
                       ("-12 dB", "fi.peak_eq(-12.0, 1000.0, 500.0)")],
                      checks=[(0, 1000.0, 12.0, 1.0), (1, 1000.0, -12.0, 1.0),
                              (0, 50.0, 0.0, 0.8)],
                      ylim=(-20, 20))
    if go("fi_low_shelf"):
        freq_response(out_dir / "fi_low_shelf.svg", "fi_low_shelf",
                      "fi.low_shelf(L, 500)",
                      [("+12 dB", "fi.low_shelf(12.0, 500.0)"),
                       ("-12 dB", "fi.low_shelf(-12.0, 500.0)")],
                      checks=[(0, 30.0, 12.0, 1.0), (1, 30.0, -12.0, 1.0),
                              (0, 20000.0, 0.0, 1.0)],
                      ylim=(-20, 20))
    if go("fi_high_shelf"):
        freq_response(out_dir / "fi_high_shelf.svg", "fi_high_shelf",
                      "fi.high_shelf(L, 2000)",
                      [("+12 dB", "fi.high_shelf(12.0, 2000.0)"),
                       ("-12 dB", "fi.high_shelf(-12.0, 2000.0)")],
                      checks=[(0, 20000.0, 12.0, 1.5), (1, 20000.0, -12.0, 1.5),
                              (0, 30.0, 0.0, 1.0)],
                      ylim=(-20, 20))
    if go("fi_notchw"):
        freq_response(out_dir / "fi_notchw.svg", "fi_notchw",
                      "fi.notchw(width, 1000)",
                      [("width=50", "fi.notchw(50.0, 1000.0)"),
                       ("width=400", "fi.notchw(400.0, 1000.0)")],
                      checks=[(0, 1000.0, -30.0, 15.0), (0, 100.0, 0.0, 1.0)],
                      ylim=(-90, 10))
    if go("fi_dcblocker"):
        freq_response(out_dir / "fi_dcblocker.svg", "fi_dcblocker",
                      "fi.dcblocker — -3 dB near 35 Hz at 44.1/48 kHz",
                      [("dcblocker", "fi.dcblocker")],
                      checks=[(0, 1000.0, 0.0, 0.5), (0, 35.0, -2.5, 2.0)],
                      ylim=(-40, 10))
    if go("fi_itu_r_bs_1770_4_kfilter"):
        freq_response(out_dir / "fi_itu_r_bs_1770_4_kfilter.svg",
                      "fi_itu_r_bs_1770_4_kfilter",
                      "fi.itu_r_bs_1770_4_kfilter — K-weighting, 0 dB at 997 Hz",
                      [("K-filter", "fi.itu_r_bs_1770_4_kfilter")],
                      checks=[(0, 997.0, 0.0, 0.1), (0, 60.0, -3.2, 1.5),
                              (0, 10000.0, 4.0, 1.0)],
                      ylim=(-30, 10))
    if go("fi_highpass_plus_lowpass"):
        freq_response(out_dir / "fi_highpass_plus_lowpass.svg",
                      "fi_highpass_plus_lowpass",
                      "fi.highpass_plus_lowpass(N, 1000) — allpass magnitude",
                      [(f"N={n}", f"fi.highpass_plus_lowpass({n}, 1000.0)")
                       for n in (3, 5)],
                      checks=[(0, 100.0, 0.0, 0.5), (0, 1000.0, 0.0, 0.5),
                              (0, 10000.0, 0.0, 0.5),
                              (1, 1000.0, 0.0, 0.5)],
                      ylim=(-12, 12))

    # ---- an.window_*: shape + sidelobes ---------------------------------
    windows = [
        ("rect", "an.window_rect(x)", -13.0),
        ("hann", "an.window_hann(x)", -31.0),
        ("hamming", "an.window_hamming(x)", -40.0),
        ("blackman", "an.window_blackman(x)", -57.0),
        ("blackman_harris", "an.window_blackman_harris(x)", -91.0),
        ("nuttall", "an.window_nuttall(x)", -92.0),
        ("flattop", "an.window_flattop(x)", -68.0),
        ("bartlett", "an.window_bartlett(x)", -26.0),
        ("tukey", "an.window_tukey(0.5, x)", None),
        ("kaiser", "an.window_kaiser(8.6, x)", -62.0),
    ]
    for name, expr, side in windows:
        stem = f"an_window_{name}"
        if go(stem):
            window_fig(out_dir / f"{stem}.svg", stem, f"window_{name}", expr,
                       side)

    # ---- envelopes.lib: time curves -------------------------------------
    envs = [
        ("en_ar", "en.ar(0.05, 0.2, g)",
         [(lambda y: y.max() > 0.9, "attack must reach ~1"),
          (lambda y: abs(y[-1]) < 0.05, "release must return to 0")]),
        ("en_asr", "en.asr(0.05, 0.7, 0.2, g)",
         [(lambda y: abs(y[int(0.35 * SR)] - 0.7) < 0.05,
           "sustain must sit at 0.7"),
          (lambda y: abs(y[-1]) < 0.05, "release must return to 0")]),
        ("en_adsr", "en.adsr(0.05, 0.1, 0.7, 0.2, g)",
         [(lambda y: y.max() > 0.9, "attack must reach ~1"),
          (lambda y: abs(y[int(0.35 * SR)] - 0.7) < 0.05,
           "sustain must sit at 0.7"),
          (lambda y: abs(y[-1]) < 0.05, "release must return to 0")]),
        ("en_are", "en.are(0.05, 0.2, g)",
         [(lambda y: y.max() > 0.9, "attack must reach ~1"),
          (lambda y: abs(y[-1]) < 0.02, "release must return to 0")]),
        ("en_asre", "en.asre(0.05, 0.7, 0.2, g)",
         [(lambda y: abs(y[int(0.35 * SR)] - 0.7) < 0.05,
           "sustain must sit at 0.7")]),
        ("en_adsre", "en.adsre(0.05, 0.1, 0.7, 0.2, g)",
         [(lambda y: abs(y[int(0.35 * SR)] - 0.7) < 0.07,
           "sustain must sit near 0.7")]),
    ]
    for stem, expr, chk in envs:
        if go(stem):
            name = stem.split("_", 1)[1]
            time_curve(out_dir / f"{stem}.svg", stem,
                       f"en.{name} — gate 0.4 s on", expr, seconds=0.8,
                       gate_expr="g", checks=chk)

    # ---- noises.lib: spectra --------------------------------------------
    if go("no_noise"):
        noise_psd(out_dir / "no_noise.svg", "no_noise",
                  "no.noise — white",
                  [("noise", "no.noise")], slope_checks=[(0, 0.0, 1.5)])
    if go("no_pink_noise"):
        noise_psd(out_dir / "no_pink_noise.svg", "no_pink_noise",
                  "no.pink_noise — -10 dB/decade",
                  [("pink_noise", "no.pink_noise")],
                  slope_checks=[(0, -10.0, 2.0)])
    if go("no_colored_noise"):
        noise_psd(out_dir / "no_colored_noise.svg", "no_colored_noise",
                  "no.colored_noise(4, alpha)",
                  [("alpha=-0.5", "no.colored_noise(4, -0.5)"),
                   ("alpha=+0.5", "no.colored_noise(4, 0.5)")],
                  slope_checks=[(0, -10.0, 5.0), (1, 10.0, 5.0)])

    # ---- compressors.lib: static characteristics ------------------------
    if go("co_compressor_mono"):
        static_io(out_dir / "co_compressor_mono.svg", "co_compressor_mono",
                  "co.compressor_mono(ratio, -20 dB, 5 ms, 100 ms)",
                  [(f"ratio {r}:1",
                    f"co.compressor_mono({r}.0, -20.0, 0.005, 0.1)")
                   for r in (2, 4, 8)],
                  slope_checks=[(0, -10, 1 / 2, 0.15), (1, -10, 1 / 4, 0.15),
                                (2, -10, 1 / 8, 0.15)])
    if go("co_limiter_1176_R4_mono"):
        static_io(out_dir / "co_limiter_1176_R4_mono.svg",
                  "co_limiter_1176_R4_mono",
                  "co.limiter_1176_R4_mono — 4:1 above -6 dB",
                  [("limiter_1176_R4", "co.limiter_1176_R4_mono")],
                  slope_checks=[(0, -8, 1 / 4, 0.2)])

    # ---- dither: error spectra ------------------------------------------
    if go("ef_dither"):
        error_spectrum(out_dir / "ef_dither.svg", "ef_dither",
                       "ef.dither(16) — requantization error (flat)",
                       [("dither(16)", "ef.dither(16)")],
                       tilt_checks=[(0, -4.0, 4.0)])
    if go("ef_dither_shaped"):
        error_spectrum(out_dir / "ef_dither_shaped.svg", "ef_dither_shaped",
                       "ef.dither_shaped(K, 16) — noise-shaped error",
                       [("K=1", "ef.dither_shaped(1, 16)"),
                        ("K=2", "ef.dither_shaped(2, 16)")],
                       tilt_checks=[(0, 8.0, 30.0), (1, 18.0, 45.0)])


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(ROOT / "doc" / "docs" / "img"))
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    wanted = set(filter(None, args.only.split(",")))

    # the envelope probes share the gate definition through LIBS
    global LIBS
    LIBS = LIBS + "g = ba.time < 19200;\n"

    build_all(out_dir, wanted)

    if failures:
        print(f"\n{len(failures)} property assertion(s) FAILED")
        return 1
    print("\nall figures generated, all property assertions hold")
    return 0


if __name__ == "__main__":
    sys.exit(main())
