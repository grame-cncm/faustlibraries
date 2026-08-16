/-
  Lean 4 specification for:

    faustlibraries-code-doc-audit-2026-08-15-en.md, §10.3 architecture B

  Scope
  -----
  Imports a compiled Faust signal graph into Lean and certifies, mechanically,
  that its feedback recursion is stable.

  This file is the hand-written, reviewed prelude. The terms it is applied to
  are generated from `faust-rs --dump-sig` by `scripts/sig2lean.py`:

      export FAUST_RS=<faust-rs>/target/release/faust-rs
      export FAUST_LIBS=<faustlibraries>
      scripts/sig2lean.py signal-import-formal-spec.lean out.lean f.dsp ...
      lean out.lean                                # Lean 4.31, bundled Std

  The generator runs Lean once to read each verdict, then emits a
  `by decide` theorem pinning it. The theorem is the artefact: Lean proves it,
  the generator only predicts it.

  Nothing in this prelude depends on the generated part, so it can be reviewed
  on its own.

  This file uses only Lean's bundled Std library. It contains no `sorry` and no
  axioms beyond `propext`. Validate it with:

      lean signal-import-formal-spec.lean
-/
import Std

namespace Faust.Signal

/-! ## Exact coefficients

Every IEEE-754 double is exactly `m / 2ᵏ`, so coefficients are carried as an
integer pair rather than as `Rat`: in Std 4.31 `Rat` does not kernel-reduce, so
`decide` (and `grind`, and `rfl`) get stuck on `Rat.instDecidableLt`. Integer
pairs keep every check decidable. -/

/-- A rational with an explicit positive denominator. -/
structure Q where
  n : Int
  d : Int
deriving Repr, DecidableEq, Inhabited

namespace Q
def zero : Q := ⟨0, 1⟩
def one  : Q := ⟨1, 1⟩
def neg  (a : Q) : Q := ⟨-a.n, a.d⟩
def add  (a b : Q) : Q := ⟨a.n * b.d + b.n * a.d, a.d * b.d⟩
def wellFormed (a : Q) : Bool := decide (0 < a.d)
end Q

inductive BinOp where
  | add | sub | mul | div
deriving Repr, DecidableEq

/-! ## The imported graph

`Sig` mirrors the tags emitted by `--dump-sig`. It is deliberately **total**:
every tag the importer does not model becomes `opaqueN`, which no analysis
below can ever read as a linear term. Adding a tag can therefore only make the
certifier accept more, never make it accept something wrong. -/

inductive Sig where
  | const   (q : Q)
  | int     (i : Int)
  | input   (i : Int)
  | delay1  (x : Sig)
  | delay   (x n : Sig)
  | proj    (i : Int) (x : Sig)
  | recur   (body : Sig)
  | ref     (i : Int)
  | cons    (a b : Sig)
  | nil
  | binop   (op : BinOp) (a b : Sig)
  | opaque  (name : String)
  | opaqueN (name : String) (kids : List Sig)
deriving Repr, Inhabited

/-! ## Recognising the linear part -/

mutual
/-- Does this subterm mention the enclosing recursion at all? -/
def hasRef : Sig → Bool
  | .ref _        => true
  | .delay1 x     => hasRef x
  | .delay x n    => hasRef x || hasRef n
  | .proj _ x     => hasRef x
  | .recur b      => hasRef b
  | .cons a b     => hasRef a || hasRef b
  | .binop _ a b  => hasRef a || hasRef b
  | .opaqueN _ ks => hasRefL ks
  | _             => false

def hasRefL : List Sig → Bool
  | []      => false
  | k :: ks => hasRef k || hasRefL ks
end

/-- `some k` when the term is exactly the recursion's own output delayed by
    `k` samples, i.e. `y[n-k]`. -/
def selfDepth : Sig → Option Nat
  | .proj 0 (.ref 1)  => some 0
  | .delay1 x         => (selfDepth x).map (· + 1)
  | .delay x (.int k) => if 0 ≤ k then (selfDepth x).map (· + k.toNat) else none
  | _                 => none

