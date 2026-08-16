/-
  Lean 4 specification for:

    faustlibraries-code-doc-audit-2026-08-15-en.md, §10.3 architecture B

  Scope
  -----
  Imports a compiled Faust signal graph into Lean and certifies, mechanically,
  that its feedback recursion is stable.

  This file is the hand-written, reviewed prelude. The terms it is applied to
  are generated from `faust-rs --dump-sig-dag` by `scripts/sig2lean.py`.

  The DAG form of the dump matters here. The tree form re-expands every shared
  subgraph at each path reaching it, so `fi.bandpass(4, 500, 2000)` prints
  2.3 MB for what the DAG form says in 6.5 kB. Read through the DAG and emitted
  as a `let`-chain, the generated Lean stays flat: 8.8 kB of bindings for that
  same filter, and a check time that does not move with filter order.

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
def ofInt (k : Int) : Q := ⟨k, 1⟩
/-- Comparison by cross-multiplication; valid because denominators are positive. -/
def le (a b : Q) : Bool := decide (a.n * b.d ≤ b.n * a.d)
def min (a b : Q) : Q := if le a b then a else b
def max (a b : Q) : Q := if le a b then b else a
def floor (a : Q) : Int := Int.fdiv a.n a.d
def ceil (a : Q) : Int := -(Int.fdiv (-a.n) a.d)
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
  | control (name : String) (id : Int) (lo hi : Q) (kids : List Sig)
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
  | .control _ _ _ _ ks => hasRefL ks
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
  | .control _ _ _ _ ks => collectRecsL ks
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

A second, independent analysis over the same imported graph: are table reads and
delay taps addressed within range?

Since `--dump-sig` resolves declared control ranges, a slider now arrives as
`.control "SIGHSLIDER" 0 lo hi []` and its bounds enter the analysis directly.
That changes what the analysis *means*. It is not "is this program safe" — the
backend inserts a clamp (`std::min<int>(…, 15)`) exactly when the compiler's own
interval analysis finds the index can leave the table. It is:

> does this index stay in range **as written**, or does its safety rest on a
> compiler-inserted clamp?

Hence a three-valued verdict. `clampRequired` is not a defect report; it says the
site is safe only because the backend clamps it, which is a genuine dependency
worth naming. The analysis doubles as an independent oracle for the compiler's
bound insertion: a site this says is in range but that the backend clamps anyway
is a missed optimisation, and the converse would be a real defect. -/

/-- A conservative rational range with **independently** optional sides:
    `max 0 x` bounds the low side while leaving the high side unknown, which a
    single `Option (Q × Q)` cannot express. `none` on a side always means "no
    bound follows from the term", and is always a safe answer. -/
structure Range where
  lo : Option Q
  hi : Option Q
deriving Repr

namespace Range
def unknown : Range := ⟨none, none⟩
def exact (q : Q) : Range := ⟨some q, some q⟩

/-- Best bound available from one or both sides. -/
private def meet (f : Q → Q → Q) : Option Q → Option Q → Option Q
  | some x, some y => some (f x y)
  | some x, none   => some x
  | none,   some y => some y
  | none,   none   => none

private def join (f : Q → Q → Q) : Option Q → Option Q → Option Q
  | some x, some y => some (f x y)
  | _,      _      => none

/-- `min x y ≤ x`, so one known upper bound suffices; the lower bound needs both. -/
def rmin (a b : Range) : Range := ⟨join Q.min a.lo b.lo, meet Q.min a.hi b.hi⟩

/-- Dually for `max`. -/
def rmax (a b : Range) : Range := ⟨meet Q.max a.lo b.lo, join Q.max a.hi b.hi⟩

/-- Truncation toward zero of a value in `[lo, hi]` lands in
    `[⌊lo⌋, ⌈hi⌉]`. Widening on both sides is what keeps this sound for
    negative values, where truncation moves *up*. -/
def trunc (r : Range) : Range :=
  ⟨r.lo.map fun q => Q.ofInt q.floor, r.hi.map fun q => Q.ofInt q.ceil⟩
end Range

