# Making the Lean certification useful: float, double and the sample-rate range

*Status: proposal, 2026-09-29, branch `lean-float-sr`. It builds on the
design described in [README.md](README.md). The measurements come from a
Python prototype in [prototype/](prototype/). It implements the algorithms
proposed here, outside Lean, to see what they would find on the real
library.*

## 1. Where things stand

### What the test tooling learned since `a53d8355`

Since `a53d8355` ("check new code in float and double, from 44.1 to
192 kHz"), the numerical side has moved a long way:

- **`make check-precision` renders every test** in `-single` and `-double`,
  at six rates. It fails on a non-finite output or on a level gap above 1e-3.
  The accepted debt is 71 `level` entries and 2 `nonfinite` entries.
- **The precision fixes rewrote direct forms into state-variable and
  trapezoidal structures**: #259, #261, #262, #263, #268, and #272/#273 in
  review.
- **`check-cpu` measures their cost**, and every function with run-time
  parameters now has `_slider_test` and `_modulated_test` variants.

These are exactly the properties the libraries fail on: behavior in float,
across the rate range, and under parameter modulation.

### What the certification did in the same period: nothing

- **`make certify` drifted silently.** It had been failing since the
  state-variable `fi.lowpass` (#262, `0965ea28`), 20 commits ago, and nobody
  noticed. It is fixed on this branch (`c8a26206`); the verdict itself did
  not change.
- **`lowpass3`, the only fixture that touches a rewritten function, was
  refused before the rewrite and is still refused after it.**

The certifier cannot see what matters now, for three structural reasons.

1. **Everything that depends on `ma.SR` is refused.** A coefficient goes
   through `tan(w/SR)` and becomes an opaque node, so no filter built on
   `tf2s`/`tf1s` is certified per graph. The one statement about the rate is
   the hand-written `tf2s` theorem, "for all c > 0", which says nothing
   about what a given graph computes.
2. **Only single-output recursions of order ≤ 2 are read.** The structures
   the precision work introduced are multi-output recursion groups: the
   state-variable filters (SVF) and the trapezoidal (TPT) sections. The
   certifier refuses them by construction. The better the library gets, the
   less it certifies.
3. **The statements are about exact rationals**, and floating point is
   explicitly excluded. Floating point is where the library fails: the
   precision baseline is entirely float debt.

Stability in exact arithmetic is also not what fails in practice. The two
`nonfinite` entries (`tf3slf_test` in single at all rates,
`bandpass2Matched_test` at 176.4 kHz) are float effects on filters whose
exact coefficients are stable. The 71 `level` entries concern accuracy, not
stability.

## 2. What a prototype measured

`prototype/float_sr_spike.py` reads the same `--dump-sig-dag` as
`sig2lean.py`.

**The method:**

- **Linear extraction.** Each recursion group (`DEBRUIJNREC`) is read as an
  affine function of its delayed outputs, which gives the state matrix `A`.
  Multi-output groups are included: this is the case of SVF/TPT.
- **Interval coefficients.** The coefficients are evaluated as intervals over
  a parameter box: the sample rate (a range, or one of the six rates), each
  control over its declared range, and, in `single`/`double`, the rounding
  of every real operation (one unit roundoff `u`, two for a libm call). The
  `exact` column models no rounding of the program, but it is still
  computed with outward-rounded double intervals.
- **Stability.**
  - Up to 2 states, the Jury conditions are multilinear in the entries of
    `A`, so an exact check at the vertices of the box is an exact answer.
  - Above that, the prototype checks a common quadratic Lyapunov function
    exactly. This matters because Lean can check the same way: the verdict
    is a rational computation, and floating-point numerics only search for
    the witness.
- **Anything else is refused**: a product of state terms, a nonlinear
  function of the state, a coupled nested group, and so on.

### The float verdicts line up with the known failures

Frozen stability at the six `check-precision` rates:

| group | exact | double | single |
|---|---|---|---|
| `fi.lowpass(2, 20)` (SVF, #262) | stable, 6 rates | stable, 6 rates | stable, 6 rates |
| `fi.tf2s` lowpass at 20 Hz (direct form) | stable, 6 rates | stable, 6 rates | stable at 44.1, 48 kHz; **not provable from 88.2 kHz** |
| `fi.tf2s` lowpass at 1 kHz | stable | stable | stable |
| `tf3slf_test` (3rd order, 0.16 Hz) | not provable: a box 1e-14 wide already holds a root of modulus 1.00001–1.00002 | not provable: same, up to 1.00004 | **box holds a root of modulus 1.02, at all 6 rates** |
| `tests/lean/lowpass3.dsp` | stable over the continuous range 44.1–192 kHz | same | same |

- **The direct form at 20 Hz / 96 kHz.** Its Jury margin `1 + a1 + a2` is
  1.7e-6, about 30 float ulps of 1. The actual float32 coefficients happen to
  fall inside the stable region, with an actual error of 1.6e-8. But the
  worst-case bound of the rounding errors of the coefficient computation
  does not fit in that margin. The SVF's margin in its own coefficients is
  O(w), not O(w²), so it has room to spare.
- **`tf3slf_test` is the baseline's `nonfinite` entry, explained.** Its
  poles form a cluster of three near z = 1, and such a cluster moves like
  δ^(1/3) under a perturbation δ of the coefficients. In float, the
  coefficient enclosure is 7e-6 wide, and it holds polynomials with a root
  of modulus 1.02 at every rate: the certifier refuses what
  `check-precision` measures as non-finite in single at all six rates.
  Even a box 1e-14 wide holds a root of modulus 1.00001. That is only the
  outward rounding of the interval arithmetic, before any rounding of the
  compiled program is modelled. Such a structure can only be certified with
  correlation-preserving arithmetic (P1), and it runs in double only by
  luck.
- **The lowpass3 fixture.** Today's Lean certifier refuses this fixture. The
  prototype certifies it over the whole continuous rate range, in the three
  precisions: 67 boxes for its first-order section, and one box for its SVF
  section.

### Structures differ by orders of magnitude in how they amplify roundoff

The indicator `G = sqrt(cond P) / (1 - gamma)` bounds the gain from a
per-sample perturbation of the state (a rounding error) to the state. It is
numerical and indicative only.

| at 20 Hz | 44.1 kHz | 192 kHz |
|---|---|---|
| direct form (`tf2s`) | 8.6e10 | ≥ 3e13 |
| SVF (`fi.lowpass`) | 2.3e3 | 9.9e3 |

`u_single · G` for the SVF is 6e-4 at 192 kHz, which is under the 1e-3
criterion, as a bound. For comparison, `contributing.md` measures 4e-5 for a
similar SVF, `fi.svf.lp(50, 0.707)`. For the direct form, the
product is meaningless, far above 1. This matches the gaps
`contributing.md` reports for `fi.lowpass(4, 50)` before and after #262.

### Coverage of the whole test suite

`prototype/survey.py` covers 1445 tests and 7650 structurally distinct
recursion groups, at 48 kHz and in double, with the controls at their
defaults.

| verdict | groups | share |
|---|---|---|
| linear, certified stable | 2577 | 34% |
| linear, not proven stable | 203 | 3% |
| linear, more than 16 states (delay lines) | 34 | 0.4% |
| refused | 4836 | 63% |

**Linear groups not proven stable.** They are mostly marginal integrators
with a pole at 1 (ρ = 1): `ba.time`, counters, `slidingSum`/`slidingMean`,
Goertzel. Their rounding error grows without bound over time, which a
one-second render cannot see.

**Refused groups, by reason:**

| reason | groups | what it would take |
|---|---|---|
| nested group coupled to its parent | 2196 | flatten coupled groups into one state vector |
| division by an interval containing 0 | 930 | inductive range invariants (coefficients fed by other recursions) |
| `select2` on the state (resets, latches, envelopes) | 791 | piecewise-linear (switched) systems |
| `max`/`min` on the state (clippers, followers) | 474 | contraction or small-gain arguments |
| unbounded coefficient | 156 | ranges of the signals driving it |
| `sqrt` of an interval reaching below 0 | 83 | same (`fi.bandpass` coefficient chain) |
| variable delay of the state | 69 | out of scope for now |
| other nonlinear (`sin`, `pow`, `abs`, comparisons, `%`, table reads) | 130 | out of scope, or specific rules |
| more than 12 uncertain coefficients (ladders, `klonCentaur`) | 7 | SDP witness instead of vertex enumeration |

In the test-level count, the input generators dominate. `os.osc`'s phasor
and the `ba.period` modulator are refused, and appear in most tests. The
distinct-group counts are the honest measure.

### What the prototype showed does not work

- **Plain interval arithmetic over a wide parameter range fails on the
  direct form.** Over 44.1–192 kHz, or with a cutoff slider over
  20 Hz–20 kHz, it exhausts a budget of 20000 boxes. The cause is that `a1`
  and `a2` are correlated, and the margin is O(w²). The SVF passes in 11 to
  29 boxes. The same loss of correlation is why the direct form at 20 Hz in
  float is "not provable": the rounding error of `tan` enters both
  coefficients, yet all it does is move the cutoff slightly *within the
  family of stable filters*.
- **Modulated verdicts need a better Lyapunov witness.** A common `P`
  computed from `Q = I` at the center fails on every slider box. Finding
  `P` is a semidefinite program.
- **The `ba.period` modulator of the `_modulated_test`s has no finite range
  without an inductive invariant** (`0 ≤ y` because `y₀ = 0` and
  `(y + 1) % p ≥ 0`). So every modulated cutoff looks unbounded.
- **The dump carries no types.** Deciding whether an operation is on
  integers (exact, wrapping) or reals (rounded) takes a heuristic.

## 3. Proposals

Every verdict should state its scope: the precision, the rate range, the
control ranges, and the libm assumption. "Stable" with no qualifier is what
the current pipeline says, and it is what made it unhelpful.

### P0. Keep `make certify` alive (hours)

- **Run it where the rest runs.** Add it to AGENTS.md rule 9 next to
  `check-precision` for changes to recursive structures, or better, to CI.
  The #262 drift went through the 20 commits that followed without anyone
  noticing.
- **Add one fixture per rewritten function** (#259–#273), so that the
  certifier's coverage follows the rewrites.

### P1. Parameters instead of constants: the rate range and the controls

- **`fSamplingFreq` becomes a parameter with a range.** The default is the
  `check-precision` rates' hull, [44100, 192000]. If faust#1321 option B
  lands, the range comes from the same `R` that faust-rs uses to size
  delays, so that the libraries, the compiler and the certificate agree on
  one bound.
- **Controls range over their declared bounds.**
- **Certified rational enclosures of `tan`, `sin`, `cos`, `exp`, `log`,
  `pow`, `sqrt` in the prelude**: Taylor series with an explicit remainder,
  all in rationals, so everything remains `decide`.
- **Correlation-preserving arithmetic.** The prototype shows plain intervals
  are not enough. Two candidates:
  - **affine arithmetic**: one noise symbol per parameter and per rounding;
  - **polynomial arithmetic in one atom** `t = tan(πf/SR)`, with positivity
    on an interval checked by Bernstein coefficients.

  The second fits the existing `tf2s` theorem, which is already stated in
  `c`.
- **The witness is a list of boxes, each with its own check.** The kernel
  checks both that the boxes cover the range and each box's check.
- **A cheap first step: the six rates as points.** It matches what
  `check-precision` samples and has no correlation problem.

### P2. Recursion groups as state-space systems

- **Extract the state matrix of any linear group**, including SVF/TPT, and
  coupled nested groups flattened into one state vector.
- **Stability:**
  - up to 2 states, Jury at the vertices, which is exact;
  - otherwise, a Lyapunov matrix `P` found by an untrusted SDP solver and
    checked exactly in Lean: `P ≻ 0` and `P − AᵀPA ≻ 0` at each vertex, by
    exact LDLᵀ.

  The pattern is the one the design already relies on: the oracle
  computes, the kernel checks.
- **Two verdicts, matching the test regimes:**
  - **frozen**: stable at every fixed setting, which is what `_test` and
    `_slider_test` exercise;
  - **modulated**: one common `P` over the whole control box, so the filter
    is stable under arbitrary per-sample variation. This is the property
    `_modulated_test` probes numerically, and the one that separates a
    direct form from an SVF.

### P3. Float and double as semantics

- **The rounding model.** Every real operation of the graph is
  `(x op y)(1 + δ)`, with `|δ| ≤ u`: `u = 2⁻²⁴` in single and `2⁻⁵³` in
  double.
  - Constants are rounded exactly to the target precision; they are known
    rationals.
  - Each libm call gets a declared ulp bound. Its obligation is named per
    function and per platform.
  - An absolute term covers subnormals, and an overflow check covers
    `FLT_MAX`.
- **Certified per precision:**
  - **finite**: no division by an interval containing 0, no overflow, no
    `sqrt`/`log` of a negative value, no `tan` pole, over the whole
    parameter box. This is a theorem-level version of the `nonfinite`
    criterion of `check-precision`, quantified over all inputs, rates and
    control values instead of one render.
  - **stable**: the coefficients as computed in that precision.
  - **index bounds in float.** The current phasor rule
    `x − ⌊x⌋ ∈ [0, 1)` is false in float: `frac(-1e-9)` is `1.0f`, which
    puts `int(frac · N)` one past the table. It holds for `x ≥ 0`, where
    `frac` is exact. So a positive-frequency phasor keeps its certificate,
    and a negative-frequency one loses it. That is correct, and is a case
    the exact-rational certificate misses today. The same applies to
    `int(t · SR)`-style delay taps.
  - **integer ranges.** Counters are bounded by inductive invariants, and
    the certificate states the wrap time (`ba.time`: 2³¹ samples, 12.4 h at
    48 kHz).
- **A design point the prototype made clear: not every rounding error is
  harmful.** A rounding that only perturbs a parameter inside the
  certified family is harmless: the error of `tan` in `tf2s` only moves the
  cutoff. The analysis should reuse the parametric theorems (for all
  `c > 0`) and charge float errors only to the operations after the
  parameter. This needs error symbols, not plain intervals, and is one more
  reason for affine arithmetic.

### P4. Quantitative float/double error bounds

- **What it computes.** For each linear group, a certified upper bound on
  `|y_float − y_exact|` relative to the input amplitude. Two sources:
  - the Lyapunov certificate: the per-sample rounding error is at most `u`
    times the magnitude of the terms, and it is amplified at most by
    `sqrt(cond P) / (1 − γ)`;
  - or, tighter, a rational upper bound on the ℓ1 norm of the
    error-to-output impulse response.
- **What it gives.** A bound comparable to `check-precision`'s 1e-3 level
  criterion, but for all inputs, rates and control values. It would:
  - explain and predict baseline entries;
  - rank structures before they are measured (direct form against SVF at
    20 Hz: 1e11 against 1e4);
  - flag the marginal recursions (ρ = 1) whose error grows with time, where
    a one-second render is blind.

### P5. Certify the test suite, not fixtures

- **A `make certify-tests` target, or a `check_precision.py` mode**, that
  runs the certifier on every `*_test`. It would write a per-test JSON
  report, with a baseline file like `precision-baseline.json` whose entries
  may only disappear.
- **Cross-check with `check-precision`.** A group certified finite and
  stable in float must never render non-finite, and a mismatch is a bug in
  one of the two tools. A level failure on a certified group points to
  accuracy (P4), not stability.
- **The fixtures in `tests/lean/` remain, as the pinned theorems.** The
  suite run is the coverage report.

### P6. A typed dump, and Lean as an oracle for faust-rs intervals

- **faust-rs prints, for each node, its nature (int/real) and the interval
  it infers**, including `fSamplingFreq ∈ [1, R]`.
- **Lean confronts those intervals as it already confronts the table
  clamps.** The first target is the delay lines: every tap is below the
  allocated size over the whole rate range. This is the memory-safety
  question left open for the `Shift` and `IfWrapping` delay strategies in
  the faust-rs analysis of #1321.

## 4. Suggested order

| step | content | cost |
|---|---|---|
| 1 | P0 | hours |
| 2 | P2 frozen, up to 2 states; P1 at the six rates as points; P3 rounding of the coefficients | days: the prototype's algorithm moved into the prelude, with interval arithmetic, libm enclosures and vertex Jury |
| 3 | P5 on the suite, with a baseline | days |
| 4 | P3 finite and float index bounds | days |
| 5 | P1 continuous ranges, with affine or Bernstein arithmetic | a week or more |
| 6 | P2 modulated, with an SDP witness | a week or more |
| 7 | P4 error bounds | research |
| 8 | P6, with faust-rs | coordinated with the compiler |

Steps 1–3 already turn the certificate into something a reviewer of a
precision PR would read. It would answer three questions for the structure
under review: does it stay stable in float at every rate, which rates and
precisions are only "stable by luck", and what did the rewrite buy in
certified terms.

## 5. What stays out

- **The evaluation order of the generated code.** The certificate is about
  the signal graph, in its evaluation order. `-ffast-math` and
  reassociation change that order, and `check-precision-matrix` covers them
  empirically.
- **Limit cycles and other nonlinear effects of rounding in the loop**,
  beyond the error bounds of P4.
- **Backend fidelity.** It is unchanged from [README.md](README.md) §5.
- **`native_decide`.** It is to be avoided: it would add the Lean compiler
  to the trusted base. Large rational checks should use `Nat`/`Int`
  arithmetic, which the kernel accelerates with GMP.

## Appendix: reproducing the measurements

```bash
cd formalisation/prototype
python3 float_sr_spike.py ../../tests/lean/lowpass3.dsp --mode frozen
python3 float_sr_spike.py probe.dsp --sr 44100,48000,88200,96000,176400,192000 --mode frozen
python3 survey.py                 # about 5 minutes on 10 cores; writes survey.json
```

`probe.dsp` is any program, for instance
`import("stdfaust.lib"); process = fi.tf2s(0, 0, 1, sqrt(2), 1, 2*ma.PI*20);`.
The prototype needs `faust-rs` on the `PATH` (for `--dump-sig-dag`), numpy
and scipy. It imports the DAG reader of `scripts/sig2lean.py`.
