#!/usr/bin/env python3
"""Feasibility spike: certify linear recursions over a sample-rate range, in
exact, double and single precision.

    float_sr_spike.py FILE.dsp [--sr 44100:192000] [--prec exact|double|single] [--mode frozen|modulated]

For every recursion group of the graph (`DEBRUIJNREC`), the body is read as an
affine function of the group's delayed outputs (the state), with coefficients
that are intervals: they depend on the sample rate, on the controls (over their
declared range), on other non-recursive signals, and, in float/double, on the
rounding of their computation (each real operation widened by one unit
roundoff, transcendental functions by two). A group that is not affine in its
state (a product of two state terms, a nonlinear function of the state, a
delay-free loop, a nested recursion coupled to it) is refused.

The state matrix A then ranges over an interval box. Up to 2 states, the Jury
conditions (1 - det > 0, 1 + det > 0, 1 - tr + det > 0, 1 + tr + det > 0) are
multilinear in the entries of A, so checking them exactly (Fractions) at the
vertices of the box is exact. Above 2 states, or in modulated mode, the group
is certified when one quadratic Lyapunov function V(x) = x'Px decreases for
every A of the box: P > 0 and P - A'PA > 0 at every vertex (an LMI, affine in
A, so the vertices suffice). P solves P - Ac'PAc = I exactly at a rational
center Ac, and the vertex check is exact: it is what Lean would do by
`decide`, the numerics only find the witness. P from Q = I is a weak witness
for ill-conditioned matrices; a real implementation would search P with an
SDP solver.

frozen    : the box is bisected over the sample rate and the controls until each
            piece is certified (stable at every fixed setting);
modulated : bisection over the sample rate only; one P per rate piece must hold
            over the whole control range (stable under arbitrary variation of
            the controls, e.g. per-sample modulation).

For each certified group it also prints gamma = ||A||_P (the contraction per
sample in the P norm, P = dlyap(A, I) at the center) and
G = sqrt(cond P) / (1 - gamma): the gain from a per-sample perturbation of the
state (a rounding error) to the state. Numerical and indicative only: it says
how much a structure amplifies its own roundoff.

A research prototype, in Python, of the algorithms proposed in
formalisation/float-sr-proposal.md; nothing here is trusted.
"""
import math, os, sys, itertools, argparse
from fractions import Fraction
import numpy as np
import scipy.linalg as sla

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
os.environ.setdefault("FAUST_RS", "faust-rs")
os.environ.setdefault("FAUST_LIBS", REPO)
sys.path.insert(0, os.path.join(REPO, "scripts"))
import sig2lean as S  # noqa: E402

INF = math.inf


class Refuse(Exception):
    pass


# ------------------------------------------------------------------ intervals

class Iv:
    __slots__ = ("lo", "hi")

    def __init__(self, lo, hi=None):
        self.lo, self.hi = lo, (lo if hi is None else hi)
        if math.isnan(self.lo) or math.isnan(self.hi):
            self.lo, self.hi = -INF, INF

    def bounded(self):
        return math.isfinite(self.lo) and math.isfinite(self.hi)

    def has0(self):
        return self.lo <= 0 <= self.hi

    def __repr__(self):
        return f"[{self.lo:.6g}, {self.hi:.6g}]"


FULL = Iv(-INF, INF)


def down(x):
    return math.nextafter(x, -INF) if math.isfinite(x) else x


def up(x):
    return math.nextafter(x, INF) if math.isfinite(x) else x


def out(lo, hi):
    """Outward-rounded interval: encloses the exact result of the double ops."""
    return Iv(down(lo), up(hi))


def prod(a, b):
    ps = []
    for x in (a.lo, a.hi):
        for y in (b.lo, b.hi):
            p = x * y
            ps.append(0.0 if math.isnan(p) else p)
    if (not a.bounded() and b.has0()) or (not b.bounded() and a.has0()):
        return FULL
    return out(min(ps), max(ps))


def quot(a, b):
    if b.has0():
        raise Refuse("division by an interval containing 0")
    return prod(a, out(1 / b.hi, 1 / b.lo))


def mono(f, a, inc=True):
    lo, hi = (f(a.lo), f(a.hi)) if inc else (f(a.hi), f(a.lo))
    return out(lo, hi)


