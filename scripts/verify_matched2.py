#!/usr/bin/env python3
"""Verify the matched second-order filters of vaeffects.lib.

lowpass2Matched, highpass2Matched, bandpass2Matched, peaking2Matched,
lowshelf2Matched and highshelf2Matched compute Vicanek's coefficients through
rewritten formulas that avoid cancellation (see _matched2, _shelf2Matched and
_matchedRun in vaeffects.lib). This script backs every claim made about them:

identities    the algebraic identities the rewrites rely on, proved with
              sympy, and the trigonometric and hyperbolic ones, evaluated
              with mpmath at 120 digits at random points, where they must
              agree to 40 digits (sympy does not simplify them reliably);
coefficients  the coefficient environments of the actual Faust code
              (_lowpass2MatchedCoefs, ..., _shelf2Matched), compiled in
              -single and -double and rendered at every rate, against
              Vicanek's original formulas evaluated with mpmath at 60 digits,
              over a grid of CF, Q and G; with --old, the original library
              code (emulated with numpy in float32 and float64) against the
              same reference.

Each filter is y = k*x + (n0 + n1*z^-1 + n2*z^-2)/A applied to x, with
A = 1 + a1*z^-1 + a2*z^-2 given by P = 1 + a1 + a2 and fq = 1 - a2, the
quantities that stay small and accurate when the poles come close to z = 1.
The error of a case is the largest relative error of P, fq, k and of the
numerator (relative to its largest coefficient). The reference for a single
precision build uses CF, Q and G rounded to float, so that only the
algorithm's error is measured.

Needs faust, a C++17 compiler, numpy, and sympy and mpmath
(pip install sympy mpmath). The exit status is 1 if an identity fails or if
an error exceeds its threshold.
"""

import argparse
import json
import os
import random
import shlex
import subprocess
import sys
import tempfile

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARCH = os.path.join(ROOT, "arch", "precision_arch.cpp")

RATES = [44100, 48000, 88200, 96000, 176400, 192000]
CFS = [20, 50, 200, 1200, 5000, 10000, 15000, 20000]
QS = [0.1, 0.3, 0.5, 0.7071, 1, 2, 5, 10, 30]
PEAK_GS = [0.25, 0.5, 2, 4]
SHELF_GS = [0.1, 0.25, 0.5, 0.9, 1, 1.1, 2, 4, 10]
QUICK = dict(rates=[44100, 192000], cfs=[20, 1200, 15000], qs=[0.1, 0.7071, 10],
             peak_gs=[0.25, 4], shelf_gs=[0.25, 1, 4])
THRESHOLDS = {"single": 2e-5, "double": 1e-8}
RESONANT = ["lowpass", "highpass", "bandpass", "peaking"]
SHELVES = ["lowshelf", "highshelf"]


# ----------------------------------------------------------------------------
# identities


