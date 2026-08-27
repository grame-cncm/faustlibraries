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

Two independent analyses run over each imported graph. Both are defined in
[signal-import-formal-spec.lean](signal-import-formal-spec.lean), the single
hand-written, hand-reviewed prelude (~500 commented lines, Lean 4.31 with only
its bundled `Std`, no `sorry`, axioms limited to `propext` on the generated
theorems).

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

The example set lives in [../tests/lean/](../tests/lean/): one small `.dsp`
per certified instantiation, plus deliberate counter-examples whose *refusal*
is itself pinned as a theorem (`+ ~ *(1.5)` is certified unstable; an
under-clamped table read is certified `CLAMP REQUIRED`). The generated
[certified.lean](../tests/lean/certified.lean) re-checks in under a second.

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

This is also what distinguishes the Lean analyses from the interval analysis
inside the Faust compilers (C++ and Rust), which must return an answer for
every node, quickly, and widens when unsure — silently. The two computations
are independent implementations, and their disagreements are informative in
both directions: a site Lean proves in range but the backend clamps anyway is
a missed optimization; a site the backend leaves unclamped but Lean cannot
prove deserves a look. The Lean side doubles as an oracle for the compiler's
own bound insertion.

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
| Exact rationals vs. floating-point execution | standing obligation, permanent limit — the theorems speak about the denoted exact arithmetic |
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