def hull(a, b):
    return Iv(min(a.lo, b.lo), max(a.hi, b.hi))


class Prec:
    def __init__(self, name):
        self.name = name
        self.u = {"exact": 0.0, "double": 2.0 ** -53, "single": 2.0 ** -24}[name]
        self.eta = {"exact": 0.0, "double": 2.0 ** -1074, "single": 2.0 ** -149}[name]

    def rnd(self, iv, ulps=1):
        """Widen by the rounding of one operation (ulps units roundoff)."""
        if self.u == 0 or not iv.bounded():
            return iv
        e = ulps * self.u
        return out(iv.lo - e * abs(iv.lo) - self.eta, iv.hi + e * abs(iv.hi) + self.eta)

    def const(self, x):
        if self.name == "single":
            return Iv(float(np.float32(x)))
        return Iv(x)


# ------------------------------------------------------------- the graph walk

TRANS = {"SIGTAN", "SIGSIN", "SIGCOS", "SIGEXP", "SIGLOG", "SIGSQRT", "SIGPOW",
         "SIGATAN", "SIGASIN", "SIGACOS", "SIGLOG10", "SIGEXP10", "SIGTANH",
         "SIGSINH", "SIGCOSH", "SIGATAN2", "SIGFMOD", "SIGREMAINDER"}
CONTROLS = {"SIGHSLIDER", "SIGVSLIDER", "SIGNUMENTRY"}


class Graph:
    def __init__(self, dsp):
        self.b, self.roots = S.dag_of(dsp)
        self.isint = {}

    def arg_int(self, a):
        kind, v = a
        if kind == "leaf":
            return v.tag == "int"
        return self.node_int(v)

    def node_int(self, k):
        """Heuristic typing (the dump carries no types): an operation is on
        integers when all its operands are. Proposal: have faust-rs print the
        nature and interval it infers."""
        if k in self.isint:
            return self.isint[k]
        self.isint[k] = False  # recursion guard
        tag, args, rng, op = self.b[k]
        if tag in ("SIGINTCAST",):
            r = True
        elif tag == "SIGBINOP":
            r = op in ("or", "and", "xor", "lsh", "rsh", "lt", "le", "gt", "ge", "eq", "ne") or \
                all(self.arg_int(a) for a in args)
        elif tag in ("SIGDELAY1", "SIGDELAY", "SIGSELECT2", "SIGMIN", "SIGMAX", "SIGABS"):
            vals = args[1:] if tag == "SIGSELECT2" else args[:1] if tag.startswith("SIGDELAY") else args
            r = all(self.arg_int(a) for a in vals)
        else:
            r = False
        self.isint[k] = r
        return r


class Box:
    """Parameter box: sample rate and control ranges."""

    def __init__(self, sr, ctl):
        self.sr, self.ctl = sr, ctl  # sr: Iv ; ctl: {node index: Iv}


