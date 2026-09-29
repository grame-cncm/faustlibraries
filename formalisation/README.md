# On-the-Fly Formalization of Faust DSP

*Status: experimental, work in progress. This document describes the design;
the contributor-facing instructions live in the "Formal certification" section
of [contributing.md](../doc/docs/contributing.md).*

## 1. The idea

The Faust libraries are tested numerically: `make check` compares the output
of each test program against stored references. This catches regressions, but
it cannot state a *property* — that a filter is stable at every sampling rate,
or that a table index can never leave the table. Formal proof can state such
properties, but the classical way of applying it to a library — hand-writing a
model of each function in a proof assistant, then proving theorems about the
model — has a structural weakness: the model and the code drift apart, and
nothing detects the drift.

The approach taken here is different, and is what "on-the-fly" means: the
object that gets certified is not a hand-written model but **the signal graph
the compiler actually produced**, imported into Lean 4 automatically, at test
time, for each example:

```
example.dsp
    │  faust-rs --dump-sig-dag          (the compiler's own signal graph)
    ▼
S-expression dump
    │  scripts/sig2lean.py              (parser + Lean emitter)
    ▼
a Lean `Sig` term                       (a let-chain mirroring the DAG)
    │  analyses defined in the prelude  (stability, index bounds)
    ▼
one theorem per verdict, proved `by decide`, re-checked by the Lean kernel
```

Every certified fact is therefore a fact about what the compiler compiled —
not about what a formalizer believed the library meant. When the library, the
compiler, or the analyses change, the theorems are *regenerated and re-proved*,
and `make certify` fails loudly on any verdict drift, exactly as `make check`
fails on a numerical divergence. Formalization stops being a one-off academic
artifact and becomes a regression harness.

## 2. The import, in detail

The pipeline above compresses several deliberate choices. This section spells
them out; the reference implementation is
[`scripts/sig2lean.py`](../scripts/sig2lean.py) (~330 lines) and the `Sig`
type at the top of the prelude.

### 2.1 What the compiler emits

`faust-rs --dump-sig-dag` prints the compiler's signal graph *after* symbolic
propagation — the same graph every backend compiles — as one binding per
interior node plus one line per output:

```
n7  = SIGTAN(n6)
n8  = SIGBINOP(op=div (/), int(1), n7)
...
n26 = DEBRUIJNREC(n25)
n27 = SIGPROJ(int(0), n26)
[0] = n54
```

Leaves are typed: `int(n)`, `float_bits(0x3fe5551d68c692f7)` (the raw 64-bit
IEEE-754 pattern, not a decimal rendering), `sym("fSamplingFreq")`, and UI
controls arrive with their declared ranges already resolved
(`init=…, min=…, max=…, step=…`). Recursions use de Bruijn indices
(`DEBRUIJNREC` / `DEBRUIJNREF`), so feedback needs no name resolution.

The **DAG form matters**. The tree form re-expands every shared subgraph at
each path reaching it: `fi.bandpass(4, 500, 2000)` prints 2.3 MB as a tree
against 6.5 kB as a DAG. Reading the DAG keeps the import linear in the size
of the actual graph, and — just as important — preserves *sharing*: the two
occurrences of `x` in the phasor body `x - floor(x)` are one node in the
dump, so after emission they are structurally identical terms, which is
exactly what the range analysis's structural equality (`beq`) tests. The
dump's post-order numbering (a child always has a lower index than its
parent) means sorting the reachable indices ascending *is* a topological
order — the emitter needs no second traversal.

### 2.2 Exact constants

Every IEEE-754 double denotes an exact rational `m / 2ᵏ`. The importer
recovers it losslessly from the bit pattern (`struct.unpack` then Python's
`Fraction`), so no decimal round-trip ever touches a coefficient. On the Lean
side these become the prelude's `Q` — an integer numerator/denominator pair
rather than Std's `Rat`, because in Std 4.31 `Rat` does not kernel-reduce:
`decide` gets stuck on its order instances, and the whole two-pass protocol
below rests on `decide` closing these goals in the kernel.

### 2.3 The target type: a total mirror

The Lean `Sig` inductive mirrors the dump tag-for-tag, with a closed escape
hatch:

| dump | `Sig` | note |
|---|---|---|
| `int(n)`, `float_bits(…)` | `.int`, `.const ⟨m, 2ᵏ⟩` | exact |
| `SIGINPUT`, `SIGDELAY1`, `SIGDELAY` | `.input`, `.delay1`, `.delay` | |
| `DEBRUIJNREC/REF`, `SIGPROJ`, `cons/nil` | `.recur`, `.ref`, `.proj`, `.cons/.nil` | recursion groups |
| `SIGBINOP` for `+ - * / %` | `.binop .add/…` | the five ops the analyses read |
| sliders, nentry, bargraphs | `.control name id lo hi kids` | declared range carried along |
| **everything else** | `.opaqueN name kids` | children kept, meaning dropped |

Totality is the point: an unmodelled tag (`SIGTAN`, `SIGFCONST`, a waveform,
an FFI call) is not an error — it becomes an `opaqueN` node that keeps its
children (so the analyses can still traverse *through* it where sound) but
that no analysis can ever read as a linear term or a known-range value.
Unmapped binary ops keep their opcode in the name (`"SIGBINOP:or"`), so
comparisons and bit operations do not collapse onto one indistinguishable
node. This is what makes "adding a tag can only make the certifier accept
more, never accept something wrong" true by construction.

### 2.4 Emission: one `let`-chain per output

For each output, the emitter walks the reachable bindings in index order and
prints them as a flat `let`-chain:

```lean
def osc_out0 : Sig :=
  let n0 : Sig := Sig.ref 1
  let n1 : Sig := Sig.proj 0 n0
  let n2 : Sig := Sig.delay1 n1
  ...
  n30
```

Sharing survives as `let`-sharing, so the generated file stays proportional
to the DAG (8.8 kB of bindings for that 4th-order bandpass) and the check
time does not move with filter order. Each definition carries the source
`.dsp` text as its doc-comment, and the whole generated section lives in its
own namespace (`Faust.Signal.Generated`), appended after a verbatim copy of
the prelude — the reviewed part and the generated part are one file but never
mixed.

### 2.5 The two-pass protocol: predict, then prove

The generator does not decide anything itself. It runs twice:

1. **Probe pass** — emit the terms plus one `#eval` per signal printing
   `name|<stability verdict>|<index verdict>`, run `lean` once, and *read*
   what the certifiers computed.
2. **Pinning pass** — re-emit the same file, replacing the probes with one
   theorem per verdict:

```lean
theorem osc_out0_stability : certifyStableB osc_out0 = false := by decide
theorem osc_out0_indices   : certifyIndicesB osc_out0 = true  := by decide
```

The theorem is the artefact. `by decide` makes the kernel re-execute the
certifier on the imported term and check that it really returns that Boolean;
the Python script only predicted it. A bug in the script can produce a
theorem that *fails to check* — it cannot produce a false theorem that
checks. This is why `sig2lean.py` sits outside the trusted base, and why the
verdicts pinned in `certified.lean` can be diffed by `make certify` like any
other test reference.

What remains assumed is the *adequacy of the import itself* — that `Sig`
faithfully mirrors what `--dump-sig` means. That is the first standing
obligation of the prelude; its honest mitigation is mechanical
round-tripping (re-printing the imported terms back to dump syntax and
diffing), which is future work.

## 3. What is certified today

Three analyses run over each imported graph. All are defined in
[signal-import-formal-spec.lean](signal-import-formal-spec.lean), the single
hand-written, hand-reviewed prelude (Lean 4.31 with only its bundled `Std`, no
`sorry`, axioms limited to `propext` on the generated theorems).

**Feedback stability.** Linear recursions of order ≤ 2 with constant
coefficients are recognized syntactically and checked against the Jury /
Schur-Cohn criterion in exact rational arithmetic — every IEEE-754 double is
exactly `m/2ᵏ`, so no rounding enters the statement. This covers `fi.tf2`
instances, biquads, and (through the DAG import, which keeps shared structure
shared) cascades of second-order sections.

**Index bounds.** Every table read and delay tap is checked to stay in range
*as written* — a three-valued verdict distinguishing `IN RANGE` (safe by
construction), `CLAMP REQUIRED` (safe only because the backend inserts a
clamp: a named dependency, not a defect report), and `not proven`. The
interval analysis understands control ranges, `min`/`max`/`int` casts, `%`,
multiplication by constants, and — through a *recursion invariant* — bounds
that hold independently of the recursive state: the phasor identity
`x - floor(x) ∈ [0, 1)` bounds every wrap-around oscillator, so a
phasor-driven `rdtable` sine oscillator is certified in range end to end.

