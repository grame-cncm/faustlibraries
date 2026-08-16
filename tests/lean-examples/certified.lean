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
  | add | sub | mul | div | rem
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

/-! ## Index bounds

A second, independent analysis over the same imported graph: are table reads
and delay taps addressed within range?

The safety of a Faust table read is **not** in general visible in the signal
graph. `rdtable` emits a bare index, and the bound is inserted later by the
backend from the compiler's interval analysis of that index — for a slider,
from its declared range, which `--dump-sig` does not carry. What the graph
*does* show is when an index is bounded by its own structure: a literal, an
explicit `min`/`max` clamp written in the library source (as `delays.lib`
does), or a remainder.

So the analysis below is a **classifier**, not a bug finder: it separates the
sites whose safety follows from the graph alone from those that delegate it to
metadata outside the graph. Only the first kind can be certified here; the
second is reported as unproven, never as unsafe. -/

/-- A conservative integer range with **independently** optional sides:
    `max 0 x` bounds the low side while leaving the high side unknown, which a
    single `Option (Int × Int)` cannot express. `none` on a side always means
    "no bound follows from the term", and is always a safe answer. -/
structure Range where
  lo : Option Int
  hi : Option Int
deriving Repr, DecidableEq

namespace Range
def unknown : Range := ⟨none, none⟩
def exact (k : Int) : Range := ⟨some k, some k⟩

/-- Best bound available from one or both sides. -/
private def meet (f : Int → Int → Int) : Option Int → Option Int → Option Int
  | some x, some y => some (f x y)
  | some x, none   => some x
  | none,   some y => some y
  | none,   none   => none

private def join (f : Int → Int → Int) : Option Int → Option Int → Option Int
  | some x, some y => some (f x y)
  | _,      _      => none

/-- `min x y ≤ x`, so one known upper bound suffices; the lower bound needs both. -/
def rmin (a b : Range) : Range := ⟨join min a.lo b.lo, meet min a.hi b.hi⟩

/-- Dually for `max`. -/
def rmax (a b : Range) : Range := ⟨meet max a.lo b.lo, join max a.hi b.hi⟩
end Range

/-- Range of a subterm, when one follows from its structure alone.

    Recursion is on an explicit fuel counter rather than on `Sig`: the
    interesting cases descend into the *children of an `opaqueN` list*, which
    Lean does not accept as structurally decreasing on a nested inductive, and
    a `partial def` would be opaque to the kernel — `#eval` would work but
    `decide` would not. Running out of fuel yields the unknown range. -/
def rangeOfFuel : Nat → Sig → Range
  | 0, _ => Range.unknown
  | _ + 1, .int k => Range.exact k
  | n + 1, .opaqueN "SIGINTCAST" [x] => rangeOfFuel n x
  | n + 1, .opaqueN "SIGMIN" [a, b]  => Range.rmin (rangeOfFuel n a) (rangeOfFuel n b)
  | n + 1, .opaqueN "SIGMAX" [a, b]  => Range.rmax (rangeOfFuel n a) (rangeOfFuel n b)
  | n + 1, .binop .rem a (.int m)    =>
      if 0 < m then
        -- C semantics: `%` truncates toward zero, so a negative dividend gives
        -- a negative remainder unless the dividend is known non-negative.
        match (rangeOfFuel n a).lo with
        | some l => if 0 ≤ l then ⟨some 0, some (m - 1)⟩ else ⟨some (1 - m), some (m - 1)⟩
        | none   => ⟨some (1 - m), some (m - 1)⟩
      else Range.unknown
  | _ + 1, _ => Range.unknown

/-- Fuel is bounded by the depth of a clamp expression, not by graph size. -/
def rangeOf (s : Sig) : Range := rangeOfFuel 64 s

/-- One addressing site: a table read of a known size, or a delay tap. -/
inductive Site where
  | table (size : Int) (idx : Sig)
  | tap   (idx : Sig)