class Walker:
    """Interval ranges of non-recursive values, and affine forms of group
    bodies, for one parameter box and one precision."""

    def __init__(self, g, box, prec):
        self.g, self.box, self.p = g, box, prec
        self.rmemo, self.escmemo = {}, {}

    # -- ranges (state-independent) -----------------------------------------
    def leaf(self, v):
        if v.tag == "int":
            return Iv(float(v.val))
        if v.tag == "float":
            return self.p.const(float(v.val))
        return FULL

    def rarg(self, a):
        return self.leaf(a[1]) if a[0] == "leaf" else self.rng(a[1])

    def rng(self, k):
        if k in self.rmemo:
            return self.rmemo[k]
        self.rmemo[k] = FULL  # recursion guard (should not trigger on a DAG)
        r = self._rng(k)
        self.rmemo[k] = r
        return r

    def _rng(self, k):
        tag, args, rngd, op = self.g.b[k]
        R = [self.rarg(a) for a in args] if tag not in ("DEBRUIJNREC",) else []
        isint = self.g.node_int(k)
        p = self.p
        if tag == "SIGFCONST":
            name = args[1][1].val if args[1][0] == "leaf" else ""
            return self.box.sr if name in ("fSamplingFreq", "fSamplingRate") else FULL
        if tag in CONTROLS:
            return self.box.ctl.get(k, Iv(float(rngd["min"]), float(rngd["max"])))
        if tag in ("SIGBUTTON", "SIGCHECKBOX"):
            return Iv(0.0, 1.0)
        if tag in ("SIGINPUT", "DEBRUIJNREF", "SIGGEN", "SIGFFUN", "FFUN"):
            return FULL
        if tag == "SIGPROJ":
            # output i of a recursion: the body's range with the state unknown
            # (the state-independent invariant of the Lean prelude)
            i = int(args[0][1].val)
            rec = args[1][1]
            body = self.cons_list(self.g.b[rec][1][0])
            return self.rarg(body[i]) if i < len(body) else FULL
        if tag == "DEBRUIJNREC":
            return FULL
        if tag in ("SIGDELAY1",):
            return hull(R[0], Iv(0.0))
        if tag == "SIGDELAY":
            return hull(R[0], Iv(0.0))
        if tag == "SIGINTCAST":
            a = R[0]
            return Iv(math.floor(a.lo) if math.isfinite(a.lo) else a.lo,
                      math.ceil(a.hi) if math.isfinite(a.hi) else a.hi)
        if tag == "SIGFLOATCAST":
            return p.rnd(R[0])
        if tag == "SIGMIN":
            return Iv(min(R[0].lo, R[1].lo), min(R[0].hi, R[1].hi))
        if tag == "SIGMAX":
            return Iv(max(R[0].lo, R[1].lo), max(R[0].hi, R[1].hi))
        if tag == "SIGABS":
            a = R[0]
            if a.lo >= 0:
                return a
            if a.hi <= 0:
                return Iv(-a.hi, -a.lo)
            return Iv(0.0, max(-a.lo, a.hi))
        if tag == "SIGFLOOR":
            a = R[0]
            return Iv(math.floor(a.lo) if math.isfinite(a.lo) else a.lo,
                      math.floor(a.hi) if math.isfinite(a.hi) else a.hi)
        if tag == "SIGSELECT2":
            return hull(R[1], R[2])
        if tag == "SIGBINOP":
            a, b = R
            if op in ("lt", "le", "gt", "ge", "eq", "ne"):
                return Iv(0.0, 1.0)
            if op == "add":
                r = out(a.lo + b.lo, a.hi + b.hi)
            elif op == "sub":
                r = out(a.lo - b.hi, a.hi - b.lo)
            elif op == "mul":
                r = prod(a, b)
            elif op == "div":
                r = quot(a, b)
            elif op == "rem":
                if b.lo == b.hi and b.lo > 0:
                    m = b.lo
                    r = Iv(0.0 if a.lo >= 0 else -(m - 1) if isint else -m, m - 1 if isint else m)
                else:
                    r = FULL
            else:
                return FULL
            return r if isint else p.rnd(r)
        if tag in TRANS:
            return p.rnd(self.trans(tag, R), 2)
        return FULL

    def trans(self, tag, R):
        a = R[0]
        if not a.bounded():
            return FULL
        if tag == "SIGTAN":
            if -math.pi / 2 < a.lo and a.hi < math.pi / 2:
                return out(math.tan(a.lo), math.tan(a.hi)) if True else None
            raise Refuse("tan over an interval reaching a pole")
        if tag in ("SIGSIN", "SIGCOS"):
            f = math.sin if tag == "SIGSIN" else math.cos
            if a.hi - a.lo >= 2 * math.pi:
                return Iv(-1.0, 1.0)
            vals = [f(a.lo), f(a.hi)]
            off = 0.0 if tag == "SIGCOS" else math.pi / 2
            kmin = math.ceil((a.lo - off) / math.pi)
            kmax = math.floor((a.hi - off) / math.pi)
            for kk in range(kmin, kmax + 1):
                vals.append(f(off + kk * math.pi))
            return Iv(max(-1.0, down(min(vals))), min(1.0, up(max(vals))))
        if tag == "SIGEXP":
            return mono(math.exp, a)
        if tag in ("SIGLOG", "SIGLOG10"):
            if a.lo <= 0:
                raise Refuse("log of an interval reaching 0")
            return mono(math.log if tag == "SIGLOG" else math.log10, a)
        if tag == "SIGSQRT":
            if a.lo < 0:
                raise Refuse("sqrt of an interval reaching below 0")
            return mono(math.sqrt, a)
        if tag == "SIGATAN":
            return mono(math.atan, a)
        if tag == "SIGTANH":
            return mono(math.tanh, a)
        if tag == "SIGPOW":
            b = R[1]
            if a.lo > 0 and b.bounded():
                cs = [math.pow(x, y) for x in (a.lo, a.hi) for y in (b.lo, b.hi)]
                return out(min(cs), max(cs))
            if b.lo == b.hi and float(b.lo).is_integer():
                n = int(b.lo)
                cs = [x ** n for x in (a.lo, a.hi)] + ([0.0] if a.has0() else [])
                return out(min(cs), max(cs))
            return FULL
        return FULL

    def cons_list(self, a):
        outl = []
        while a[0] == "ref" and self.g.b[a[1]][0] == "cons":
            _, args, _, _ = self.g.b[a[1]]
            outl.append(args[0])
            a = args[1]
        return outl

    # -- escape check for nested recursions ---------------------------------
    def escapes(self, a, depth):
        """Does this subterm reference a recursion level outside `depth`
        enclosing groups (de Bruijn index > depth)?"""
        kind, k = a
        if kind != "ref":
            return False
        key = (k, depth)
        if key in self.escmemo:
            return self.escmemo[key]
        tag, args, _, _ = self.g.b[k]
        if tag == "DEBRUIJNREF":
            r = int(args[0][1].val) > depth
        elif tag == "DEBRUIJNREC":
            r = any(self.escapes(x, depth + 1) for x in args)
        else:
            r = any(self.escapes(x, depth) for x in args)
        self.escmemo[key] = r
        return r

    # -- affine forms of a group body ---------------------------------------
    def group(self, rec):
        """Affine form of every output of recursion group `rec`."""
        memo = {}
        bodies = self.cons_list(self.g.b[rec][1][0])
        return [self.aff(x, memo) for x in bodies]

    def aff(self, a, memo):
        """(const: Iv, coeffs: {(i, k): Iv}) with k the delay in samples of
        output i of the group; k = 0 marks the undelayed output."""
        kind, k = a
        if kind == "leaf":
            return (self.leaf(k), {})
        if k in memo:
            return memo[k]
        if not self.escapes(a, 0):
            r = (self.rng(k), {})  # does not involve this group's state
            memo[k] = r
            return r
        tag, args, _, op = self.g.b[k]
        p = self.p
        if tag == "SIGPROJ" and args[1][0] == "ref" and self.g.b[args[1][1]][0] == "DEBRUIJNREF":
            if int(self.g.b[args[1][1]][1][0][1].val) != 1:
                raise Refuse("reference to an outer recursion")
            r = (Iv(0.0), {(int(args[0][1].val), 0): Iv(1.0)})
        elif tag == "DEBRUIJNREC":
            raise Refuse("nested recursion coupled to the group")
        elif tag in ("SIGDELAY1", "SIGDELAY"):
            c, co = self.aff(args[0], memo)
            if tag == "SIGDELAY1":
                d = 1
            else:
                dv = self.rarg(args[1])
                if not (dv.lo == dv.hi and float(dv.lo).is_integer()):
                    raise Refuse("variable delay of the state")
                d = int(dv.lo)
            r = (hull(c, Iv(0.0)), {(i, kk + d): v for (i, kk), v in co.items()})
        elif tag == "SIGBINOP" and op in ("add", "sub", "mul", "div"):
            (ca, xa), (cb, xb) = self.aff(args[0], memo), self.aff(args[1], memo)
            if op in ("add", "sub"):
                neg = op == "sub"
                c = p.rnd(out(ca.lo - cb.hi, ca.hi - cb.lo) if neg else out(ca.lo + cb.lo, ca.hi + cb.hi))
                co = dict(xa)
                for key, v in xb.items():
                    v2 = Iv(-v.hi, -v.lo) if neg else v
                    co[key] = out(co[key].lo + v2.lo, co[key].hi + v2.hi) if key in co else v2
                r = (c, co)
            elif op == "mul":
                if xa and xb:
                    raise Refuse("product of two state terms")
                (cs, xs), s = ((ca, xa), cb) if xa else ((cb, xb), ca)
                if xs and not s.bounded():
                    raise Refuse("unbounded coefficient on the state")
                r = (p.rnd(prod(ca, cb)), {key: p.rnd(prod(v, s)) for key, v in xs.items()})
            else:
                if xb:
                    raise Refuse("division by the state")
                r = (p.rnd(quot(ca, cb)), {key: p.rnd(quot(v, cb)) for key, v in xa.items()})
        else:
            raise Refuse(f"{tag}{'/' + op if op else ''} applied to the state")
        memo[k] = r
        return r


