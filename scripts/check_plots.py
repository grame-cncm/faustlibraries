#!/usr/bin/env python3
"""Check that the documentation figures are up to date with the libraries.

Regenerates every figure (`plot_lib.py` and `plot_families.py`) in a
temporary directory and compares each one with its committed copy in
doc/docs/img. A figure is *stale* when its rendering differs: the two SVGs
are rasterized (`rsvg-convert`, or the `cairosvg` module) and compared pixel
by pixel. Their text alone cannot decide it, since matplotlib writes the
date, its version and random ids into every file, and the last digits of a
coordinate move with the platform; a figure that only differs that way is
left alone, so that the committed SVGs do not churn.

    scripts/check_plots.py [--only STEM,STEM] [--update] [--keep DIR]

The check fails (exit status 1) on a failed property assertion of
`plot_families.py`, a stale figure, a figure generated but not committed,
or a committed figure no generator writes (its probe no longer compiles).
The functions `plot_lib.py` skips by design are listed, not counted. `--update` copies the stale and new figures into doc/docs/img and
leaves the others untouched; it updates nothing while an assertion fails. `--only` takes
figure stems (`fi_lowpass,aa_tanh1`), `--keep` writes the regenerated
figures to DIR instead of a temporary directory.
"""
from __future__ import annotations

import argparse
import io
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import matplotlib.image as mpimg
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
IMG = ROOT / "doc" / "docs" / "img"
DPI = 96
# A pixel differs when a channel moves by more than this (0..1 scale). The
# same figure rendered by two matplotlib versions or platforms stays below
# 0.05; a curve moved by one pixel exceeds 0.5.
PIXEL_TOL = 0.25


def rasterize(svg: Path) -> np.ndarray:
    if shutil.which("rsvg-convert"):
        png = subprocess.run(["rsvg-convert", "-d", str(DPI), "-p", str(DPI), str(svg)],
                             capture_output=True, check=True).stdout
    else:
        import cairosvg  # noqa: PLC0415 -- optional fallback
        png = cairosvg.svg2png(url=str(svg), dpi=DPI)
    return mpimg.imread(io.BytesIO(png), format="png")


def differs(a: Path, b: Path) -> str | None:
    """None when the two figures render the same, else what differs."""
    if a.read_bytes() == b.read_bytes():
        return None
    ra, rb = rasterize(a), rasterize(b)
    if ra.shape != rb.shape:
        return f"size {ra.shape[1]}x{ra.shape[0]} vs {rb.shape[1]}x{rb.shape[0]}"
    n = int((np.abs(ra - rb).max(axis=-1) > PIXEL_TOL).sum())
    return f"{n} pixels differ" if n else None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--only", default="",
                    help="comma-separated figure stems to check, e.g. fi_lowpass,aa_tanh1 (default: all)")
    ap.add_argument("--update", action="store_true",
                    help="copy the stale and new figures into doc/docs/img")
    ap.add_argument("--keep", metavar="DIR",
                    help="write the regenerated figures to DIR instead of a temporary directory")
    args = ap.parse_args()
    if not shutil.which("rsvg-convert"):
        try:
            import cairosvg  # noqa: F401, PLC0415
        except ImportError:
            print("check_plots: needs rsvg-convert (librsvg) or the cairosvg module "
                  "to compare the renderings", file=sys.stderr)
            return 2

    wanted = set(filter(None, args.only.split(",")))
    aa = sorted(s[3:] for s in wanted if s.startswith("aa_"))
    families = sorted(s for s in wanted if not s.startswith("aa_"))
    tmp = None if args.keep else tempfile.TemporaryDirectory()
    out = Path(args.keep or tmp.name)
    out.mkdir(parents=True, exist_ok=True)

    # The two generators are independent: run them side by side.
    jobs = []
    if not wanted or aa:
        jobs.append(("plot_lib.py", aa))
    if not wanted or families:
        jobs.append(("plot_families.py", families))
    procs = [(script, subprocess.Popen(
        [sys.executable, str(ROOT / "scripts" / script), "--out", str(out)]
        + (["--only", ",".join(only)] if only else []),
        cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True))
        for script, only in jobs]
    problems, notes = [], []
    for script, p in procs:
        log = p.communicate()[0]
        if p.returncode != 0:
            problems.append(f"{script} failed (exit {p.returncode}):")
            problems += [f"  {line.strip()}" for line in log.splitlines()
                         if "FAILED" in line or "Error" in line or "Traceback" in line]
        # A function whose probe does not fit is skipped by design (aa.ADAA1
        # takes functions); one that loses its figure shows as "not generated".
        notes += [f"{script}: {line.strip()}" for line in log.splitlines()
                  if line.startswith("skipped")]

    generated = {p.stem: p for p in out.glob("*.svg")}
    committed = {p.stem: p for p in IMG.glob("*.svg")}
    if wanted:
        committed = {s: p for s, p in committed.items() if s in wanted}
        problems += [f"{s}: no generator writes this figure" for s in sorted(wanted)
                     if s not in generated and s not in committed]
    stale, new = [], []
    for stem in sorted(generated):
        if stem not in committed:
            new.append(stem)
            continue
        what = differs(generated[stem], committed[stem])
        if what:
            stale.append((stem, what))
    orphans = sorted(set(committed) - set(generated))

    for stem, what in stale:
        print(f"stale: {stem}.svg ({what})")
    for stem in new:
        print(f"new: {stem}.svg (generated, not in doc/docs/img)")
    for stem in orphans:
        print(f"not generated: {stem}.svg (committed, but no generator wrote it)")
    if args.update and problems:
        print("not updating doc/docs/img: fix the problems below first")
    elif args.update:
        for stem in [s for s, _ in stale] + new:
            shutil.copy2(generated[stem], IMG / f"{stem}.svg")
        if stale or new:
            print(f"updated {len(stale) + len(new)} figure(s) in doc/docs/img")
    for line in notes + problems:
        print(line)

    if args.keep:
        print(f"regenerated figures kept in {out}")
    else:
        tmp.cleanup()
    failed = problems or orphans or (not args.update and (stale or new))
    print(f"\n{len(generated)} figures regenerated: {len(stale)} stale, {len(new)} new, "
          f"{len(orphans)} not generated, {len(generated) - len(stale) - len(new)} up to date")
    if failed:
        print("check_plots: FAILED")
        return 1
    if args.update and (stale or new):
        print("check_plots: stale figures updated, all property assertions hold")
    else:
        print("check_plots: all figures up to date, all property assertions hold")
    return 0


if __name__ == "__main__":
    sys.exit(main())