mutual
def sites : Sig → List Site
  | .opaqueN "SIGRDTBL" [.opaqueN "SIGWRTBL" (.int size :: rest), idx] =>
      .table size idx :: sitesL rest ++ sites idx
  | .delay x n    => .tap n :: sites x ++ sites n
  | .delay1 x     => sites x
  | .proj _ x     => sites x
  | .recur b      => sites b
  | .cons a b     => sites a ++ sites b
  | .binop _ a b  => sites a ++ sites b
  | .opaqueN _ ks => sitesL ks
  | _             => []

def sitesL : List Sig → List Site
  | []      => []
  | k :: ks => sites k ++ sitesL ks
end

/-- A table read is certified when its index provably lies in `[0, size-1]`;
    a delay tap when its index is provably non-negative. -/
def siteOkB : Site → Bool
  | .table size idx =>
      match (rangeOf idx).lo, (rangeOf idx).hi with
      | some l, some h => decide (0 ≤ l) && decide (h ≤ size - 1)
      | _, _           => false
  | .tap idx =>
      match (rangeOf idx).lo with
      | some l => decide (0 ≤ l)
      | none   => false

def certifyIndicesB (s : Sig) : Bool := (sites s).all siteOkB

def siteReport : Site → String
  | .table size idx =>
      match (rangeOf idx).lo, (rangeOf idx).hi with
      | some l, some h =>
          s!"table[{size}] index in [{l}, {h}] => " ++
          (if 0 ≤ l && h ≤ size - 1 then "IN RANGE" else "OUT OF RANGE")
      | _, _ => s!"table[{size}] index not bounded by structure => not proven"
  | .tap idx =>
      match (rangeOf idx).lo, (rangeOf idx).hi with
      | some l, some h => s!"delay tap in [{l}, {h}] => " ++
                          (if 0 ≤ l then "BOUNDED" else "may be negative")
      | some l, none   => s!"delay tap >= {l} => " ++ (if 0 ≤ l then "BOUNDED" else "may be negative")
      | _, _ => "delay tap not bounded by structure => not proven"

def indexReport (s : Sig) : String :=
  match sites s with
  | [] => "no addressing site"
  | ss => String.intercalate "; " (ss.map siteReport)

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

/-- `de = library("delays.lib");
process = de.fdelay(1024, hslider("d", 100, 0, 2000, 1));` — output 0 -/
def fdelay_clamped_out0 : Sig :=
  (.binop .add (.binop .mul (.delay (.input 0) (.opaqueN "SIGMIN" [(.int 1025), (.opaqueN "SIGMAX" [(.int 0), (.opaqueN "SIGINTCAST" [(.opaqueN "SIGHSLIDER" [(.int 0)])])])])) (.binop .sub (.int 1) (.binop .sub (.opaqueN "SIGHSLIDER" [(.int 0)]) (.opaqueN "SIGFLOOR" [(.opaqueN "SIGHSLIDER" [(.int 0)])])))) (.binop .mul (.delay (.input 0) (.opaqueN "SIGMIN" [(.int 1025), (.opaqueN "SIGMAX" [(.int 0), (.binop .add (.opaqueN "SIGINTCAST" [(.opaqueN "SIGHSLIDER" [(.int 0)])]) (.int 1))])])) (.binop .sub (.opaqueN "SIGHSLIDER" [(.int 0)]) (.opaqueN "SIGFLOOR" [(.opaqueN "SIGHSLIDER" [(.int 0)])]))))

/-- `import("maths.lib");
process = + ~ (*(0.9) : ma.tanh);` — output 0 -/
def nonlinear_out0 : Sig :=
  (.proj 0 (.recur (.cons (.binop .add (.opaqueN "SIGFFUN" [(.opaqueN "FFUN" [(.cons (.int 1) (.cons (.cons (.opaque "tanhf") (.cons (.opaque "tanh") (.cons (.opaque "tanhl") (.cons (.opaque "tanhl") (.nil))))) (.cons (.int 1) (.nil)))), (.opaque "<math.h>"), (.opaque "\\\"\\\"")]), (.cons (.binop .mul (.delay1 (.proj 0 (.ref 1))) (.const ⟨8106479329266893, 9007199254740992⟩)) (.nil))]) (.input 0)) (.nil))))