/-- Flatten an `+`/`-` tree into signed leaves. `true` = positive. -/
def addends (sign : Bool) : Sig → List (Bool × Sig)
  | .binop .add a b => addends sign a ++ addends sign b
  | .binop .sub a b => addends sign a ++ addends (!sign) b
  | t               => [(sign, t)]

/-- Read one addend as `coefficient · y[n-k]`. -/
def tapOf : Sig → Option (Nat × Q)
  | .binop .mul a b =>
      match selfDepth a, b with
      | some k, .const q => some (k, q)
      | _, _ =>
        match selfDepth b, a with
        | some k, .const q => some (k, q)
        | _, _             => none
  | t => (selfDepth t).map fun k => (k, Q.one)

/-! A real filter does not have its recursion at the root: `fi.tf2` emits the
numerator applied to the recursive state, so the `SIGREC` sits *below* a sum of
taps. The recursion is therefore searched for, not assumed. -/

mutual
/-- Every single-output recursion group occurring anywhere in the term. -/
def collectRecs : Sig → List Sig
  | s@(.proj 0 (.recur (.cons body .nil))) => s :: collectRecs body
  | .delay1 x     => collectRecs x
  | .delay x n    => collectRecs x ++ collectRecs n
  | .proj _ x     => collectRecs x
  | .recur b      => collectRecs b
  | .cons a b     => collectRecs a ++ collectRecs b
  | .binop _ a b  => collectRecs a ++ collectRecs b
  | .opaqueN _ ks => collectRecsL ks
  | _             => []

def collectRecsL : List Sig → List Sig
  | []      => []
  | k :: ks => collectRecs k ++ collectRecsL ks
end

/-- Accumulate the feedback taps of one recursion body. -/
def scanBody : List (Bool × Sig) → Q → Q → Option (Q × Q)
  | [], c1, c2 => some (c1, c2)
  | (s, t) :: rest, c1, c2 =>
      if !hasRef t then scanBody rest c1 c2
      else match tapOf t with
           | some (1, q) => scanBody rest (c1.add (if s then q else q.neg)) c2
           | some (2, q) => scanBody rest c1 (c2.add (if s then q else q.neg))
           | _           => none

/-- Feedback coefficients of a second-order (or lower) linear recursion,
    written `y[n] = c₁·y[n-1] + c₂·y[n-2] + (terms free of y)`.

    Returns `none` — refusing to certify — whenever the term does not hold
    exactly one single-output recursion, or when any addend of that recursion
    mentions it without being exactly such a tap: a nonlinear recursion, a
    delay-free loop (`k = 0`), an order above 2, or an unmodelled node. -/
def analyseRec : Sig → Option (Q × Q)
  | .proj 0 (.recur (.cons body .nil)) => scanBody (addends true body) Q.zero Q.zero
  | _ => none

/-- `Sig` is a nested inductive, so `deriving DecidableEq` does not apply and
    the collected recursions cannot be deduplicated structurally. Comparing
    their *analyses* instead is both cheaper and sufficient: the verdict is
    accepted only when every recursion in the graph yields the same feedback
    pair, in which case certifying that pair certifies all of them. -/
def feedbackOf (s : Sig) : Option (Q × Q) :=
  match collectRecs s with
  | []      => none
  | r :: rs => let f := analyseRec r
               if rs.all (fun x => analyseRec x == f) then f else none

/-! ## The Jury criterion

For a denominator `1 + a₁z⁻¹ + a₂z⁻²` the order-2 criterion is `|a₂| < 1`
together with `|a₁| < 1 + a₂`; at order 1 it is `|a₁| < 1`. Both are cleared
of denominators here so every comparison is over `Int`. -/

/-- `a₁`, `a₂` from the feedback coefficients: the denominator of
    `y[n] = c₁y[n-1] + c₂y[n-2] + …` is `1 - c₁z⁻¹ - c₂z⁻²`. -/
def denomCoefs (c : Q × Q) : Q × Q := (c.1.neg, c.2.neg)

