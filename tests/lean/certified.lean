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
def mul (a b : Q) : Q := ⟨a.n * b.n, a.d * b.d⟩
/-- Strict positivity; like `le`, valid because denominators are positive. -/
def pos (a : Q) : Bool := decide (0 < a.n)
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

mutual
/-- Structural equality. `Sig` is a nested inductive, so `deriving DecidableEq`
    does not apply (see `feedbackOf`); this hand-written `Bool` version is what
    the range analysis uses to recognise `x - floor(x)` — the two occurrences
    of `x` come from one DAG node, so after `let`-inlining they are structurally
    identical. -/
def beq : Sig → Sig → Bool
  | .const a, .const b => a == b
  | .int a, .int b => a == b
  | .input a, .input b => a == b
  | .delay1 a, .delay1 b => beq a b
  | .delay a n, .delay b m => beq a b && beq n m
  | .proj i a, .proj j b => i == j && beq a b
  | .recur a, .recur b => beq a b
  | .ref a, .ref b => a == b
  | .cons a b, .cons c d => beq a c && beq b d
  | .nil, .nil => true
  | .binop o a b, .binop p c d => o == p && beq a c && beq b d
  | .control n i lo hi ks, .control m j lo' hi' ks' =>
      n == m && i == j && lo == lo' && hi == hi' && beqL ks ks'
  | .opaque a, .opaque b => a == b
  | .opaqueN a ks, .opaqueN b ks' => a == b && beqL ks ks'
  | _, _ => false

def beqL : List Sig → List Sig → Bool
  | [], [] => true
  | a :: as, b :: bs => beq a b && beqL as bs
  | _, _ => false
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
    bound follows from the term", and is always a safe answer.

    The upper bound additionally carries a strictness flag: `hiStrict = true`
    reads `v < hi` instead of `v ≤ hi`. It exists for one client — the phasor
    identity `x - floor(x) ∈ [0, 1)`, where the closed bound `1` would put
    `intCast(frac · N)` at `N`, one past the table, and lose the verdict that
    matters. The lower bound stays closed: no current rule produces a strict
    one, and a strict bound may always be weakened to the closed bound at the
    same value (`v < h` implies `v ≤ h`). `hiStrict` is meaningful only when
    `hi` is `some`. -/
structure Range where
  lo : Option Q
  hi : Option Q
  hiStrict : Bool
deriving Repr

namespace Range
def unknown : Range := ⟨none, none, false⟩
def exact (q : Q) : Range := ⟨some q, some q, false⟩

/-- Best bound available from one or both sides. -/
private def meet (f : Q → Q → Q) : Option Q → Option Q → Option Q
  | some x, some y => some (f x y)
  | some x, none   => some x
  | none,   some y => some y
  | none,   none   => none

private def join (f : Q → Q → Q) : Option Q → Option Q → Option Q
  | some x, some y => some (f x y)
  | _,      _      => none

/-- Strictness of `min` over upper bounds: the smaller bound's flag wins; on a
    tie, either strict flag keeps the result strict. -/
private def strictMin : Option Q → Bool → Option Q → Bool → Bool
  | some x, sx, some y, sy =>
      if Q.le x y then (if Q.le y x then sx || sy else sx) else sy
  | some _, sx, none, _  => sx
  | none, _, some _, sy  => sy
  | none, _, none, _     => false

/-- Strictness of `max` over upper bounds: the larger bound's flag wins; on a
    tie, both must be strict for the result to be. Unknown on either side
    already makes the joined bound `none`, so the flag is then irrelevant. -/
private def strictMax : Option Q → Bool → Option Q → Bool → Bool
  | some x, sx, some y, sy =>
      if Q.le x y then (if Q.le y x then sx && sy else sy) else sx
  | _, _, _, _ => false

/-- `min x y ≤ x`, so one known upper bound suffices; the lower bound needs both. -/
def rmin (a b : Range) : Range :=
  ⟨join Q.min a.lo b.lo, meet Q.min a.hi b.hi,
   strictMin a.hi a.hiStrict b.hi b.hiStrict⟩