# ------------------------------------------------------------ the state matrix

def state_matrix(forms):
    """Interval state matrix of a group, from the affine forms of its outputs."""
    depth = {}
    for c, co in forms:
        for (i, k) in co:
            if k == 0:
                raise Refuse("delay-free loop")
            depth[i] = max(depth.get(i, 0), k)
    states = [(i, k) for i in sorted(depth) for k in range(1, depth[i] + 1)]
    idx = {s: n for n, s in enumerate(states)}
    n = len(states)
    lo, hi = np.zeros((n, n)), np.zeros((n, n))
    for (i, k), r in idx.items():
        if k == 1:
            _, co = forms[i]
            for key, v in co.items():
                if key not in idx:
                    raise Refuse("unexpected state")
                if not v.bounded():
                    raise Refuse("unbounded coefficient")
                lo[r, idx[key]], hi[r, idx[key]] = v.lo, v.hi
        else:
            lo[r, idx[(i, k - 1)]] = hi[r, idx[(i, k - 1)]] = 1.0
    return states, lo, hi


def ldl_pd(M):
    """Exact positive-definiteness of a symmetric Fraction matrix."""
    M = [row[:] for row in M]
    n = len(M)
    for j in range(n):
        if M[j][j] <= 0:
            return False
        for i in range(j + 1, n):
            f = M[i][j] / M[j][j]
            if f:
                for k in range(j, n):
                    M[i][k] -= f * M[j][k]
    return True