def juryStableB (a : Q × Q) : Bool :=
  let n1 := a.1.n * a.2.d
  let n2 := a.2.n * a.1.d
  let D  := a.1.d * a.2.d
  decide (0 < D) &&
  decide (n2.natAbs < D.natAbs) &&
  decide (0 < D + n2 - n1) &&
  decide (0 < D + n2 + n1)

/-- The end-to-end certifier: import graph in, verdict out. -/
def certifyStableB (s : Sig) : Bool :=
  match feedbackOf s with
  | some c => juryStableB (denomCoefs c)
  | none   => false

/-- Human-readable form of the same computation, for `#eval`. -/
def certifyReport (s : Sig) : String :=
  match feedbackOf s with
  | none => "not a recognised linear recursion of order <= 2 — not certified"
  | some c =>
      let a := denomCoefs c
      s!"a1 = {a.1.n}/{a.1.d}, a2 = {a.2.n}/{a.2.d} => " ++
      (if juryStableB a then "STABLE" else "NOT STABLE")

/-! ## Standing obligations

Two gaps are recorded here rather than silently relied upon.

1. **Adequacy of the import.** `Sig` is asserted to mirror what
   `--dump-sig` emits. Nothing in Lean checks that; it is a review gate, and
   the honest mitigation is round-tripping the generated terms back to the
   dump text and diffing.

2. **Adequacy of `feedbackOf`.** It is asserted to return the feedback
   coefficients of the recursion it was given. Proving that needs a denotation
   `Sig → (ℕ → ℝ)` and hence mathlib. Until then the guarantee is one-sided
   but useful: `feedbackOf` returns `none` on anything it does not recognise
   exactly, so a `true` verdict is never produced from a graph it misread —
   only from one it read as a plain second-order linear recursion.

The classical equivalence "Jury criterion ⟺ roots inside the unit disc" is the
same standing obligation as in `tf2s-stability-formal-spec.lean`.

Note also that certification is over the **exact rationals** denoted by the
exported double-precision coefficients. It says nothing about the behaviour of
the filter as executed in floating point. -/

end Faust.Signal

/-! # Generated section

Everything below is produced by `scripts/sig2lean.py` from
`faust-rs --dump-sig`. Do not edit by hand. -/

namespace Faust.Signal.Generated
open Faust.Signal

/-- `import("maths.lib");
process = + ~ (*(0.9) : ma.tanh);` — output 0 -/
def nonlinear_out0 : Sig :=
  (.proj 0 (.recur (.cons (.binop .add (.opaqueN "SIGFFUN" [(.opaqueN "FFUN" [(.cons (.int 1) (.cons (.cons (.opaque "tanhf") (.cons (.opaque "tanh") (.cons (.opaque "tanhl") (.cons (.opaque "tanhl") (.nil))))) (.cons (.int 1) (.nil)))), (.opaque "<math.h>"), (.opaque "\\\"\\\"")]), (.cons (.binop .mul (.delay1 (.proj 0 (.ref 1))) (.const ⟨8106479329266893, 9007199254740992⟩)) (.nil))]) (.input 0)) (.nil))))

/-- `process = *(0.5) : (+ ~ *(0.7));` — output 0 -/
def onepole_out0 : Sig :=
  (.proj 0 (.recur (.cons (.binop .add (.binop .mul (.delay1 (.proj 0 (.ref 1))) (.const ⟨3152519739159347, 4503599627370496⟩)) (.binop .mul (.input 0) (.const ⟨1, 2⟩))) (.nil))))