/-- Dually for `max`. -/
def rmax (a b : Range) : Range :=
  ⟨meet Q.max a.lo b.lo, join Q.max a.hi b.hi,
   strictMax a.hi a.hiStrict b.hi b.hiStrict⟩

/-- Truncation toward zero of a value in `[lo, hi]` lands in
    `[⌊lo⌋, ⌈hi⌉]`. Widening on both sides is what keeps this sound for
    negative values, where truncation moves *up*.

    A strict upper bound tightens to `max (⌈hi⌉ - 1) 0`: a non-negative value
    below `hi` truncates to an integer at most `⌈hi⌉ - 1`, and a negative one
    truncates upward to at most `0` — reaching `0` even when `hi ≤ 0`, hence
    the outer `max`. The result is closed either way: truncation outputs can
    attain these integer bounds. -/
def trunc (r : Range) : Range :=
  ⟨r.lo.map fun q => Q.ofInt q.floor,
   r.hi.map fun q =>
     if r.hiStrict then
       let c := q.ceil - 1
       Q.ofInt (if c ≤ 0 then 0 else c)
     else Q.ofInt q.ceil,
   false⟩

/-- Multiply a range by an exact constant. A positive factor preserves both
    sides and the upper bound's strictness; a negative factor swaps the sides,
    the strict upper bound weakening to a closed lower one (`v < h` gives
    `q·v > q·h`, hence `q·v ≥ q·h`); a zero factor pins the product at zero. -/
def scale (r : Range) (q : Q) : Range :=
  if Q.pos q then ⟨r.lo.map (Q.mul q), r.hi.map (Q.mul q), r.hiStrict⟩
  else if Q.pos q.neg then ⟨r.hi.map (Q.mul q), r.lo.map (Q.mul q), false⟩
  else exact Q.zero
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
  | _ + 1, .control _ _ lo hi _ => ⟨some lo, some hi, false⟩
  | n + 1, .opaqueN "SIGINTCAST" [x] => (rangeOfFuel n x).trunc
  | n + 1, .opaqueN "SIGMIN" [a, b]  => Range.rmin (rangeOfFuel n a) (rangeOfFuel n b)
  | n + 1, .opaqueN "SIGMAX" [a, b]  => Range.rmax (rangeOfFuel n a) (rangeOfFuel n b)
  | n + 1, .binop .rem a (.int m)    =>
      if 0 < m then
        -- C semantics: `%` truncates toward zero, so a negative dividend gives
        -- a negative remainder unless the dividend is known non-negative.
        match (rangeOfFuel n a).lo with
        | some l => if Q.le (Q.ofInt 0) l then ⟨some (Q.ofInt 0), some (Q.ofInt (m - 1)), false⟩
                    else ⟨some (Q.ofInt (1 - m)), some (Q.ofInt (m - 1)), false⟩
        | none   => ⟨some (Q.ofInt (1 - m)), some (Q.ofInt (m - 1)), false⟩
      else Range.unknown
  | _ + 1, .binop .sub x (.opaqueN "SIGFLOOR" [y]) =>
      -- The phasor identity: over exact rationals, `x - ⌊x⌋ ∈ [0, 1)` whatever
      -- the range of `x`. The two occurrences are one DAG node, so structural
      -- equality is the right test.
      if beq x y then ⟨some Q.zero, some Q.one, true⟩ else Range.unknown
  | n + 1, .binop .mul a (.const q) => (rangeOfFuel n a).scale q
  | n + 1, .binop .mul a (.int k)   => (rangeOfFuel n a).scale (Q.ofInt k)
  | n + 1, .binop .mul (.const q) b => (rangeOfFuel n b).scale q
  | n + 1, .binop .mul (.int k) b   => (rangeOfFuel n b).scale (Q.ofInt k)
  | n + 1, .proj 0 (.recur (.cons body .nil)) =>
      -- The recursion invariant, in its state-independent form: `ref`, `delay1`
      -- and `delay` all yield the unknown range, so any bound this returns for
      -- the body holds for arbitrary values of the recursive state — hence for
      -- every output of the recursion, with no fixed-point iteration. This is
      -- what bounds a phasor: its body is `frac(state + inc)`, and the `[0, 1)`
      -- of the rule above does not depend on the state at all.
      rangeOfFuel n body
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
  let close := if r.hiStrict then ")" else "]"
  match r.lo, r.hi with
  | some l, some h => s!"[{showQ l}, {showQ h}{close}"
  | some l, none   => s!"[{showQ l}, ?]"
  | none,   some h => s!"[?, {showQ h}{close}"
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
same standing obligation as in `tf2s-stability-formal-spec.lean`. At order 2 it
is discharged in the optional mathlib project: `mathlib/JuryRoots.lean` proves
`juryStableB a = true ↔ every root of z² + a₁z + a₂ has norm < 1` for the
denoted rational coefficients (`make certify-deep`). This Std-only file does
not depend on that proof; the obligation note stays here so the trust story is
readable from one place.

