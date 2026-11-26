#!/usr/bin/env python3
"""The coefficients of fastmath.lib, and the error of each approximation.

Each approximation is a polynomial in a reduced variable (a rational
function for the single-precision tanpi and tanh), fitted on the reduced
range of fastmath.lib's code:

- single precision (and the `faster` tier, in both precisions): minimax by
  Lawson's algorithm (iteratively reweighted least squares, which converges
  to the minimax solution) in float64, rational functions by Loeb's
  linearization with the same weights;
- double precision: Chebyshev interpolation in mpmath at 50 digits
  (`mpmath.chebyfit`, within a small factor of the minimax error), of a
  degree that brings the error of the exact coefficients below 1e-17.

The errors printed are those of the exact coefficients, in float64 or at 50
digits; the evaluation in the program's precision adds its rounding, which
is what the doc blocks of fastmath.lib give (measured on the compiled
code). The output is Faust: the definitions to paste.

    scripts/fit_fastmath.py
"""
import mpmath as mp
import numpy as np

GRID = 20001
mp.mp.dps = 50


# ---------------------------------------------------------------------------------------------
# Single precision: Lawson minimax in float64
# ---------------------------------------------------------------------------------------------

def lawson(basis, target, weight, iters=400):
    """Minimize max |weight * (basis @ c - target)| over the grid."""
    A = basis * weight[:, None]
    b = target * weight
    w = np.ones(len(b)) / len(b)
    for _ in range(iters):
        sw = np.sqrt(w)
        c, *_ = np.linalg.lstsq(A * sw[:, None], b * sw, rcond=None)
        e = np.abs(A @ c - b)
        w = w * e
        s = w.sum()
        if s == 0:
            break
        w /= s
    return c, np.max(np.abs(A @ c - b))


def exp2_frac(deg):
    """2^f = 1 + f p(f), f in [-1/2, 1/2], relative error."""
    f = np.linspace(-0.5, 0.5, GRID)
    basis = np.stack([f ** (k + 1) for k in range(deg)], axis=1)
    c, err = lawson(basis, 2.0 ** f - 1.0, 1.0 / 2.0 ** f)
    return [1.0] + list(c), err


def log2_mant(deg):
    """log2(1 + u) = u p(u), 1 + u in [sqrt(1/2), sqrt(2)], absolute error."""
    u = np.linspace(np.sqrt(0.5) - 1.0, np.sqrt(2.0) - 1.0, GRID)
    basis = np.stack([u ** (k + 1) for k in range(deg)], axis=1)
    c, err = lawson(basis, np.log2(1.0 + u), np.ones_like(u))
    return list(c), err


def expm1_red(deg):
    """e^r - 1 = r p(r), r in [-0.35, 0.35] (ln 2 / 2 and a margin), relative error: p is fitted
    to (e^r - 1)/r with the weight r/(e^r - 1)."""
    r = np.linspace(-0.35, 0.35, GRID)
    t = np.where(r == 0, 1.0, np.expm1(r) / np.where(r == 0, 1.0, r))
    basis = np.stack([r ** k for k in range(deg)], axis=1)
    c, err = lawson(basis, t, 1.0 / t)
    return list(c), err


def log1p_mant(deg):
    """log(1 + f) = f p(f), 1 + f in [sqrt(1/2), sqrt(2)], relative error: p is fitted to
    log(1 + f)/f with the weight f/log(1 + f)."""
    f = np.linspace(np.sqrt(0.5) - 1.0, np.sqrt(2.0) - 1.0, GRID)
    t = np.where(f == 0, 1.0, np.log1p(f) / np.where(f == 0, 1.0, f))
    basis = np.stack([f ** k for k in range(deg)], axis=1)
    c, err = lawson(basis, t, 1.0 / t)
    return list(c), err