def frac_mat(A):
    return [[Fraction(float(x)) for x in row] for row in A]


def mat_mul(A, B):
    n, m, p = len(A), len(B), len(B[0])
    return [[sum((A[i][k] * B[k][j] for k in range(m)), Fraction(0)) for j in range(p)] for i in range(n)]


def transpose(A):
    return [list(r) for r in zip(*A)]


def solve_exact(M, v):
    """Gaussian elimination over Fractions."""
    n = len(M)
    M = [row[:] + [v[i]] for i, row in enumerate(M)]
    for c in range(n):
        p = next((r for r in range(c, n) if M[r][c] != 0), None)
        if p is None:
            return None
        M[c], M[p] = M[p], M[c]
        for r in range(n):
            if r != c and M[r][c] != 0:
                f = M[r][c] / M[c][c]
                for k in range(c, n + 1):
                    M[r][k] -= f * M[c][k]
    return [M[i][n] / M[i][i] for i in range(n)]


def exact_lyapunov(A):
    """Rational P with P - A'PA = I exactly, for a rational matrix A."""
    n = len(A)
    idx = [(i, j) for i in range(n) for j in range(i, n)]
    pos = {ij: k for k, ij in enumerate(idx)}
    def var(i, j):
        return pos[(min(i, j), max(i, j))]
    M, v = [], []
    for (i, j) in idx:
        row = [Fraction(0)] * len(idx)
        row[var(i, j)] += 1
        for k in range(n):
            for l in range(n):
                if A[k][i] and A[l][j]:
                    row[var(k, l)] -= A[k][i] * A[l][j]
        M.append(row)
        v.append(Fraction(1 if i == j else 0))
    x = solve_exact(M, v)
    if x is None:
        return None
    return [[x[var(i, j)] for j in range(n)] for i in range(n)]


def simple(x, digits=12):
    """A short rational close to x: keeps the exact Lyapunov solve cheap."""
    return Fraction(float(x)).limit_denominator(10 ** digits)


def vertices(lo, hi, max_vertices=4096):
    n = lo.shape[0]
    unc = [(i, j) for i in range(n) for j in range(n) if lo[i, j] != hi[i, j]]
    if 2 ** len(unc) > max_vertices:
        raise Refuse(f"{len(unc)} uncertain coefficients: too many vertices")
    for bits in itertools.product((0, 1), repeat=len(unc)):
        Avf = [[Fraction(float(lo[i, j])) for j in range(n)] for i in range(n)]
        for (i, j), b in zip(unc, bits):
            if b:
                Avf[i][j] = Fraction(float(hi[i, j]))
        yield Avf