def check_identities(verbose=True):
    import mpmath as mp
    import sympy as sp

    results = []

    def report(name, ok, detail=""):
        results.append((name, ok))
        if verbose:
            print(f"  [{'ok' if ok else 'FAIL'}] {name}{(': ' + detail) if detail else ''}")

    # --- symbolic: small quantities of _matched2. X = (q*w/2)^2, Y = (th/2)^2,
    # W = (w/2)^2 = X + Y; ex = a - X, et = Y - b, ew = W - phi with
    # a = sinh(q*w/2)^2, b = sin(th/2)^2, phi = sin(w/2)^2.
    X, Y, ex, et, ew = sp.symbols("X Y ex et ew")
    W = X + Y
    a, b, f = X + ex, Y - et, W - ew
    K = ex + ew - et
    ch, ct, cw = 1 + 2 * a, 1 - 2 * b, 1 - 2 * f          # cosh(q*w), cos(th), cos(w)
    s = a + b
    zero = lambda e: sp.expand(e) == 0
    report("cosh(q*w) - cos(th) - 2*phi = 2*K", zero(ch - ct - 2 * f - 2 * K))
    report("cos(th) - cosh(q*w)*cos(w) = 4*a*phi - 2*K (peaking)", zero(ct - ch * cw - (4 * a * f - 2 * K)))
    # lowpass: with Q^2 = W/(4X), X*(P^2 - Q^2*RA)/rho^2 = 4*X*C^2 - W*RA/(4*rho^2),
    # C = cosh(q*w) - cos(th), RA/(4*rho^2) = (C - 2*phi*cosh(q*w))^2 + 4*phi*(1 - phi)*sinh(q*w)^2
    C = ch - ct
    RA4 = (C - 2 * f * ch) ** 2 + 4 * f * (1 - f) * (ch ** 2 - 1)
    lpn = 4 * X * C ** 2 - W * RA4
    L = ((3 * a - b) * K * (2 * s - K) + f ** 2 * (4 * a * b + K) + (K - 4 * ex) * s ** 2
         - ew * (s * (a + K) - a * K + f * (3 * a - 4 * a * b - K)))
    report("lowpass: X*(P^2 - Q^2*RA)/rho^2 = 4*L", zero(lpn - 4 * L))
    report("lowpass: leading term of L is 4*X*Y*W^2",
           zero(sp.expand(L).subs({ex: 0, et: 0, ew: 0}) - 4 * X * Y * W ** 2))

    # --- symbolic: Vicanek's numerators, in A0 = (1 + a1 + a2)^2,
    # A1 = (1 - a1 + a2)^2, A2 = -4*a2 and phi (phi0 = 1 - phi, phi2 = 4*phi0*phi).
    A0, A1, A2, ph, Q, G = sp.symbols("A0 A1 A2 phi Q G", positive=True)
    ph0 = 1 - ph
    RA = A0 * ph0 + A1 * ph + A2 * 4 * ph0 * ph
    D = A0 + 4 * A2 * ph ** 2                                  # P^2 - 16*a2*phi^2
    # bandpass: u^2 = (b0 - b2)^2 = B2 + B1/4, v = -b0*b2 = B2/4
    R1, R2 = RA, -A0 + A1 + 4 * (ph0 - ph) * A2
    B2 = (R1 - R2 * ph) / (4 * ph ** 2)
    B1 = R2 + 4 * (ph - ph0) * B2
    report("bandpass: B2 + B1/4 = (RA + D)/(4*phi)", zero(sp.simplify(B2 + B1 / 4 - (RA + D) / (4 * ph))))
    report("bandpass: B2/4 = D/(16*phi^2)", zero(sp.simplify(B2 / 4 - D / (16 * ph ** 2))))
    # lowpass: b0 + b1 = sqrt(A0), b0*b1 = (A0 - Q^2*RA)/(4*phi)
    B1l = (RA * Q ** 2 - A0 * ph0) / ph
    report("lowpass: b0*b1 = (A0 - Q^2*RA)/(4*phi)", zero(sp.simplify((A0 - B1l) / 4 - (A0 - Q ** 2 * RA) / (4 * ph))))
    # peaking: Vicanek's B1 in closed form
    R1p, R2p = RA * G ** 2, (-A0 + A1 + 4 * (ph0 - ph) * A2) * G ** 2
    B2p = (R1p - R2p * ph - A0) / (4 * ph ** 2)
    B1p = R2p + A0 + 4 * (ph - ph0) * B2p
    report("peaking: B1 = G^2*A1 + (1 - G^2)*A0*phi0^2/phi^2",
           zero(sp.simplify(B1p - (G ** 2 * A1 + (1 - G ** 2) * A0 * ph0 ** 2 / ph ** 2))))

    # --- symbolic: shelves. A normalized to A(1) = 1: a1 = 1 - a0 - a2,
    # sa = A(-1) = sqrt(aa1), al = aa1 + 4*aa2 with aa2 = -4*a0*a2.
    a0, a2, c, al_, sa_ = sp.symbols("a0 a2 c al sa")
    a1 = 1 - a0 - a2
    sa = a0 - a1 + a2
    al = sa ** 2 - 16 * a0 * a2
    report("shelves: 4*(a0 - a2)^2 = 1 + al + 2*sqrt(aa1)", zero(4 * (a0 - a2) ** 2 - (1 + al + 2 * sa)))
    na2, nb2 = (1 + al_ + 2 * sa_) / 4, (1 + al_ + 2 * c * sa_) / 4    # sb = c*sa
    report("shelves: nb^2 - c^2*na^2 = (1 - c)*((1 + c)*(1 + al) + 2*sb)/4",
           zero(nb2 - c ** 2 * na2 - (1 - c) * ((1 + c) * (1 + al_) + 2 * c * sa_) / 4))
    f4, fx4, gn, Gd = sp.symbols("f4 fx4 gn Gd", positive=True)
    h, hny = (f4 + fx4 * gn) / (f4 + fx4 * Gd), (f4 + gn) / (f4 + Gd)
    report("shelves: h - 1 = fx^4*(gn - Gd)/(f^4 + fx^4*Gd)",
           zero(sp.simplify(h - 1 - fx4 * (gn - Gd) / (f4 + fx4 * Gd))))
    report("shelves: hny - h = (gn - Gd)*f^4*(1 - fx^4)/((f^4 + Gd)*(f^4 + fx^4*Gd))",
           zero(sp.simplify(hny - h - (gn - Gd) * f4 * (1 - fx4) / ((f4 + Gd) * (f4 + fx4 * Gd)))))

    # --- numeric: the trigonometric and hyperbolic forms of _matched2, at 120
    # digits, since the reference sides (1 + a1 + a2, (P - 4*rho*phi)/(4*rho)...)
    # cancel by up to 25 digits themselves at w = 1e-4; each form must agree to
    # 40 digits.
    mp.mp.dps = 120
    rnd = random.Random(263)
    worst = {k: mp.mpf(0) for k in ("P", "RA", "RA4", "K", "om", "series")}
    for _ in range(400):
        w = mp.mpf(rnd.uniform(1e-4, 3.1))
        q = mp.mpf(10 ** rnd.uniform(-2, 0.8))
        qw, rho = q * w, mp.e ** (-q * w)
        phi = mp.sin(w / 2) ** 2
        oc = 1 - rho
        if q <= 1:
            sq = mp.sqrt(1 - q * q); th = sq * w; dm = w * q * q / (1 + sq); sm = (w + th) / 2
            a1v = -2 * rho * mp.cos(th)
            Pn = oc ** 2 + 4 * rho * mp.sin(th / 2) ** 2
            RAn = (oc ** 2 + 4 * rho * mp.sin(dm / 2) ** 2) * (oc ** 2 + 4 * rho * mp.sin(sm) ** 2)
            exv = mp.sinh(qw / 2) ** 2 - (qw / 2) ** 2
            Kn = exv + (dm / 2 - mp.sin(dm / 2)) * mp.sin(sm) + dm / 2 * (sm - mp.sin(sm))
            ctv = mp.cos(th)
        else:
            sr = mp.sqrt(q * q - 1); y1 = w / (q + sr); y2 = w * (q + sr)
            a1v = -2 * rho * mp.cosh(sr * w)
            Pn = (1 - mp.e ** -y1) * (1 - mp.e ** -y2)
            RAn = (((1 - mp.e ** -y1) ** 2 + 4 * mp.e ** -y1 * phi)
                   * ((1 - mp.e ** -y2) ** 2 + 4 * mp.e ** -y2 * phi))
            ewv = (w / 2) ** 2 - phi
            Kn = ((mp.sinh(y1 / 2) - y1 / 2) * mp.sinh(y2 / 2)
                  + y1 / 2 * (mp.sinh(y2 / 2) - y2 / 2) + ewv)
            ctv = mp.cosh(sr * w)
        a2v = rho * rho
        A0v, A1v, A2v = (1 + a1v + a2v) ** 2, (1 - a1v + a2v) ** 2, -4 * a2v
        RAv = A0v * (1 - phi) + A1v * phi + A2v * 4 * (1 - phi) * phi
        Pv = 1 + a1v + a2v
        chv, cwv = mp.cosh(qw), mp.cos(w)
        RA4v = 4 * rho ** 2 * ((chv * cwv - ctv) ** 2 + (chv ** 2 - 1) * (1 - cwv ** 2))
        rel = lambda x, y: abs(x - y) / abs(y)
        worst["P"] = max(worst["P"], rel(Pn, Pv))
        worst["RA"] = max(worst["RA"], rel(RAn, RAv))
        worst["RA4"] = max(worst["RA4"], rel(RA4v, RAv))
        worst["K"] = max(worst["K"], rel(Kn, (Pv - 4 * rho * phi) / (4 * rho)))
        t = mp.tanh(qw / 2)
        worst["om"] = max(worst["om"], rel(2 * t / (1 + t), 1 - rho))
    for _ in range(200):     # the truncated series of h - sin(h) and sinh(h) - h below 1
        hh = mp.mpf(rnd.uniform(-1, 1))
        h2 = hh * hh
        sd = hh * h2 / 6 * (1 - h2 / 20 * (1 - h2 / 42 * (1 - h2 / 72 * (1 - h2 / 110))))
        shd = hh * h2 / 6 * (1 + h2 / 20 * (1 + h2 / 42 * (1 + h2 / 72 * (1 + h2 / 110))))
        if hh != 0:
            worst["series"] = max(worst["series"], abs(sd - (hh - mp.sin(hh))) / abs(hh - mp.sin(hh)),
                                  abs(shd - (mp.sinh(hh) - hh)) / abs(mp.sinh(hh) - hh))
    tol = mp.mpf(10) ** -40
    report("P: products of pole distances = 1 + a1 + a2", worst["P"] < tol, f"{float(worst['P']):.1e}")
    report("RA: products of pole distances = |A(exp(j*w))|^2", worst["RA"] < tol, f"{float(worst['RA']):.1e}")
    report("RA = 4*rho^2*((cosh(q*w)*cos(w) - cos(th))^2 + sinh(q*w)^2*sin(w)^2)",
           worst["RA4"] < tol, f"{float(worst['RA4']):.1e}")
    report("K: sums of positive terms = (P - 4*rho*phi)/(4*rho)", worst["K"] < tol, f"{float(worst['K']):.1e}")
    report("1 - exp(-y) = 2*t/(1 + t), t = tanh(y/2)", worst["om"] < tol, f"{float(worst['om']):.1e}")
    report("h - sin(h), sinh(h) - h: truncated series within 1e-9 below 1",
           worst["series"] < 1e-9, f"{float(worst['series']):.1e}")
    return all(ok for _, ok in results)


