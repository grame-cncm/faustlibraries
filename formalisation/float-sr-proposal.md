# Making the Lean certification useful: float, double and the sample-rate range

*Status: proposal, 2026-09-29, branch `lean-float-sr`. **P0, step 2, step 3,
P3 and the Lyapunov certificates of P2 are implemented** (see "Implemented"
at the end); the rest is still a proposal. It builds on the
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

## Implemented (2026-09-29)

- **P0.** `make certify` runs again (`certified.lean` regenerated after #262).
  AGENTS.md rule 9 and `contributing.md` ask for a `tests/lean/` fixture and
  a `make certify` run with any rewrite of a recursive structure. New
  fixtures: `lowpass_svf_20hz`, `tf2s_direct_20hz`, `bandpass_tpt`,
  `tf2snp_exact`, `resonlp`, `smoo_sr`, `tf3slf_low`.
- **Step 2**, in the Std-only prelude (section "Stability at the sample
  rates"), with no mathlib dependency:
  - the graph is emitted a second time as a `Dag`, evaluated bottom-up so
    that each node is computed once;
  - it uses intervals with dyadic endpoints (grid 2⁻¹⁰⁰), rounded outward;
  - the rounding model covers exact, double and single arithmetic, a libm
    within `libmUlps` = 2 ulps, and controls stored as `float`;
  - `sin`, `cos`, `tan`, `exp`, `sqrt` and integer `pow` are enclosed by
    Taylor polynomials with an explicit remainder, or by a checked integer
    square root;
  - linear extraction handles multi-output groups;
  - stability uses the Jury conditions at the vertices, for groups of up to
    2 states;
  - the six `check-precision` rates are taken as points, with the controls
    at their default values.

  The verdicts are pinned per program and precision by
  `theorem …_rates_<prec> : srVerdicts …_dag .<prec> = […] := by decide +kernel`.
  The whole `make certify` takes about 30 s, and the optional mathlib layer
  still builds.
- **Verdicts obtained.**
  - `fi.lowpass(2, 20)`, `fi.bandpass(1, 500, 2000)`, `fi.resonlp`, `si.smoo`
    and `lowpass3` are stable at the six rates, in all three arithmetics.
  - The direct-form `fi.tf2s` at 20 Hz is `SSSSSS` in exact and double and
    `SSUUUU` in single, the same verdict as the prototype.
  - `tf2snp` (coupled nested groups), `tf3slf` (3 states), `ba.time` and
    `no.noise` (integer recursions) are refused, with their reason pinned.
- **Step 3 (P5)**: `make certify-tests` (`scripts/certify_tests.py`) runs the
  rate analysis on the 1445 tests in about 80 s. The prelude is compiled once,
  and each graph is read from a string (`Dag.parse`). Its verdicts come from
  `#eval`, not from the kernel; `--kernel` re-checks them with
  `decide +kernel`. `tests/certify-baseline.json` pins the accepted
  not-proven slots (107 tests). The analysis gained exact comparisons and a
  `select2` that follows a selector known to the ranges (`fi.peak_eq`,
  `fi.avg_t60` and the envelope followers went from `U` to `S`).

  Of the 7650 structurally distinct recursion groups:

  | arithmetic | stable at the six rates | not proven | refused |
  |---|---|---|---|
  | exact | 1496 | 94 | 6060 |
  | double | 1484 | 95 | 6071 |
  | single | 1451 | 125 | 6074 |

  **The groups not proven in exact.** Most are marginal: integrators,
  counters, sliding sums, Goertzel, sine oscillators by rotation (`oscr`,
  `wgr`), and the sustain of an envelope. A few are losses of precision of
  the analysis: `inst.asympT60` combines two exclusive conditions, each
  bounded in [0, 1].

  **The 31 groups not proven in single only** are all low bands of
  direct-form filter banks at 88.2–192 kHz: `filterbank_demo`,
  `mth_octave_*`, `spectral_level_demo`, `vocoder_demo`, `vocoder`. This is
  the problem the `tf2s` rewrite of #273 addresses.

  **The refusals** are dominated by unbounded coefficients (2707: the
  coefficient depends on a signal whose range the analysis does not know)
  and by coupled nested groups (1523+191), then by `select2`/`max` on the
  state.

  **Against check-precision.** The two tools agree on the two tests
  `check-precision` finds non-finite in single:
  - `tf3slf_test` has its filter group refused (3 states).
  - `bandpass2Matched_test` has its filter group `n124` certified stable at
    176.4 kHz, where the render is non-finite. The generated code shows why
    both are right: the per-block `fSlow14 = sqrt(…)` gets a negative
    argument in single precision at that rate (a cancellation). It makes the
    numerator coefficients `fSlow14..16` NaN, and they are outside the loop.
    The recursion's own coefficients (`fSlow3`, `fSlow6`) stay finite and
    stable. This is the case P3's "finite" check is for: a `sqrt` whose
    enclosure reaches below 0 in single precision.
- **P3.** Three verdicts per program, precision and rate, pinned together
  by `theorem …_rates_<prec> : verdicts …_dag .<prec> = ⟨groups, finite, sites⟩`.

  **The additions to the analysis:**
  - **Finite values.** Every time-invariant value stays in its domain and
    does not overflow; the result is `F`, `D` (the first operation that may
    fail is named) or `?` (not bounded).
  - **Indices.** Table reads stay in `[0, size - 1]` and delay taps stay
    non-negative, for every value of the controls.
  - **Inductive invariants** for the ranges of recursion outputs.
  - **Floating-point rules**:
    - exact `float` rounding of literals and control defaults;
    - exact products by powers of two;
    - `frac` in `[0, 1 - u]` for `x ≥ 0`, `[0, 1]` below;
    - monotone truncation.
  - **New operations modelled**: `log` and `log10` (the `atanh` series),
    `round`/`rint`/`ceil`, `fmod`, the bit operations, and the `<math.h>`
    foreign functions, taken as pure.

  **A soundness fix.** A coefficient that varies in time (an envelope stage,
  an LFO) could get a bounded range, and the frozen Jury check then called
  its group stable. This happened for 5 groups, in `en.adsre`, `en.ahdsre`
  and `envelopes_demo`. Such a coefficient is now accepted with one state
  only, where `|a| < 1` over the box makes the recursion a contraction
  whatever the variation; with two states the group is refused.

  **Results on the suite** (1445 tests, 136 s):
  - **Finite values.** In exact arithmetic, 1237 tests are `F`, 2 `D` and
    206 `?`; in single, 1222, 7 and 216.
  - **The 7 `D` in single**:
    - the four `*2Matched` filters, which compute a `sqrt` of a cancelling
      expression — the cause of the non-finite render of
      `bandpass2Matched_test` at 176.4 kHz;
    - `FTZ_test`, which overflows by design;
    - `tapeStop` and `tapeStop_demo`, which compute `1/select2(stop, 128, 0)`,
      an infinity each block while the stop button is pressed, discarded
      further on.
  - **Indices.** 8848 table reads and delay taps are proven in range in
    double and single, and 5709 are not, mostly indices computed from
    signals.
  - **`tf3slf_test`** has its time-invariant values finite: its non-finite
    render comes from its third-order recursion, which the analysis refuses.

  `make certify` now takes about two minutes.
- **Two targeted rules.**
  - **The small-gain test.** Take the outputs that feed back, with
    `M o o' ≥ Σ_k |c|` over the box. If `M v < v` for some weights `v > 0`,
    the recursion contracts a weighted max norm. That holds for any delays,
    variable ones included, and for coefficients that vary in time. It
    covers feedback combs and allpasses (`|g| < 1`), damped combs and
    delays in a loop.
  - **Coupled nested groups.** They are analysed as one system with the
    group that encloses them, with outputs keyed `(group, output)`. The
    analysis is limited to 32 nested groups, because a shared nested group
    is re-analysed along every path.

  Two further bounds keep the analysis fast: `sin`/`cos` with a range
  reduction modulo 2π (π between two 37-digit rationals, a new obligation),
  and `exp` bounded before its halvings. The squares `x*x` are non-negative,
  and tables have the range of their generator.

  **Results on the suite.** 147 distinct groups become stable and none is
  lost: freeverb (48 groups), `jcrev`, `satrev`, `dattorro_rev`,
  `kb_rom_rev1`, string models, the `allpassn*` lattices. Of the 7650
  distinct groups:

  | arithmetic | stable | not proven | refused | analysed with an enclosing group |
  |---|---|---|---|---|
  | exact | 1653 | 460 | 2579 | 2958 |
  | single | 1602 | 462 | 2628 | 2958 |

  Among the refusals, 5841 before these rules, 2958 are nested groups that
  their enclosing group now analyses. The groups not proven are mostly
  those the small-gain test reads without concluding: FDN reverbs with
  orthogonal mixing, the rotations of `fi.tf2snp` and of the oscillators,
  `tf3slf`. They need the Lyapunov certificate of P2.

  `make certify-tests` takes 139 s, and `make certify` about 4 minutes.
- **P2: Lyapunov–Krasovskii certificates.** What Jury and the small-gain
  test leave unproven is proved with a quadratic energy that decreases at
  every sample.
  - **The system.** Short delays (up to 4 samples) are explicit states. The
    input of each longer delay line becomes an output of the system, and its
    output becomes a *channel*: an FDN line is one channel, whatever the
    mixing in front of it. Without this step, the flattened forms read every
    output through every line, and no diagonal weighting can work.
  - **The energy.** `V = xᵀPx + Σ_b Σ_{m ≤ b} v_b[n-m]ᵀ D_b v_b[n-m]`, the
    second term being the energy stored in the delay lines, with one block
    `D_b` per delay length. `P ≻ 0` and `diag(P, D) - Gᵀ diag(P, W) G ≻ 0`
    on the box of coefficients give exponential stability, whatever the long
    delays and even with coefficients that vary in time within the box.
  - **Oracle and check.** `scripts/lyapunov_oracle.py` (numpy, scipy, untrusted)
    finds `D` by minimizing the peak gain over frequency with
    block-diagonal scalings, then `P` from the bounded-real Riccati
    equation. It retries with larger margins until a float estimate
    survives the box. Lean (`lyapCheck`) encloses `M` in interval
    arithmetic, shifts its rounded centre by a bound of the spread, and
    checks positive definiteness exactly: Sylvester's criterion by Bareiss
    elimination on integers.
  - **The protocol.** A probe run prints the systems (`L|` lines), the
    oracle answers (`W|` lines), and a second run gives the verdicts. In
    `certified.lean` the certificates are definitions `X_wit_p`, which
    `make certify` leaves out of its drift check because their floats depend
    on the platform.
  - **A rounding rule on the way.** A correctly rounded operation whose exact
    result is a representable dyadic (an integer delay `SR*t - SR*t'`,
    `44100 * 0.125 + 0.5`) is not widened: the delays of `zita_rev1` were
    intervals, hence variable, and only the small-gain test could read them.

  **Results on the suite.** Groups of 39 tests become stable, and none is
  lost:
  - the FDN reverbs: `zita_rev1` and its variants, `fdnrev0`,
    `dattorro_rev`, `instrReverb`;
  - the 4-state rotation of `fi.tf2snp` at low cutoff;
  - the Moog ladders;
  - `fi.tf3` and other sections of order 3 to 5.

  | arithmetic | stable | not proven | refused | analysed with an enclosing group |
  |---|---|---|---|---|
  | exact | 1692 | 421 | 2579 | 2958 |
  | single | 1646 | 452 | 2594 | 2958 |

  Three tests (`SFFormantModel*_ui`) have groups that were refused and are
  now read: some of them are proven and others are not, so their baseline
  entries grow. Still not proven:
  - the lossless rotations of the oscillators, marginal by design;
  - `tf3slf`, whose triple pole near 1 leaves less margin than the box;
  - recursions whose coefficient boxes are wide (the interpolation weights
    of a fractional delay, envelopes, LFOs), where the analysis loses the
    correlation between coefficients (P1).

  `make certify-tests` takes about 6 minutes (the tests with certificates
  run twice), and `make certify` about 5 minutes.
- **Not done yet.** Continuous rate and control ranges (P1, which needs
  correlation-preserving arithmetic), error bounds (P4), integer wrap times,
  and faust-rs typing (P6).