/-- Range of a subterm, when one follows from its structure alone.

    Recursion is on an explicit fuel counter rather than on `Sig`: the
    interesting cases descend into the *children of an `opaqueN` list*, which
    Lean does not accept as structurally decreasing on a nested inductive, and
    a `partial def` would be opaque to the kernel — `#eval` would work but
    `decide` would not. Running out of fuel yields the unknown range. -/
def rangeOfFuel : Nat → Sig → Range
  | 0, _ => Range.unknown
  | _ + 1, .int k => Range.exact (Q.ofInt k)
  | _ + 1, .const q => Range.exact q
  | _ + 1, .control _ _ lo hi _ => ⟨some lo, some hi⟩
  | n + 1, .opaqueN "SIGINTCAST" [x] => (rangeOfFuel n x).trunc
  | n + 1, .opaqueN "SIGMIN" [a, b]  => Range.rmin (rangeOfFuel n a) (rangeOfFuel n b)
  | n + 1, .opaqueN "SIGMAX" [a, b]  => Range.rmax (rangeOfFuel n a) (rangeOfFuel n b)
  | n + 1, .binop .rem a (.int m)    =>
      if 0 < m then
        -- C semantics: `%` truncates toward zero, so a negative dividend gives
        -- a negative remainder unless the dividend is known non-negative.
        match (rangeOfFuel n a).lo with
        | some l => if Q.le (Q.ofInt 0) l then ⟨some (Q.ofInt 0), some (Q.ofInt (m - 1))⟩
                    else ⟨some (Q.ofInt (1 - m)), some (Q.ofInt (m - 1))⟩
        | none   => ⟨some (Q.ofInt (1 - m)), some (Q.ofInt (m - 1))⟩
      else Range.unknown
  | _ + 1, _ => Range.unknown

/-- Fuel is bounded by the depth of an index expression, not by graph size. -/
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
  | .control _ _ _ _ ks => sitesL ks
  | .opaqueN _ ks => sitesL ks
  | _             => []

def sitesL : List Sig → List Site
  | []      => []
  | k :: ks => sites k ++ sitesL ks
end

inductive Verdict where
  | inRange
  | clampRequired
  | notProven
deriving Repr, DecidableEq

def siteVerdict : Site → Verdict
  | .table size idx =>
      match (rangeOf idx).lo, (rangeOf idx).hi with
      | some l, some h =>
          if Q.le (Q.ofInt 0) l && Q.le h (Q.ofInt (size - 1)) then .inRange
          else .clampRequired
      | _, _ => .notProven
  | .tap idx =>
      match (rangeOf idx).lo with
      | some l => if Q.le (Q.ofInt 0) l then .inRange else .clampRequired
      | none   => .notProven

/-- Certified only when every site is in range *as written*. -/
def certifyIndicesB (s : Sig) : Bool :=
  (sites s).all fun st => siteVerdict st == Verdict.inRange

private def showQ (q : Q) : String := s!"{q.n}/{q.d}"

private def showRange (r : Range) : String :=
  match r.lo, r.hi with
  | some l, some h => s!"[{showQ l}, {showQ h}]"
  | some l, none   => s!"[{showQ l}, ?]"
  | none,   some h => s!"[?, {showQ h}]"
  | none,   none   => "[?, ?]"

/-- Table and tap verdicts are not the same claim, so they are not worded the
    same. A table read is checked against a size the graph carries. A delay tap
    has no declared size in the graph — the compiler derives the line length
    from this very index — so all that can be checked here is non-negativity. -/
def siteReport (st : Site) : String :=
  match st with
  | .table size idx =>
      let v := match siteVerdict st with
               | .inRange       => "IN RANGE"
               | .clampRequired => "CLAMP REQUIRED"
               | .notProven     => "not proven"
      s!"table[{size}] index {showRange (rangeOf idx)} => {v}"
  | .tap idx =>
      let v := match siteVerdict st with
               | .inRange       => "NON-NEGATIVE"
               | .clampRequired => "may be negative"
               | .notProven     => "not proven"
      s!"delay tap {showRange (rangeOf idx)} => {v}"

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