# ----------------------------------------------------------------------------
# reference: Vicanek's formulas, as the original library code writes them


def vicanek_resonant(kind, CF, Q, G, SR, M):
    """a1, a2, b0, b1, b2 of the original code, with the math module M (mpmath or numpy)."""
    one = M.mpf(1) if M.__name__ == "mpmath" else M.float32(1) if M is _NP32 else 1.0
    c = lambda v: one * v
    q = c(1) / (c(2) * c(Q))
    w = c(2) * c(M.pi) * c(CF) / c(SR)
    if q <= 1:
        a1 = c(-2) * M.exp(-q * w) * M.cos(M.sqrt(c(1) - q * q) * w)
    else:
        a1 = c(-2) * M.exp(-q * w) * M.cosh(M.sqrt(q * q - c(1)) * w)
    a2 = M.exp(c(-2) * q * w)
    phi1 = M.sin(c(.5) * w) ** 2
    phi0 = c(1) - phi1
    phi2 = c(4) * phi0 * phi1
    A0, A1, A2 = (c(1) + a1 + a2) ** 2, (c(1) - a1 + a2) ** 2, c(-4) * a2
    RA = A0 * phi0 + A1 * phi1 + A2 * phi2
    Q, G = c(Q), c(G)
    if kind == "lowpass":
        B1 = (RA * Q * Q - A0 * phi0) / phi1
        b0 = (M.sqrt(A0) + M.sqrt(B1)) / c(2)
        return a1, a2, b0, M.sqrt(A0) - b0, c(0)
    if kind == "highpass":
        b0 = Q * M.sqrt(RA) / (c(4) * phi1)
        return a1, a2, b0, c(-2) * b0, b0
    if kind == "bandpass":
        R1, R2 = RA, -A0 + A1 + c(4) * (phi0 - phi1) * A2
        B2 = (R1 - R2 * phi1) / (c(4) * phi1 * phi1)
        B1 = R2 + c(4) * (phi1 - phi0) * B2
        b1 = c(-.5) * M.sqrt(B1)
        b0 = c(.5) * (M.sqrt(B2 + b1 * b1) - b1)
        return a1, a2, b0, b1, -(b0 + b1)
    R1, R2 = RA * G * G, (-A0 + A1 + c(4) * (phi0 - phi1) * A2) * G * G
    B2 = (R1 - R2 * phi1 - A0) / (c(4) * phi1 * phi1)
    B1 = R2 + A0 + c(4) * (phi1 - phi0) * B2
    Wd = c(.5) * (M.sqrt(A0) + M.sqrt(B1))
    b0 = c(.5) * (Wd + M.sqrt(Wd * Wd + B2))
    return a1, a2, b0, c(.5) * (M.sqrt(A0) - M.sqrt(B1)), -B2 / (c(4) * b0)