Note also that certification is over the **exact rationals** denoted by the
exported double-precision coefficients. It says nothing about the behaviour of
the filter as executed in floating point.

The same caveat carries one concrete instance in the range analysis: the
phasor rule reads `x - floor(x) ∈ [0, 1)`, which is an identity of exact
arithmetic. In floating point the subtraction is exact whenever
`floor(x) ≤ x < 2·floor(x)` (Sterbenz) and rounds otherwise; a rounding that
reached `1.0` would step outside the certified interval. Auditing the float
behaviour of `frac` is part of the same floating-point obligation, not a new
one. -/

end Faust.Signal

/-! # Generated section

Everything below is produced by `scripts/sig2lean.py` from
`faust-rs --dump-sig`. Do not edit by hand. -/

namespace Faust.Signal.Generated
open Faust.Signal

/-- `de = library("delays.lib");
process = de.fdelay(1024, hslider("d", 100, 0, 2000, 1));` — output 0 -/
def fdelay_clamped_out0 : Sig :=
  let n0 : Sig := Sig.input 0
  let n1 : Sig := Sig.control "SIGHSLIDER" 0 ⟨0, 1⟩ ⟨2000, 1⟩ []
  let n2 : Sig := Sig.opaqueN "SIGINTCAST" [n1]
  let n3 : Sig := Sig.opaqueN "SIGMAX" [(.int 0), n2]
  let n4 : Sig := Sig.opaqueN "SIGMIN" [(.int 1025), n3]
  let n5 : Sig := Sig.delay n0 n4
  let n6 : Sig := Sig.opaqueN "SIGFLOOR" [n1]
  let n7 : Sig := Sig.binop .sub n1 n6
  let n8 : Sig := Sig.binop .sub (.int 1) n7
  let n9 : Sig := Sig.binop .mul n5 n8
  let n10 : Sig := Sig.binop .add n2 (.int 1)
  let n11 : Sig := Sig.opaqueN "SIGMAX" [(.int 0), n10]
  let n12 : Sig := Sig.opaqueN "SIGMIN" [(.int 1025), n11]
  let n13 : Sig := Sig.delay n0 n12
  let n14 : Sig := Sig.binop .mul n13 n7
  let n15 : Sig := Sig.binop .add n9 n14
  n15

