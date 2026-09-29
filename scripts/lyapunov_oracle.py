#!/usr/bin/env python3
"""Untrusted oracle for the Lyapunov-Krasovskii certificates of the Lean rate
analysis (formalisation/signal-import-formal-spec.lean, section "Lyapunov-
Krasovskii certificates").

The Lean probe prints, for every recursion group and rate that Jury and the
small-gain test leave unproven, the linear system it built:

    L|group|rate|nx nl|chan ...|row;row;...

(rows of G = [[A, B], [Cx, Cz]] over nx states and nl channels, sparse,
`col:lo/den:hi/den`; each channel as `output:delay`). This script answers with

    W|group|rate|D row;D row;...|P row;P row;...

where D (symmetric, block diagonal: one block per delay) weights the energy of
the delay lines and P (symmetric) the energy of the states, both as dyadic
rationals. Lean checks the answer
exactly (P > 0, diag(P, D) - G^T H G > 0 on the whole box of coefficients);
nothing computed here is trusted, and a wrong or missing answer only leaves the
group unproven.

How: D = L^T L, with L block diagonal minimizing the peak over frequency of
the largest singular value of L K(w) L^-1 (K: from the channels back to the
channels through the states; a structured small-gain bound, whose blocks are
the channels that share a delay), and P is the stabilizing solution of the
bounded-real Riccati equation for that D, with a small margin. Needs numpy and
scipy.

    scripts/lyapunov_oracle.py < requests > answers
"""

import os
import sys
import warnings
from fractions import Fraction

# One BLAS thread: a multithreaded BLAS may sum in an order that depends on
# the load of the machine, and a certificate near the limit would then be
# accepted on one run and rejected on the next.
for _var in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS",
             "VECLIB_MAXIMUM_THREADS"):
    os.environ.setdefault(_var, "1")

import numpy as np  # noqa: E402
import scipy.linalg as sl  # noqa: E402
import scipy.optimize as so  # noqa: E402

# overflows while the search wanders: the answer is checked, not trusted
warnings.filterwarnings("ignore", category=RuntimeWarning, module=__name__)
warnings.filterwarnings("ignore", category=sl.LinAlgWarning)



def parse_request(line):
    _, group, rate, dims, chan, rows = line.rstrip("\n").split("|", 5)
    nx, nl = map(int, dims.split())
    chan = [tuple(map(int, c.split(":"))) for c in chan.split()]
    rows = rows.split(";") if rows else []
    n = nx + nl
    G = np.zeros((len(rows), n))
    R = np.zeros((len(rows), n))
    for r, row in enumerate(rows):
        for entry in filter(None, row.split(",")):
            k, lo, hi = entry.split(":")
            lo, hi = Fraction(lo), Fraction(hi)
            G[r, int(k)] += float((lo + hi) / 2)
            R[r, int(k)] += float((hi - lo) / 2)
    nf = len(rows) - nx
    Wmap = np.zeros((nf, nl))
    for j, (f, _) in enumerate(chan):
        Wmap[f, j] = 1.0
    bases = sorted({b for _, b in chan})
    blocks = [[j for j, (_, b) in enumerate(chan) if b == base] for base in bases]
    return int(group), int(rate), nx, nl, G, R, Wmap, blocks


def loop_matrices(A, B, Cx, Cz, Wmap, ws):
    """K(w) = Wmap^T (Cz + Cx (e^jw - A)^-1 B): channels back to channels."""
    n = A.shape[0]
    out = []
    for w in ws:
        z = np.exp(1j * w)
        T = Cz + (Cx @ np.linalg.solve(z * np.eye(n) - A, B) if n else 0)
        out.append(Wmap.T @ T)
    return np.array(out)


def channel_weights(K, blocks, iters=200):
    """A block-diagonal L (one full block per delay: the channels of a block
    see the same delay, so any scaling inside the block commutes with it)
    minimizing max_w sigma_max(L K(w) L^-1), smoothed; D = L^T L."""
    nl = K.shape[1]
    mask = np.zeros((nl, nl), dtype=bool)
    for b in blocks:
        mask[np.ix_(b, b)] = True
    idx = np.nonzero(mask)

    def unpack(v):
        L = np.zeros((nl, nl))
        L[idx] = v
        return L

    def f(v, beta=60.0):
        L = unpack(v)
        try:
            Li = np.linalg.inv(L)
        except np.linalg.LinAlgError:
            return 1e9, np.zeros_like(v)
        X = L[None] @ K @ Li[None]
        if not np.isfinite(X).all():
            return 1e9, np.zeros_like(v)
        U, sv, Vh = np.linalg.svd(X)
        sig = sv[:, 0]
        m = sig.max()
        e = np.exp(beta * (sig - m))
        wts = e / e.sum()
        u = U[:, :, 0]
        v_ = Vh[:, 0, :].conj()
        # d sigma = sigma Re(u^H E u - v^H E v), E = dL L^-1
        GE = (wts[:, None, None] * sig[:, None, None] *
              np.real(np.conj(u)[:, :, None] * u[:, None, :] -
                      np.conj(v_)[:, :, None] * v_[:, None, :])).sum(0)
        GL = GE @ Li.T
        return m + np.log(e.sum()) / beta, GL[idx]

    r = so.minimize(f, np.eye(nl)[idx], jac=True, method="L-BFGS-B", options={"maxiter": iters})
    L = unpack(r.x)
    L /= np.abs(np.linalg.det(L)) ** (1 / nl) if nl else 1
    X = L[None] @ K @ np.linalg.inv(L)[None]
    return L.T @ L, np.linalg.svd(X, compute_uv=False)[:, 0].max()