def vicanek_shelf(kind, G, CF, SR, M):
    """a1, a2 and the numerator normalized to a DC gain 1, of the original code."""
    one = M.mpf(1) if M.__name__ == "mpmath" else M.float32(1) if M is _NP32 else 1.0
    c = lambda v: one * v
    G = c(G)
    gn, Gd = (c(1) / G, G) if kind == "lowshelf" else (G, c(1) / G)
    f = c(CF) / (c(SR) * c(.5))
    f4 = f ** 4
    hny = (f4 + gn) / (f4 + Gd)
    f1 = f / M.sqrt(c(.160) + c(1.543) * f * f)
    h1 = (f4 + f1 ** 4 * gn) / (f4 + f1 ** 4 * Gd)
    p1 = M.sin(c(M.pi) * c(.5) * f1) ** 2
    f2 = f / M.sqrt(c(.947) + c(3.806) * f * f)
    h2 = (f4 + f2 ** 4 * gn) / (f4 + f2 ** 4 * Gd)
    p2 = M.sin(c(M.pi) * c(.5) * f2) ** 2
    d1, d2 = (h1 - c(1)) * (c(1) - p1), (h2 - c(1)) * (c(1) - p2)
    c11, c12 = -p1 * d1, p1 * p1 * (hny - h1)
    c21, c22 = -p2 * d2, p2 * p2 * (hny - h2)
    al = (c22 * d1 - c12 * d2) / (c11 * c22 - c12 * c21)
    aa1 = (d1 - c11 * al) / c12
    bb1 = hny * aa1
    aa2, bb2 = c(.25) * (al - aa1), c(.25) * (al - bb1)
    v, w = c(.5) * (c(1) + M.sqrt(aa1)), c(.5) * (c(1) + M.sqrt(bb1))
    a0 = c(.5) * (v + M.sqrt(v * v + aa2))
    b0 = c(.5) * (w + M.sqrt(w * w + bb2)) / a0
    return (c(1) - v) / a0, c(-.25) * aa2 / (a0 * a0), b0, (c(1) - w) / a0, (c(-.25) * bb2 / b0) / (a0 * a0)