/-- `process = *(0.5) : (+ ~ *(0.7));` — output 0 -/
def onepole_out0 : Sig :=
  (.proj 0 (.recur (.cons (.binop .add (.binop .mul (.delay1 (.proj 0 (.ref 1))) (.const ⟨3152519739159347, 4503599627370496⟩)) (.binop .mul (.input 0) (.const ⟨1, 2⟩))) (.nil))))

/-- `os = library("oscillators.lib");
process = os.osc(440);` — output 0 -/
def osc_out0 : Sig :=
  (.opaqueN "SIGRDTBL" [(.opaqueN "SIGWRTBL" [(.int 65536), (.opaqueN "SIGGEN" [(.opaqueN "SIGSIN" [(.binop .div (.binop .mul (.opaqueN "SIGFLOATCAST" [(.proj 0 (.recur (.cons (.binop .rem (.binop .add (.delay1 (.proj 0 (.ref 1))) (.delay1 (.int 1))) (.int 65536)) (.nil))))]) (.const ⟨884279719003555, 140737488355328⟩)) (.const ⟨65536, 1⟩))])]), (.nil), (.nil)]), (.opaqueN "SIGINTCAST" [(.binop .mul (.proj 0 (.recur (.cons (.binop .sub (.opaqueN "SIGSELECT2" [(.opaqueN "SIGBINOP:or" [(.binop .sub (.int 1) (.delay1 (.int 1))), (.int 0)]), (.binop .add (.delay1 (.proj 0 (.ref 1))) (.binop .div (.int 440) (.opaqueN "SIGMIN" [(.const ⟨192000, 1⟩), (.opaqueN "SIGMAX" [(.const ⟨1, 1⟩), (.opaqueN "SIGFCONST" [(.int 0), (.opaque "fSamplingFreq"), (.opaque "<math.h>")])])]))), (.int 0)]) (.opaqueN "SIGFLOOR" [(.opaqueN "SIGSELECT2" [(.opaqueN "SIGBINOP:or" [(.binop .sub (.int 1) (.delay1 (.int 1))), (.int 0)]), (.binop .add (.delay1 (.proj 0 (.ref 1))) (.binop .div (.int 440) (.opaqueN "SIGMIN" [(.const ⟨192000, 1⟩), (.opaqueN "SIGMAX" [(.const ⟨1, 1⟩), (.opaqueN "SIGFCONST" [(.int 0), (.opaque "fSamplingFreq"), (.opaque "<math.h>")])])]))), (.int 0)])])) (.nil)))) (.const ⟨65536, 1⟩))])])

/-- `process = rdtable(16, 1.0, min(100, max(0, int(hslider("i",0,0,100,1)))));` — output 0 -/
def table_bad_clamp_out0 : Sig :=
  (.opaqueN "SIGRDTBL" [(.opaqueN "SIGWRTBL" [(.int 16), (.opaqueN "SIGGEN" [(.const ⟨1, 1⟩)]), (.nil), (.nil)]), (.opaqueN "SIGMIN" [(.int 100), (.opaqueN "SIGMAX" [(.int 0), (.opaqueN "SIGINTCAST" [(.opaqueN "SIGHSLIDER" [(.int 0)])])])])])

/-- `process = rdtable(16, 1.0, min(15, max(0, int(hslider("i",0,0,100,1)))));` — output 0 -/
def table_good_clamp_out0 : Sig :=
  (.opaqueN "SIGRDTBL" [(.opaqueN "SIGWRTBL" [(.int 16), (.opaqueN "SIGGEN" [(.const ⟨1, 1⟩)]), (.nil), (.nil)]), (.opaqueN "SIGMIN" [(.int 15), (.opaqueN "SIGMAX" [(.int 0), (.opaqueN "SIGINTCAST" [(.opaqueN "SIGHSLIDER" [(.int 0)])])])])])