/-- `import("stdfaust.lib");
process = fi.lowpass(3, 1000);` — output 0 -/
def lowpass3_out0 : Sig :=
  let n0 : Sig := Sig.ref 1
  let n1 : Sig := Sig.proj 0 n0
  let n2 : Sig := Sig.delay1 n1
  let n3 : Sig := Sig.opaqueN "SIGFCONST" [(.int 0), (.opaque "fSamplingFreq"), (.opaque "<math.h>")]
  let n4 : Sig := Sig.opaqueN "SIGMAX" [(.const ⟨1, 1⟩), n3]
  let n5 : Sig := Sig.opaqueN "SIGMIN" [(.const ⟨192000, 1⟩), n4]
  let n6 : Sig := Sig.binop .div (.const ⟨6908435304715273, 2199023255552⟩) n5
  let n7 : Sig := Sig.opaqueN "SIGTAN" [n6]
  let n8 : Sig := Sig.binop .div (.int 1) n7
  let n9 : Sig := Sig.binop .sub (.int 1) n8
  let n10 : Sig := Sig.binop .add (.int 1) n8
  let n11 : Sig := Sig.binop .div n9 n10
  let n12 : Sig := Sig.binop .sub (.int 0) n11
  let n13 : Sig := Sig.binop .mul n2 n12
  let n14 : Sig := Sig.input 0
  let n15 : Sig := Sig.binop .mul (.int 0) n8
  let n16 : Sig := Sig.binop .add (.int 1) n15
  let n17 : Sig := Sig.binop .div n16 n10
  let n18 : Sig := Sig.binop .mul n14 n17
  let n19 : Sig := Sig.delay1 n14
  let n20 : Sig := Sig.binop .sub (.int 1) n15
  let n21 : Sig := Sig.binop .div n20 n10
  let n22 : Sig := Sig.binop .mul n19 n21
  let n23 : Sig := Sig.binop .add n18 n22
  let n24 : Sig := Sig.binop .add n13 n23
  let n25 : Sig := Sig.cons n24 (.nil)
  let n26 : Sig := Sig.recur n25
  let n27 : Sig := Sig.proj 0 n26
  let n28 : Sig := Sig.binop .mul n8 n8
  let n29 : Sig := Sig.binop .sub (.int 1) n28
  let n30 : Sig := Sig.binop .mul (.int 2) n29
  let n31 : Sig := Sig.binop .mul (.const ⟨2251799813685249, 2251799813685248⟩) n8
  let n32 : Sig := Sig.binop .add (.int 1) n31
  let n33 : Sig := Sig.binop .add n32 n28
  let n34 : Sig := Sig.binop .div n30 n33
  let n35 : Sig := Sig.binop .mul n2 n34
  let n36 : Sig := Sig.delay n2 (.int 1)
  let n37 : Sig := Sig.binop .sub (.int 1) n31
  let n38 : Sig := Sig.binop .add n37 n28
  let n39 : Sig := Sig.binop .div n38 n33
  let n40 : Sig := Sig.binop .mul n36 n39
  let n41 : Sig := Sig.binop .add n35 n40
  let n42 : Sig := Sig.binop .sub n27 n41
  let n43 : Sig := Sig.cons n42 (.nil)
  let n44 : Sig := Sig.recur n43
  let n45 : Sig := Sig.proj 0 n44
  let n46 : Sig := Sig.binop .div (.int 1) n33
  let n47 : Sig := Sig.binop .mul n45 n46
  let n48 : Sig := Sig.delay n45 (.int 1)
  let n49 : Sig := Sig.binop .div (.int 2) n33
  let n50 : Sig := Sig.binop .mul n48 n49
  let n51 : Sig := Sig.binop .add n47 n50
  let n52 : Sig := Sig.delay n45 (.int 2)
  let n53 : Sig := Sig.binop .mul n52 n46
  let n54 : Sig := Sig.binop .add n51 n53
  n54

/-- `import("maths.lib");
process = + ~ (*(0.9) : ma.tanh);` — output 0 -/
def nonlinear_out0 : Sig :=
  let n0 : Sig := Sig.cons (.opaque "tanhl") (.nil)
  let n1 : Sig := Sig.cons (.opaque "tanhl") n0
  let n2 : Sig := Sig.cons (.opaque "tanh") n1
  let n3 : Sig := Sig.cons (.opaque "tanhf") n2
  let n4 : Sig := Sig.cons (.int 1) (.nil)
  let n5 : Sig := Sig.cons n3 n4
  let n6 : Sig := Sig.cons (.int 1) n5
  let n7 : Sig := Sig.opaqueN "FFUN" [n6, (.opaque "<math.h>"), (.opaque "\\\"\\\"")]
  let n8 : Sig := Sig.ref 1
  let n9 : Sig := Sig.proj 0 n8
  let n10 : Sig := Sig.delay1 n9
  let n11 : Sig := Sig.binop .mul n10 (.const ⟨8106479329266893, 9007199254740992⟩)
  let n12 : Sig := Sig.cons n11 (.nil)
  let n13 : Sig := Sig.opaqueN "SIGFFUN" [n7, n12]
  let n14 : Sig := Sig.input 0
  let n15 : Sig := Sig.binop .add n13 n14
  let n16 : Sig := Sig.cons n15 (.nil)
  let n17 : Sig := Sig.recur n16
  let n18 : Sig := Sig.proj 0 n17
  n18