class _NP32:
    """numpy in float32, with the few names the formulas use."""
    __name__ = "numpy32"
    pi = np.float32(np.pi)
    exp, cos, cosh, sin, sqrt = np.exp, np.cos, np.cosh, np.sin, np.sqrt
    float32 = np.float32


class _NP64:
    __name__ = "numpy64"
    pi = np.pi
    exp, cos, cosh, sin, sqrt = np.exp, np.cos, np.cosh, np.sin, np.sqrt


_NP32 = _NP32()


def to_form(kind, a1, a2, b0, b1, b2, mp):
    """P, fq, k, (n0, n1, n2) of a filter, computed exactly (mpmath) from its coefficients."""
    a1, a2, b0, b1, b2 = (mp.mpf(float(x)) if not isinstance(x, mp.mpf) else x
                          for x in (a1, a2, b0, b1, b2))
    P, fq = 1 + a1 + a2, 1 - a2
    if kind in ("lowpass", "bandpass"):
        return P, fq, mp.mpf(0), (b0, b1, b2)
    if kind == "highpass":
        return P, fq, b0, (mp.mpf(0), -b0 * (P + fq), b0 * fq)
    if kind == "peaking":
        return P, fq, mp.mpf(1), (b0 - 1, b1 - a1, b2 - a2)
    cc = (b0 - b1 + b2) / (1 - a1 + a2)      # shelves: Nyquist gain, B/A = c + R/A
    return P, fq, cc, (b0 - cc, b1 - cc * a1, b2 - cc * a2)