def norm2_bound(X):
    """sqrt(||X||_1 ||X||_inf), an upper bound of the spectral norm."""
    return np.sqrt(np.abs(X).sum(0).max() * np.abs(X).sum(1).max()) if X.size else 0.0


def robust(P, D, G, R, Wmap):
    """Float estimate of Lean's check, relative to the size of M: the
    smallest eigenvalue of M at the center of the box, less a bound of its
    variation over the box, divided by the largest entry of M."""
    nx = P.shape[0]
    H = sl.block_diag(P, Wmap @ D @ Wmap.T)
    M = sl.block_diag(P, D) - G.T @ H @ G
    if not M.size:
        return 1.0
    lam = np.linalg.eigvalsh((M + M.T) / 2).min()
    spread = 2 * norm2_bound(H @ G) * norm2_bound(R) + norm2_bound(H) * norm2_bound(R) ** 2
    if nx and np.linalg.eigvalsh(P).min() <= 0:
        return -1.0
    return (lam - spread) / max(np.abs(M).max(), 1e-300)


def certificate(nx, nl, G, R, Wmap, blocks):
    """Among a few Riccati margins, the certificate whose float estimate of
    the check has the largest relative slack: a certificate far from the
    limit gets the same verdict from Lean on every run and platform."""
    best, best_slack = None, None
    for eps in (1e-6, 1e-4, 1e-3, 1e-2, 3e-2, 1e-1):
        try:
            cert = certificate_at(nx, nl, G, Wmap, blocks, eps)
        except (np.linalg.LinAlgError, ValueError):
            continue
        if cert is None:
            break
        slack = robust(*cert, G, R, Wmap)
        if best_slack is None or slack > best_slack:
            best, best_slack = cert, slack
    return best


def certificate_at(nx, nl, G, Wmap, blocks, eps):
    A, B = G[:nx, :nx], G[:nx, nx:]
    Cx, Cz = G[nx:, :nx], G[nx:, nx:]
    if nx and np.abs(np.linalg.eigvals(A)).max() >= 1:
        return None
    D = np.eye(nl)
    if nl:
        ws = np.concatenate([np.linspace(0, np.pi, 128), np.geomspace(1e-5, 0.1, 32),
                             np.pi - np.geomspace(1e-5, 0.1, 32)])
        D, peak = channel_weights(loop_matrices(A, B, Cx, Cz, Wmap, ws), blocks)
        if not peak < 1:
            return None
    if nx == 0:
        return np.zeros((0, 0)), D
    # W = Wmap D Wmap^T = Wh^T Wh; D = Ld^T Ld
    lam, V = np.linalg.eigh(Wmap @ D @ Wmap.T)
    Wh = (V * np.sqrt(np.clip(lam, 0, None))).T
    Ld = np.linalg.cholesky(D).T if nl else np.zeros((0, 0))
    Si = np.linalg.inv(Ld) if nl else Ld
    Bt, Cxt, Czt = B @ Si, Wh @ Cx, Wh @ Cz @ Si
    if nl == 0:
        P = sl.solve_discrete_lyapunov(A.T, np.eye(nx))   # no channel: W = 0
    else:
        Q = -(Cxt.T @ Cxt) - eps * np.eye(nx)
        R = (1 - eps) * np.eye(nl) - Czt.T @ Czt
        P = -sl.solve_discrete_are(A, Bt, Q, R, s=-(Cxt.T @ Czt))
    P = (P + P.T) / 2
    return P, D


def dyadic(x, bits=40):
    """`x` rounded to `bits` significant bits, as `m/2^k`: the low bits of
    the oracle's floats vary with the platform and do not matter to a
    certificate with some margin."""
    x = float(x)
    if x == 0 or not np.isfinite(x):
        return "0/1"
    m, e = np.frexp(x)
    f = Fraction(int(round(m * 2 ** bits))) * Fraction(2) ** (int(e) - bits)
    return f"{f.numerator}/{f.denominator}"


def answer(line):
    """The `W|...` answer to one `L|...` request, or None."""
    with np.errstate(all="ignore"):
        return _answer(line)


def _answer(line):
    group, rate, nx, nl, G, R, Wmap, blocks = parse_request(line)
    try:
        cert = certificate(nx, nl, G, R, Wmap, blocks)
    except (np.linalg.LinAlgError, ValueError):
        return None
    if cert is None:
        return None
    P, D = cert
    if not (np.isfinite(P).all() and np.isfinite(D).all()):
        return None

    def rows(m):   # rounded to doubles, made exactly symmetric
        m = np.triu(m) + np.triu(m, 1).T
        return ";".join(" ".join(dyadic(x) for x in row) for row in m)
    return f"W|{group}|{rate}|{rows(D)}|{rows(P)}"


def main():
    for line in sys.stdin:
        if line.startswith("L|"):
            a = answer(line)
            if a:
                print(a, flush=True)


if __name__ == "__main__":
    main()