/-- `process = rdtable(16, 1.0, int(hslider("i",0,0,100,1)));` — output 0 -/
def table_unclamped_out0 : Sig :=
  (.opaqueN "SIGRDTBL" [(.opaqueN "SIGWRTBL" [(.int 16), (.opaqueN "SIGGEN" [(.const ⟨1, 1⟩)]), (.nil), (.nil)]), (.opaqueN "SIGINTCAST" [(.opaqueN "SIGHSLIDER" [(.int 0)])])])

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

Two independent analyses over the same imported graph.
`certifyStableB` reads the feedback coefficients and applies the
Jury criterion. `certifyIndicesB` checks every table read and
delay tap whose range follows from the graph structure alone;
`false` there means *not proven*, never *unsafe*. -/

#eval certifyReport fdelay_clamped_out0
#eval certifyReport nonlinear_out0
#eval certifyReport onepole_out0
#eval certifyReport osc_out0
#eval certifyReport table_bad_clamp_out0
#eval certifyReport table_good_clamp_out0
#eval certifyReport table_unclamped_out0
#eval certifyReport tf2_stable_out0
#eval certifyReport tf2_unstable_out0
#eval certifyReport unstable_out0

#eval indexReport fdelay_clamped_out0
#eval indexReport nonlinear_out0
#eval indexReport onepole_out0
#eval indexReport osc_out0
#eval indexReport table_bad_clamp_out0
#eval indexReport table_good_clamp_out0
#eval indexReport table_unclamped_out0
#eval indexReport tf2_stable_out0
#eval indexReport tf2_unstable_out0
#eval indexReport unstable_out0

theorem fdelay_clamped_out0_stability : certifyStableB fdelay_clamped_out0 = false := by decide
theorem nonlinear_out0_stability : certifyStableB nonlinear_out0 = false := by decide
theorem onepole_out0_stability : certifyStableB onepole_out0 = true := by decide
theorem osc_out0_stability : certifyStableB osc_out0 = false := by decide
theorem table_bad_clamp_out0_stability : certifyStableB table_bad_clamp_out0 = false := by decide
theorem table_good_clamp_out0_stability : certifyStableB table_good_clamp_out0 = false := by decide
theorem table_unclamped_out0_stability : certifyStableB table_unclamped_out0 = false := by decide
theorem tf2_stable_out0_stability : certifyStableB tf2_stable_out0 = true := by decide
theorem tf2_unstable_out0_stability : certifyStableB tf2_unstable_out0 = false := by decide
theorem unstable_out0_stability : certifyStableB unstable_out0 = false := by decide

theorem fdelay_clamped_out0_indices : certifyIndicesB fdelay_clamped_out0 = true := by decide
theorem nonlinear_out0_indices : certifyIndicesB nonlinear_out0 = true := by decide
theorem onepole_out0_indices : certifyIndicesB onepole_out0 = true := by decide
theorem osc_out0_indices : certifyIndicesB osc_out0 = false := by decide
theorem table_bad_clamp_out0_indices : certifyIndicesB table_bad_clamp_out0 = false := by decide
theorem table_good_clamp_out0_indices : certifyIndicesB table_good_clamp_out0 = true := by decide
theorem table_unclamped_out0_indices : certifyIndicesB table_unclamped_out0 = false := by decide
theorem tf2_stable_out0_indices : certifyIndicesB tf2_stable_out0 = true := by decide
theorem tf2_unstable_out0_indices : certifyIndicesB tf2_unstable_out0 = true := by decide
theorem unstable_out0_indices : certifyIndicesB unstable_out0 = true := by decide

end Faust.Signal.Generated