def form_error(got, ref):
    """Largest relative error of P, fq, k and of the numerator; inf if not finite."""
    gP, gfq, gk, gn = (float(got[0]), float(got[1]), float(got[2]), [float(x) for x in got[3]])
    if not all(np.isfinite([gP, gfq, gk, *gn])):
        return float("inf")
    rP, rfq, rk, rn = (float(ref[0]), float(ref[1]), float(ref[2]), [float(x) for x in ref[3]])
    e = max(abs(gP - rP) / abs(rP), abs(gfq - rfq) / abs(rfq))
    e = max(e, abs(gk - rk) / abs(rk) if rk != 0 else abs(gk))
    scale = max(abs(x) for x in rn)
    return max(e, max(abs(g - r) for g, r in zip(gn, rn)) / scale)


# ----------------------------------------------------------------------------
# the Faust code


def grid(args):
    g = QUICK if args.quick else dict(rates=RATES, cfs=CFS, qs=QS, peak_gs=PEAK_GS, shelf_gs=SHELF_GS)
    resonant = [(cf, q, gg) for cf in g["cfs"] for q in g["qs"] for gg in g["peak_gs"]]
    shelves = [(cf, gg) for cf in g["cfs"] for gg in g["shelf_gs"]]
    return g["rates"], resonant, shelves


def faust_program(resonant, shelves):
    table = lambda vals: "waveform{" + ",".join(repr(float(v)) for v in vals) + "}, i : rdtable"
    n = max(len(resonant), len(shelves))
    out = ",\n    ".join(f"(c.P, c.fq, c.k, c.n0, c.n1, c.n2 with {{ c = v._{k}2MatchedCoefs({a}); }})"
                         for k, a in (("lowpass", "cf, qq"), ("highpass", "cf, qq"),
                                      ("bandpass", "cf, qq"), ("peaking", "gg, cf, qq")))
    return f'''v = library("vaeffects.lib");
ba = library("basics.lib");
i = ba.time % {n};
cf = {table([r[0] for r in resonant] + [0] * (n - len(resonant)))};
qq = {table([r[1] for r in resonant] + [1] * (n - len(resonant)))};
gg = {table([r[2] for r in resonant] + [1] * (n - len(resonant)))};
scf = {table([s[0] for s in shelves] + [1000] * (n - len(shelves)))};
sg = {table([s[1] for s in shelves] + [2] * (n - len(shelves)))};
process = {out},
    (c.P, c.fq, c.k, c.n0, c.n1, c.n2 with {{ c = v._shelf2Matched(1.0 / sg, sg, scf); }}),
    (c.P, c.fq, c.k, c.n0, c.n1, c.n2 with {{ c = v._shelf2Matched(sg, 1.0 / sg, scf); }});
'''


