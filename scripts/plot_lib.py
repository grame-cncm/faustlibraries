#!/usr/bin/env python3
"""Generate documentation plots for library functions.

Prototype scope: `aanl.lib`, the antialiased nonlinearities. Those are the
functions whose whole purpose — suppressing the alias partials a naive
waveshaper folds back into the audible band — is invisible in prose and obvious
in a picture.

Each function gets one figure with two panels:

* **transfer curve**, from a slow DC ramp: the shape, statically;
* **output spectrum**, from a bin-aligned sine driven into the nonlinearity,
  with the true harmonics of the fundamental marked. Energy *off* those marks is
  aliasing, so the plot reads as a property check rather than as decoration.

No new architecture file is needed: the probe signal is written in Faust, so the
existing `arch/print_arch.cpp` (silence in, samples out) drives everything.

    scripts/plot_lib.py [--out doc/docs/img] [--only NAME,NAME]
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
# Emit text as `<text>` rather than glyph outlines. matplotlib's default embeds
# every character as a path, which dominates the file: 45 kB per figure becomes
# a few kB, and the labels stay selectable and searchable in the browser.
matplotlib.rcParams["svg.fonttype"] = "none"
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
ARCH = ROOT / "arch" / "print_arch.cpp"

SR = 48000
N = 8192
# Bin-aligned so the fundamental lands exactly on a bin and the harmonic marks
# below mean what they say: 512 * 48000 / 8192 = 3000 Hz.
F0 = 512 * SR / N
DRIVE = 2.0          # enough to engage every saturator in the library
RAMP_SPAN = 2.0      # transfer curve swept over [-RAMP_SPAN, +RAMP_SPAN]
WARMUP = 32          # frames `print_arch.cpp` computes with buttons held on
CURVE_DECIMATION = 8
SPECTRUM_DECIMATION = 4

PROBE_TRANSFER = """\
aa = library("aanl.lib");
ba = library("basics.lib");
ramp = (float(ba.time) / {n}.0) * {span2} - {span};
process = ramp : aa.{name};
"""

PROBE_SPECTRUM = """\
aa = library("aanl.lib");
os = library("oscillators.lib");
process = {drive} * os.osc({f0}) : aa.{name};
"""


def documented_functions(lib: Path) -> list[str]:
    """Names carrying a `//---`(aa.)name`---` documentation header."""
    marker = re.compile(r"^//-{3,}[^-].*`")
    names: list[str] = []
    for line in lib.read_text(errors="replace").splitlines():
        if marker.match(line):
            names += re.findall(r"`\(aa\.\)([a-zA-Z0-9_]+)`", line)
    return names


def run_probe(source: str, frames: int) -> np.ndarray | None:
    """Compile one probe and return its output, or `None` if it does not build.

    A function that does not fit the probe — wrong arity, extra parameters —
    simply fails to compile, so the compiler does the selection and this script
    needs no per-function table.
    """
    with tempfile.TemporaryDirectory() as tmp:
        d = Path(tmp)
        (d / "p.dsp").write_text(source)
        cpp, exe = d / "p.cpp", d / "p"
        faust = subprocess.run(
            ["faust", "-I", str(ROOT), "-double", "-a", str(ARCH),
             str(d / "p.dsp"), "-o", str(cpp)],
            capture_output=True, text=True)
        if faust.returncode != 0:
            return None
        cxx = subprocess.run(["g++", "-O2", "-std=c++17", str(cpp), "-o", str(exe)],
                             capture_output=True, text=True)
        if cxx.returncode != 0:
            return None
        run = subprocess.run([str(exe), str(frames), str(SR)],
                             capture_output=True, text=True)
        if run.returncode != 0 or not run.stdout.strip():
            return None
        data = np.loadtxt(run.stdout.splitlines())
        return data[:, 1] if data.ndim == 2 else data


def harmonic_marks(f0: float, nyquist: float, count: int = 24) -> list[float]:
    """Harmonics of `f0` reflected into `[0, nyquist]`, as an alias-free model."""
    marks = []
    for k in range(1, count + 1):
        f = k * f0
        # Reflect repeatedly: this is where a naive waveshaper puts its partials.
        while f > nyquist:
            f = abs(2 * nyquist - f) if f < 2 * nyquist else f - 2 * nyquist
        if 0 < f <= nyquist:
            marks.append(f)
    return marks


def plot(name: str, curve: np.ndarray, spectrum: np.ndarray, out: Path) -> None:
    fig, (ax_t, ax_f) = plt.subplots(1, 2, figsize=(9.0, 3.4))

    # The harness computes 32 warm-up frames with buttons held on; drop them,
    # then decimate — an SVG carrying 8192 points is 47 kB for a smooth curve.
    body = curve[WARMUP:][::CURVE_DECIMATION]
    x = np.linspace(-RAMP_SPAN + 2 * RAMP_SPAN * WARMUP / len(curve),
                    RAMP_SPAN, len(body))
    ax_t.plot(x, body, lw=1.6, color="#1f6feb")
    ax_t.axhline(0, lw=0.6, color="#999")
    ax_t.axvline(0, lw=0.6, color="#999")
    ax_t.set_title(f"aa.{name} — transfer curve", fontsize=10)
    ax_t.set_xlabel("input")
    ax_t.set_ylabel("output")
    ax_t.grid(alpha=0.25)

    # Drop the warm-up transient before transforming.
    seg = spectrum[-N:] * np.hanning(N)
    mag = np.abs(np.fft.rfft(seg))
    freq = np.fft.rfftfreq(N, 1 / SR)
    db = 20 * np.log10(mag / max(mag.max(), 1e-30) + 1e-12)
    # Peak-preserving decimation: plain subsampling would drop the very
    # partials the plot exists to show, so keep the maximum of each group.
    group = SPECTRUM_DECIMATION
    keep = (len(db) // group) * group
    db = db[:keep].reshape(-1, group).max(axis=1)
    freq = freq[:keep].reshape(-1, group).mean(axis=1)
    for f in harmonic_marks(F0, SR / 2):
        ax_f.axvline(f, color="#d0d7de", lw=0.8, zorder=0)
    ax_f.plot(freq, db, lw=0.9, color="#cf222e")
    ax_f.set_xlim(0, SR / 2)
    ax_f.set_ylim(-120, 5)
    ax_f.set_title(f"spectrum, {F0:.0f} Hz drive (grey = true harmonics)", fontsize=10)
    ax_f.set_xlabel("Hz")
    ax_f.set_ylabel("dB")
    ax_f.grid(alpha=0.25)

    fig.tight_layout()
    fig.savefig(out, format="svg")
    plt.close(fig)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(ROOT / "doc" / "docs" / "img"))
    ap.add_argument("--only", default="")
    args = ap.parse_args()

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    wanted = set(filter(None, args.only.split(",")))

    names = documented_functions(ROOT / "aanl.lib")
    done, skipped = [], []
    for name in names:
        if wanted and name not in wanted:
            continue
        curve = run_probe(
            PROBE_TRANSFER.format(name=name, n=N, span=RAMP_SPAN, span2=2 * RAMP_SPAN),
            N)
        spec = run_probe(
            PROBE_SPECTRUM.format(name=name, drive=DRIVE, f0=int(F0)), 2 * N)
        if curve is None or spec is None:
            skipped.append(name)
            continue
        target = out_dir / f"aa_{name}.svg"
        plot(name, curve, spec, target)
        done.append(name)
        print(f"  {target.name}  ({target.stat().st_size // 1024} kB)")

    print(f"\n{len(done)} plotted, {len(skipped)} skipped")
    if skipped:
        print("skipped (probe did not compile): " + ", ".join(skipped))
    return 0


if __name__ == "__main__":
    sys.exit(main())