/-- `process = *(0.5) : (+ ~ *(0.7));` — output 0 -/
def onepole_out0 : Sig :=
  let n0 : Sig := Sig.ref 1
  let n1 : Sig := Sig.proj 0 n0
  let n2 : Sig := Sig.delay1 n1
  let n3 : Sig := Sig.binop .mul n2 (.const ⟨3152519739159347, 4503599627370496⟩)
  let n4 : Sig := Sig.input 0
  let n5 : Sig := Sig.binop .mul n4 (.const ⟨1, 2⟩)
  let n6 : Sig := Sig.binop .add n3 n5
  let n7 : Sig := Sig.cons n6 (.nil)
  let n8 : Sig := Sig.recur n7
  let n9 : Sig := Sig.proj 0 n8
  n9

/-- `os = library("oscillators.lib");
process = os.osc(440);` — output 0 -/
def osc_out0 : Sig :=
  let n0 : Sig := Sig.ref 1
  let n1 : Sig := Sig.proj 0 n0
  let n2 : Sig := Sig.delay1 n1
  let n3 : Sig := Sig.delay1 (.int 1)
  let n4 : Sig := Sig.binop .add n2 n3
  let n5 : Sig := Sig.binop .rem n4 (.int 65536)
  let n6 : Sig := Sig.cons n5 (.nil)
  let n7 : Sig := Sig.recur n6
  let n8 : Sig := Sig.proj 0 n7
  let n9 : Sig := Sig.opaqueN "SIGFLOATCAST" [n8]
  let n10 : Sig := Sig.binop .mul n9 (.const ⟨884279719003555, 140737488355328⟩)
  let n11 : Sig := Sig.binop .div n10 (.const ⟨65536, 1⟩)
  let n12 : Sig := Sig.opaqueN "SIGSIN" [n11]
  let n13 : Sig := Sig.opaqueN "SIGGEN" [n12]
  let n14 : Sig := Sig.opaqueN "SIGWRTBL" [(.int 65536), n13, (.nil), (.nil)]
  let n15 : Sig := Sig.binop .sub (.int 1) n3
  let n16 : Sig := Sig.opaqueN "SIGBINOP:or" [n15, (.int 0)]
  let n17 : Sig := Sig.opaqueN "SIGFCONST" [(.int 0), (.opaque "fSamplingFreq"), (.opaque "<math.h>")]
  let n18 : Sig := Sig.opaqueN "SIGMAX" [(.const ⟨1, 1⟩), n17]
  let n19 : Sig := Sig.opaqueN "SIGMIN" [(.const ⟨192000, 1⟩), n18]
  let n20 : Sig := Sig.binop .div (.int 440) n19
  let n21 : Sig := Sig.binop .add n2 n20
  let n22 : Sig := Sig.opaqueN "SIGSELECT2" [n16, n21, (.int 0)]
  let n23 : Sig := Sig.opaqueN "SIGFLOOR" [n22]
  let n24 : Sig := Sig.binop .sub n22 n23
  let n25 : Sig := Sig.cons n24 (.nil)
  let n26 : Sig := Sig.recur n25
  let n27 : Sig := Sig.proj 0 n26
  let n28 : Sig := Sig.binop .mul n27 (.const ⟨65536, 1⟩)
  let n29 : Sig := Sig.opaqueN "SIGINTCAST" [n28]
  let n30 : Sig := Sig.opaqueN "SIGRDTBL" [n14, n29]
  n30

