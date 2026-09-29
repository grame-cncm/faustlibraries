/-
  Lean 4 specification for:

    faustlibraries-code-doc-audit-2026-08-15-en.md, §10.3 architecture B

  Scope
  -----
  Imports a compiled Faust signal graph into Lean and certifies, mechanically,
  that its feedback recursion is stable, that its table reads and delay taps
  stay in range, and — reading the graph as a DAG — that each recursion group
  is stable at the six rates of `make check-precision` in exact, double and
  single arithmetic (section "Stability at the sample rates").

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
  `by decide` theorem pinning it (`by decide +kernel` for the rate analysis,
  whose computations are too deep for the elaborator's `decide`). The theorem is the artefact: Lean proves it,
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
/-- Multiplicative inverse, sign-normalized so the positive-denominator
    invariant is preserved. Meaningful only when `a.n ≠ 0`; the one caller
    (the division rule of `rangeOfFuel`) guards the zero case. -/
def inv (a : Q) : Q := if 0 < a.n then ⟨a.d, a.n⟩ else ⟨-a.d, -a.n⟩
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
is a missed optimisation, and the converse would be a real defect.

Since faust-rs moved that clamp to the signal level (`-ct`, visible through
`--dump-sig-dag-prepared`), the oracle comparison is mechanized:
`sig2lean.py` reads each table verdict here through `tableSiteVerdictsB`,
reads what the compiler actually did by diffing the prepared forest under
`-ct 1` against `-ct 0`, and fails certification on the defect direction
(a `clampRequired` table size the compiler left unclamped). The agreed
outcome is pinned in the generated section of `certified.lean`. -/

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

/-- Translation by a constant: both bounds shift by `q`, each side
    independently (`none` stays `none`). Sound because `v ≤ h ↔ v + q ≤ h + q`
    over the rationals; the same equivalence for `<` is why `hiStrict` is
    preserved, unlike under a negative `scale`. -/
def translate (r : Range) (q : Q) : Range :=
  ⟨r.lo.map (Q.add q), r.hi.map (Q.add q), r.hiStrict⟩
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
  -- Affine completions, the shapes `ba.tabulate`'s index arithmetic
  -- ((x - r0) / (r1 - r0) * (S-1) + 1/2) normalizes to. Addition and
  -- subtraction of a constant are exact translations; division by a nonzero
  -- constant is multiplication by its sign-normalized inverse, delegating
  -- the negative-divisor bound swap (and strictness drop) to `scale`.
  | n + 1, .binop .add a (.const q) => (rangeOfFuel n a).translate q
  | n + 1, .binop .add a (.int k)   => (rangeOfFuel n a).translate (Q.ofInt k)
  | n + 1, .binop .add (.const q) b => (rangeOfFuel n b).translate q
  | n + 1, .binop .add (.int k) b   => (rangeOfFuel n b).translate (Q.ofInt k)
  | n + 1, .binop .sub a (.const q) => (rangeOfFuel n a).translate q.neg
  | n + 1, .binop .sub a (.int k)   => (rangeOfFuel n a).translate (Q.ofInt (-k))
  | n + 1, .binop .div a (.const q) =>
      if q.n == 0 then Range.unknown else (rangeOfFuel n a).scale q.inv
  | n + 1, .binop .div a (.int k)   =>
      if k == 0 then Range.unknown else (rangeOfFuel n a).scale (Q.inv (Q.ofInt k))
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

/-- Machine-readable table verdicts for the compiler clamp oracle: one
    `size:verdict` entry per **table** site, in `sites` order (delay taps are
    excluded — the compiler has no clamp pass for taps). `sig2lean.py` parses
    this from a probe `#eval` and compares it, per table size, against the
    clamps the compiler actually inserted (`--dump-sig-dag-prepared` under
    `-ct 1` versus `-ct 0`). Shared reads may appear once per path here while
    the compiler's hash-consed forest holds one node, so the comparison is by
    table-size presence, not by site count. -/
def tableSiteVerdictsB (s : Sig) : String :=
  String.intercalate ";" ((sites s).filterMap fun st =>
    match st with
    | .table size _ =>
        let v := match siteVerdict st with
                 | .inRange       => "inRange"
                 | .clampRequired => "clampRequired"
                 | .notProven     => "notProven"
        some s!"{size}:{v}"
    | .tap _ => none)

/-! ## Stability at the sample rates, in exact, double and single precision

The analyses above read a tree (`Sig`) and refuse every coefficient that goes
through a transcendental function, so nothing that depends on `ma.SR` is ever
certified, and they read only single-output recursions. This section reads the
same graph as a **DAG** (`Dag`, one `Node` per dump binding, children by index),
evaluates it bottom-up so that each node is computed once, and certifies each
recursion group (`DEBRUIJNREC`):

* at each of the six rates of `make check-precision` (`checkRates`), with the
  controls at their default values — the configuration `check-precision`
  renders;
* in three arithmetics (`Prec`): `exact` (no rounding modelled), `double` and
  `single`, where every real operation of the graph is rounded;
* for groups whose state is at most 2 samples: first order, direct-form second
  order, and two-output state-variable (SVF/TPT) sections.

### What is claimed

For a group, precision `p` and rate `sr`: *the linear recursion whose
coefficients take the values the program computes in precision `p` at rate
`sr` is stable.* Every state-free subexpression (a coefficient) is enclosed in
an interval that contains its value as computed in `p`; the matrix of the
recursion then ranges over a box, and every matrix of the box is checked stable
(Jury). The rounding of the loop arithmetic itself — the products and sums that
involve the state — is not part of the claim: it perturbs the state at each
sample, which is an accuracy question (proposal P4), not a change of the
recursion's coefficients.

### How

* **Intervals** (`Iv`) have rational endpoints rounded outward to multiples of
  `2⁻¹⁰⁰` after every operation (`Q.down`, `Q.up`), so the numbers stay small
  and every enclosure stays sound.
* **Rounding model.** A real operation's result is widened by the unit roundoff
  `u` of the precision (relative) and `eta` (absolute, for subnormals):
  `x op y` computed is `(x op y)(1 + δ) + ε`, `|δ| ≤ u`, `|ε| ≤ eta`. Libm calls
  are widened by `libmUlps` ulps. Literals are rounded to the precision, and
  controls to `float` (`FAUSTFLOAT`). Integer operations are exact, and refused
  when they may leave the int32 range.
* **Transcendentals** are Taylor polynomials evaluated in interval arithmetic,
  plus an explicit Lagrange remainder: `sinI`, `cosI` (|x| ≤ 4), `tanI` as
  `sin/cos` when the cosine enclosure excludes 0, `expI` with halving,
  `sqrtI` from an integer square root whose bounds are *checked*, not assumed.
* **Linear extraction.** Inside a group, a node that does not depend on the
  group's state (`free = 0`) is a coefficient, known by its interval; the others
  are affine forms over the delayed outputs `y_i[n-k]`. A product of two state
  terms, a nonlinear function of the state, a delay-free loop, a variable delay
  of the state, a nested recursion coupled to the group: refused.
* **Jury at the vertices.** Up to 2 states, the four Jury conditions
  (`1 - det > 0`, `1 + det > 0`, `1 - tr + det > 0`, `1 + tr + det > 0`, or
  `|a| < 1` at order 1) are multilinear in the entries of the matrix, so their
  minimum over a box is reached at a vertex: checking the vertices, in exact
  rational arithmetic, checks the whole box.

Every rule below states its soundness argument; the ones that need analysis
(Taylor remainders, the vertex lemma) are listed with the standing obligations
at the end of the file. -/

namespace Q
def sub (a b : Q) : Q := a.add b.neg
/-- Strict comparison; valid because denominators are positive. -/
def lt (a b : Q) : Bool := decide (a.n * b.d < b.n * a.d)
def abs (a : Q) : Q := if 0 ≤ a.n then a else a.neg
/-- `2⁻ᵏ`. -/
def pow2neg (k : Nat) : Q := ⟨1, ((2 : Nat) ^ k : Nat)⟩
/-- Interval endpoints are rounded to multiples of `2⁻PREC`. -/
def PREC : Nat := 100
def grid : Int := ((2 : Nat) ^ PREC : Nat)
/-- Largest multiple of `2⁻PREC` below `a`: `⌊a·2^PREC⌋ ≤ a·2^PREC`. -/
def down (a : Q) : Q := ⟨Int.fdiv (a.n * grid) a.d, grid⟩
/-- Smallest multiple of `2⁻PREC` above `a`: `-down(-a)`. -/
def up (a : Q) : Q := ⟨-(Int.fdiv (-(a.n * grid)) a.d), grid⟩
end Q

/-- A closed interval with rational endpoints, `lo ≤ hi`. An unknown or
    unbounded value is `none : Option Iv`. -/
structure Iv where
  lo : Q
  hi : Q
deriving Repr, Inhabited

namespace Iv
def pt (q : Q) : Iv := ⟨q, q⟩
def ofInt (k : Int) : Iv := pt (Q.ofInt k)
def zero : Iv := pt Q.zero
def neg (a : Iv) : Iv := ⟨a.hi.neg, a.lo.neg⟩
def add (a b : Iv) : Iv := ⟨(a.lo.add b.lo).down, (a.hi.add b.hi).up⟩
def sub (a b : Iv) : Iv := a.add b.neg
/-- The product's extremes are among the four endpoint products. -/
def mul (a b : Iv) : Iv :=
  let p1 := a.lo.mul b.lo
  let p2 := a.lo.mul b.hi
  let p3 := a.hi.mul b.lo
  let p4 := a.hi.mul b.hi
  ⟨(Q.min (Q.min p1 p2) (Q.min p3 p4)).down, (Q.max (Q.max p1 p2) (Q.max p3 p4)).up⟩
def hasZero (a : Iv) : Bool := Q.le a.lo Q.zero && Q.le Q.zero a.hi
/-- `1/x` is decreasing on each side of 0, so on an interval excluding 0 it maps
    `[lo, hi]` to `[1/hi, 1/lo]`. -/
def inv (a : Iv) : Option Iv :=
  if a.hasZero then none else some ⟨(Q.inv a.hi).down, (Q.inv a.lo).up⟩
def div (a b : Iv) : Option Iv := (inv b).map a.mul
/-- Division by a positive integer. -/
def divNat (a : Iv) (m : Nat) : Iv :=
  ⟨(⟨a.lo.n, a.lo.d * m⟩ : Q).down, (⟨a.hi.n, a.hi.d * m⟩ : Q).up⟩
def hull (a b : Iv) : Iv := ⟨Q.min a.lo b.lo, Q.max a.hi b.hi⟩
def rmin (a b : Iv) : Iv := ⟨Q.min a.lo b.lo, Q.min a.hi b.hi⟩
def rmax (a b : Iv) : Iv := ⟨Q.max a.lo b.lo, Q.max a.hi b.hi⟩
def abs (a : Iv) : Iv :=
  if Q.le Q.zero a.lo then a
  else if Q.le a.hi Q.zero then a.neg
  else ⟨Q.zero, Q.max a.lo.neg a.hi⟩
/-- `max |x|` over the interval. -/
def mag (a : Iv) : Q := Q.max a.lo.abs a.hi.abs
def within (a : Iv) (m : Q) : Bool := Q.le a.mag m
/-- Truncation toward zero, and floor, land in `[⌊lo⌋, ⌈hi⌉]`. -/
def trunc (a : Iv) : Iv := ⟨Q.ofInt a.lo.floor, Q.ofInt a.hi.ceil⟩
def floor (a : Iv) : Iv := ⟨Q.ofInt a.lo.floor, Q.ofInt a.hi.floor⟩
/-- Rounding of one operation: a result `v(1 + δ) + ε` with `|δ| ≤ e`,
    `|ε| ≤ eta`. Sound because `v ↦ v - e|v|` and `v ↦ v + e|v|` are
    non-decreasing for `e < 1`, so their extremes over `[lo, hi]` are at the
    endpoints. -/
def widen (a : Iv) (e eta : Q) : Iv :=
  ⟨((a.lo.sub (e.mul a.lo.abs)).sub eta).down, ((a.hi.add (e.mul a.hi.abs)).add eta).up⟩
def fitsInt32 (a : Iv) : Bool :=
  Q.le (Q.ofInt (-2147483648)) a.lo && Q.le a.hi (Q.ofInt 2147483647)
end Iv

/-! ### Transcendental enclosures -/

/-- Number of Taylor terms for `sin`/`cos` at `|x| ≤ m`, chosen so that the
    remainder is below about `10⁻²⁴` (far below a double ulp). Any choice is
    sound: the remainder is always added to the enclosure. -/
def trigTerms (m : Q) : Nat :=
  if Q.le m ⟨1, 4⟩ then 8 else if Q.le m ⟨1, 2⟩ then 10 else if Q.le m Q.one then 12
  else if Q.le m (Q.ofInt 2) then 15 else 20

/-- Terms for `exp` at `|x| ≤ 1/2`. -/
def EXPTERMS : Nat := 20

/-- `mⁿ/n!` rounded up, for `m ≥ 0`: each step multiplies by `m/(j+1)` and
    rounds up, which keeps an upper bound. -/
def remUp (m : Q) : Nat → Nat → Q → Q
  | 0, _, r => r
  | n + 1, j, r =>
      let p := r.mul m
      remUp m n (j + 1) (⟨p.n, p.d * (j + 1)⟩ : Q).up

def taylorRem (m : Q) (n : Nat) : Q := remUp m n 0 Q.one

/-- `∑_{k<N} (-1)ᵏ x^(2k+off)/(2k+off)!` in interval arithmetic, from the
    first term `term` (`x` for `sin`, `1` for `cos`): the interval extension of
    the Taylor polynomial, which encloses the polynomial at every point of `x`. -/
def taylorAlt (x2 : Iv) (off : Nat) : Nat → Nat → Iv → Iv → Iv
  | 0, _, _, acc => acc
  | n + 1, k, term, acc =>
      let next := (term.mul x2).divNat ((2 * k + 1 + off) * (2 * k + 2 + off))
      taylorAlt x2 off n (k + 1) next.neg (acc.add term)

/-- The Taylor polynomial of `sin` with `N` terms has degree `2N - 1`, and also
    `2N` (the next coefficient is 0); every derivative of `sin` is bounded by 1,
    so the Lagrange remainder is at most `|x|^(2N+1)/(2N+1)!`. -/
def sinI (x : Iv) : Option Iv :=
  if x.within (Q.ofInt 4) then
    let n := trigTerms x.mag
    let s := taylorAlt (x.mul x) 1 n 0 x Iv.zero
    let r := taylorRem x.mag (2 * n + 1)
    some ⟨(s.lo.sub r).down, (s.hi.add r).up⟩
  else none

/-- Same for `cos`: degree `2N - 2`, remainder at most `|x|^(2N)/(2N)!`. -/
def cosI (x : Iv) : Option Iv :=
  if x.within (Q.ofInt 4) then
    let n := trigTerms x.mag
    let c := taylorAlt (x.mul x) 0 n 0 (Iv.pt Q.one) Iv.zero
    let r := taylorRem x.mag (2 * n)
    some ⟨(c.lo.sub r).down, (c.hi.add r).up⟩
  else none

/-- When the enclosure of `cos` over `x` excludes 0, `cos` has no zero on `x`,
    `tan = sin/cos` is continuous there, and the quotient of the two
    enclosures contains `tan` at every point of `x`. -/
def tanI (x : Iv) : Option Iv := do
  let s ← sinI x
  let c ← cosI x
  s.div c

/-- `exp` for `|x| ≤ 1/2`: `N` terms, Lagrange remainder
    `e^ξ |x|^N/N! ≤ 2|x|^N/N!` since `e^(1/2) < 2`. -/
def expSmall (x : Iv) : Iv :=
  let rec go : Nat → Nat → Iv → Iv → Iv
    | 0, _, _, acc => acc
    | n + 1, k, term, acc => go n (k + 1) ((term.mul x).divNat (k + 1)) (acc.add term)
  let s := go EXPTERMS 0 (Iv.pt Q.one) Iv.zero
  let r := (Q.ofInt 2).mul (taylorRem x.mag EXPTERMS)
  ⟨(s.lo.sub r).down, (s.hi.add r).up⟩

/-- `exp x = (exp (x/2))²`, halving until `|x| ≤ 1/2`. The square of an
    enclosure of a positive quantity is an enclosure of its square. -/
def expI : Nat → Iv → Option Iv
  | 0, _ => none
  | f + 1, x =>
      if x.within ⟨1, 2⟩ then some (expSmall x)
      else (expI f (x.divNat 2)).map fun e => e.mul e

/-- Integer square root by Newton's method from above. Untrusted: `sqrtI`
    checks its result. -/
def isqrtNewton (n : Nat) : Nat → Nat → Nat
  | 0, x => x
  | f + 1, x =>
      let y := (x + n / x) / 2
      if y < x then isqrtNewton n f y else x

def isqrt (n : Nat) : Nat :=
  if n = 0 then 0 else isqrtNewton n 400 ((2 : Nat) ^ (Nat.log2 n / 2 + 1))

/-- `sqrt` is increasing. With `a = down lo = na/G` and `b = up hi = nb/G`
    (`G = 2^PREC`), `sqrt a = sqrt(na·G)/G`: a checked `r² ≤ na·G` gives the
    lower bound `r/G`, a checked `nb·G ≤ (s+1)²` the upper bound `(s+1)/G`. -/
def sqrtI (x : Iv) : Option Iv :=
  if Q.lt x.lo Q.zero then none else
  let a := x.lo.down
  let b := x.hi.up
  let na := (a.n * Q.grid).toNat
  let nb := (b.n * Q.grid).toNat
  let ra := isqrt na
  let rb := isqrt nb
  if ra * ra ≤ na && nb ≤ (rb + 1) * (rb + 1) && 0 ≤ a.n then
    some ⟨⟨ra, Q.grid⟩, ⟨rb + 1, Q.grid⟩⟩
  else none

/-- `xᵏ` for a natural `k`: repeated interval products, on `|x|` when `k` is
    even (`xᵏ = |x|ᵏ`), which keeps the lower bound non-negative. -/
def powNat (x : Iv) (k : Nat) : Iv :=
  let b := if k % 2 == 0 then x.abs else x
  let rec go : Nat → Iv → Iv
    | 0, acc => acc
    | n + 1, acc => go n (acc.mul b)
  go k (Iv.pt Q.one)

/-! ### Precisions -/

inductive Prec where
  | exact
  | double
  | single
deriving Repr, DecidableEq, Inhabited

/-- Accuracy assumed of the math library (`tan`, `sin`, `cos`, `exp`), in ulps:
    a standing obligation. One ulp is at most `2u` relative. -/
def libmUlps : Nat := 2

namespace Prec
/-- Unit roundoff: half an ulp of 1, the relative error of a correctly
    rounded operation. -/
def u : Prec → Q
  | .exact  => Q.zero
  | .double => Q.pow2neg 53
  | .single => Q.pow2neg 24
/-- Absolute error allowance for subnormal results (at least the smallest
    subnormal step of both formats). -/
def eta : Prec → Q
  | .exact => Q.zero
  | _      => Q.pow2neg 140
/-- Largest integer magnitude converted exactly to the real type. -/
def intExact : Prec → Int
  | .single => 16777216
  | _       => 9007199254740992
/-- A correctly rounded operation (`+ - * /`, `sqrt`, int-to-real). -/
def op (p : Prec) (a : Iv) : Iv := if p = .exact then a else a.widen p.u p.eta
/-- A libm call. -/
def libm (p : Prec) (a : Iv) : Iv :=
  if p = .exact then a else a.widen ((Q.ofInt (2 * libmUlps)).mul p.u) p.eta
/-- A control value, stored as `FAUSTFLOAT` = `float` in both precisions. -/
def control (p : Prec) (a : Iv) : Iv :=
  if p = .exact then a else a.widen (Q.pow2neg 24) (Q.pow2neg 140)
/-- A real literal: the dump gives the double, the single-precision program
    uses it rounded to `float`. -/
def lit (p : Prec) (q : Q) : Iv := if p = .single then (Iv.pt q).widen p.u p.eta else Iv.pt q
/-- An integer operand converted to the real type. -/
def promote (p : Prec) (isInt : Bool) (a : Iv) : Iv :=
  if isInt && !(Q.le (Q.ofInt p.intExact) a.mag) then a else if isInt then p.op a else a
end Prec

/-! ### The DAG -/

inductive Tag where
  | input | delay1 | delay | proj | recur | ref | cons
  | binop (op : BinOp)
  | cmp          -- comparisons: 0 or 1
  | sr           -- `SIGFCONST fSamplingFreq`
  | control      -- sliders and numerical entries, with their declared range
  | button       -- buttons and checkboxes: 0 or 1
  | intcast | floatcast | min | max | abs | floor | select2
  | tan | sin | cos | exp | sqrt | pow
  | other (name : String)
deriving Repr, Inhabited

def Tag.name : Tag → String
  | .input => "SIGINPUT" | .delay1 => "SIGDELAY1" | .delay => "SIGDELAY"
  | .proj => "SIGPROJ" | .recur => "DEBRUIJNREC" | .ref => "DEBRUIJNREF"
  | .cons => "cons" | .binop .add => "SIGBINOP:add" | .binop .sub => "SIGBINOP:sub"
  | .binop .mul => "SIGBINOP:mul" | .binop .div => "SIGBINOP:div"
  | .binop .rem => "SIGBINOP:rem" | .cmp => "comparison" | .sr => "SIGFCONST"
  | .control => "control" | .button => "button" | .intcast => "SIGINTCAST"
  | .floatcast => "SIGFLOATCAST" | .min => "SIGMIN" | .max => "SIGMAX"
  | .abs => "SIGABS" | .floor => "SIGFLOOR" | .select2 => "SIGSELECT2"
  | .tan => "SIGTAN" | .sin => "SIGSIN" | .cos => "SIGCOS" | .exp => "SIGEXP"
  | .sqrt => "SIGSQRT" | .pow => "SIGPOW" | .other s => s

inductive Arg where
  | ref   (i : Nat)
  | int   (v : Int)
  | const (q : Q)
  | nil
  | other
deriving Repr, Inhabited

/-- One dump binding. `ctl` is `(init, min, max)` for a control. -/
structure Node where
  tag  : Tag
  args : List Arg
  ctl  : Q × Q × Q
deriving Repr, Inhabited

/-- Bindings in dump order: node `i` is `n i`, and a child always has a lower
    index than its parent (the dump is in post-order). -/
abbrev Dag := List Node

/-- The value of node `j` while computing node `i`, from `acc`, the values
    computed so far, most recent first. A forward reference (`j ≥ i`, which a
    post-order dump never contains) yields `d`. -/
def lookback {α} (acc : List α) (i j : Nat) (d : α) : α :=
  if j < i then acc.getD (i - 1 - j) d else d

/-- Fold a node function over the DAG in index order. -/
def dagPass {α} (dag : Dag) (f : List α → Nat → Node → α) : List α :=
  let rec go : Nat → List Node → List α → List α
    | _, [], acc => acc.reverse
    | i, nd :: rest, acc => go (i + 1) rest (f acc i nd :: acc)
  go 0 dag []

/-- Element `k` of a `cons` list of arguments. -/
def consNth (dag : Dag) : Nat → Arg → Option Arg
  | 0, .ref c => match (dag.getD c default).tag, (dag.getD c default).args with
      | .cons, [h, _] => some h
      | _, _ => none
  | k + 1, .ref c => match (dag.getD c default).tag, (dag.getD c default).args with
      | .cons, [_, t] => consNth dag k t
      | _, _ => none
  | _, _ => none

/-- All elements of a `cons` list (fuel bounds its length). -/
def consList (dag : Dag) : Nat → Arg → List Arg
  | 0, _ => []
  | f + 1, .ref c => match (dag.getD c default).tag, (dag.getD c default).args with
      | .cons, [h, t] => h :: consList dag f t
      | _, _ => []
  | _ + 1, _ => []

def recBody (dag : Dag) (r : Nat) : List Arg :=
  match (dag.getD r default).tag, (dag.getD r default).args with
  | .recur, [b] => consList dag 4096 b
  | _, _ => []

/-! ### Context-free passes: recursion level, nature -/

/-- Highest de Bruijn level a node refers to outside itself: `REF k` refers to
    level `k`, a `REC` binds one level. `0` means the node depends on no
    enclosing recursion. Unknown children count as escaping. -/
def freeLevels (dag : Dag) : List Nat :=
  dagPass dag fun acc i nd =>
    let fa : Arg → Nat := fun
      | .ref j => lookback acc i j 1000
      | _ => 0
    match nd.tag, nd.args with
    | .ref, [.int k] => k.toNat
    | .recur, [a] => fa a - 1
    | _, args => args.foldl (fun m a => Nat.max m (fa a)) 0

/-- `true` when the node's value is an integer in the compiled program.
    Pessimistic: a recursion output is not known to be an integer (`false`),
    which only makes the analysis treat it as real, i.e. model more rounding.
    With `optimistic`, a projection of the enclosing recursion is taken to be
    an integer: used only to *refuse* integer recursions (wrapping semantics). -/
def natures (dag : Dag) (optimistic : Bool) : List Bool :=
  dagPass dag fun acc i nd =>
    let ia : Arg → Bool := fun
      | .ref j => lookback acc i j false
      | .int _ => true
      | _ => false
    match nd.tag, nd.args with
    | .intcast, _ | .cmp, _ | .sr, _ => true
    | .binop .div, _ => false                -- Faust's `/` is always a real division
    | .binop _, [a, b] | .min, [a, b] | .max, [a, b] | .select2, [_, a, b] => ia a && ia b
    | .abs, [a] | .delay1, [a] | .delay, [a, _] => ia a
    | .proj, [_, .ref j] =>
        optimistic && (match (dag.getD j default).tag with | .ref => true | _ => false)
    | _, _ => false

/-! ### Ranges -/

/-- Interval of every node, for one precision and rate, controls at their
    default values. `none`: unknown or unbounded. The state of a recursion is
    unknown; a recursion output gets the range of its body element with the
    state unknown, which holds for every value of the state. -/
def ranges (dag : Dag) (nat natOpt : List Bool) (p : Prec) (sr : Int) : List (Option Iv) :=
  dagPass dag fun acc i nd =>
    let v : Arg → Option Iv := fun
      | .ref j => lookback acc i j none
      | .int k => some (Iv.ofInt k)
      | .const q => some (p.lit q)
      | _ => none
    let isInt : Arg → Bool := fun
      | .ref j => nat.getD j false
      | .int _ => true
      | _ => false
    let rv : Arg → Option Iv := fun a => (v a).map (p.promote (isInt a))
    let intNode := nat.getD i false
    -- a node that may be an integer in the program (its value depends on a
    -- recursion typed int) is modelled as real, which covers its rounding,
    -- but its int32 wrap-around is not modelled: its range must fit int32
    let maybeInt := natOpt.getD i false
    let noWrap : Option Iv → Option Iv := fun r =>
      if maybeInt then r.bind fun x => if x.fitsInt32 then some x else none else r
    match nd.tag, nd.args with
    | .sr, _ => some (Iv.ofInt sr)
    | .control, _ => some (p.control (Iv.pt nd.ctl.1))
    | .button, _ | .cmp, _ => some ⟨Q.zero, Q.one⟩
    | .delay1, [a] | .delay, [a, _] => (v a).map (·.hull Iv.zero)
    | .proj, [.int k, .ref r] =>
        if r < i then
          match (dag.getD r default).tag, (dag.getD r default).args with
          | .recur, [b] => (consNth dag k.toNat b).bind v
          | _, _ => none
        else none
    | .intcast, [a] => (v a).map Iv.trunc
    | .floatcast, [a] => rv a
    | .min, [a, b] => do let x ← v a; let y ← v b; pure (x.rmin y)
    | .max, [a, b] => do let x ← v a; let y ← v b; pure (x.rmax y)
    | .select2, [_, a, b] => do let x ← v a; let y ← v b; pure (x.hull y)
    | .abs, [a] => (v a).map Iv.abs
    | .floor, [a] => (v a).map Iv.floor
    | .binop op, [a, b] =>
        if intNode then do
          let x ← v a
          let y ← v b
          let r ← match op with
            | .add => some (x.add y)
            | .sub => some (x.sub y)
            | .mul => some (x.mul y)
            | .div => none                         -- not an integer operation in Faust
            | .rem => if y.lo == y.hi && Q.lt Q.zero y.lo then
                        let m := y.lo.floor
                        if Q.le Q.zero x.lo then some ⟨Q.zero, Q.ofInt (m - 1)⟩
                        else some ⟨Q.ofInt (1 - m), Q.ofInt (m - 1)⟩
                      else none
          if r.fitsInt32 then some r else none
        else noWrap do
          let x ← rv a
          let y ← rv b
          match op with
          | .add => some (p.op (x.add y))
          | .sub => some (p.op (x.sub y))
          | .mul => some (p.op (x.mul y))
          | .div => (x.div y).map p.op
          | .rem =>                          -- fmod: exact, |r| < |m|, sign of x
              if y.lo == y.hi && Q.lt Q.zero y.lo then
                if Q.le Q.zero x.lo then some ⟨Q.zero, y.lo⟩ else some ⟨y.lo.neg, y.lo⟩
              else none
    | .tan, [a]  => ((rv a).bind tanI).map p.libm
    | .sin, [a]  => ((rv a).bind sinI).map p.libm
    | .cos, [a]  => ((rv a).bind cosI).map p.libm
    | .exp, [a]  => ((rv a).bind (expI 64)).map p.libm
    | .sqrt, [a] => ((rv a).bind sqrtI).map p.op
    | .pow, [a, b] =>                        -- integer exponents only
        match v b with
        | some e =>
            if e.lo == e.hi && e.lo.n % e.lo.d == 0 && 0 ≤ e.lo.n && e.lo.n / e.lo.d ≤ 64 then
              (rv a).map fun x => p.libm (powNat x (e.lo.n / e.lo.d).toNat)
            else none
        | none => none
    | _, _ => none

/-! ### Linear extraction of a recursion group -/

/-- `((i, k), c)`: coefficient `c` on `y_i[n-k]`, output `i` of the group
    delayed by `k` samples. -/
abbrev Aff := List ((Nat × Nat) × Iv)

def Aff.shift (k : Nat) (a : Aff) : Aff := a.map fun ((i, d), c) => ((i, d + k), c)
def Aff.scale (s : Iv) (a : Aff) : Aff := a.map fun (key, c) => (key, c.mul s)
def Aff.neg (a : Aff) : Aff := a.map fun (key, c) => (key, c.neg)
def Aff.coef (a : Aff) (key : Nat × Nat) : Iv :=
  a.foldl (fun s (k, c) => if k == key then s.add c else s) Iv.zero

/-- Affine form, in the state of the group being analysed, of every node that
    can be reached from its body without entering a nested recursion. A node
    with `free = 0` is a coefficient (its form is empty, its value is its
    range). `REF 1` is the group itself, since only nodes at depth 0 of its
    body are read here. The loop arithmetic (products by a coefficient,
    sums) is exact in the claim, see the section header. -/
def affines (dag : Dag) (free : List Nat) (nat : List Bool) (p : Prec)
    (rng : List (Option Iv)) : List (Except String Aff) :=
  dagPass dag fun acc i nd =>
    let fr : Arg → Nat := fun
      | .ref j => free.getD j 1000
      | _ => 0
    let f : Arg → Except String Aff := fun
      | .ref j => if free.getD j 1000 == 0 then .ok [] else lookback acc i j (.error "forward reference")
      | _ => .ok []
    -- a coefficient: its range, converted to the real type of the state
    let val : Arg → Option Iv := fun
      | .ref j => (rng.getD j none).map (p.promote (nat.getD j false))
      | .int k => some (p.promote true (Iv.ofInt k))
      | .const q => some (p.lit q)
      | _ => none
    if free.getD i 1000 == 0 then .ok [] else
    match nd.tag, nd.args with
    | .proj, [.int k, .ref j] =>
        match (dag.getD j default).tag, (dag.getD j default).args with
        | .ref, [.int 1] => .ok [((k.toNat, 0), Iv.pt Q.one)]
        | .ref, _ => .error "reference to an outer recursion"
        | _, _ => .error "nested recursion coupled to the group"
    | .recur, _ => .error "nested recursion coupled to the group"
    | .delay1, [a] => (f a).map (Aff.shift 1)
    | .delay, [a, n] =>
        let amount : Option Iv := match n with
          | .ref j => rng.getD j none
          | .int k => some (Iv.ofInt k)
          | _ => none
        match amount with
        | some d =>
            if Q.le d.hi d.lo && d.lo.n % d.lo.d == 0 && 0 ≤ d.lo.n then
              (f a).map (Aff.shift (d.lo.n / d.lo.d).toNat)
            else .error "variable delay of the state"
        | none => .error "variable delay of the state"
    | .binop .add, [a, b] => do let x ← f a; let y ← f b; pure (x ++ y)
    | .binop .sub, [a, b] => do let x ← f a; let y ← f b; pure (x ++ y.neg)
    | .binop .mul, [a, b] =>
        if fr a != 0 && fr b != 0 then .error "product of two state terms"
        else
          let (st, sc) := if fr a == 0 then (b, a) else (a, b)
          match val sc with
          | some s => (f st).map (Aff.scale s)
          | none   => .error "unbounded coefficient on the state"
    | .binop .div, [a, b] =>
        if fr b != 0 then .error "division by the state"
        else match (val b).bind Iv.inv with
          | some s => (f a).map (Aff.scale s)
          | none   => .error "coefficient 1/x with x possibly 0"
    | .floatcast, [a] => f a
    | t, _ => .error s!"{t.name} applied to the state"

/-! ### Jury at the vertices -/

/-- Both endpoints, or one when the interval is a point. -/
def Iv.ends (a : Iv) : List Q := if a.lo == a.hi then [a.lo] else [a.lo, a.hi]

def pos (q : Q) : Bool := Q.lt Q.zero q

/-- Order 1: `|a| < 1` for every `a` of the interval. -/
def jury1 (a : Iv) : Bool := Q.lt (Q.ofInt (-1)) a.lo && Q.lt a.hi Q.one

/-- Order 2, matrix `[[a, b], [c, d]]`: the four Jury conditions at every
    vertex of the box, in exact arithmetic. -/
def jury2 (a b c d : Iv) : Bool :=
  a.ends.all fun a => b.ends.all fun b => c.ends.all fun c => d.ends.all fun d =>
    let tr  := a.add d
    let det := (a.mul d).sub (b.mul c)
    pos (Q.one.sub det) && pos (Q.one.add det) &&
    pos ((Q.one.sub tr).add det) && pos ((Q.one.add tr).add det)

inductive GV where
  | stable     -- every matrix of the box is Jury-stable
  | unproven   -- linear, but some matrix of the box fails Jury
  | refused    -- not a linear group of at most 2 states
deriving Repr, DecidableEq

/-- The state of a group: `(i, k)` for `k = 1 .. depth i`, where `depth i` is
    the largest delay at which output `i` is read. -/
def stateOf (forms : List Aff) : Except String (List (Nat × Nat)) := do
  let keys := forms.flatMap (·.map (·.1))
  if keys.any (·.2 == 0) then throw "delay-free loop"
  if keys.any (·.1 ≥ forms.length) then throw "state beyond the outputs read"
  let outs := (List.range forms.length).filter fun i => keys.any (·.1 == i)
  pure (outs.flatMap fun i =>
    let depth := keys.foldl (fun m (j, k) => if j == i then Nat.max m k else m) 0
    (List.range depth).map fun k => (i, k + 1))

/-- Row of the state matrix for state `(i, k)`: the form of output `i` for
    `k = 1`, the shift `y_i[n-k] ← y_i[n-k+1]` otherwise. -/
def rowOf (forms : List Aff) (states : List (Nat × Nat)) (s : Nat × Nat) : List Iv :=
  if s.2 == 1 then states.map fun t => (forms.getD s.1 []).coef t
  else states.map fun t => if t == (s.1, s.2 - 1) then Iv.pt Q.one else Iv.zero

def groupVerdict (dag : Dag) (free : List Nat) (nat natOpt : List Bool) (p : Prec)
    (rng : List (Option Iv)) (r : Nat) : GV × String :=
  let body := recBody dag r
  let isIntArg : Arg → Bool := fun
    | .ref j => natOpt.getD j false
    | .int _ => true
    | _ => false
  if body.all isIntArg then (.refused, "integer recursion (wrapping semantics)") else
  let affs := affines dag free nat p rng
  let formOf : Arg → Except String Aff := fun
    | .ref j => if free.getD j 1000 == 0 then .ok [] else affs.getD j (.error "?")
    | _ => .ok []
  match body.mapM formOf with
  | .error e => (.refused, e)
  | .ok forms =>
    match stateOf forms with
    | .error e => (.refused, e)
    | .ok states =>
      match states.map (rowOf forms states) with
      | [] => (.stable, "no feedback")
      | [[a]] => if jury1 a then (.stable, "") else (.unproven, "Jury fails on the box")
      | [[a, b], [c, d]] =>
          if jury2 a b c d then (.stable, "") else (.unproven, "Jury fails on the box")
      | _ => (.refused, s!"{states.length} states (more than 2)")

/-- The rates of `make check-precision`. -/
def checkRates : List Int := [44100, 48000, 88200, 96000, 176400, 192000]

def recNodes (dag : Dag) : List Nat :=
  (List.range dag.length).filter fun i =>
    match (dag.getD i default).tag with | .recur => true | _ => false

/-- For each recursion group, its verdict at each rate of `checkRates`. -/
def srVerdictsFull (dag : Dag) (p : Prec) : List (Nat × List (GV × String)) :=
  let free := freeLevels dag
  let nat := natures dag false
  let natOpt := natures dag true
  let perRate := checkRates.map fun sr =>
    let rng := ranges dag nat natOpt p sr
    (recNodes dag).map fun r => groupVerdict dag free nat natOpt p rng r
  (recNodes dag).zipIdx.map fun (r, g) => (r, perRate.map fun vs => vs.getD g (.refused, "?"))

def srVerdicts (dag : Dag) (p : Prec) : List (Nat × List GV) :=
  (srVerdictsFull dag p).map fun (r, vs) => (r, vs.map (·.1))

def GV.letter : GV → String
  | .stable => "S" | .unproven => "U" | .refused => "R"

/-- `n26:SSSSSS;n49:RRRRRR(reason)`, the probe format read by `sig2lean.py`. -/
def srProbe (dag : Dag) (p : Prec) : String :=
  String.intercalate ";" ((srVerdictsFull dag p).map fun (r, vs) =>
    let letters := String.join (vs.map (·.1.letter))
    let why := (vs.map (·.2)).filter (· != "") |>.eraseDups
    s!"n{r}:{letters}" ++ (if why.isEmpty then "" else s!"({String.intercalate ", " why})"))

/-! ## Standing obligations

The gaps below are recorded here rather than silently relied upon.

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

Note also that `certifyStableB` and `certifyIndicesB` are over the **exact
rationals** denoted by the exported double-precision coefficients. They say
nothing about the behaviour of the filter as executed in floating point.

The same caveat carries one concrete instance in the range analysis: the
phasor rule reads `x - floor(x) ∈ [0, 1)`, which is an identity of exact
arithmetic. In floating point `frac` is exact for `x ≥ 0`, but not below:
in single precision `frac(-1e-9)` is `1.0`, one past the interval. Auditing
the float behaviour of `frac` is part of the same floating-point obligation,
not a new one.

The rate analysis (`srVerdicts`) does model floating point, under these
assumptions:

3. **IEEE 754 arithmetic.** `+ - * /` and `sqrt` are correctly rounded, in the
   evaluation order of the graph. A fused multiply-add is covered (it rounds
   once where the model rounds twice); a reassociation (`-ffast-math`) is
   not: it changes the computation, not its rounding.

4. **The math library.** `tan`, `sin`, `cos`, `exp` and `pow` return their
   result within `libmUlps` ulps. This is a property of each platform's libm,
   stated, not proved.

5. **The enclosures.** The Taylor remainders of `sinI`, `cosI` and `expSmall`,
   the continuity argument of `tanI`, the monotonicity of `sqrt` and of the
   rounding widening, and the vertex lemma of `jury2` (a multilinear function
   reaches its minimum over a box at a vertex) are stated with their argument
   next to the code, and reviewed as mathematics. They are the next targets of
   the optional mathlib layer, which already proves the Jury criterion.

6. **What is claimed.** The coefficients (the state-free subexpressions) are
   taken as the program computes them; the loop arithmetic that involves the
   state is taken exactly. Its rounding perturbs the state at each sample: an
   accuracy question, bounded by no theorem here. The controls are at their
   default values, as in `make check-precision`. -/

end Faust.Signal