def jury2(lo, hi):
    """Up to 2 states: the Jury conditions 1 - det > 0, 1 + det > 0,
    1 - tr + det > 0, 1 + tr + det > 0 are multilinear in the entries of A,
    so their minimum over the box is reached at a vertex: checking the
    vertices exactly is exact."""
    n = lo.shape[0]
    worst = None
    for A in vertices(lo, hi):
        if n == 1:
            conds = [1 - A[0][0], 1 + A[0][0]]
        else:
            tr, det = A[0][0] + A[1][1], A[0][0] * A[1][1] - A[0][1] * A[1][0]
            conds = [1 - det, 1 + det, 1 - tr + det, 1 + tr + det]
        m = min(conds)
        worst = m if worst is None else min(worst, m)
        if m <= 0:
            return False, float(worst)
    return True, float(worst)


def metrics(Ac):
    """Indicative (numerical, not certified) roundoff gain of the structure:
    G = sqrt(cond P) / (1 - gamma) for P = dlyap(A, I)."""
    try:
        P = sla.solve_discrete_lyapunov(Ac.T, np.eye(Ac.shape[0]))
        P = (P + P.T) / 2
        ev = np.linalg.eigvalsh(P)
        g2 = max(np.linalg.eigvals(np.linalg.inv(P) @ Ac.T @ P @ Ac).real)
        g = math.sqrt(min(max(g2, 0.0), 1.0))
        return g, ev.max() / ev.min()
    except Exception:
        return 1.0, INF


def lyapunov(lo, hi, max_vertices=4096, frozen=True):
    """Stability of every A in [lo, hi]: Jury at the vertices up to 2 states
    (frozen: each A of the box is stable), otherwise, or when the matrix may
    vary from sample to sample, a common quadratic Lyapunov function.
    Returns (ok, gamma, condP, rho_center)."""
    Ac = (lo + hi) / 2
    rho = max(abs(np.linalg.eigvals(Ac))) if Ac.size else 0.0
    if frozen and Ac.shape[0] <= 2:
        ok, _ = jury2(lo, hi)
        g, c = metrics(Ac)
        return ok, g, c, rho
    return lyapunov_n(lo, hi, max_vertices)


def lyapunov_n(lo, hi, max_vertices=4096):
    """Common quadratic Lyapunov function for every A in [lo, hi]:
    returns (ok, gamma, condP, rho_center)."""
    Ac = (lo + hi) / 2
    rho = max(abs(np.linalg.eigvals(Ac))) if Ac.size else 0.0
    if rho >= 1:
        return False, None, None, rho
    n = Ac.shape[0]
    Pf = exact_lyapunov([[simple(x) for x in row] for row in Ac])
    if Pf is None or not ldl_pd(Pf):
        return False, None, None, rho
    unc = [(i, j) for i in range(n) for j in range(n) if lo[i, j] != hi[i, j]]
    if 2 ** len(unc) > max_vertices:
        raise Refuse(f"{len(unc)} uncertain coefficients: too many vertices")
    P = np.array([[float(x) for x in row] for row in Pf])
    Pinv = np.linalg.inv(P)
    gamma2 = 0.0
    for bits in itertools.product((0, 1), repeat=len(unc)):
        Avf = [[Fraction(float(lo[i, j])) for j in range(n)] for i in range(n)]
        for (i, j), b in zip(unc, bits):
            if b:
                Avf[i][j] = Fraction(float(hi[i, j]))
        M = mat_mul(mat_mul(transpose(Avf), Pf), Avf)
        D = [[Pf[i][j] - M[i][j] for j in range(n)] for i in range(n)]
        if not ldl_pd(D):
            return False, None, None, rho
        Av = np.array([[float(x) for x in row] for row in Avf])
        gamma2 = max(gamma2, max(np.linalg.eigvals(Pinv @ Av.T @ P @ Av).real))
    ev = np.linalg.eigvalsh(P)
    return True, math.sqrt(min(gamma2, 1.0)), ev.max() / ev.min(), rho


# ------------------------------------------------------------------ the driver

def split(iv, logscale):
    if logscale and iv.lo > 0:
        m = math.sqrt(iv.lo * iv.hi)
    else:
        m = (iv.lo + iv.hi) / 2
    return Iv(iv.lo, m), Iv(m, iv.hi)