/-- `process = rdtable(16, 1.0, min(100, max(0, int(hslider("i",0,0,100,1)))));` — output 0 -/
def table_bad_clamp_out0 : Sig :=
  let n0 : Sig := Sig.opaqueN "SIGGEN" [(.const ⟨1, 1⟩)]
  let n1 : Sig := Sig.opaqueN "SIGWRTBL" [(.int 16), n0, (.nil), (.nil)]
  let n2 : Sig := Sig.control "SIGHSLIDER" 0 ⟨0, 1⟩ ⟨100, 1⟩ []
  let n3 : Sig := Sig.opaqueN "SIGINTCAST" [n2]
  let n4 : Sig := Sig.opaqueN "SIGMAX" [(.int 0), n3]
  let n5 : Sig := Sig.opaqueN "SIGMIN" [(.int 100), n4]
  let n6 : Sig := Sig.opaqueN "SIGRDTBL" [n1, n5]
  n6

/-- `process = rdtable(16, 1.0, min(15, max(0, int(hslider("i",0,0,100,1)))));` — output 0 -/
def table_good_clamp_out0 : Sig :=
  let n0 : Sig := Sig.opaqueN "SIGGEN" [(.const ⟨1, 1⟩)]
  let n1 : Sig := Sig.opaqueN "SIGWRTBL" [(.int 16), n0, (.nil), (.nil)]
  let n2 : Sig := Sig.control "SIGHSLIDER" 0 ⟨0, 1⟩ ⟨100, 1⟩ []
  let n3 : Sig := Sig.opaqueN "SIGINTCAST" [n2]
  let n4 : Sig := Sig.opaqueN "SIGMAX" [(.int 0), n3]
  let n5 : Sig := Sig.opaqueN "SIGMIN" [(.int 15), n4]
  let n6 : Sig := Sig.opaqueN "SIGRDTBL" [n1, n5]
  n6

/-- `process = rdtable(16, 1.0, int(hslider("i",0,0,100,1)));` — output 0 -/
def table_unclamped_out0 : Sig :=
  let n0 : Sig := Sig.opaqueN "SIGGEN" [(.const ⟨1, 1⟩)]
  let n1 : Sig := Sig.opaqueN "SIGWRTBL" [(.int 16), n0, (.nil), (.nil)]
  let n2 : Sig := Sig.control "SIGHSLIDER" 0 ⟨0, 1⟩ ⟨100, 1⟩ []
  let n3 : Sig := Sig.opaqueN "SIGINTCAST" [n2]
  let n4 : Sig := Sig.opaqueN "SIGRDTBL" [n1, n3]
  n4

/-- `import("filters.lib");
process = fi.tf2(0.3, 0.2, 0.1, -1.2, 0.5);` — output 0 -/
def tf2_stable_out0 : Sig :=
  let n0 : Sig := Sig.input 0
  let n1 : Sig := Sig.ref 1
  let n2 : Sig := Sig.proj 0 n1
  let n3 : Sig := Sig.delay1 n2
  let n4 : Sig := Sig.binop .mul n3 (.const ⟨(-5404319552844595), 4503599627370496⟩)
  let n5 : Sig := Sig.delay n3 (.int 1)
  let n6 : Sig := Sig.binop .mul n5 (.const ⟨1, 2⟩)
  let n7 : Sig := Sig.binop .add n4 n6
  let n8 : Sig := Sig.binop .sub n0 n7
  let n9 : Sig := Sig.cons n8 (.nil)
  let n10 : Sig := Sig.recur n9
  let n11 : Sig := Sig.proj 0 n10
  let n12 : Sig := Sig.binop .mul n11 (.const ⟨5404319552844595, 18014398509481984⟩)
  let n13 : Sig := Sig.delay n11 (.int 1)
  let n14 : Sig := Sig.binop .mul n13 (.const ⟨3602879701896397, 18014398509481984⟩)
  let n15 : Sig := Sig.binop .add n12 n14
  let n16 : Sig := Sig.delay n11 (.int 2)
  let n17 : Sig := Sig.binop .mul n16 (.const ⟨3602879701896397, 36028797018963968⟩)
  let n18 : Sig := Sig.binop .add n15 n17
  n18