def build(dsp, precision, build_dir, args):
    exe = os.path.join(build_dir, f"matched.{precision}")
    cpp = exe + ".cpp"
    r = subprocess.run([args.faust, *shlex.split(args.faust_options), f"-{precision}",
                        "-I", ROOT, "-a", ARCH, dsp, "-o", cpp],
                       capture_output=True, text=True, cwd=ROOT)
    if r.returncode != 0:
        sys.exit("faust: " + r.stderr.strip())
    r = subprocess.run([args.cxx, *shlex.split(args.cxx_options), "-std=c++17", cpp, "-o", exe],
                       capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit("c++: " + r.stderr.strip().splitlines()[0])
    return exe


def render(exe, sr, frames):
    with tempfile.NamedTemporaryFile(suffix=".raw", delete=False) as t:
        path = t.name
    subprocess.run([exe, str(frames), str(sr), path], check=True, capture_output=True)
    with open(path, "rb") as f:
        channels = int(np.frombuffer(f.read(4), dtype=np.int32)[0])
        data = np.frombuffer(f.read(), dtype=np.float64)
    os.remove(path)
    return data.reshape(-1, channels)


def check_coefficients(args):
    import mpmath as mp
    mp.mp.dps = 60
    rates, resonant, shelves = grid(args)
    build_dir = args.build_dir or tempfile.mkdtemp(prefix="verify_matched2_")
    os.makedirs(build_dir, exist_ok=True)
    dsp = os.path.join(build_dir, "matched.dsp")
    with open(dsp, "w") as f:
        f.write(faust_program(resonant, shelves))
    frames = max(len(resonant), len(shelves))
    stats, cases = {}, []

    def add(filt, version, err, case):
        st = stats.setdefault((filt, version), {"cases": 0, "nonfinite": 0, "over_1e-3": 0,
                                                "over_1e-5": 0, "max": 0.0, "at": None})
        st["cases"] += 1
        if not np.isfinite(err):
            st["nonfinite"] += 1
            st["over_1e-3"] += 1
            st["over_1e-5"] += 1
            return
        st["over_1e-3"] += err > 1e-3
        st["over_1e-5"] += err > 1e-5
        if err > st["max"]:
            st["max"], st["at"] = err, case

    ref_cache = {}

    def reference(kind, params, sr, precision):
        # CF, Q and G as the build sees them: rounded to float in -single.
        rounded = tuple(float(np.float32(p)) if precision == "single" else p for p in params)
        key = (kind, rounded, sr)
        if key not in ref_cache:
            if kind in RESONANT:
                cf, q, gg = rounded
                ref_cache[key] = to_form(kind, *vicanek_resonant(kind, cf, q, gg, sr, mp), mp)
            else:
                cf, gg = rounded
                ref_cache[key] = None if gg == 1 else to_form(kind, *vicanek_shelf(kind, gg, cf, sr, mp), mp)
        return ref_cache[key]

    for precision in ("single", "double"):
        exe = build(dsp, precision, build_dir, args)
        for sr in rates:
            out = render(exe, sr, frames)
            for i, (cf, q, gg) in enumerate(resonant):
                if cf >= sr / 2:
                    continue
                for j, kind in enumerate(RESONANT):
                    if kind != "peaking" and gg != resonant[0][2]:
                        continue          # G only matters for the peaking filter
                    o = out[i, 6 * j:6 * j + 6]
                    got = (o[0], o[1], o[2], o[3:6])
                    err = form_error(got, reference(kind, (cf, q, gg), sr, precision))
                    add(kind, "new " + precision, err, dict(sr=sr, cf=cf, q=q, g=gg))
            for i, (cf, gg) in enumerate(shelves):
                if cf >= sr / 2:
                    continue
                for j, kind in enumerate(SHELVES):
                    o = out[i, 24 + 6 * j:30 + 6 * j]
                    ref = reference(kind, (cf, gg), sr, precision)
                    if ref is None:
                        # G = 1: the identity, k = 1 and a zero numerator, with finite P and fq.
                        ok = (np.isfinite(o).all() and o[2] == 1.0 and not o[3:].any())
                        err = 0.0 if ok else float("inf")
                    else:
                        err = form_error((o[0], o[1], o[2], o[3:6]), ref)
                    add(kind, "new " + precision, err, dict(sr=sr, cf=cf, g=gg))

    if args.old:
        for version, M, precision in (("old single", _NP32, "single"), ("old double", _NP64, "double")):
            with np.errstate(all="ignore"):
                for sr in rates:
                    for cf, q, gg in resonant:
                        if cf >= sr / 2:
                            continue
                        for kind in RESONANT:
                            if kind != "peaking" and gg != resonant[0][2]:
                                continue
                            coefs = vicanek_resonant(kind, cf, q, gg, sr, M)
                            err = (float("inf") if not np.isfinite(np.array(coefs, dtype=float)).all()
                                   else form_error(to_form(kind, *coefs, mp),
                                                   reference(kind, (cf, q, gg), sr, precision)))
                            add(kind, version, err, dict(sr=sr, cf=cf, q=q, g=gg))
                    for cf, gg in shelves:
                        if cf >= sr / 2:
                            continue
                        for kind in SHELVES:
                            ref = reference(kind, (cf, gg), sr, precision)
                            coefs = vicanek_shelf(kind, gg, cf, sr, M)
                            finite = np.isfinite(np.array(coefs, dtype=float)).all()
                            err = (float("inf") if not finite or ref is None
                                   else form_error(to_form(kind, *coefs, mp), ref))
                            add(kind, version, err, dict(sr=sr, cf=cf, g=gg))

    print(f"coefficients against Vicanek's formulas at 60 digits "
          f"({len(rates)} rates, faust {args.faust_options or '(no option)'}, c++ {args.cxx_options}):")
    print("| filter | version | cases | non-finite | error > 1e-3 | error > 1e-5 | max error |")
    print("|---|---|---|---|---|---|---|")
    failed = False
    for kind in RESONANT + SHELVES:
        for version in ("old single", "old double", "new single", "new double"):
            st = stats.get((kind, version))
            if not st:
                continue
            print(f"| {kind} | {version} | {st['cases']} | {st['nonfinite']} | {st['over_1e-3']} "
                  f"| {st['over_1e-5']} | {st['max']:.1e} |")
            if version.startswith("new") and (st["nonfinite"] or st["max"] > THRESHOLDS[version[4:]]):
                failed = True
                print(f"  [FAIL] {kind} {version}: worst {st['max']:.1e} at {st['at']}, "
                      f"threshold {THRESHOLDS[version[4:]]:g}")
    if args.json:
        with open(args.json, "w") as f:
            json.dump({f"{k} {v}": st for (k, v), st in stats.items()}, f, indent=1)
    return not failed


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("what", nargs="?", default="all", choices=["all", "identities", "coefficients"])
    p.add_argument("--quick", action="store_true", help="a small grid (2 rates, 3 CF, 3 Q)")
    p.add_argument("--old", action="store_true",
                   help="also evaluate the original library code (numpy float32/float64)")
    p.add_argument("--faust", default=os.environ.get("FAUST", "faust"))
    p.add_argument("--cxx", default=os.environ.get("CXX", "c++"))
    p.add_argument("--faust-options", default="", help='e.g. --faust-options=-vec')
    p.add_argument("--cxx-options", default="-O2", help='e.g. --cxx-options="-O3 -ffast-math"')
    p.add_argument("--build-dir", help="where to build (default: a temporary directory)")
    p.add_argument("--json", help="write the statistics to this file")
    args = p.parse_args()
    try:
        import mpmath  # noqa: F401
        import sympy  # noqa: F401
    except ImportError as e:
        sys.exit(f"{e.name} is needed: pip install sympy mpmath")
    ok = True
    if args.what in ("all", "identities"):
        print("identities:")
        ok = check_identities() and ok
    if args.what in ("all", "coefficients"):
        ok = check_coefficients(args) and ok
    print("\nverify_matched2: " + ("all checks pass" if ok else "FAILED"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