def certify(dsp, sr, prec, mode, budget=4000, min_rel=1e-9, controls="range"):
    g = Graph(dsp)
    recs = [k for k, v in g.b.items() if v[0] == "DEBRUIJNREC"]
    if controls == "default":
        controls = {k: Iv(float(v[2]["init"])) for k, v in g.b.items() if v[0] in CONTROLS}
    else:
        controls = {k: Iv(float(v[2]["min"]), float(v[2]["max"])) for k, v in g.b.items()
                    if v[0] in CONTROLS}
    results = {}
    for rec in recs:
        todo = [Box(sr, dict(controls))]
        worst = {"boxes": 0, "gamma": 0.0, "cond": 1.0, "G": 0.0}
        verdict, why = "certified", ""
        while todo:
            box = todo.pop()
            worst["boxes"] += 1
            if worst["boxes"] > budget:
                verdict, why = "not certified", "bisection budget exhausted"
                break
            w = Walker(g, box, prec)
            point_matrix = False
            try:
                forms = w.group(rec)
                states, lo, hi = state_matrix(forms)
                if not states:
                    verdict, why = "no state", ""
                    break
                ok, gamma, cond, rho = lyapunov(lo, hi, frozen=(mode == 'frozen'))
                point_matrix = bool((lo == hi).all())
            except Refuse as e:
                if "division by an interval" in str(e) or "tan over" in str(e):
                    ok, rho = False, None  # may vanish after bisection
                    gamma = cond = None
                    reason = str(e)
                else:
                    verdict, why = "refused", str(e)
                    break
            if ok:
                worst["gamma"] = max(worst["gamma"], gamma)
                worst["cond"] = max(worst["cond"], cond)
                worst["G"] = max(worst["G"], math.sqrt(cond) / (1 - gamma) if gamma < 1 else INF)
                continue
            if rho is not None and rho >= 1 and point_matrix:
                verdict, why = "UNSTABLE", f"rho = {rho:.9f}"
                break
            # bisect the widest parameter (relative width)
            params = [("sr", box.sr)] + ([] if mode == "modulated" else
                                         [(c, v) for c, v in box.ctl.items()])
            def relw(iv):
                if iv.lo > 0:
                    return math.log(iv.hi / iv.lo)
                return (iv.hi - iv.lo) / max(1.0, abs(iv.hi), abs(iv.lo))
            name, iv = max(params, key=lambda t: relw(t[1]))
            if relw(iv) < min_rel:
                verdict = "not certified"
                why = (f"sr {box.sr}" + "".join(f", ctl{c} {v}" for c, v in box.ctl.items())
                       + (f": rho(center) = {rho:.9f}" if rho is not None else f": {reason}"))
                break
            for half in split(iv, name == "sr"):
                nb = Box(box.sr, dict(box.ctl))
                if name == "sr":
                    nb.sr = half
                else:
                    nb.ctl[name] = half
                todo.append(nb)
        results[rec] = (verdict, why, worst, len(states) if verdict == "certified" else None)
    return results


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dsp")
    ap.add_argument("--sr", default="44100:192000",
                    help="a range LO:HI, or a list of rates R1,R2,...")
    ap.add_argument("--prec", default="exact,double,single")
    ap.add_argument("--mode", default="frozen,modulated")
    ap.add_argument("--budget", type=int, default=4000)
    ap.add_argument("--controls", default="range", help="range | default")
    a = ap.parse_args()
    if ":" in a.sr:
        srs = [Iv(*(float(x) for x in a.sr.split(":")))]
    else:
        srs = [Iv(float(x)) for x in a.sr.split(",")]
    for mode in a.mode.split(","):
        for pr in a.prec.split(","):
            for sr in srs:
                res = certify(a.dsp, sr, Prec(pr), mode, a.budget, controls=a.controls)
                for rec, (v, why, w, ns) in sorted(res.items()):
                    extra = (f" states={ns} boxes={w['boxes']} gamma={w['gamma']:.9f} "
                             f"condP={w['cond']:.3g} G={w['G']:.3g}") if v == "certified" else f"  {why}"
                    print(f"{os.path.basename(a.dsp)} sr={sr} {mode:9s} {pr:6s} rec n{rec}: {v}{extra}")


if __name__ == "__main__":
    main()