/-- `import("filters.lib");
process = fi.tf2(1, 0, 0, -0.5, -0.8);` — output 0 -/
def tf2_unstable_out0 : Sig :=
  let n0 : Sig := Sig.input 0
  let n1 : Sig := Sig.ref 1
  let n2 : Sig := Sig.proj 0 n1
  let n3 : Sig := Sig.delay1 n2
  let n4 : Sig := Sig.binop .mul n3 (.const ⟨(-1), 2⟩)
  let n5 : Sig := Sig.delay n3 (.int 1)
  let n6 : Sig := Sig.binop .mul n5 (.const ⟨(-3602879701896397), 4503599627370496⟩)
  let n7 : Sig := Sig.binop .add n4 n6
  let n8 : Sig := Sig.binop .sub n0 n7
  let n9 : Sig := Sig.cons n8 (.nil)
  let n10 : Sig := Sig.recur n9
  let n11 : Sig := Sig.proj 0 n10
  let n12 : Sig := Sig.binop .mul n11 (.int 1)
  let n13 : Sig := Sig.delay n11 (.int 1)
  let n14 : Sig := Sig.binop .mul n13 (.int 0)
  let n15 : Sig := Sig.binop .add n12 n14
  let n16 : Sig := Sig.delay n11 (.int 2)
  let n17 : Sig := Sig.binop .mul n16 (.int 0)
  let n18 : Sig := Sig.binop .add n15 n17
  n18

/-- `process = + ~ *(1.5);` — output 0 -/
def unstable_out0 : Sig :=
  let n0 : Sig := Sig.ref 1
  let n1 : Sig := Sig.proj 0 n0
  let n2 : Sig := Sig.delay1 n1
  let n3 : Sig := Sig.binop .mul n2 (.const ⟨3, 2⟩)
  let n4 : Sig := Sig.input 0
  let n5 : Sig := Sig.binop .add n3 n4
  let n6 : Sig := Sig.cons n5 (.nil)
  let n7 : Sig := Sig.recur n6
  let n8 : Sig := Sig.proj 0 n7
  n8

/-! ## Certification

Two independent analyses over the same imported graph.
`certifyStableB` reads the feedback coefficients and applies the
Jury criterion. `certifyIndicesB` checks every table read and
delay tap whose range follows from the graph structure alone;
`false` there means *not proven*, never *unsafe*. -/

#eval certifyReport fdelay_clamped_out0
#eval certifyReport lowpass3_out0
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
#eval indexReport lowpass3_out0
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
theorem lowpass3_out0_stability : certifyStableB lowpass3_out0 = false := by decide
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
theorem lowpass3_out0_indices : certifyIndicesB lowpass3_out0 = true := by decide
theorem nonlinear_out0_indices : certifyIndicesB nonlinear_out0 = true := by decide
theorem onepole_out0_indices : certifyIndicesB onepole_out0 = true := by decide
theorem osc_out0_indices : certifyIndicesB osc_out0 = true := by decide
theorem table_bad_clamp_out0_indices : certifyIndicesB table_bad_clamp_out0 = false := by decide
theorem table_good_clamp_out0_indices : certifyIndicesB table_good_clamp_out0 = true := by decide
theorem table_unclamped_out0_indices : certifyIndicesB table_unclamped_out0 = false := by decide
theorem tf2_stable_out0_indices : certifyIndicesB tf2_stable_out0 = true := by decide
theorem tf2_unstable_out0_indices : certifyIndicesB tf2_unstable_out0 = true := by decide
theorem unstable_out0_indices : certifyIndicesB unstable_out0 = true := by decide

end Faust.Signal.Generated