**Stability at the sample rates, in float and double.** The two analyses
above refuse every coefficient that depends on `ma.SR` (it goes through `tan`)
and read single-output recursions only. The third one reads the graph as a
DAG and certifies each recursion group at the six rates of `make
check-precision` (44.1 to 192 kHz), with the controls at their default values,
in three arithmetics: `exact`, `double` and `single`. The coefficients are
enclosed in intervals that contain their value *as the program computes it*
in that precision: every real operation is widened by one unit roundoff, a
libm call by `libmUlps` ulps, and `tan`, `sin`, `cos`, `exp`, `sqrt` are
enclosed by Taylor polynomials with an explicit remainder, in rational
arithmetic. A group whose state is at most 2 samples (first order, direct-form
second order, state-variable and trapezoidal sections) is then certified by
the Jury conditions at the vertices of the box of its state matrix, which is
exact because the conditions are multilinear. The verdicts are `S` (stable),
`U` (not proven) and `R` (refused, with the reason), per rate. For instance,
`fi.lowpass(2, 20)` (state-variable since #262) is stable at every rate in the
three arithmetics, whereas the direct form it replaced is stable in exact and
double arithmetic but not proven in single from 88.2 kHz: its Jury margin,
1.7e-6 at 96 kHz, is smaller than what the rounding of its coefficients in
single precision can move. The design and the measurements behind it are in
[float-sr-proposal.md](float-sr-proposal.md).

### What "at most 2 states" means

**The state of a recursion** is the set of past values it needs to compute the
next sample. Their number is the order of the section, that is, its number of
poles:

| structure | recursion | state | size |
|---|---|---|---|
| one pole (`si.smooth`, `fi.dcblocker`) | `y[n] = a·y[n-1] + x[n]` | `y[n-1]` | 1 |
| direct-form biquad (`fi.tf2`, `fi.tf2s`, `fi.resonlp`) | `y[n] = -a1·y[n-1] - a2·y[n-2] + …` | `y[n-1]`, `y[n-2]` | 2 |
| state-variable / trapezoidal section (`fi.lowpass` since #262, `fi.tf2sb`) | two outputs `ic1eq`, `ic2eq`, each read back one sample later | `ic1eq[n-1]`, `ic2eq[n-1]` | 2 |
| `fi.tf3slf`, Moog or diode ladder | order 3 or 4 in one recursion | 3 or 4 values | 3–4 |
| comb or allpass with a delay line in its loop (`y[n] = x + g·y[n-N]`) | the delay line is in the recursion | the last N values of `y` | N |

Written as a vector `z`, the recursion becomes `z[n] = A·z[n-1] + (input)`.
It is stable when every eigenvalue of `A` (every pole) lies inside the unit
disc.

**Why 2 is the limit of the current check.** If `A` were known exactly, any
size could be tested. Here its coefficients are intervals: in single
precision, a computed coefficient lies somewhere in `[a - error, a + error]`.
Stability has to be proved for every matrix of that box, of which there are
infinitely many.

- **Up to 2 states, the box is decided by its corners.** The four Jury
  conditions, `1 - det > 0`, `1 + det > 0`, `1 - tr + det > 0` and
  `1 + tr + det > 0`, are multilinear in the entries of `A`: no entry appears
  squared. A multilinear function reaches its minimum over a box at a corner,
  so checking the corners (at most 2⁴ = 16), exactly in rational arithmetic,
  proves the whole box. That is `jury2` in the prelude.
- **From 3 states on, corners are no longer enough.** The stability
  conditions become polynomials of higher degree in the entries, and the
  stable region is no longer convex: a box can have all its corners stable
  and still contain an unstable matrix. Another certificate is needed. One is
  a Lyapunov matrix `P` found by an external solver (a semidefinite program)
  and checked exactly in Lean: `P ≻ 0` and `P - AᵀPA ≻ 0` at every corner, a
  condition that is affine in `A` once written as a block matrix, so the
  corners suffice. The other is the full Jury table with a subdivision of the
  box. This is item P2 of [float-sr-proposal.md](float-sr-proposal.md).

**What this covers.** Most high-order filters of `filters.lib` are cascades
of second-order sections, and each section is its own recursion group:
`fi.lowpass(4, …)` compiles to two groups of 2 states, both within reach.
Three kinds of structure remain out of reach:

- recursions of order 3 or more in one piece: `fi.tf3slf`, the Moog and
  diode ladders, and parts of `ve.klonCentaur`;
- loops that contain a delay line: combs, allpasses, the FDNs of the reverbs,
  the waveguides. A dedicated rule would be far simpler than a Lyapunov
  certificate for them: a comb `y = x + g·y[n-N]` is stable if and only if
  `|g| < 1`, whatever N;
- groups coupled to each other, which would first have to be flattened into
  one state vector.

**Finite values and indices in floating point.** The same DAG analysis
gives two more verdicts per rate and arithmetic:

- **Finite values** (`F`, `D`, `?`). Every time-invariant value (a constant,
  a coefficient computed from the sample rate and the controls) stays in the
  domain of its operation over its whole enclosure (no division by an
  interval containing 0, no `sqrt` or `log` of a value that may be negative,
  no `tan` near a pole) and does not overflow. `D` names the first operation
  that may fail, `?` the first value the analysis cannot bound. In single
  precision, `ve.bandpass2Matched` gets `D` on a `sqrt` of a cancelling
  expression, the cause of its non-finite render at 176.4 kHz.
- **Indices** (`I`, `N`). Table reads stay in `[0, size - 1]` and delay taps
  are non-negative, for every value of the controls. Here the floating-point
  model matters: `x - floor(x)` is `[0, 1 - u]` for `x ≥ 0` but can round to
  `1.0` below 0, so the table read of `os.osc(440)` is proven in range in
  double and single, and that of `os.osc(-440)` is not.

The ranges of recursion outputs come from inductive invariants, checked, not
assumed: a candidate range containing the initial state 0, such that the body
evaluated with the state in it stays in it. That is how the phase of
`os.osc` is known to stay non-negative.

The example set lives in [../tests/lean/](../tests/lean/): one small `.dsp`
per certified instantiation, plus deliberate counter-examples whose *refusal*
is itself pinned as a theorem (`+ ~ *(1.5)` is certified unstable; an
under-clamped table read is certified `CLAMP REQUIRED`). The generated
[certified.lean](../tests/lean/certified.lean) re-checks in about two minutes,
almost all of it in the rate analysis (`by decide +kernel` on the interval
computations).

## 4. Safety by refusal

The prelude's central design rule: **anything the analyses do not recognize
exactly is refused, never guessed.** The imported `Sig` type is total — every
compiler tag the importer does not model becomes an opaque node that no
analysis can read as a linear term — so adding a rule can only make the
certifier accept *more*, never accept something wrong. A `tanh` in a feedback
loop, a coefficient that depends symbolically on the sampling rate, a
recursion of order 3: all yield "not certified", pinned as a `= false`
theorem. If a later extension of the analyses unlocks such a case, the pinned
refusal flips and `make certify` shows it.

### The compiler's interval analysis and the Lean proof

The Faust compilers (C++ and Rust) already carry an internal interval
library, used among other things to decide where table accesses need a
clamp. A fair question is what the Lean analysis adds on top of it. The
answer is that the two computations differ on every axis that matters — they
are complements, not competitors:

**They answer different questions.** The compiler's analysis answers *"must I
insert a clamp to make this access safe?"* — an engineering decision, after
which the program is safe regardless. The Lean verdict answers *"is this
index in range as written, or does its safety rest on a compiler-inserted
clamp?"* The three-valued verdict makes that dependency explicit: `CLAMP
REQUIRED` is not a defect report, it is a *named dependency* — of interest to
the library author (a clamp-dependent site in a `.lib` function suggests
clamping or documenting on the Faust side) and to performance work (`IN
RANGE` is a licence to elide the clamp in an inner loop).

**They sit on opposite sides of the trust boundary.** The internal interval
code is part of the object under test: if it computes a wrong interval — too
wide *or* too narrow — nothing signals it, because it is both the judge and
the party. Its result is trusted output of trusted code, with no witness. The
Lean analysis is a second, independently written implementation over the
exported graph, and its result is not an analysis output at all but a
*theorem* the kernel re-checks on every `lake`/`lean` run. The trusted base
shrinks from "the whole interval library of the compiler" to the ~500-line
reviewed prelude, the Lean kernel, and the recorded adequacy obligations.

**They fail in opposite directions.** The compiler's analysis must return an
interval for *every* node, quickly; when unsure it widens — silently, since a
too-wide interval only costs an extra clamp, and a too-narrow one is an
invisible soundness bug. The prelude is total in the opposite way: whatever
it does not recognize exactly becomes an unreadable opaque node and the
verdict "not proven". Widening errors cannot exist because widening does not
exist; each accepting rule carries its soundness argument as a comment and is
reviewed as mathematics.

**Their disagreements are the payoff.** Because the two are independent,
every divergence is information: a site Lean proves in range but the backend
clamps anyway is a missed optimization; a site the backend leaves unclamped
but Lean cannot prove deserves a look at both sides. Run under `make
certify`, the Lean analysis thus doubles as a standing, kernel-checked oracle
for the compiler's own bound insertion — and any regression in either
implementation surfaces as a verdict drift on the committed reference.

Since faust-rs moved its clamp insertion to the signal level (option `-ct`,
observable through `--dump-sig-dag-prepared`), this confrontation is
mechanized rather than aspirational. During generation, `sig2lean.py` reads
what the compiler actually did — the prepared forest under `-ct 1` diffed
against `-ct 0`, a table read whose index changed was clamped — and compares
it, per table size, with Lean's `tableSiteVerdictsB`. The defect direction
(a `clampRequired` table left unclamped) **fails** `make certify`; the
missed-optimization direction is recorded, not fatal. The per-program
outcome is pinned in a "Compiler clamp oracle" section of `certified.lean`,
so it drifts — and is reviewed — like any other verdict. The first run
already earned its keep: on `osc.dsp`, Lean's strict phasor bound
`x - ⌊x⌋ ∈ [0, 1)` proves the 65536-entry table read in range, while the
compiler's own interval analysis does not and clamps it — a recorded missed
optimization in faust-rs (and reference C++, which shares the behavior).

## 5. The trust story

What must be believed, and what is checked, is meant to be readable from one
place — the "Standing obligations" section of the prelude. The chain:

| Link | Status |
|---|---|
| The generated theorems (one per verdict) | proved `by decide`, re-checked by the Lean kernel on every run |
| The prelude's analyses (Jury test, interval rules) | hand-reviewed; each rule carries its soundness argument as a comment |
| Jury criterion ⟺ poles strictly inside the unit disc | **proved** at order 2 in the optional mathlib layer ([mathlib/JuryRoots.lean](mathlib/JuryRoots.lean), `make certify-deep`) |
| `0 < 1/tan(w)` for cutoffs below Nyquist (the `tf2s` hypothesis) | **proved** in the same layer |
| Adequacy of the import (`Sig` mirrors `--dump-sig`) | standing obligation; mitigated by round-tripping |
| Exact rationals vs. floating-point execution | for stability and indices, a standing obligation — those theorems speak about the denoted exact arithmetic; the rate analysis models floating point |
| IEEE 754 rounding of `+ - * /` and `sqrt`, libm within `libmUlps` ulps, no reassociation | standing obligations of the rate analysis |
| Taylor remainders, `tan` as `sin/cos`, vertex lemma of the Jury check | hand-reviewed; the next targets of the mathlib layer |
| The backend compiles the graph faithfully | out of scope — certification is about the signal graph, not the generated C++/Rust |

The generator (`sig2lean.py`) is deliberately *outside* the trusted base: it
only predicts each verdict and emits the theorem pinning it. If it predicts
wrongly, the theorem fails to check; it cannot make a false statement pass.

Alongside the import pipeline sits one hand-written parametric theorem,
[tf2s-stability-formal-spec.lean](tf2s-stability-formal-spec.lean): the
bilinear transform `fi.tf2s` — the basis of most of `filters.lib` — maps
every Hurwitz-stable analog second-order section to a Jury-stable digital
one, at every sampling rate and every cutoff below Nyquist. The `tan` in the
formula is never modelled; only its sign matters, which is what keeps the
statement inside exact rational arithmetic. Where the import pipeline
certifies concrete instantiations, this theorem covers the `tf2s` family
symbolically, once.

## 6. Workflow

```bash
make certify            # regenerate theorems into tests/build/, kernel-check,
                        # diff against the committed tests/lean/certified.lean
make certify-reference  # accept: regenerate the committed reference in place
make certify-tests      # the rate analysis on every regression test (#eval, not
                        # kernel-checked), against tests/certify-baseline.json
make certify-deep       # optional: build the mathlib layer discharging the
                        # Jury and tan obligations (downloads a large cache)
```

Contributors never write Lean. Adding coverage for a new function means
adding a small `.dsp` instantiating it in `tests/lean/`, reading the verdicts
in the `make certify` diff, and committing the regenerated reference.
Extending *what can be certified* means adding a rule to the prelude — a
different kind of contribution, reviewed as mathematics, with its soundness
argument in a comment.

## 7. Related work

No audio DSP library appears to maintain machine-checked certification of its
functions as part of its test harness. The closest works, each different in
kind:

- **Faust in Coq** — Gallego Arias, Hermant and Jouvelot,
  [*Verification of Faust Signal Processing Programs in Coq*](https://hal.science/hal-01108173)
  (CoqPL 2015) and [*A Taste of Sound Reasoning*](http://lac.linuxaudio.org/2015/video.php?id=19)
  (LAC 2015): a formalization of Faust's semantics in Coq, with a proof that a
  simple lowpass meets a specification property. The direct ancestor of this
  effort on the semantics side; the difference here is the live coupling — the
  certified object is regenerated from the compiler on every run rather than
  modelled once.
- **Verified numerical acoustics** — Boldo, Clément, Filliâtre, Mayero,
  Melquiond, Weis,
  [*Wave Equation Numerical Resolution: A Comprehensive Mechanized Proof of a C Program*](https://arxiv.org/abs/1112.1795)
  (J. Automated Reasoning, 2013): a C solver for the 1D acoustic wave
  equation proved correct including floating-point rounding, via Frama-C,
  Coq and Gappa. Evidence that the floating-point gap left open here is
  closable, at considerable cost.
- **Model checking of digital filters** —
  [DSVerifier](https://link.springer.com/chapter/10.1007/978-3-319-23404-5_9)
  (Cordeiro et al.): bounded model checking of fixed-point filters and
  controllers — stability, overflow, limit cycles. The same property family
  as our Jury criterion, checked by SMT-based exploration rather than by
  kernel-checked theorem.
- **Verified FFT** — Capretta,
  [*Certifying the Fast Fourier Transform with Coq*](https://link.springer.com/chapter/10.1007/3-540-44755-5_12)
  (TPHOLs 2001): algorithm-level correctness, one artifact, not a living
  library.
- **DSP hardware** — Brock and Hunt,
  [*Formal Analysis of the Motorola CAP DSP*](https://link.springer.com/chapter/10.1007/978-1-4471-0523-7_5)
  (ACL2, 1990s): microcode-level verification of a DSP processor, finding
  50+ pipeline hazards.
- **Synchronous dataflow** — [Vélus](https://velus.inria.fr/) (Bourke,
  Pouzet et al.): a Lustre compiler verified in Coq down to assembly on top
  of CompCert. The nearest neighbour on the language side; it certifies the
  *compiler*, where this work certifies *properties of compiled programs*.

## 8. Where this can go

*Since this section was written, the numerical tests have moved to float and
double over 44.1–192 kHz. [float-sr-proposal.md](float-sr-proposal.md)
proposes how the certification can follow: the sample rate and the controls
as ranges, recursion groups as state-space systems, and float and double as
semantics. It gives measurements from a prototype.*

The realistic ambition is not "prove the libraries correct" but two fronts
with different economics:

- **Index bounds, near-universally.** The property is meaningful for any
  function that reads a table or a delay line, and the interval analysis
  grows rule by rule with a comment-level soundness argument each time.
  Natural next steps: `select2` as range union, division by constants,
  ranges for `delay1`/`delay` outputs (state range ∪ {0}).
- **Stability, for the linear filter family.** The main missing step is
  symbolic coefficients: treating the `1/tan(w)` subterm as an opaque
  positive atom would let the import pipeline certify `fi.lowpass`,
  `fi.highpass` and the rest of the `tf2s`/`tf1s` family per-graph, the way
  the parametric theorem already covers them per-formula. Higher-order Jury
  and the `|g| < 1` comb/allpass conditions of `reverbs.lib` are finite
  arithmetic, within the house style. Weakly nonlinear loops (`tanh`-style
  saturators) look reachable through small-gain arguments — a new
  certifier with its own obligation.
- **Deeper trust, optionally.** The mathlib layer can grow toward a real
  denotation `Sig → (ℕ → ℝ)`, turning "the graph has shape X and X passes
  test Y" into an end-to-end statement about signal behaviour. Frequency-
  domain properties (−3 dB at cutoff, allpass on the unit circle) remain
  hand-written analytical work; the floating-point gap remains open, with
  Gappa-style analysis as the known road if it is ever attacked.

The infrastructure cost of adding a library function to the certified set is
one small `.dsp` file. That is the point of the design: the marginal cost of
coverage is low enough that certification can follow the library's growth
instead of trailing it.
