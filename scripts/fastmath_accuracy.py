#!/usr/bin/env python3
"""The accuracy of the functions of fastmath.lib, in single and double precision.

Each function is compiled (scripts/check_precision.py's build and
arch/precision_arch.cpp) over a sweep of 2^20 points of its domain, the
program writing x and f(x), and compared with numpy's float64 function at
the same x: the error printed is relative or absolute as the doc block of
the function says. In double precision, numpy's own error (half an ulp or
so) is part of what is measured: the figures say how close to the C library
fastmath.lib is, not to the exact value.

    scripts/fastmath_accuracy.py [--precision single|double|both] [-k REGEX] [--json OUT]
"""
import argparse
import concurrent.futures as cf
import json
import os
import re
import sys
import tempfile

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_precision as cp  # noqa: E402

FRAMES = 1 << 20


def sin2pi(x):
    """sin(2 pi x) with an exact reduction: np.sin(2*np.pi*x) rounds the product."""
    return np.sin(2 * np.pi * (x - np.round(x)))


def tanpi(x):
    """tan(pi x), x in (-1/2, 1/2): near the pole, from the exact complement 1/2 - |x|."""
    a = np.abs(x)
    return np.where(a <= 0.25, np.tan(np.pi * x), np.sign(x) / np.tan(np.pi * (0.5 - a)))

# name, Faust expression of the sweep's x -> f(x), sweep (lin|log2, lo, hi), metric, reference
FUNCTIONS = [
    ("fexp2", "fa.fexp2", ("lin", -125, 127), "rel", np.exp2),
    ("fexp2_faster", "fa.fexp2_faster", ("lin", -125, 127), "rel", np.exp2),
    ("fexp", "fa.fexp", ("lin", -80, 80), "rel", np.exp),
    ("fexp_faster", "fa.fexp_faster", ("lin", -80, 80), "rel", np.exp),
    ("fexp10", "fa.fexp10", ("lin", -37, 37), "rel", lambda x: 10.0 ** x),
    ("fdb2linear", "fa.fdb2linear", ("lin", -300, 300), "rel", lambda x: 10.0 ** (x / 20)),
    ("fdb2linear_faster", "fa.fdb2linear_faster", ("lin", -300, 300), "rel",
     lambda x: 10.0 ** (x / 20)),
    ("flog2", "fa.flog2", ("log2", -125, 127), "abs", np.log2),
    ("flog2_faster", "fa.flog2_faster", ("log2", -125, 127), "abs", np.log2),
    ("flog2_sqrt", "fa.flog2_sqrt", ("log2", -32, 32), "abs", np.log2),
    ("flog", "fa.flog", ("log2", -125, 127), "abs", np.log),
    ("flog10", "fa.flog10", ("log2", -125, 127), "abs", np.log10),
    ("flinear2db", "fa.flinear2db", ("log2", -125, 127), "abs", lambda x: 20 * np.log10(x)),
    ("flinear2db_faster", "fa.flinear2db_faster", ("log2", -125, 127), "abs",
     lambda x: 20 * np.log10(x)),
    ("flinear2db_sqrt", "fa.flinear2db_sqrt", ("log2", -32, 32), "abs",
     lambda x: 20 * np.log10(x)),
    ("fpow", "fa.fpow(_, 2.5)", ("log2", -10, 10), "rel", lambda x: x ** 2.5),
    ("fsin2pi", "fa.fsin2pi", ("lin", -1000, 1000), "abs", sin2pi),
    ("fsin2pi_faster", "fa.fsin2pi_faster", ("lin", -1000, 1000), "abs", sin2pi),
    ("fcos2pi", "fa.fcos2pi", ("lin", -1000, 1000), "abs", lambda x: sin2pi(x + 0.25)),
    ("fsin", "fa.fsin", ("lin", -3.14159265, 3.14159265), "abs", np.sin),
    ("fsin_big", "fa.fsin", ("lin", -1000, 1000), "abs", np.sin),
    ("fsin_faster", "fa.fsin_faster", ("lin", -3.14159265, 3.14159265), "abs", np.sin),
    ("fcos", "fa.fcos", ("lin", -3.14159265, 3.14159265), "abs", np.cos),
    ("ftanpi", "fa.ftanpi", ("lin", -0.49, 0.49), "rel", tanpi),
    ("ftan", "fa.ftan", ("lin", -1.5, 1.5), "rel", np.tan),
    ("ftanh", "fa.ftanh", ("lin", -20, 20), "abs", np.tanh),
    ("ftanh_faster", "fa.ftanh_faster", ("lin", -20, 20), "abs", np.tanh),
]


def sweep(s):
    kind, lo, hi = s
    t = f"(float(ba.time) / {FRAMES}.0)"
    x = f"({lo} + ({hi} - ({lo})) * {t})"
    return x if kind == "lin" else f"pow(2.0, {x})"


def measure(spec, args, cfg, dsp, precision):
    name, expr, s, metric, ref = spec
    exe, err = cp.build(dsp, f"acc_{name}_test", precision, cfg, args)
    if err:
        return name, precision, {"error": err}
    out = cp.render(exe, 48000, FRAMES, exe + ".raw")
    x, y = out[:, 0], out[:, 1]
    r = ref(x)
    if metric == "rel":
        ok = np.isfinite(r) & (np.abs(r) > 1e-300)
        e = np.abs(y[ok] - r[ok]) / np.abs(r[ok])
        xs = x[ok]
    else:
        e = np.abs(y - r)
        xs = x
    i = int(np.argmax(e))
    return name, precision, {"metric": metric, "max": float(e[i]), "at": float(xs[i]),
                             "finite": bool(np.isfinite(y).all())}


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("--precision", default="both", choices=("single", "double", "both"))
    p.add_argument("-k", "--filter")
    p.add_argument("--json")
    p.add_argument("--faust", default=os.environ.get("FAUST", "faust"))
    p.add_argument("--cxx", default=os.environ.get("CXX", "c++"))
    args = p.parse_args()
    specs = [f for f in FUNCTIONS if not args.filter or re.search(args.filter, f[0])]
    precisions = ("single", "double") if args.precision == "both" else (args.precision,)
    build = tempfile.mkdtemp(prefix="fastmath_accuracy_")
    dsp = os.path.join(build, "fastmath_accuracy.dsp")
    with open(dsp, "w") as f:
        f.write('import("stdfaust.lib");\n')
        for name, expr, s, *_ in specs:
            f.write(f"acc_{name}_test = {sweep(s)} : min(ma.MAX) <: _, ({expr});\n")
    cfg = cp.Config("acc", "", "-O2", build)
    res = {}
    with cf.ThreadPoolExecutor(os.cpu_count()) as pool:
        jobs = [pool.submit(measure, s, args, cfg, dsp, prec) for s in specs for prec in precisions]
        for j in jobs:
            name, prec, r = j.result()
            res.setdefault(name, {})[prec] = r
    for name, expr, s, metric, _ in specs:
        cells = []
        for prec in precisions:
            r = res[name][prec]
            cells.append(f"{prec} {r['error']}" if "error" in r else
                         f"{prec} {r['max']:.2g} at {r['at']:.6g}" + ("" if r["finite"] else " NOT FINITE"))
        print(f"{name:18s} {metric} {s}: " + "   ".join(cells))
    if args.json:
        with open(args.json, "w") as f:
            json.dump(res, f, indent=1)


if __name__ == "__main__":
    main()