def sin2pi(deg):
    """sin(2 pi s) = s p(s^2), s in [-1/4, 1/4], absolute error (odd degree deg)."""
    s = np.linspace(0.0, 0.25, GRID)
    basis = np.stack([s ** (2 * k + 1) for k in range((deg + 1) // 2)], axis=1)
    c, err = lawson(basis, np.sin(2 * np.pi * s), np.ones_like(s))
    return list(c), err


def rational_fit(x, t, nnum, nden, iters, relative):
    """Odd rational x P(x^2) / Q(x^2), Q(0) = 1: Loeb's iteration with Lawson weights."""
    x2 = x * x
    q = np.ones_like(x)
    w = np.ones_like(x) / len(x)
    best = None
    for _ in range(iters):
        A = np.concatenate([np.stack([x * x2 ** k for k in range(nnum)], axis=1),
                            np.stack([-t * x2 ** (k + 1) for k in range(nden)], axis=1)], axis=1)
        scale = 1.0 / q / (np.abs(t) if relative else 1.0)
        for _ in range(30):
            sw = np.sqrt(w) * scale
            c, *_ = np.linalg.lstsq(A * sw[:, None], t * sw, rcond=None)
            e = np.abs(A @ c - t) * scale
            w = w * e
            w /= w.sum()
        P = sum(c[k] * x2 ** k for k in range(nnum))
        Q = 1.0 + sum(c[nnum + k] * x2 ** (k + 1) for k in range(nden))
        err = np.abs(x * P / Q - t) / (np.abs(t) if relative else 1.0)
        if best is None or err.max() < best[1]:
            best = (list(c[:nnum]), [1.0] + list(c[nnum:])), err.max()
        q = Q
    return best


def tanpi_rational():
    """tan(pi s) = s P(s^2) / Q(s^2), s in [0, 1/4], relative error."""
    s = np.linspace(1e-6, 0.25, GRID)
    return rational_fit(s, np.tan(np.pi * s), 2, 2, 60, relative=True)


def tanh_rational():
    """tanh(x) = x P(x^2) / Q(x^2), x in [0, 9], absolute error."""
    x = np.linspace(1e-6, 9.0, GRID)
    return rational_fit(x, np.tanh(x), 4, 3, 60, relative=False)


# ---------------------------------------------------------------------------------------------
# Double precision: Chebyshev interpolation in mpmath
# ---------------------------------------------------------------------------------------------

def chebyfit(f, a, b, n):
    """Coefficients, constant first, of the degree-n Chebyshev interpolant of f on [a, b], and
    the largest error of these coefficients rounded to double, on 2001 points (mpmath's own
    estimate is unreliable for some degrees)."""
    poly = mp.chebyfit(f, [a, b], n + 1)
    cs = [float(c) for c in reversed(poly)]
    err = max(abs(mp.polyval([mp.mpf(c) for c in reversed(cs)], x) - f(x))
              for x in mp.linspace(a, b, 2001))
    return cs, float(err)


def dexp2():
    """2^f = 1 + f H(f), H(f) = (2^f - 1) / f, f in [-1/2, 1/2]."""
    H = lambda f: mp.log(2) if f == 0 else (mp.power(2, f) - 1) / f
    c, e = chebyfit(H, mp.mpf(-0.5), mp.mpf(0.5), 10)
    return [1.0] + c, e * 0.5


def dlog2():
    """log2(m) = t L(t^2), t = (m - 1)/(m + 1), m in [sqrt(1/2), sqrt(2)]."""
    tmax = (mp.sqrt(2) - 1) / (mp.sqrt(2) + 1)
    L = lambda z: 2 / mp.log(2) if z == 0 else mp.log((1 + mp.sqrt(z)) / (1 - mp.sqrt(z)), 2) / mp.sqrt(z)
    c, e = chebyfit(L, mp.mpf(0), tmax ** 2, 7)
    return c, e * float(tmax)


def dexpm1():
    """e^r - 1 = r E(r), r in [-0.35, 0.35]."""
    E = lambda r: mp.mpf(1) if r == 0 else mp.expm1(r) / r
    c, e = chebyfit(E, mp.mpf(-0.35), mp.mpf(0.35), 11)
    return c, e


def dlog1p():
    """log(m) = t L(t^2), t = (m - 1)/(m + 1), m in [sqrt(1/2), sqrt(2)]: dlog2 in natural
    units."""
    tmax = (mp.sqrt(2) - 1) / (mp.sqrt(2) + 1)
    L = lambda z: mp.mpf(2) if z == 0 else mp.log((1 + mp.sqrt(z)) / (1 - mp.sqrt(z))) / mp.sqrt(z)
    c, e = chebyfit(L, mp.mpf(0), tmax ** 2, 7)
    return c, e * float(tmax)


def dsin2pi():
    """sin(2 pi s) = s S(s^2), s in [0, 1/4]."""
    S = lambda z: 2 * mp.pi if z == 0 else mp.sin(2 * mp.pi * mp.sqrt(z)) / mp.sqrt(z)
    c, e = chebyfit(S, mp.mpf(0), mp.mpf(1) / 16, 8)
    return c, e * 0.25


def dtanh():
    """tanh(x) = x T(x^2), x in [0, 1/4]."""
    T = lambda z: mp.mpf(1) if z == 0 else mp.tanh(mp.sqrt(z)) / mp.sqrt(z)
    c, e = chebyfit(T, mp.mpf(0), mp.mpf(1) / 16, 7)
    return c, e * 0.25


def sinr(cs):
    """sin(r) = r p(r^2), r in [-pi/2, pi/2]: the sin2pi polynomial in s = r/(2 pi), rescaled
    (the same absolute error)."""
    return [float(mp.mpf(c) / (2 * mp.pi) ** (2 * k + 1)) for k, c in enumerate(cs)]


def pi_parts(bits, last, value=None):
    """pi = P1 + P2 + P3, P1 and P2 rounded to bits[0] and bits[1] significant bits (so that
    k P1 and k P2 are exact for a k of up to 24 - bits bits in single precision, 53 - bits in
    double), P3 the rest rounded to `last` bits; and the residual pi - P1 - P2 - P3. Another
    `value` (ln 2) is split the same way, in len(bits) + 1 parts."""
    parts, rem = [], +(mp.pi if value is None else value)
    for b in bits + (last,):
        e = int(mp.floor(mp.log(abs(rem), 2)))
        q = mp.nint(rem * mp.mpf(2) ** (b - 1 - e)) / mp.mpf(2) ** (b - 1 - e)
        parts.append(float(q))
        rem -= q
    return parts, float(rem)


def faust(name, cs):
    body = ", ".join(f"{c:.17g}" for c in cs)
    return f"{name} = ({body});"


def main():
    c, e = exp2_frac(5)
    print(f"// exp2, single: relative error {e:.2g}\n{faust('_FM_EXP2', c)}")
    c, e = exp2_frac(3)
    print(f"// exp2, faster: relative error {e:.2g}\n{faust('_FM_EXP2_FASTER', c)}")
    c, e = dexp2()
    print(f"// exp2, double: relative error {e:.2g}\n{faust('_FM_EXP2', c)}")
    c, e = log2_mant(8)
    print(f"// log2 mantissa, single, u = m - 1: absolute error {e:.2g}\n{faust('_FM_LOG2', c)}")
    c, e = log2_mant(5)
    print(f"// log2 mantissa, faster: absolute error {e:.2g}\n{faust('_FM_LOG2_FASTER', c)}")
    c, e = dlog2()
    print(f"// log2 mantissa, double, t = (m - 1)/(m + 1), in t^2: absolute error {e:.2g}\n"
          f"{faust('_FM_LOG2', c)}")
    c, e = sin2pi(9)
    print(f"// sin2pi, single, in s^2: absolute error {e:.2g}\n{faust('_FM_SIN2PI', c)}")
    c, e = sin2pi(5)
    print(f"// sin2pi, faster: absolute error {e:.2g}\n{faust('_FM_SIN2PI_FASTER', c)}")
    c, e = dsin2pi()
    print(f"// sin2pi, double, in s^2: absolute error {e:.2g}\n{faust('_FM_SIN2PI', c)}")
    c, e = sin2pi(9)
    print(f"// sin(r), single, in r^2: absolute error {e:.2g}\n{faust('_FA_SINR', sinr(c))}")
    c, e = dsin2pi()
    print(f"// sin(r), double, in r^2: absolute error {e:.2g}\n{faust('_FA_SINR', sinr(c))}")
    for prec, bits, last in (("single", (8, 8), 24), ("double", (29, 29), 53)):
        p, rem = pi_parts(bits, last)
        print(f"// pi in three parts, {prec}: residual {rem:.2g}\n{faust('_FA_PI3', p)}")
    for prec, bits, last in (("single", (17,), 24), ("double", (43,), 53)):
        p, rem = pi_parts(bits, last, mp.log(2))
        print(f"// ln 2 in two parts, {prec}: residual {rem:.2g}\n{faust('_FA_LN2', p)}")
    c, e = expm1_red(6)
    print(f"// expm1, single, in r: relative error {e:.2g}\n{faust('_FA_EXPM1', c)}")
    c, e = dexpm1()
    print(f"// expm1, double, in r: relative error {e:.2g}\n{faust('_FA_EXPM1', c)}")
    c, e = log1p_mant(9)
    print(f"// log1p mantissa, single, in f = m - 1: relative error {e:.2g}\n{faust('_FA_LOG1P', c)}")
    c, e = dlog1p()
    print(f"// log1p mantissa, double, t = (m - 1)/(m + 1), in t^2: absolute error {e:.2g}\n"
          f"{faust('_FA_LOG1P', c)}")
    (p, q), e = tanpi_rational()
    print(f"// tanpi, single, rational: relative error {e:.2g}\n{faust('_FM_TANPI_P', p)}\n"
          f"{faust('_FM_TANPI_Q', q)}")
    (p, q), e = tanh_rational()
    print(f"// tanh, single, rational on [0, 9]: absolute error {e:.2g}\n{faust('_FM_TANH_P', p)}\n"
          f"{faust('_FM_TANH_Q', q)}")
    c, e = dtanh()
    print(f"// tanh, double, x in [0, 1/4], in x^2: absolute error {e:.2g}\n{faust('_FM_TANH', c)}")


if __name__ == "__main__":
    main()