/-- `import("filters.lib");
process = fi.tf2(0.3, 0.2, 0.1, -1.2, 0.5);` — output 0 -/
def tf2_stable_out0 : Sig :=
  (.binop .add (.binop .add (.binop .mul (.proj 0 (.recur (.cons (.binop .sub (.input 0) (.binop .add (.binop .mul (.delay1 (.proj 0 (.ref 1))) (.const ⟨(-5404319552844595), 4503599627370496⟩)) (.binop .mul (.delay (.delay1 (.proj 0 (.ref 1))) (.int 1)) (.const ⟨1, 2⟩)))) (.nil)))) (.const ⟨5404319552844595, 18014398509481984⟩)) (.binop .mul (.delay (.proj 0 (.recur (.cons (.binop .sub (.input 0) (.binop .add (.binop .mul (.delay1 (.proj 0 (.ref 1))) (.const ⟨(-5404319552844595), 4503599627370496⟩)) (.binop .mul (.delay (.delay1 (.proj 0 (.ref 1))) (.int 1)) (.const ⟨1, 2⟩)))) (.nil)))) (.int 1)) (.const ⟨3602879701896397, 18014398509481984⟩))) (.binop .mul (.delay (.proj 0 (.recur (.cons (.binop .sub (.input 0) (.binop .add (.binop .mul (.delay1 (.proj 0 (.ref 1))) (.const ⟨(-5404319552844595), 4503599627370496⟩)) (.binop .mul (.delay (.delay1 (.proj 0 (.ref 1))) (.int 1)) (.const ⟨1, 2⟩)))) (.nil)))) (.int 2)) (.const ⟨3602879701896397, 36028797018963968⟩)))

/-- `import("filters.lib");
process = fi.tf2(1, 0, 0, -0.5, -0.8);` — output 0 -/
def tf2_unstable_out0 : Sig :=
  (.binop .add (.binop .add (.binop .mul (.proj 0 (.recur (.cons (.binop .sub (.input 0) (.binop .add (.binop .mul (.delay1 (.proj 0 (.ref 1))) (.const ⟨(-1), 2⟩)) (.binop .mul (.delay (.delay1 (.proj 0 (.ref 1))) (.int 1)) (.const ⟨(-3602879701896397), 4503599627370496⟩)))) (.nil)))) (.int 1)) (.binop .mul (.delay (.proj 0 (.recur (.cons (.binop .sub (.input 0) (.binop .add (.binop .mul (.delay1 (.proj 0 (.ref 1))) (.const ⟨(-1), 2⟩)) (.binop .mul (.delay (.delay1 (.proj 0 (.ref 1))) (.int 1)) (.const ⟨(-3602879701896397), 4503599627370496⟩)))) (.nil)))) (.int 1)) (.int 0))) (.binop .mul (.delay (.proj 0 (.recur (.cons (.binop .sub (.input 0) (.binop .add (.binop .mul (.delay1 (.proj 0 (.ref 1))) (.const ⟨(-1), 2⟩)) (.binop .mul (.delay (.delay1 (.proj 0 (.ref 1))) (.int 1)) (.const ⟨(-3602879701896397), 4503599627370496⟩)))) (.nil)))) (.int 2)) (.int 0)))

/-- `process = + ~ *(1.5);` — output 0 -/
def unstable_out0 : Sig :=
  (.proj 0 (.recur (.cons (.binop .add (.binop .mul (.delay1 (.proj 0 (.ref 1))) (.const ⟨3, 2⟩)) (.input 0)) (.nil))))

/-! ## Certification

Each line below is kernel-checked. `true` means the feedback
coefficients read off the exported graph satisfy the Jury
criterion; `false` means they do not, or that the graph was
not recognised as a linear recursion of order ≤ 2. -/

#eval certifyReport nonlinear_out0
#eval certifyReport onepole_out0
#eval certifyReport tf2_stable_out0
#eval certifyReport tf2_unstable_out0
#eval certifyReport unstable_out0

theorem nonlinear_out0_certified : certifyStableB nonlinear_out0 = false := by decide
theorem onepole_out0_certified : certifyStableB onepole_out0 = true := by decide
theorem tf2_stable_out0_certified : certifyStableB tf2_stable_out0 = true := by decide
theorem tf2_unstable_out0_certified : certifyStableB tf2_unstable_out0 = false := by decide
theorem unstable_out0_certified : certifyStableB unstable_out0 = false := by decide

end Faust.Signal.Generated