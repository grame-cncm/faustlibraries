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

/-! ## The sample rates, in exact, double and single precision

The analyses above read a tree (`Sig`) and refuse every coefficient that goes
through a transcendental function, so nothing that depends on `ma.SR` is ever
certified, and they read only single-output recursions. This section reads the
same graph as a **DAG** (`Dag`, one `Node` per dump binding, children by index),
evaluates it bottom-up so that each node is computed once, and gives three
verdicts (`verdicts`), each at every rate and in every arithmetic:

* **stability** of each recursion group (`DEBRUIJNREC`), below;
* **finite values** (`finiteVerdict`): every time-invariant value (constants,
  coefficients computed from the sample rate and the controls) stays in the
  domain of its operation and does not overflow;
* **indices in range** (`siteVerdicts`): table reads and delay taps, for every
  value of the controls.

The stability verdict is given:

* at each of the six rates of `make check-precision` (`checkRates`), with the
  controls at their default values — the configuration `check-precision`
  renders;
* in three arithmetics (`Prec`): `exact` (no rounding modelled), `double` and
  `single`, where every real operation of the graph is rounded;
* exactly by Jury for systems whose state is at most 2 samples (first order,
  direct-form second order, two-output state-variable and TPT sections), and
  by the small-gain test otherwise (feedback combs and allpasses, delays in a
  loop, higher orders), a sufficient condition;
* over the groups nested in a group and coupled to it, analysed as one
  system with it (outputs `(g, i)`, group `g`, output `i`).

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

A coefficient that varies in time (it depends on a signal: an envelope stage,
an LFO) or a state read through a variable delay rules out Jury, which is
about frozen matrices: with one state, `|a| < 1` over the box is still a
contraction; otherwise only the small-gain test, which holds for any
variation within the box, may conclude.

For the finite verdict, the controls are at their default values, as for
stability and as in `check-precision`. For indices, a safety property, they
range over their declared bounds.

The ranges of recursion outputs come from **inductive invariants**
(`groupRanges`): a candidate range `C` containing the initial state 0 is
accepted when the body, evaluated with the state in `C`, stays in `C`. This
bounds phasors (`os.osc`: the phase stays in `[0, 1 - u]` in floating point
since it stays non-negative), counters (`ba.period`) and clamped recursions.

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
  `sin/cos` when the cosine enclosure excludes 0, `expI` with halving, `logI`
  from the `atanh` series; `sqrtI` from an integer square root whose bounds
  are *checked*, not assumed.
* **Floating-point rules.** Literals and control defaults are rounded to
  `float` exactly (`Q.toFloat32`); a product by a power of two is exact;
  `x - floor(x)` is `[0, 1 - u]` for `x ≥ 0` and `[0, 1]` otherwise
  (`frac(-1e-9)` is `1.0` in single); truncation is monotone.
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
/-- Truncation toward zero of one value: `⌊q⌋` for `q ≥ 0`, `⌈q⌉` below. -/
def truncQ (q : Q) : Q := if 0 ≤ q.n then Q.ofInt q.floor else Q.ofInt q.ceil
/-- Truncation toward zero and floor are non-decreasing, so they map
    `[lo, hi]` into `[f lo, f hi]`. -/
def trunc (a : Iv) : Iv := ⟨truncQ a.lo, truncQ a.hi⟩
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

/-- `π` between two rationals, 37 decimals: a standing obligation (the
    digits of `π`), which mathlib's `Real.pi` bounds discharge. -/
def piLo : Q := ⟨31415926535897932384626433832795028841, 10 ^ 37⟩
def piHi : Q := ⟨31415926535897932384626433832795028842, 10 ^ 37⟩

/-- `x - 2πk` for the integer `k` nearest `x / 2π`: the same `sin` and `cos`,
    an argument within 4 when `x` is narrower than about `2π`. `none` when
    `x` is too wide for the reduction to help. -/
def reduce2Pi (x : Iv) : Option Iv :=
  let twoPiLo := (Q.ofInt 2).mul piLo
  let twoPiHi := (Q.ofInt 2).mul piHi
  let mid : Q := ⟨x.lo.n * x.hi.d + x.hi.n * x.lo.d, 2 * x.lo.d * x.hi.d⟩
  let k : Int := ((Q.mul mid (Q.inv twoPiLo)).add ⟨1, 2⟩).floor   -- nearest
  -- 2πk lies between k·2πlo and k·2πhi (swapped for k < 0)
  let a := (Q.ofInt k).mul twoPiLo
  let b := (Q.ofInt k).mul twoPiHi
  let y : Iv := ⟨(x.lo.sub (Q.max a b)).down, (x.hi.sub (Q.min a b)).up⟩
  if y.within (Q.ofInt 4) then some y else none

/-- `sin` and `cos` over any interval: reduced modulo `2π`, and `[-1, 1]`
    when the interval is too wide. -/
def sinAny (x : Iv) : Iv :=
  ((if x.within (Q.ofInt 4) then some x else reduce2Pi x).bind sinI).getD ⟨Q.one.neg, Q.one⟩
def cosAny (x : Iv) : Iv :=
  ((if x.within (Q.ofInt 4) then some x else reduce2Pi x).bind cosI).getD ⟨Q.one.neg, Q.one⟩

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

/-- `exp` over any interval: beyond 710 it overflows a double (unknown);
    below -800 it is under `2⁻¹⁰⁰⁰` (`e⁻⁸⁰⁰ < 10⁻³⁴⁷`), and `exp` is
    increasing. Keeps the halvings of `expI` few and its numbers small. -/
def expRange (x : Iv) : Option Iv :=
  if Q.lt (Q.ofInt 710) x.hi then none
  else if Q.lt x.hi (Q.ofInt (-800)) then some ⟨Q.zero, Q.pow2neg 1000⟩
  else if Q.lt x.lo (Q.ofInt (-800)) then
    (expI 64 ⟨Q.ofInt (-800), x.hi⟩).map fun e => ⟨Q.zero, e.hi⟩
  else expI 64 x

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

/-- `mᵏ` rounded up, for `m ≥ 0`. -/
def powUp (m : Q) : Nat → Q
  | 0 => Q.one
  | k + 1 => ((powUp m k).mul m).up

/-- `Σ_{j<N} z^(2j+1)/(2j+1)` in interval arithmetic: `atanh z` without its
    remainder. -/
def atanhSeries (z2 : Iv) : Nat → Nat → Iv → Iv → Iv
  | 0, _, _, acc => acc
  | n + 1, j, pw, acc => atanhSeries z2 n (j + 1) (pw.mul z2) (acc.add (pw.divNat (2 * j + 1)))

def ATANHTERMS : Nat := 26

/-- `log m = 2·atanh z`, `z = (m-1)/(m+1)`, for `|z| ≤ 1/2`. After `N` terms
    the remainder of the `atanh` series is at most
    `|z|^(2N+1) / ((2N+1)(1 - z²)) ≤ (4/3)·|z|^(2N+1)/(2N+1)`. -/
def logNear1 (m : Iv) : Option Iv := do
  let z ← (m.sub (Iv.pt Q.one)).div (m.add (Iv.pt Q.one))
  if !(z.within ⟨1, 2⟩) then none else
  let s := atanhSeries (z.mul z) ATANHTERMS 0 z Iv.zero
  let rn := (⟨4, 3⟩ : Q).mul (powUp z.mag (2 * ATANHTERMS + 1))
  let r : Q := (⟨rn.n, rn.d * (2 * ATANHTERMS + 1)⟩ : Q).up
  let t : Iv := ⟨(s.lo.sub r).down, (s.hi.add r).up⟩
  pure (t.add t)

/-- `log q` for a rational `q > 0`: with `a = ⌊log₂ n⌋`, `b = ⌊log₂ d⌋` and
    `k = a - b`, `m = q / 2ᵏ` lies in `(1/2, 2)`, so `|z| < 1/3`, and
    `log q = log m + k·log 2`. -/
def logQ (q : Q) : Option Iv :=
  if !(Q.lt Q.zero q) then none else
  let k : Int := (Nat.log2 q.n.toNat : Int) - (Nat.log2 q.d.toNat : Int)
  let m : Q := if 0 ≤ k then ⟨q.n, q.d * ((2 : Nat) ^ k.toNat : Nat)⟩
               else ⟨q.n * ((2 : Nat) ^ (-k).toNat : Nat), q.d⟩
  do
    let lm ← logNear1 (Iv.pt m)
    let l2 ← logNear1 (Iv.pt (Q.ofInt 2))
    pure (lm.add (l2.mul (Iv.ofInt k)))

/-- `log` is increasing on `x > 0`. -/
def logI (x : Iv) : Option Iv :=
  if Q.lt Q.zero x.lo then do
    let a ← logQ x.lo
    let b ← logQ x.hi
    pure ⟨a.lo, b.hi⟩
  else none

def log10I (x : Iv) : Option Iv := do
  let l ← logI x
  let t ← logQ (Q.ofInt 10)
  l.div t

/-- The float nearest to `q` (ties to even), for a dyadic `q` (its
    denominator a power of two, as every double is) in the normal range of
    single precision; `none` otherwise. With `e = ⌊log₂ |q|⌋`, the
    significand `|q|·2^(23-e)` lies in `[2²³, 2²⁴)` and is rounded to an
    integer. -/
def Q.toFloat32 (q : Q) : Option Q :=
  if q.n == 0 then some Q.zero else
  let n := q.n.natAbs
  let d := q.d.toNat
  if !(0 < d && d &&& (d - 1) == 0) then none else
  let e : Int := (Nat.log2 n : Int) - (Nat.log2 d : Int)
  if e < -126 || e > 127 then none else
  -- |q|·2^(23-e) = n·2^(23-e) / d, as num / den
  let sh : Int := 23 - e
  let num : Nat := if 0 ≤ sh then n * 2 ^ sh.toNat else n
  let den : Nat := if 0 ≤ sh then d else d * 2 ^ (-sh).toNat
  let fl := num / den
  let rem := num % den
  let m := if 2 * rem > den || (2 * rem == den && fl % 2 == 1) then fl + 1 else fl
  -- value m·2^(e-23), sign of q
  let sgn : Int := if q.n < 0 then -1 else 1
  some (if 0 ≤ sh then ⟨sgn * (m : Int), ((2 : Nat) ^ sh.toNat : Nat)⟩
        else ⟨sgn * (m : Int) * ((2 : Nat) ^ (-sh).toNat : Nat), 1⟩)

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
/-- A control value, stored as `FAUSTFLOAT` = `float` in both precisions:
    its default value rounded to `float`, exactly (`Q.toFloat32`), or widened
    by one unit roundoff of `float` outside the normal range. -/
def control (p : Prec) (a : Iv) : Iv :=
  if p = .exact then a else
  match a.lo == a.hi, a.lo.toFloat32 with
  | true, some f => Iv.pt f
  | _, _ => a.widen (Q.pow2neg 24) (Q.pow2neg 140)
/-- A real literal: the dump gives the double, the single-precision program
    uses it rounded to `float`: exactly (`Q.toFloat32`), or widened by one
    unit roundoff outside the normal range. -/
def lit (p : Prec) (q : Q) : Iv :=
  if p = .single then
    match q.toFloat32 with
    | some f => Iv.pt f
    | none => (Iv.pt q).widen p.u p.eta
  else Iv.pt q
/-- An integer operand converted to the real type. -/
def promote (p : Prec) (isInt : Bool) (a : Iv) : Iv :=
  if isInt && !(Q.le (Q.ofInt p.intExact) a.mag) then a else if isInt then p.op a else a
end Prec

/-! ### The DAG -/

/-- The branch `select2(s, a, b)` takes, when the selector decides it. The
    generated code reads `((int)s) ? b : a`: the selector is truncated toward
    zero, so `|s| < 1` selects `a` and `|s| ≥ 1` selects `b`. -/
def Iv.selects (c : Iv) : Option Bool :=
  if Q.lt (Q.ofInt (-1)) c.lo && Q.lt c.hi Q.one then some false
  else if Q.le Q.one c.lo || Q.le c.hi (Q.ofInt (-1)) then some true
  else none

inductive CmpOp where
  | lt | le | gt | ge | eq | ne
deriving Repr, DecidableEq, Inhabited

/-- `some b` when the comparison of every value of `x` with every value of `y`
    gives `b`, `none` when the intervals do not decide it. -/
def CmpOp.decide (op : CmpOp) (x y : Iv) : Option Bool :=
  let lt := Q.lt x.hi y.lo              -- every x < every y
  let ge := Q.le y.hi x.lo              -- every x ≥ every y
  let le := Q.le x.hi y.lo
  let gt := Q.lt y.hi x.lo
  let same := x.lo == x.hi && y.lo == y.hi && x.lo.n * y.lo.d == y.lo.n * x.lo.d
  let apart := lt || gt
  match op with
  | .lt => if lt then some true else if ge then some false else none
  | .le => if le then some true else if gt then some false else none
  | .gt => if gt then some true else if le then some false else none
  | .ge => if ge then some true else if lt then some false else none
  | .eq => if same then some true else if apart then some false else none
  | .ne => if apart then some true else if same then some false else none

inductive BitOp where
  | and | or | xor | lsh | rsh | arsh
deriving Repr, DecidableEq, Inhabited

inductive Tag where
  | input | delay1 | delay | proj | recur | ref | cons
  | bit (op : BitOp)   -- integer bit operations
  | round             -- `round`, `rint`, `ceil`: an integer near the value
  | log | log10 | fmod
  | rdtbl | wrtbl     -- table read, table write (the table and its size)
  | binop (op : BinOp)
  | cmp (op : CmpOp)  -- comparisons: 0 or 1
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
  | .binop .rem => "SIGBINOP:rem" | .cmp _ => "comparison" | .sr => "SIGFCONST"
  | .control => "control" | .button => "button" | .intcast => "SIGINTCAST"
  | .floatcast => "SIGFLOATCAST" | .min => "SIGMIN" | .max => "SIGMAX"
  | .abs => "SIGABS" | .floor => "SIGFLOOR" | .select2 => "SIGSELECT2"
  | .tan => "SIGTAN" | .sin => "SIGSIN" | .cos => "SIGCOS" | .exp => "SIGEXP"
  | .sqrt => "SIGSQRT" | .pow => "SIGPOW" | .bit _ => "bit operation"
  | .round => "SIGROUND" | .log => "SIGLOG" | .log10 => "SIGLOG10" | .fmod => "SIGFMOD"
  | .rdtbl => "SIGRDTBL" | .wrtbl => "SIGWRTBL" | .other s => s

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
abbrev Dag := Array Node

/-- The value of node `j` while computing node `i`, from `acc`, the values
    computed so far, in index order. A forward reference (`j ≥ i`, which a
    post-order dump never contains) yields `d`. -/
def lookback {α} (acc : Array α) (i j : Nat) (d : α) : α :=
  if j < i then acc.getD j d else d

/-- Fold a node function over the DAG in index order. -/
def dagPass {α} (dag : Dag) (f : Array α → Nat → Node → α) : Array α :=
  let rec go : Nat → List Node → Array α → Array α
    | _, [], acc => acc
    | i, nd :: rest, acc => go (i + 1) rest (acc.push (f acc i nd))
  go 0 dag.toList #[]

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
def freeLevels (dag : Dag) : Array Nat :=
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
def natures (dag : Dag) (optimistic : Bool) : Array Bool :=
  dagPass dag fun acc i nd =>
    let ia : Arg → Bool := fun
      | .ref j => lookback acc i j false
      | .int _ => true
      | _ => false
    match nd.tag, nd.args with
    | .intcast, _ | .cmp _, _ | .sr, _ | .bit _, _ => true
    | .binop .div, _ => false                -- Faust's `/` is always a real division
    | .binop _, [a, b] | .min, [a, b] | .max, [a, b] | .select2, [_, a, b] => ia a && ia b
    | .abs, [a] | .delay1, [a] | .delay, [a, _] => ia a
    | .proj, [_, .ref j] =>
        optimistic && (match (dag.getD j default).tag with | .ref => true | _ => false)
    | _, _ => false

/-! ### Ranges -/

/-- The nodes the body of group `r` reads, without entering a coefficient
    (`free = 0`: its range is all that is needed) or a nested recursion (an
    error when it is coupled to the group), in index order. A node the search
    misses stays "unevaluated", which can only refuse the group. -/
def bodyNodes (dag : Dag) (free : Array Nat) (r : Nat) : List Nat :=
  let push : Array Bool × List Nat → Arg → Array Bool × List Nat := fun (vis, st) a =>
    match a with
    | .ref j =>
        if j < r && !(vis.getD j true) && free.getD j 0 != 0 then (vis.set! j true, j :: st)
        else (vis, st)
    | _ => (vis, st)
  let rec go : Nat → Array Bool × List Nat → Array Bool
    | 0, (vis, _) => vis
    | _, (vis, []) => vis
    | f + 1, (vis, j :: rest) =>
        let nd := dag.getD j default
        let kids := match nd.tag with
          | .recur => []
          | _ => nd.args
        go f (kids.foldl push (vis, rest))
  let vis := go (r + 1) ((recBody dag r).foldl push (Array.replicate r false, []))
  (List.range r).filter fun j => vis.getD j false

/-- A point interval holding a power of two `2ᵏ`, `k ≥ 0`: multiplying a
    float by it is exact (barring overflow, which `finiteVerdict` checks). -/
def isPow2 (c : Iv) : Bool :=
  c.lo == c.hi && 0 < c.lo.n && c.lo.n % c.lo.d == 0 &&
    (let m := (c.lo.n / c.lo.d).toNat; m &&& (m - 1) == 0)

/-- `x - floor(x)` computed in floating point. For `x ≥ 0` it is exact (for
    `x ≥ 1`, `⌊x⌋ ≥ x/2` and Sterbenz applies; below 1, `⌊x⌋ = 0`), and the
    fractional part of a float is a float below 1, hence at most `1 - u`
    (the largest float below 1 in both formats). For a negative `x` it can
    round to `1.0` (`frac(-1e-9) = 1.0` in single): `[0, 1]`. In exact
    arithmetic the value is below 1 but with no margin: `[0, 1]` as well. -/
def fracRange (p : Prec) (x : Iv) : Iv :=
  if p = .exact then ⟨Q.zero, Q.one⟩
  else if Q.le Q.zero x.lo then ⟨Q.zero, Q.one.sub p.u⟩
  else ⟨Q.zero, Q.one⟩

/-- Range of one node from the ranges of its arguments (`ref`). `self k` is
    the range of output `k` of the recursion group being evaluated (for a
    projection of `REF 1`), `recOut r k` the range of output `k` of the group
    `r` (for a projection of a nested recursion). `none`: unknown. -/
def rangeNode (dag : Dag) (nat natOpt : Array Bool) (p : Prec) (sr : Int) (full : Bool)
    (ref : Nat → Option Iv) (self : Nat → Option Iv) (recOut : Nat → Nat → Option Iv)
    (i : Nat) (nd : Node) : Option Iv :=
    let v : Arg → Option Iv := fun
      | .ref j => if j < i then ref j else none
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
    let isFrac : Arg → Arg → Bool := fun a b =>
      match a, b with
      | .ref x, .ref j =>
          match (dag.getD j default).tag, (dag.getD j default).args with
          | .floor, [.ref y] => x == y
          | _, _ => false
      | _, _ => false
    let pt : Iv → Bool := fun c => c.lo == c.hi && c.lo.n % c.lo.d == 0
    let k : Iv → Int := fun c => c.lo.n / c.lo.d
    match nd.tag, nd.args with
    | .sr, _ => some (Iv.ofInt sr)
    | .control, _ =>
        if full then                            -- any value of the declared range
          let r : Iv := ⟨nd.ctl.2.1, nd.ctl.2.2⟩
          some (if p = .exact then r else r.widen (Q.pow2neg 24) (Q.pow2neg 140))
        else some (p.control (Iv.pt nd.ctl.1))  -- the default value
    | .button, _ => some ⟨Q.zero, Q.one⟩
    | .cmp op, [a, b] =>
        match (do let x ← v a; let y ← v b; op.decide x y) with
        | some true  => some (Iv.pt Q.one)
        | some false => some Iv.zero
        | none       => some ⟨Q.zero, Q.one⟩
    | .delay1, [a] | .delay, [a, _] => (v a).map (·.hull Iv.zero)
    | .proj, [.int n, .ref j] =>
        if j < i then
          match (dag.getD j default).tag, (dag.getD j default).args with
          | .ref, [.int 1] => self n.toNat
          | .recur, _ => recOut j n.toNat
          | _, _ => none
        else none
    | .intcast, [a] => (v a).map Iv.trunc
    | .floatcast, [a] => rv a
    | .min, [a, b] => do let x ← v a; let y ← v b; pure (x.rmin y)
    | .max, [a, b] => do let x ← v a; let y ← v b; pure (x.rmax y)
    | .select2, [s, a, b] =>
        match (v s).bind Iv.selects with
        | some false => v a
        | some true  => v b
        | none => do let x ← v a; let y ← v b; pure (x.hull y)
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
        else if op == .sub && isFrac a b then (v a).map (fracRange p)
        else noWrap do
          let x ← rv a
          let y ← rv b
          match op with
          | .add => some (p.op (x.add y))
          | .sub => some (p.op (x.sub y))
          | .mul =>
              -- `x * x` of one node is a square: non-negative
              let prod := match a, b with
                | .ref j, .ref j' => if j == j' then x.abs.mul x.abs else x.mul y
                | _, _ => x.mul y
              some (if isPow2 x || isPow2 y then prod else p.op prod)
          | .div => (x.div y).map p.op
          | .rem =>                          -- fmod: exact, |r| < |m|, sign of x
              if y.lo == y.hi && Q.lt Q.zero y.lo then
                if Q.le Q.zero x.lo then some ⟨Q.zero, y.lo⟩ else some ⟨y.lo.neg, y.lo⟩
              else none
    | .tan, [a]  => ((rv a).bind tanI).map p.libm
    | .sin, [a]  => some (p.libm (((rv a).map sinAny).getD ⟨Q.one.neg, Q.one⟩))  -- |sin| ≤ 1
    | .cos, [a]  => some (p.libm (((rv a).map cosAny).getD ⟨Q.one.neg, Q.one⟩))
    | .other "SIGGEN", [a] => v a                -- a table's generator: its values
    | .rdtbl, [.ref w, _] =>                     -- a value of the table: generated or written
        if w < i then
          match (dag.getD w default).tag, (dag.getD w default).args with
          | .wrtbl, [_, g, wi, wv] => do
              let gen ← v g
              match wi, wv with
              | .ref _, .ref _ => (v wv).map gen.hull   -- rwtable: the written values too
              | _, _ => some gen
          | _, _ => none
        else none
    | .exp, [a]  => ((rv a).bind expRange).map p.libm
    | .sqrt, [a] => ((rv a).bind sqrtI).map p.op
    | .log, [a]   => ((rv a).bind logI).map p.libm
    | .log10, [a] => ((rv a).bind log10I).map p.libm
    | .round, [a] => (v a).map fun x => ⟨Q.ofInt x.lo.floor, Q.ofInt x.hi.ceil⟩
    | .fmod, [a, b] => do                    -- exact, |r| < |m|, sign of x
        let x ← rv a
        let y ← rv b
        if y.lo == y.hi && Q.lt Q.zero y.lo then
          if Q.le Q.zero x.lo then some ⟨Q.zero, y.lo⟩ else some ⟨y.lo.neg, y.lo⟩
        else none
    | .bit op, [a, b] => do
        let x ← v a
        let y ← v b
        let nonneg : Iv → Bool := fun c => Q.le Q.zero c.lo
        let shift : Int → Iv := fun e =>        -- x >> e = ⌊x / 2^e⌋ for integers
          let d : Int := (2 : Int) ^ e.toNat
          ⟨Q.ofInt (Int.fdiv x.lo.ceil d), Q.ofInt (Int.fdiv x.hi.floor d)⟩
        let r ← match op with
          | .and =>                             -- x & m ∈ [0, m] for m ≥ 0
              if pt y && 0 ≤ k y then some ⟨Q.zero, Q.ofInt (k y)⟩
              else if pt x && 0 ≤ k x then some ⟨Q.zero, Q.ofInt (k x)⟩
              else if nonneg x && nonneg y then some ⟨Q.zero, Q.min x.hi y.hi⟩ else none
          | .or | .xor =>
              if pt y && k y == 0 then some x else if pt x && k x == 0 then some y else none
          | .lsh => if pt y && 0 ≤ k y && k y ≤ 30 then
                      some (x.mul (Iv.ofInt ((2 : Int) ^ (k y).toNat))) else none
          | .arsh => if pt y && 0 ≤ k y && k y ≤ 31 then some (shift (k y)) else none
          | .rsh => if nonneg x && pt y && 0 ≤ k y && k y ≤ 31 then some (shift (k y)) else none
        if r.fitsInt32 then some r else none
    | .pow, [a, b] =>                        -- integer exponents only
        match v b with
        | some e =>
            if e.lo == e.hi && e.lo.n % e.lo.d == 0 && 0 ≤ e.lo.n && e.lo.n / e.lo.d ≤ 64 then
              (rv a).map fun x => p.libm (powNat x (e.lo.n / e.lo.d).toNat)
            else none
        | none => none
    | _, _ => none


/-- Ranges of the outputs of recursion group `r`, valid at every sample.
    `outer` holds the ranges of the nodes below `r`. The body is evaluated
    with the state (the group's own outputs, delayed) in a candidate range
    `C` containing 0, the initial state: if every output then lands in `C`,
    `C` is an inductive invariant and the outputs lie in what the body
    gives, at every sample. The candidates are guesses — the range with the
    state unknown and its non-negative part, and two Kleene steps from the
    initial state — and only their check matters. Without an invariant, the
    range with the state unknown holds. -/
def groupRanges (dag : Dag) (free : Array Nat) (nat natOpt : Array Bool) (p : Prec)
    (sr : Int) (full : Bool) (outer : Array (Option Iv)) (r : Nat) : Array (Option Iv) :=
  let body := recBody dag r
  let nodes := bodyNodes dag free r
  let eval : Array (Option Iv) → Array (Option Iv) := fun S =>
    let loc := nodes.foldl (fun m j =>
        m.set! j (rangeNode dag nat natOpt p sr full
          (fun x => if free.getD x 1000 == 0 then outer.getD x none else m.getD x none)
          (fun n => S.getD n none) (fun _ _ => none) j (dag.getD j default)))
      (Array.replicate r none)
    (body.map fun a => match a with
      | .ref x => if free.getD x 1000 == 0 then outer.getD x none else loc.getD x none
      | .int n => some (Iv.ofInt n)
      | .const q => some (p.lit q)
      | _ => none).toArray
  let r0 := eval (Array.replicate body.length none)
  let within : Option Iv → Option Iv → Bool := fun f c =>
    match f, c with
    | some f, some c => Q.le c.lo f.lo && Q.le f.hi c.hi
    | _, _ => false
  let check : Array (Option Iv) → Option (Array (Option Iv)) := fun C =>
    if C.all (·.isSome) then
      let F := eval C
      if (List.range C.size).all fun n => within (F.getD n none) (C.getD n none) then some F
      else none
    else none
  let withZero := r0.map (·.map (·.hull Iv.zero))
  let nonneg := r0.map (·.map fun x => (⟨Q.max Q.zero x.lo, Q.max Q.zero x.hi⟩ : Iv).hull Iv.zero)
  -- Kleene steps from the initial state 0: K₀ = {0}, Kₙ₊₁ = Kₙ ∪ F(Kₙ)
  let step : Array (Option Iv) → Array (Option Iv) := fun K =>
    let F := eval K
    (List.range K.size).toArray.map fun n =>
      match K.getD n none, F.getD n none with
      | some k, some f => some (k.hull f)
      | _, _ => none
  let k0 : Array (Option Iv) := Array.replicate body.length (some Iv.zero)
  let k1 := step k0
  let k2 := step k1
  let candidates := [nonneg, withZero, k1, k2]
  match candidates.findSome? check with
  | some F => F
  | none => r0

/-- Interval of every node, for one precision and rate, with the controls at
    their default values (`full = false`) or anywhere in their declared range
    (`full = true`). `none`: unknown or unbounded. A recursion output gets the
    range `groupRanges` proves for it. -/
def ranges (dag : Dag) (free : Array Nat) (nat natOpt : Array Bool) (p : Prec) (sr : Int)
    (full : Bool) : Array (Option Iv) :=
  dagPass dag fun acc i nd =>
    rangeNode dag nat natOpt p sr full (fun j => lookback acc i j none) (fun _ => none)
      (fun r n => if r < i then (groupRanges dag free nat natOpt p sr full acc r).getD n none
                  else none)
      i nd

/-! ### Linear extraction of a recursion group -/

/-- An output of a recursion group: `(g, i)` is output `i` of the group whose
    `DEBRUIJNREC` is node `g`. A group coupled to groups nested in it is
    analysed as one system over the outputs of all of them. -/
abbrev Out := Nat × Nat

/-- `((o, k), c)`: coefficient `c` on output `o` delayed by `k` samples. -/
structure Aff where
  terms : List ((Out × Nat) × Iv)
  /-- some coefficient or selector of the form varies in time -/
  tv : Bool := false
  /-- some state is read through a variable delay (its key holds 1, the
      least delay; only the small-gain test may then conclude) -/
  vd : Bool := false

def Aff.none : Aff := ⟨[], false, false⟩
def Aff.state (o : Out) (k : Nat) : Aff := ⟨[((o, k), Iv.pt Q.one)], false, false⟩
def Aff.shift (k : Nat) (a : Aff) : Aff :=
  { a with terms := a.terms.map fun ((o, d), c) => ((o, d + k), c) }
def Aff.scale (s : Iv) (a : Aff) : Aff := { a with terms := a.terms.map fun (key, c) => (key, c.mul s) }
def Aff.neg (a : Aff) : Aff := { a with terms := a.terms.map fun (key, c) => (key, c.neg) }
def Aff.add (a b : Aff) : Aff := ⟨a.terms ++ b.terms, a.tv || b.tv, a.vd || b.vd⟩
def Aff.varying (a : Aff) : Aff := { a with tv := true }
def Aff.varDelay (a : Aff) : Aff := { a with vd := true }
def Aff.coef (a : Aff) (key : Out × Nat) : Iv :=
  a.terms.foldl (fun s (k, c) => if k == key then s.add c else s) Iv.zero
/-- Coefficient by coefficient hull of two forms: at each sample, the value
    is one of the two, so each coefficient lies in the hull. -/
def Aff.hullWith (a b : Aff) : Aff :=
  let keys := ((a.terms ++ b.terms).map (·.1)).eraseDups
  ⟨keys.map fun k => (k, (a.coef k).hull (b.coef k)), a.tv || b.tv, a.vd || b.vd⟩

/-- Affine form, in the state of the system being analysed, of every node
    that can be reached from the body of a group without entering a nested
    recursion. A node with `free = 0` is a coefficient (its form is empty, its
    value is its range). `REF m` is the group `ctx[m-1]` (the group itself
    for `m = 1`, the one enclosing it for `m = 2`...); an output of a nested
    group coupled to this one is its form, from `inner`. The loop arithmetic
    (products by a coefficient, sums) is exact in the claim, see the section
    header. -/
def affNode (dag : Dag) (free : Array Nat) (nat tinv : Array Bool) (p : Prec)
    (rng : Array (Option Iv)) (ctx : List Nat) (inner : List (Out × Aff))
    (acc : Array (Except String Aff)) (i : Nat) (nd : Node) : Except String Aff :=
    -- a coefficient that varies in time marks the form (`tv`): Jury on a box
    -- of frozen matrices says nothing of a recursion whose matrix moves from
    -- sample to sample, except with one state (see `groupVerdict`)
    let timeInv : Arg → Bool := fun
      | .ref j => tinv.getD j false
      | _ => true
    let fr : Arg → Nat := fun
      | .ref j => free.getD j 1000
      | _ => 0
    let f : Arg → Except String Aff := fun
      | .ref j => if free.getD j 1000 == 0 then .ok Aff.none
                  else lookback acc i j (.error "forward reference")
      | _ => .ok Aff.none
    -- a coefficient: its range, converted to the real type of the state
    let val : Arg → Option Iv := fun
      | .ref j => (rng.getD j none).map (p.promote (nat.getD j false))
      | .int k => some (p.promote true (Iv.ofInt k))
      | .const q => some (p.lit q)
      | _ => none
    if free.getD i 1000 == 0 then .ok Aff.none else
    match nd.tag, nd.args with
    | .proj, [.int k, .ref j] =>
        match (dag.getD j default).tag, (dag.getD j default).args with
        | .ref, [.int m] =>                     -- output k of group ctx[m-1], now
            match (if 1 ≤ m then ctx[m.toNat - 1]? else none) with
            | some g => .ok (Aff.state (g, k.toNat) 0)
            | none => .error "part of an enclosing group (analysed with it)"
        | .recur, _ =>                          -- a nested group coupled to this one
            match inner.lookup (j, k.toNat) with
            | some form => .ok form
            | none => .error "nested recursion coupled to the group"
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
            -- a variable delay of at least one sample: the small-gain test
            -- only needs a delay ≥ 1, not its value
            else if Q.le Q.one d.lo then (f a).map fun x => (x.shift 1).varDelay
            else .error "variable delay of the state, possibly below 1"
        | none => .error "variable delay of the state"
    | .binop .add, [a, b] => do let x ← f a; let y ← f b; pure (x.add y)
    | .binop .sub, [a, b] => do let x ← f a; let y ← f b; pure (x.add y.neg)
    | .binop .mul, [a, b] =>
        if fr a != 0 && fr b != 0 then .error "product of two state terms"
        else
          let (st, sc) := if fr a == 0 then (b, a) else (a, b)
          match val sc with
          | some s => (f st).map fun x =>
              let y := x.scale s
              if timeInv sc then y else y.varying
          | none   => .error "unbounded coefficient on the state"
    | .binop .div, [a, b] =>
        if fr b != 0 then .error "division by the state"
        else match (val b).bind Iv.inv with
          | some s => (f a).map fun x =>
              let y := x.scale s
              if timeInv b then y else y.varying
          | none   => .error "coefficient 1/x with x possibly 0"
    | .floatcast, [a] => f a
    | .select2, [s, a, b] =>                -- a state-free selector
        if fr s != 0 then .error "SIGSELECT2 on the state"
        else match (val s).bind Iv.selects, timeInv s with
          | some false, true => f a
          | some true, true  => f b
          | _, tvs => do                        -- either branch: the hull of both
              let x ← f a
              let y ← f b
              let h := x.hullWith y
              pure (if tvs then h else h.varying)  -- `tvs`: the selector is time-invariant
    | t, _ => .error s!"{t.name} applied to the state"

/-- Affine forms of the nodes of `bodyNodes`, the others left unevaluated. -/
def affinesAt (dag : Dag) (free : Array Nat) (nat tinv : Array Bool) (p : Prec)
    (rng : Array (Option Iv)) (ctx : List Nat) (inner : List (Out × Aff)) (r : Nat) :
    Array (Except String Aff) :=
  (bodyNodes dag free r).foldl
    (fun acc i => acc.set! i (affNode dag free nat tinv p rng ctx inner acc i (dag.getD i default)))
    (Array.replicate r (.error "unevaluated"))

/-- The nested groups coupled to `r`, read at depth 0 of its body. -/
def nestedOf (dag : Dag) (free : Array Nat) (r : Nat) : List Nat :=
  (bodyNodes dag free r).filter fun j =>
    match (dag.getD j default).tag with | .recur => true | _ => false

/-- The number of `groupForms` calls the analysis of `r` makes, or more than
    `budget` as soon as it exceeds it: a shared nested group is analysed once
    per path, which can grow exponentially in a large DAG. -/
def formCalls (dag : Dag) (free : Array Nat) : Nat → Nat → Nat → Nat
  | 0, _, budget => budget + 1
  | f + 1, r, budget =>
      (nestedOf dag free r).foldl (fun used g =>
        if used > budget then used else used + formCalls dag free f g (budget - used)) 1

/-- The forms of the outputs of group `r`, in context `ctx` (the groups
    enclosing it, innermost first), and of every group nested in it and
    coupled to it (a nested group that refers to the state of `r` or of a
    group enclosing it), innermost first: nested groups are analysed first,
    and their outputs enter the forms of `r` through their own forms. -/
def groupForms (dag : Dag) (free : Array Nat) (nat tinv : Array Bool) (p : Prec)
    (rng : Array (Option Iv)) : Nat → List Nat → Nat → Except String (List (Out × Aff))
  | 0, _, _ => .error "nested recursions too deep"
  | f + 1, ctx, r => do
      let ctx' := r :: ctx
      let inner ← (nestedOf dag free r).foldlM (fun acc g => do
          let fs ← groupForms dag free nat tinv p rng f ctx' g
          pure (acc ++ fs)) []
      let affs := affinesAt dag free nat tinv p rng ctx' inner r
      let formOf : Arg → Except String Aff := fun
        | .ref j => if free.getD j 1000 == 0 then .ok Aff.none else affs.getD j (.error "?")
        | _ => .ok Aff.none
      let own ← (recBody dag r).zipIdx.mapM fun (a, n) => (formOf a).map fun fm => ((r, n), fm)
      pure (own ++ inner)

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
  | stable     -- proven stable (Jury at the vertices, or the small-gain test)
  | unproven   -- linear, but neither test concludes
  | refused    -- not a linear system the analysis reads
deriving Repr, DecidableEq

/-! ### The small-gain test

If every output that feeds back reads `y_o[n] = Σ c · y_{o'}[n - k] + x_o`
with delays `k ≥ 1`, let `M o o'` bound `Σ_k |c|` over the box. If some
weights `v > 0` satisfy `M v < v` componentwise, then with
`ρ = max_o (M v)_o / v_o < 1` and `E_n = max_{m ≤ n, o} |y_o[m]| / v_o`,
`|y_o[n]| ≤ ρ v_o E_{n-1} + |x_o|`, so `E` stays below
`max |x| / (min v · (1 - ρ))`: the recursion is stable. The argument needs no
bound on the delays and holds when the coefficients change at every sample
(within the box) and when a delay varies (at least one sample): it covers
feedback combs and allpasses (`|g| < 1`), their damped variants, and
variable delays in a loop. It is sufficient, not necessary: a lossless
orthogonal mixing matrix (an FDN) has `M v ≥ v`. The weights come from the
iteration `v ← 1 + M v`, untrusted; only the final check `M v < v`, with
products and sums rounded up, matters. -/

/-- `M o o'`: the sum over the delays of the largest `|c|` of the box, rounded
    up. -/
def gainMatrix (forms : List (Out × Aff)) (fed : List Out) : List (List Q) :=
  fed.map fun o =>
    let fm := (forms.lookup o).getD Aff.none
    fed.map fun o' =>
      fm.terms.foldl (fun s ((o'', _), c) => if o'' == o' then (s.add c.mag).up else s) Q.zero

/-- An upper bound of `M v`, for `v ≥ 0`. -/
def mulVecUp (M : List (List Q)) (v : List Q) : List Q :=
  M.map fun row => (row.zip v).foldl (fun s (a, b) => (s.add (a.mul b)).up) Q.zero

def smallGain (M : List (List Q)) : Nat → List Q → Bool
  | 0, _ => false
  | f + 1, v =>
      let mv := mulVecUp M v
      if (mv.zip v).all (fun (a, b) => Q.lt a b) then true
      else smallGain M f (mv.map (Q.one.add ·))

/-- The state of a system: `(o, k)` for `k = 1 .. depth o`, where `depth o`
    is the largest delay at which output `o` is read, for the outputs that
    feed back (`fed`). -/
def stateOf (forms : List (Out × Aff)) (fed : List Out) : List (Out × Nat) :=
  let keys := forms.flatMap (·.2.terms.map (·.1))
  fed.flatMap fun o =>
    let depth := keys.foldl (fun m (o', k) => if o' == o then Nat.max m k else m) 0
    (List.range depth).map fun k => (o, k + 1)

/-- Row of the state matrix for state `(o, k)`: the form of output `o` for
    `k = 1`, the shift `y_o[n-k] ← y_o[n-k+1]` otherwise. -/
def rowOf (forms : List (Out × Aff)) (states : List (Out × Nat)) (s : Out × Nat) : List Iv :=
  if s.2 == 1 then states.map fun t => ((forms.lookup s.1).getD Aff.none).coef t
  else states.map fun t => if t == (s.1, s.2 - 1) then Iv.pt Q.one else Iv.zero

/-- The stability verdict of group `r` (with the groups nested in it and
    coupled to it). Up to 2 states, constant coefficients and fixed delays:
    Jury at the vertices, exact. One state with a time-varying coefficient:
    `|a| < 1` over the box, a contraction. Otherwise: the small-gain test. -/
def groupVerdict (dag : Dag) (free : Array Nat) (nat natOpt tinv : Array Bool) (p : Prec)
    (rng : Array (Option Iv)) (r : Nat) : GV × String :=
  let body := recBody dag r
  let isIntArg : Arg → Bool := fun
    | .ref j => natOpt.getD j false
    | .int _ => true
    | _ => false
  if body.all isIntArg then (.refused, "integer recursion (wrapping semantics)") else
  -- a group that refers to an enclosing one is analysed with it
  if free.getD r 1000 != 0 then (.refused, "part of an enclosing group (analysed with it)") else
  if formCalls dag free 16 r 32 > 32 then
    (.refused, "more than 32 nested groups coupled to the group") else
  match groupForms dag free nat tinv p rng 16 [] r with
  | .error e => (.refused, e)
  | .ok forms =>
    let keys := forms.flatMap (·.2.terms.map (·.1))
    if keys.any (·.2 == 0) then (.refused, "delay-free loop") else
    let fed := (keys.map (·.1)).eraseDups
    if fed.any (fun o => (forms.lookup o).isNone) then
      (.refused, "state beyond the outputs read") else
    let tv := forms.any (·.2.tv)
    let vd := forms.any (·.2.vd)
    let depth : Out → Nat := fun o => keys.foldl (fun m (o', k) => if o' == o then Nat.max m k else m) 0
    let total : Nat := fed.foldl (fun t o => t + depth o) 0
    let bySmallGain : GV × String :=
      if smallGain (gainMatrix forms fed) 64 (fed.map fun _ => Q.one) then (.stable, "")
      else (.unproven, s!"small-gain test fails ({total} states)")
    if vd || total > 2 || (tv && total == 2) then bySmallGain else
    let states := stateOf forms fed
    match states.map (rowOf forms states) with
    | [] => (.stable, "no feedback")
    | [[a]] => if jury1 a then (.stable, "") else (.unproven, "Jury fails on the box")
    | [[a, b], [c, d]] =>
        if jury2 a b c d then (.stable, "") else (.unproven, "Jury fails on the box")
    | _ => bySmallGain

/-- The rates of `make check-precision`. -/
def checkRates : List Int := [44100, 48000, 88200, 96000, 176400, 192000]

def recNodes (dag : Dag) : List Nat :=
  (List.range dag.size).filter fun i =>
    match (dag.getD i default).tag with | .recur => true | _ => false

/-- Nodes whose value does not vary in time under the claim: they depend
    only on constants, the sample rate and the controls (held at their
    default values). A signal (an input, a delay, a recursion, a table, a
    generator, a foreign function other than those of `<math.h>`) is not. -/
def pureOther (s : String) : Bool :=
  ["SIGASIN", "SIGACOS", "SIGATAN", "SIGATAN2", "SIGFCONST", "FFUN", "SIGFFUN<math.h>"].contains s ||
    s.startsWith "SIGBINOP:"

def pures (dag : Dag) : Array Bool :=
  dagPass dag fun acc i nd =>
    let pa : Arg → Bool := fun
      | .ref j => lookback acc i j false
      | _ => true
    let args := nd.args.all pa
    match nd.tag with
    | .input | .delay1 | .delay | .proj | .recur | .ref | .rdtbl | .wrtbl => false
    | .other s => args && pureOther s
    | _ => args

/-! ### Finite values and table indices in floating point -/

inductive FV where
  | finite    -- every time-invariant value is finite and in its domain
  | domain    -- some operation may leave its domain or overflow
  | unknown   -- some time-invariant value cannot be bounded (unmodelled)
deriving Repr, DecidableEq

/-- The largest finite value of the precision: `(2²⁴-1)·2¹⁰⁴` and
    `(2⁵³-1)·2⁹⁷¹`. -/
def Prec.maxFinite : Prec → Option Q
  | .exact  => none
  | .single => some (Q.ofInt ((2 ^ 24 - 1) * 2 ^ 104))
  | .double => some (Q.ofInt ((2 ^ 53 - 1) * 2 ^ 971))

private def showQd (q : Q) : String :=
  toString (Float.ofInt q.n / Float.ofInt q.d)

private def showIv (x : Iv) : String := s!"[{showQd x.lo}, {showQd x.hi}]"

/-- Every time-invariant value (a constant, a coefficient computed from the
    sample rate and the controls) is finite, at one rate and in one
    precision: each operation stays in its domain over the ranges of its
    arguments (no division by an interval containing 0, no `sqrt` or `log`
    of a value that may be negative, no `tan` near a pole) and no result
    overflows. A `domain` verdict names the first operation that may fail;
    `unknown` the first value the analysis cannot bound. This is the
    time-invariant part of `check-precision`'s non-finite criterion, for
    every value of the ranges instead of one render. -/
def finiteVerdict (dag : Dag) (tinv : Array Bool) (p : Prec) (rng : Array (Option Iv)) :
    FV × String :=
  let argv : Arg → Option Iv := fun
    | .ref j => rng.getD j none
    | .int k => some (Iv.ofInt k)
    | .const q => some (Iv.pt q)
    | _ => none
  let known : Node → Bool := fun nd => nd.args.all fun a =>
    match a with
    | .ref j => (rng.getD j none).isSome
    | _ => true
  let check : Nat → Node → Option (FV × String) := fun i nd =>
    let tag := nd.tag.name
    let dom : Option String :=
      match nd.tag, nd.args with
      | .binop .div, [_, b] | .binop .rem, [_, b] | .fmod, [_, b] =>
          (argv b).bind fun y => if y.hasZero then some s!"divisor {showIv y}" else none
      | .sqrt, [a] => (argv a).bind fun x =>
          if Q.lt x.lo Q.zero then some s!"argument {showIv x}" else none
      | .log, [a] | .log10, [a] => (argv a).bind fun x =>
          if Q.le x.lo Q.zero then some s!"argument {showIv x}" else none
      | .tan, [a] => (argv a).bind fun x =>
          if x.within (Q.ofInt 4) && (tanI x).isNone then some s!"near a pole, {showIv x}" else none
      | _, _ => none
    match dom with
    | some why => some (.domain, s!"n{i} {tag}: {why}")
    | none =>
      match rng.getD i none, p.maxFinite with
      | some x, some m =>
          if Q.lt m x.mag then some (.domain, s!"n{i} {tag}: overflow {showIv x}") else none
      | none, _ =>
          if known nd then some (.unknown, s!"n{i} {tag}: value not bounded") else none
      | _, _ => none
  -- argument lists and foreign-function signatures are not values
  let isValue : Node → Bool := fun nd =>
    match nd.tag with
    | .cons => false
    | .other "FFUN" => false
    | _ => true
  let found := (List.range dag.size).filterMap fun i =>
    let nd := dag.getD i default
    if tinv.getD i false && isValue nd then check i nd else none
  match found.find? (·.1 == .domain), found.head? with
  | some d, _ => d
  | none, some u => u
  | none, none => (.finite, "")

/-- Table reads and delay taps, with whether their index is in range at one
    rate and in one precision, for every value of the controls in their
    declared range (`rng` from `ranges … true`): a table index in
    `[0, size - 1]`, a delay amount non-negative. A safety property: unlike
    the stability and finite verdicts, which take the controls at their
    default values as `check-precision` does, it must hold for any setting. -/
def siteVerdicts (dag : Dag) (rng : Array (Option Iv)) : List (Nat × Bool) :=
  (List.range dag.size).filterMap fun i =>
    let nd := dag.getD i default
    let val : Arg → Option Iv := fun
      | .ref j => rng.getD j none
      | .int k => some (Iv.ofInt k)
      | _ => none
    match nd.tag, nd.args with
    | .rdtbl, [.ref w, idx] =>
        match (dag.getD w default).tag, (dag.getD w default).args with
        | .wrtbl, .int size :: _ =>
            some (i, match val idx with
              | some x => Q.le Q.zero x.lo && Q.le x.hi (Q.ofInt (size - 1))
              | none => false)
        | _, _ => none
    | .delay, [_, n] =>
        some (i, match val n with
          | some x => Q.le Q.zero x.lo
          | none => false)
    | _, _ => none

/-- Everything the rate analysis says of one program in one precision, at
    each rate of `checkRates`. -/
structure Verdicts where
  groups : List (Nat × List GV)      -- per recursion group
  finite : List FV                   -- per rate
  sites  : List (Nat × List Bool)    -- per table read and delay tap
deriving Repr, DecidableEq

/-- Per rate: the group verdicts, the finite verdict, the site verdicts. -/
def analysis (dag : Dag) (p : Prec) :
    List (List (GV × String) × (FV × String) × List (Nat × Bool)) :=
  let free := freeLevels dag
  let nat := natures dag false
  let natOpt := natures dag true
  let tinv := pures dag
  checkRates.map fun sr =>
    let rng := ranges dag free nat natOpt p sr false
    let rngFull := ranges dag free nat natOpt p sr true
    ((recNodes dag).map fun r => groupVerdict dag free nat natOpt tinv p rng r,
     finiteVerdict dag tinv p rng,
     siteVerdicts dag rngFull)

def transpose {α} (rows : List (List α)) (n : Nat) (d : α) : List (List α) :=
  (List.range n).map fun k => rows.map fun row => row.getD k d

def verdictsOf (dag : Dag)
    (a : List (List (GV × String) × (FV × String) × List (Nat × Bool))) : Verdicts :=
  let recs := recNodes dag
  let sites := ((a.head?.map (·.2.2)).getD []).map (·.1)
  { groups := recs.zip (transpose (a.map fun (g, _, _) => g.map (·.1)) recs.length .refused)
    finite := a.map fun (_, f, _) => f.1
    sites  := sites.zip (transpose (a.map fun (_, _, s) => s.map (·.2)) sites.length false) }

def verdicts (dag : Dag) (p : Prec) : Verdicts := verdictsOf dag (analysis dag p)

/-- Group verdicts only (the step-2 statement, kept for the report). -/
def srVerdicts (dag : Dag) (p : Prec) : List (Nat × List GV) := (verdicts dag p).groups

def GV.letter : GV → String
  | .stable => "S" | .unproven => "U" | .refused => "R"

def FV.letter : FV → String
  | .finite => "F" | .domain => "D" | .unknown => "?"

/-- The probe read by `sig2lean.py` and `certify_tests.py`:
    `n26:SSSSSS;n49:RRRRRR(reason)|FFFFFF(reason)|n30:IIIIII;n41:NNNNNN`. -/
def probe (dag : Dag) (p : Prec) : String :=
  let a := analysis dag p
  let recs := recNodes dag
  let groups := recs.zipIdx.map fun (r, g) =>
    let vs := a.map fun (gs, _, _) => gs.getD g (.refused, "?")
    let why := (vs.map (·.2)).filter (· != "") |>.eraseDups
    s!"n{r}:{String.join (vs.map (·.1.letter))}" ++
      (if why.isEmpty then "" else s!"({String.intercalate ", " why})")
  let fin := a.map fun (_, f, _) => f
  let whyF := (fin.map (·.2)).filter (· != "") |>.eraseDups
  let finS := String.join (fin.map (·.1.letter)) ++
    (if whyF.isEmpty then "" else s!"({String.intercalate "; " whyF})")
  let sites := ((a.head?.map (·.2.2)).getD []).zipIdx.map fun ((i, _), k) =>
    s!"n{i}:" ++ String.join (a.map fun (_, _, ss) =>
      if (ss.getD k (0, false)).2 then "I" else "N")
  String.intercalate ";" groups ++ "|" ++ finS ++ "|" ++ String.intercalate ";" sites

/-- The group part of the probe, as before. -/
def srProbe (dag : Dag) (p : Prec) : String := ((probe dag p).splitOn "|").headD ""

/-! ### Reading a DAG from text

Used by `scripts/certify_tests.py` on the whole test suite, whose largest
graphs (about 10 000 nodes) take a minute to elaborate as a `Dag` literal: the
graph is passed as a string, one node per line,
`tag|arg arg ...|init min max`, with `rJ` a child, `iK` an integer, `qN/D` a
rational, `n` nil and `o` anything else. It feeds `#eval` only: the theorems of
`make certify` are stated on `Dag` literals. -/

def parseQ (s : String) : Option Q :=
  match s.splitOn "/" with
  | [n, d] => do
      let n ← n.toInt?
      let d ← d.toInt?
      if 0 < d then some ⟨n, d⟩ else none
  | _ => none

def parseArg (s : String) : Option Arg :=
  if s == "n" then some .nil else if s == "o" then some .other else
  let rest := (s.drop 1).toString
  match s.front with
  | 'r' => rest.toNat?.map .ref
  | 'i' => rest.toInt?.map .int
  | 'q' => (parseQ rest).map .const
  | _ => none

def parseCmp : String → Option CmpOp
  | "lt" => some .lt | "le" => some .le | "gt" => some .gt
  | "ge" => some .ge | "eq" => some .eq | "ne" => some .ne
  | _ => none

def parseTag (s : String) : Option Tag :=
  match s with
  | "input" => some .input | "delay1" => some .delay1 | "delay" => some .delay
  | "proj" => some .proj | "recur" => some .recur | "ref" => some .ref
  | "cons" => some .cons | "sr" => some .sr | "control" => some .control
  | "button" => some .button | "intcast" => some .intcast
  | "floatcast" => some .floatcast | "min" => some .min | "max" => some .max
  | "abs" => some .abs | "floor" => some .floor | "select2" => some .select2
  | "tan" => some .tan | "sin" => some .sin | "cos" => some .cos
  | "exp" => some .exp | "sqrt" => some .sqrt | "pow" => some .pow
  | "binop:add" => some (.binop .add) | "binop:sub" => some (.binop .sub)
  | "binop:mul" => some (.binop .mul) | "binop:div" => some (.binop .div)
  | "binop:rem" => some (.binop .rem)
  | "round" => some .round | "log" => some .log | "log10" => some .log10
  | "fmod" => some .fmod | "rdtbl" => some .rdtbl | "wrtbl" => some .wrtbl
  | "bit:and" => some (.bit .and) | "bit:or" => some (.bit .or) | "bit:xor" => some (.bit .xor)
  | "bit:lsh" => some (.bit .lsh) | "bit:rsh" => some (.bit .rsh) | "bit:arsh" => some (.bit .arsh)
  | _ =>
      if s.startsWith "cmp:" then (parseCmp (s.drop 4).toString).map .cmp
      else if s.startsWith "other:" then some (.other (s.drop 6).toString)
      else none

def parseNode (line : String) : Option Node :=
  match line.splitOn "|" with
  | [t, args, ctl] => do
      let tag ← parseTag t
      let as ← ((args.splitOn " ").filter (· != "")).mapM parseArg
      let c ← match (ctl.splitOn " ").filter (· != "") with
        | [] => some (Q.zero, Q.zero, Q.zero)
        | [a, b, c] => do pure (← parseQ a, ← parseQ b, ← parseQ c)
        | _ => none
      pure ⟨tag, as, c⟩
  | _ => none

/-- `none` if any line does not parse. -/
def Dag.parse (text : String) : Option Dag :=
  (((text.splitOn "\n").filter (· != "")).mapM parseNode).map List.toArray

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

4. **The math library** (and the digits of `π` in `piLo`, `piHi`). `tan`, `sin`, `cos`, `exp` and `pow` return their
   result within `libmUlps` ulps. This is a property of each platform's libm,
   stated, not proved.

5. **The enclosures.** The Taylor remainders of `sinI`, `cosI`, `expSmall`
   and `logNear1`, the continuity argument of `tanI`, the monotonicity of
   `sqrt`, `log`, truncation and of the rounding widening, the vertex lemma of
   `jury2` (a multilinear function reaches its minimum over a box at a
   vertex), the contraction argument for one time-varying state, the
   weighted max-norm argument of the small-gain test, the
   floating-point facts of `fracRange` and `isPow2`, and the rounding of
   `Q.toFloat32` are stated with their argument next to the code, and
   reviewed as mathematics. They are the next targets of the optional mathlib
   layer, which already proves the Jury criterion.

6. **What is claimed.** The coefficients (the state-free subexpressions) are
   taken as the program computes them; the loop arithmetic that involves the
   state is taken exactly. Its rounding perturbs the state at each sample: an
   accuracy question, bounded by no theorem here. For stability and finite
   values, the controls are at their default values, as in `make
   check-precision`; for indices, anywhere in their declared range. A foreign
   function of `<math.h>` is taken to be pure (no state), which the header
   says, not the dump. -/

end Faust.Signal

/-! # Generated section

Everything below is produced by `scripts/sig2lean.py` from
`faust-rs --dump-sig`. Do not edit by hand. -/

namespace Faust.Signal.Generated
open Faust.Signal

/-- `// fi.allpass_comb, the Schroeder allpass of the reverbs: its recursion is a
// feedback comb with gain -aN. Pins: stable for |aN| < 1, by the small-gain test.
fi = library("filters.lib");
process = fi.allpass_comb(1024, 441, 0.6);` — output 0 -/
def allpass_comb_out0 : Sig :=
  let n0 : Sig := Sig.ref 1
  let n1 : Sig := Sig.proj 0 n0
  let n2 : Sig := Sig.delay1 n1
  let n3 : Sig := Sig.binop .mul n2 (.const ⟨(-5404319552844595), 9007199254740992⟩)
  let n4 : Sig := Sig.input 0
  let n5 : Sig := Sig.binop .add n3 n4
  let n6 : Sig := Sig.opaqueN "SIGMAX" [(.int 0), (.int 440)]
  let n7 : Sig := Sig.opaqueN "SIGMIN" [(.int 1024), n6]
  let n8 : Sig := Sig.delay n5 n7
  let n9 : Sig := Sig.binop .mul n5 (.const ⟨5404319552844595, 9007199254740992⟩)
  let n10 : Sig := Sig.cons n9 (.nil)
  let n11 : Sig := Sig.cons n8 n10
  let n12 : Sig := Sig.recur n11
  let n13 : Sig := Sig.proj 0 n12
  let n14 : Sig := Sig.delay1 n13
  let n15 : Sig := Sig.proj 1 n12
  let n16 : Sig := Sig.binop .add n14 n15
  n16

/-- `// fi.allpass_comb, the Schroeder allpass of the reverbs: its recursion is a
// feedback comb with gain -aN. Pins: stable for |aN| < 1, by the small-gain test.
fi = library("filters.lib");
process = fi.allpass_comb(1024, 441, 0.6);` — the whole graph, for the rate analysis -/
def allpass_comb_dag : Dag := #[
  ⟨.ref, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 2, .const ⟨(-5404319552844595), 9007199254740992⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.input, [.int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 3, .ref 4], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.int 0, .int 440], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.min, [.int 1024, .ref 6], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay, [.ref 5, .ref 7], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 5, .const ⟨5404319552844595, 9007199254740992⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 9, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 8, .ref 10], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 11], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 12], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 13], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 1, .ref 12], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 14, .ref 15], (Q.zero, Q.zero, Q.zero)⟩]

/-- `// ve.bandpass2Matched at the defaults of bandpass2Matched_test, which
// check-precision reports non-finite in single at 176.4 kHz: a per-block
// sqrt of a cancelling expression gets a negative argument in single
// precision. Pins: the finite verdict names that sqrt where it may fail.
ve = library("vaeffects.lib");
process = ve.bandpass2Matched(1200, 2.0);` — output 0 -/
def bandpass2matched_float_out0 : Sig :=
  let n0 : Sig := Sig.opaqueN "SIGFCONST" [(.int 0), (.opaque "fSamplingFreq"), (.opaque "<math.h>")]
  let n1 : Sig := Sig.opaqueN "SIGMAX" [(.const ⟨1, 1⟩), n0]
  let n2 : Sig := Sig.opaqueN "SIGMIN" [(.const ⟨192000, 1⟩), n1]
  let n3 : Sig := Sig.binop .div (.const ⟨1, 1⟩) n2
  let n4 : Sig := Sig.binop .mul (.const ⟨1036265295707291, 137438953472⟩) n3
  let n5 : Sig := Sig.binop .mul (.const ⟨(-1), 4⟩) n4
  let n6 : Sig := Sig.opaqueN "SIGEXP" [n5]
  let n7 : Sig := Sig.binop .mul (.const ⟨(-2), 1⟩) n6
  let n8 : Sig := Sig.cons (.opaque "coshl") (.nil)
  let n9 : Sig := Sig.cons (.opaque "coshl") n8
  let n10 : Sig := Sig.cons (.opaque "cosh") n9
  let n11 : Sig := Sig.cons (.opaque "coshf") n10
  let n12 : Sig := Sig.cons (.int 1) (.nil)
  let n13 : Sig := Sig.cons n11 n12
  let n14 : Sig := Sig.cons (.int 1) n13
  let n15 : Sig := Sig.opaqueN "FFUN" [n14, (.opaque "<math.h>"), (.opaque "\\\"\\\"")]
  let n16 : Sig := Sig.binop .mul (.const ⟨0, 1⟩) n4
  let n17 : Sig := Sig.cons n16 (.nil)
  let n18 : Sig := Sig.opaqueN "SIGFFUN" [n15, n17]
  let n19 : Sig := Sig.binop .mul n7 n18
  let n20 : Sig := Sig.binop .mul (.const ⟨4360591588697965, 4503599627370496⟩) n4
  let n21 : Sig := Sig.opaqueN "SIGCOS" [n20]
  let n22 : Sig := Sig.binop .mul n7 n21
  let n23 : Sig := Sig.opaqueN "SIGSELECT2" [(.const ⟨1, 1⟩), n19, n22]
  let n24 : Sig := Sig.binop .add (.const ⟨1, 1⟩) n23
  let n25 : Sig := Sig.binop .mul (.const ⟨(-1), 2⟩) n4
  let n26 : Sig := Sig.opaqueN "SIGEXP" [n25]
  let n27 : Sig := Sig.binop .add n24 n26
  let n28 : Sig := Sig.opaqueN "SIGPOW" [n27, (.const ⟨2, 1⟩)]
  let n29 : Sig := Sig.binop .mul (.const ⟨1, 2⟩) n4
  let n30 : Sig := Sig.opaqueN "SIGSIN" [n29]
  let n31 : Sig := Sig.opaqueN "SIGPOW" [n30, (.const ⟨2, 1⟩)]
  let n32 : Sig := Sig.binop .sub (.const ⟨1, 1⟩) n31
  let n33 : Sig := Sig.binop .mul n28 n32
  let n34 : Sig := Sig.binop .sub (.const ⟨1, 1⟩) n23
  let n35 : Sig := Sig.binop .add n34 n26
  let n36 : Sig := Sig.opaqueN "SIGPOW" [n35, (.const ⟨2, 1⟩)]
  let n37 : Sig := Sig.binop .mul n36 n31
  let n38 : Sig := Sig.binop .add n33 n37
  let n39 : Sig := Sig.binop .mul (.const ⟨(-4), 1⟩) n26
  let n40 : Sig := Sig.binop .mul (.const ⟨4, 1⟩) n32
  let n41 : Sig := Sig.binop .mul n40 n31
  let n42 : Sig := Sig.binop .mul n39 n41
  let n43 : Sig := Sig.binop .add n38 n42
  let n44 : Sig := Sig.binop .mul (.const ⟨(-1), 1⟩) n28
  let n45 : Sig := Sig.binop .add n44 n36
  let n46 : Sig := Sig.binop .sub n32 n31
  let n47 : Sig := Sig.binop .mul (.const ⟨4, 1⟩) n46
  let n48 : Sig := Sig.binop .mul n47 n39
  let n49 : Sig := Sig.binop .add n45 n48
  let n50 : Sig := Sig.binop .mul n49 n31
  let n51 : Sig := Sig.binop .sub n43 n50
  let n52 : Sig := Sig.binop .mul (.const ⟨4, 1⟩) n31
  let n53 : Sig := Sig.binop .mul n52 n31
  let n54 : Sig := Sig.binop .div n51 n53
  let n55 : Sig := Sig.binop .sub n31 n32
  let n56 : Sig := Sig.binop .mul (.const ⟨4, 1⟩) n55
  let n57 : Sig := Sig.binop .mul n56 n54
  let n58 : Sig := Sig.binop .add n49 n57
  let n59 : Sig := Sig.opaqueN "SIGSQRT" [n58]
  let n60 : Sig := Sig.binop .mul (.const ⟨(-1), 2⟩) n59
  let n61 : Sig := Sig.binop .mul n60 n60
  let n62 : Sig := Sig.binop .add n54 n61
  let n63 : Sig := Sig.opaqueN "SIGSQRT" [n62]
  let n64 : Sig := Sig.binop .sub n63 n60
  let n65 : Sig := Sig.binop .mul (.const ⟨1, 2⟩) n64
  let n66 : Sig := Sig.input 0
  let n67 : Sig := Sig.binop .mul n65 n66
  let n68 : Sig := Sig.delay1 n66
  let n69 : Sig := Sig.binop .mul n60 n68
  let n70 : Sig := Sig.binop .add n67 n69
  let n71 : Sig := Sig.binop .add n65 n60
  let n72 : Sig := Sig.binop .mul (.const ⟨(-1), 1⟩) n71
  let n73 : Sig := Sig.delay1 n68
  let n74 : Sig := Sig.binop .mul n72 n73
  let n75 : Sig := Sig.binop .add n70 n74
  let n76 : Sig := Sig.ref 1
  let n77 : Sig := Sig.proj 0 n76
  let n78 : Sig := Sig.delay1 n77
  let n79 : Sig := Sig.binop .mul n23 n78
  let n80 : Sig := Sig.binop .sub n75 n79
  let n81 : Sig := Sig.delay1 n78
  let n82 : Sig := Sig.binop .mul n26 n81
  let n83 : Sig := Sig.binop .sub n80 n82
  let n84 : Sig := Sig.cons n83 (.nil)
  let n85 : Sig := Sig.recur n84
  let n86 : Sig := Sig.proj 0 n85
  n86

/-- `// ve.bandpass2Matched at the defaults of bandpass2Matched_test, which
// check-precision reports non-finite in single at 176.4 kHz: a per-block
// sqrt of a cancelling expression gets a negative argument in single
// precision. Pins: the finite verdict names that sqrt where it may fail.
ve = library("vaeffects.lib");
process = ve.bandpass2Matched(1200, 2.0);` — the whole graph, for the rate analysis -/
def bandpass2matched_float_dag : Dag := #[
  ⟨.sr, [.int 0, .other, .other], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.const ⟨1, 1⟩, .ref 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.min, [.const ⟨192000, 1⟩, .ref 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.const ⟨1, 1⟩, .ref 2], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.const ⟨1036265295707291, 137438953472⟩, .ref 3], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.const ⟨(-1), 4⟩, .ref 4], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.exp, [.ref 5], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.const ⟨(-2), 1⟩, .ref 6], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.other, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.other, .ref 8], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.other, .ref 9], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.other, .ref 10], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.int 1, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 11, .ref 12], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.int 1, .ref 13], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.other "FFUN", [.ref 14, .other, .other], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.const ⟨0, 1⟩, .ref 4], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 16, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.other "SIGFFUN<math.h>", [.ref 15, .ref 17], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 7, .ref 18], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.const ⟨4360591588697965, 4503599627370496⟩, .ref 4], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cos, [.ref 20], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 7, .ref 21], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.select2, [.const ⟨1, 1⟩, .ref 19, .ref 22], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.const ⟨1, 1⟩, .ref 23], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.const ⟨(-1), 2⟩, .ref 4], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.exp, [.ref 25], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 24, .ref 26], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.pow, [.ref 27, .const ⟨2, 1⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.const ⟨1, 2⟩, .ref 4], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.sin, [.ref 29], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.pow, [.ref 30, .const ⟨2, 1⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.const ⟨1, 1⟩, .ref 31], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 28, .ref 32], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.const ⟨1, 1⟩, .ref 23], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 34, .ref 26], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.pow, [.ref 35, .const ⟨2, 1⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 36, .ref 31], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 33, .ref 37], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.const ⟨(-4), 1⟩, .ref 26], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.const ⟨4, 1⟩, .ref 32], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 40, .ref 31], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 39, .ref 41], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 38, .ref 42], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.const ⟨(-1), 1⟩, .ref 28], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 44, .ref 36], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 32, .ref 31], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.const ⟨4, 1⟩, .ref 46], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 47, .ref 39], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 45, .ref 48], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 49, .ref 31], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 43, .ref 50], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.const ⟨4, 1⟩, .ref 31], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 52, .ref 31], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 51, .ref 53], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 31, .ref 32], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.const ⟨4, 1⟩, .ref 55], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 56, .ref 54], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 49, .ref 57], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.sqrt, [.ref 58], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.const ⟨(-1), 2⟩, .ref 59], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 60, .ref 60], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 54, .ref 61], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.sqrt, [.ref 62], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 63, .ref 60], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.const ⟨1, 2⟩, .ref 64], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.input, [.int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 65, .ref 66], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 66], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 60, .ref 68], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 67, .ref 69], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 65, .ref 60], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.const ⟨(-1), 1⟩, .ref 71], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 68], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 72, .ref 73], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 70, .ref 74], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.ref, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 76], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 77], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 23, .ref 78], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 75, .ref 79], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 78], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 26, .ref 81], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 80, .ref 82], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 83, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 84], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 85], (Q.zero, Q.zero, Q.zero)⟩]

/-- `// fi.bandpass built on fi.tf2sb, trapezoidal state-variable sections since
// #261. Pins the verdict of each section at the six rates.
fi = library("filters.lib");
process = fi.bandpass(1, 500, 2000);` — output 0 -/
def bandpass_tpt_out0 : Sig :=
  let n0 : Sig := Sig.input 0
  let n1 : Sig := Sig.binop .mul n0 (.int 0)
  let n2 : Sig := Sig.ref 1
  let n3 : Sig := Sig.proj 0 n2
  let n4 : Sig := Sig.delay1 n3
  let n5 : Sig := Sig.opaqueN "SIGFCONST" [(.int 0), (.opaque "fSamplingFreq"), (.opaque "<math.h>")]
  let n6 : Sig := Sig.opaqueN "SIGMAX" [(.const ⟨1, 1⟩), n5]
  let n7 : Sig := Sig.opaqueN "SIGMIN" [(.const ⟨192000, 1⟩), n6]
  let n8 : Sig := Sig.binop .mul (.const ⟨2, 1⟩) n7
  let n9 : Sig := Sig.binop .div (.const ⟨6908435304715273, 2199023255552⟩) n8
  let n10 : Sig := Sig.opaqueN "SIGTAN" [n9]
  let n11 : Sig := Sig.binop .mul n8 n10
  let n12 : Sig := Sig.binop .div (.const ⟨6908435304715273, 549755813888⟩) n8
  let n13 : Sig := Sig.opaqueN "SIGTAN" [n12]
  let n14 : Sig := Sig.binop .mul n8 n13
  let n15 : Sig := Sig.binop .mul n11 n14
  let n16 : Sig := Sig.opaqueN "SIGSQRT" [n15]
  let n17 : Sig := Sig.binop .mul n16 (.const ⟨1, 2⟩)
  let n18 : Sig := Sig.binop .div n17 n7
  let n19 : Sig := Sig.proj 1 n2
  let n20 : Sig := Sig.delay1 n19
  let n21 : Sig := Sig.binop .sub n0 n20
  let n22 : Sig := Sig.binop .mul n18 n21
  let n23 : Sig := Sig.binop .add n4 n22
  let n24 : Sig := Sig.opaqueN "SIGPOW" [n16, (.int 2)]
  let n25 : Sig := Sig.binop .div n24 n14
  let n26 : Sig := Sig.binop .sub n14 n25
  let n27 : Sig := Sig.binop .mul (.int 1) n26
  let n28 : Sig := Sig.binop .div n27 n16
  let n29 : Sig := Sig.binop .add n18 n28
  let n30 : Sig := Sig.binop .mul n18 n29
  let n31 : Sig := Sig.binop .add (.int 1) n30
  let n32 : Sig := Sig.binop .div n23 n31
  let n33 : Sig := Sig.binop .mul (.int 2) n32
  let n34 : Sig := Sig.binop .sub n33 n4
  let n35 : Sig := Sig.binop .mul n18 n32
  let n36 : Sig := Sig.binop .add n20 n35
  let n37 : Sig := Sig.binop .mul (.int 2) n36
  let n38 : Sig := Sig.binop .sub n37 n20
  let n39 : Sig := Sig.binop .mul n28 n32
  let n40 : Sig := Sig.binop .sub n0 n39
  let n41 : Sig := Sig.binop .sub n40 n36
  let n42 : Sig := Sig.cons n41 (.nil)
  let n43 : Sig := Sig.cons n32 n42
  let n44 : Sig := Sig.cons n36 n43
  let n45 : Sig := Sig.cons n38 n44
  let n46 : Sig := Sig.cons n34 n45
  let n47 : Sig := Sig.recur n46
  let n48 : Sig := Sig.proj 3 n47
  let n49 : Sig := Sig.binop .mul n48 n28
  let n50 : Sig := Sig.binop .add n1 n49
  n50

/-- `// fi.bandpass built on fi.tf2sb, trapezoidal state-variable sections since
// #261. Pins the verdict of each section at the six rates.
fi = library("filters.lib");
process = fi.bandpass(1, 500, 2000);` — the whole graph, for the rate analysis -/
def bandpass_tpt_dag : Dag := #[
  ⟨.input, [.int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 0, .int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.ref, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 2], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 3], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.sr, [.int 0, .other, .other], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.const ⟨1, 1⟩, .ref 5], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.min, [.const ⟨192000, 1⟩, .ref 6], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.const ⟨2, 1⟩, .ref 7], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.const ⟨6908435304715273, 2199023255552⟩, .ref 8], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.tan, [.ref 9], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 8, .ref 10], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.const ⟨6908435304715273, 549755813888⟩, .ref 8], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.tan, [.ref 12], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 8, .ref 13], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 11, .ref 14], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.sqrt, [.ref 15], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 16, .const ⟨1, 2⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 17, .ref 7], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 1, .ref 2], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 19], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 0, .ref 20], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 18, .ref 21], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 4, .ref 22], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.pow, [.ref 16, .int 2], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 24, .ref 14], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 14, .ref 25], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 1, .ref 26], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 27, .ref 16], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 18, .ref 28], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 18, .ref 29], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.int 1, .ref 30], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 23, .ref 31], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 2, .ref 32], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 33, .ref 4], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 18, .ref 32], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 20, .ref 35], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 2, .ref 36], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 37, .ref 20], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 28, .ref 32], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 0, .ref 39], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 40, .ref 36], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 41, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 32, .ref 42], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 36, .ref 43], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 38, .ref 44], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 34, .ref 45], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 46], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 3, .ref 47], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 48, .ref 28], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 1, .ref 49], (Q.zero, Q.zero, Q.zero)⟩]

/-- `// fi.dcblocker = zero(1) : pole(0.995) — a classic constant-coefficient
// one-pole from filters.lib. Pins: STABLE through the zero/pole composition.
fi = library("filters.lib");
process = fi.dcblocker;` — output 0 -/
def dcblocker_out0 : Sig :=
  let n0 : Sig := Sig.ref 1
  let n1 : Sig := Sig.proj 0 n0
  let n2 : Sig := Sig.delay1 n1
  let n3 : Sig := Sig.binop .mul n2 (.const ⟨8962163258467287, 9007199254740992⟩)
  let n4 : Sig := Sig.input 0
  let n5 : Sig := Sig.delay1 n4
  let n6 : Sig := Sig.binop .mul n5 (.int 1)
  let n7 : Sig := Sig.binop .sub n4 n6
  let n8 : Sig := Sig.binop .add n3 n7
  let n9 : Sig := Sig.cons n8 (.nil)
  let n10 : Sig := Sig.recur n9
  let n11 : Sig := Sig.proj 0 n10
  n11

/-- `// fi.dcblocker = zero(1) : pole(0.995) — a classic constant-coefficient
// one-pole from filters.lib. Pins: STABLE through the zero/pole composition.
fi = library("filters.lib");
process = fi.dcblocker;` — the whole graph, for the rate analysis -/
def dcblocker_dag : Dag := #[
  ⟨.ref, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 2, .const ⟨8962163258467287, 9007199254740992⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.input, [.int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 4], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 5, .int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 4, .ref 6], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 3, .ref 7], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 8, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 9], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 10], (Q.zero, Q.zero, Q.zero)⟩]

/-- `// A delay set in seconds, de.delay(ma.SR, 0.25*ma.SR): the tap is computed
// from the sample rate in each precision. Pins: non-negative at every rate.
de = library("delays.lib");
ma = library("maths.lib");
process = de.delay(ma.SR, 0.25*ma.SR);` — output 0 -/
def delay_sr_out0 : Sig :=
  let n0 : Sig := Sig.input 0
  let n1 : Sig := Sig.opaqueN "SIGFCONST" [(.int 0), (.opaque "fSamplingFreq"), (.opaque "<math.h>")]
  let n2 : Sig := Sig.opaqueN "SIGMAX" [(.const ⟨1, 1⟩), n1]
  let n3 : Sig := Sig.opaqueN "SIGMIN" [(.const ⟨192000, 1⟩), n2]
  let n4 : Sig := Sig.binop .mul (.const ⟨1, 4⟩) n3
  let n5 : Sig := Sig.opaqueN "SIGMAX" [(.int 0), n4]
  let n6 : Sig := Sig.opaqueN "SIGMIN" [n3, n5]
  let n7 : Sig := Sig.delay n0 n6
  n7

/-- `// A delay set in seconds, de.delay(ma.SR, 0.25*ma.SR): the tap is computed
// from the sample rate in each precision. Pins: non-negative at every rate.
de = library("delays.lib");
ma = library("maths.lib");
process = de.delay(ma.SR, 0.25*ma.SR);` — the whole graph, for the rate analysis -/
def delay_sr_dag : Dag := #[
  ⟨.input, [.int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.sr, [.int 0, .other, .other], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.const ⟨1, 1⟩, .ref 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.min, [.const ⟨192000, 1⟩, .ref 2], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.const ⟨1, 4⟩, .ref 3], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.int 0, .ref 4], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.min, [.ref 3, .ref 5], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay, [.ref 0, .ref 6], (Q.zero, Q.zero, Q.zero)⟩]

/-- `// fi.fb_comb: y[n] = x[n] - aN*y[n-441], a feedback comb with 441 samples of
// state. Jury does not read it (more than 2 states); the small-gain test
// does: stable when |aN| < 1, whatever the delay. Pins: stable, and
// fb_comb_unstable.dsp is not.
fi = library("filters.lib");
process = fi.fb_comb(1024, 441, 1, 0.7);` — output 0 -/
def fb_comb_out0 : Sig :=
  let n0 : Sig := Sig.ref 1
  let n1 : Sig := Sig.proj 0 n0
  let n2 : Sig := Sig.delay1 n1
  let n3 : Sig := Sig.opaqueN "SIGMAX" [(.int 0), (.int 440)]
  let n4 : Sig := Sig.opaqueN "SIGMIN" [(.int 1024), n3]
  let n5 : Sig := Sig.delay n2 n4
  let n6 : Sig := Sig.binop .mul (.const ⟨(-3152519739159347), 4503599627370496⟩) n5
  let n7 : Sig := Sig.input 0
  let n8 : Sig := Sig.binop .add n6 n7
  let n9 : Sig := Sig.cons n8 (.nil)
  let n10 : Sig := Sig.recur n9
  let n11 : Sig := Sig.proj 0 n10
  let n12 : Sig := Sig.binop .mul n11 (.int 1)
  let n13 : Sig := Sig.delay1 n12
  n13

/-- `// fi.fb_comb: y[n] = x[n] - aN*y[n-441], a feedback comb with 441 samples of
// state. Jury does not read it (more than 2 states); the small-gain test
// does: stable when |aN| < 1, whatever the delay. Pins: stable, and
// fb_comb_unstable.dsp is not.
fi = library("filters.lib");
process = fi.fb_comb(1024, 441, 1, 0.7);` — the whole graph, for the rate analysis -/
def fb_comb_dag : Dag := #[
  ⟨.ref, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.int 0, .int 440], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.min, [.int 1024, .ref 3], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay, [.ref 2, .ref 4], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.const ⟨(-3152519739159347), 4503599627370496⟩, .ref 5], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.input, [.int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 6, .ref 7], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 8, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 9], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 10], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 11, .int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 12], (Q.zero, Q.zero, Q.zero)⟩]

/-- `// fi.fb_comb with |aN| = 1.1: its poles lie outside the unit circle. Pins:
// not proven stable (the small-gain test cannot conclude, as it must not).
fi = library("filters.lib");
process = fi.fb_comb(1024, 441, 1, 1.1);` — output 0 -/
def fb_comb_unstable_out0 : Sig :=
  let n0 : Sig := Sig.ref 1
  let n1 : Sig := Sig.proj 0 n0
  let n2 : Sig := Sig.delay1 n1
  let n3 : Sig := Sig.opaqueN "SIGMAX" [(.int 0), (.int 440)]
  let n4 : Sig := Sig.opaqueN "SIGMIN" [(.int 1024), n3]
  let n5 : Sig := Sig.delay n2 n4
  let n6 : Sig := Sig.binop .mul (.const ⟨(-2476979795053773), 2251799813685248⟩) n5
  let n7 : Sig := Sig.input 0
  let n8 : Sig := Sig.binop .add n6 n7
  let n9 : Sig := Sig.cons n8 (.nil)
  let n10 : Sig := Sig.recur n9
  let n11 : Sig := Sig.proj 0 n10
  let n12 : Sig := Sig.binop .mul n11 (.int 1)
  let n13 : Sig := Sig.delay1 n12
  n13

/-- `// fi.fb_comb with |aN| = 1.1: its poles lie outside the unit circle. Pins:
// not proven stable (the small-gain test cannot conclude, as it must not).
fi = library("filters.lib");
process = fi.fb_comb(1024, 441, 1, 1.1);` — the whole graph, for the rate analysis -/
def fb_comb_unstable_dag : Dag := #[
  ⟨.ref, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.int 0, .int 440], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.min, [.int 1024, .ref 3], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay, [.ref 2, .ref 4], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.const ⟨(-2476979795053773), 2251799813685248⟩, .ref 5], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.input, [.int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 6, .ref 7], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 8, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 9], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 10], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 11, .int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 12], (Q.zero, Q.zero, Q.zero)⟩]

/-- `// fi.fb_fcomb, a feedback comb with a fractional delay: two taps weighted by
// the interpolation, whose absolute values sum to |aN|. Pins: stable.
fi = library("filters.lib");
process = fi.fb_fcomb(1024, 441.5, 1, 0.7);` — output 0 -/
def fb_fcomb_out0 : Sig :=
  let n0 : Sig := Sig.ref 1
  let n1 : Sig := Sig.proj 0 n0
  let n2 : Sig := Sig.delay1 n1
  let n3 : Sig := Sig.opaqueN "SIGMAX" [(.int 0), (.int 440)]
  let n4 : Sig := Sig.opaqueN "SIGMIN" [(.int 1025), n3]
  let n5 : Sig := Sig.delay n2 n4
  let n6 : Sig := Sig.opaqueN "SIGFLOOR" [(.const ⟨881, 2⟩)]
  let n7 : Sig := Sig.binop .sub (.const ⟨881, 2⟩) n6
  let n8 : Sig := Sig.binop .sub (.int 1) n7
  let n9 : Sig := Sig.binop .mul n5 n8
  let n10 : Sig := Sig.opaqueN "SIGMAX" [(.int 0), (.int 441)]
  let n11 : Sig := Sig.opaqueN "SIGMIN" [(.int 1025), n10]
  let n12 : Sig := Sig.delay n2 n11
  let n13 : Sig := Sig.binop .mul n12 n7
  let n14 : Sig := Sig.binop .add n9 n13
  let n15 : Sig := Sig.binop .mul (.const ⟨(-3152519739159347), 4503599627370496⟩) n14
  let n16 : Sig := Sig.input 0
  let n17 : Sig := Sig.binop .add n15 n16
  let n18 : Sig := Sig.cons n17 (.nil)
  let n19 : Sig := Sig.recur n18
  let n20 : Sig := Sig.proj 0 n19
  let n21 : Sig := Sig.binop .mul n20 (.int 1)
  let n22 : Sig := Sig.delay1 n21
  n22

/-- `// fi.fb_fcomb, a feedback comb with a fractional delay: two taps weighted by
// the interpolation, whose absolute values sum to |aN|. Pins: stable.
fi = library("filters.lib");
process = fi.fb_fcomb(1024, 441.5, 1, 0.7);` — the whole graph, for the rate analysis -/
def fb_fcomb_dag : Dag := #[
  ⟨.ref, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.int 0, .int 440], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.min, [.int 1025, .ref 3], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay, [.ref 2, .ref 4], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.floor, [.const ⟨881, 2⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.const ⟨881, 2⟩, .ref 6], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.int 1, .ref 7], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 5, .ref 8], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.int 0, .int 441], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.min, [.int 1025, .ref 10], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay, [.ref 2, .ref 11], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 12, .ref 7], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 9, .ref 13], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.const ⟨(-3152519739159347), 4503599627370496⟩, .ref 14], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.input, [.int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 15, .ref 16], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 17, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 18], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 19], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 20, .int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 21], (Q.zero, Q.zero, Q.zero)⟩]

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

/-- `de = library("delays.lib");
process = de.fdelay(1024, hslider("d", 100, 0, 2000, 1));` — the whole graph, for the rate analysis -/
def fdelay_clamped_dag : Dag := #[
  ⟨.input, [.int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.control, [.int 0], (⟨100, 1⟩, ⟨0, 1⟩, ⟨2000, 1⟩)⟩,
  ⟨.intcast, [.ref 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.int 0, .ref 2], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.min, [.int 1025, .ref 3], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay, [.ref 0, .ref 4], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.floor, [.ref 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 1, .ref 6], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.int 1, .ref 7], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 5, .ref 8], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 2, .int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.int 0, .ref 10], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.min, [.int 1025, .ref 11], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay, [.ref 0, .ref 12], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 13, .ref 7], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 9, .ref 14], (Q.zero, Q.zero, Q.zero)⟩]

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
  let n28 : Sig := Sig.binop .mul (.int 0) n27
  let n29 : Sig := Sig.proj 1 n0
  let n30 : Sig := Sig.delay1 n29
  let n31 : Sig := Sig.binop .sub n27 n30
  let n32 : Sig := Sig.binop .mul n7 n31
  let n33 : Sig := Sig.binop .add n2 n32
  let n34 : Sig := Sig.binop .add n7 (.const ⟨2251799813685249, 2251799813685248⟩)
  let n35 : Sig := Sig.binop .mul n7 n34
  let n36 : Sig := Sig.binop .add (.int 1) n35
  let n37 : Sig := Sig.binop .div n33 n36
  let n38 : Sig := Sig.binop .mul (.int 2) n37
  let n39 : Sig := Sig.binop .sub n38 n2
  let n40 : Sig := Sig.binop .mul n7 n37
  let n41 : Sig := Sig.binop .add n30 n40
  let n42 : Sig := Sig.binop .mul (.int 2) n41
  let n43 : Sig := Sig.binop .sub n42 n30
  let n44 : Sig := Sig.cons n41 (.nil)
  let n45 : Sig := Sig.cons n37 n44
  let n46 : Sig := Sig.cons n27 n45
  let n47 : Sig := Sig.cons n43 n46
  let n48 : Sig := Sig.cons n39 n47
  let n49 : Sig := Sig.recur n48
  let n50 : Sig := Sig.proj 3 n49
  let n51 : Sig := Sig.binop .mul (.int 0) n50
  let n52 : Sig := Sig.binop .add n28 n51
  let n53 : Sig := Sig.proj 4 n49
  let n54 : Sig := Sig.binop .mul (.int 1) n53
  let n55 : Sig := Sig.binop .add n52 n54
  n55

/-- `import("stdfaust.lib");
process = fi.lowpass(3, 1000);` — the whole graph, for the rate analysis -/
def lowpass3_dag : Dag := #[
  ⟨.ref, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.sr, [.int 0, .other, .other], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.const ⟨1, 1⟩, .ref 3], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.min, [.const ⟨192000, 1⟩, .ref 4], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.const ⟨6908435304715273, 2199023255552⟩, .ref 5], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.tan, [.ref 6], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.int 1, .ref 7], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.int 1, .ref 8], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.int 1, .ref 8], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 9, .ref 10], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.int 0, .ref 11], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 2, .ref 12], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.input, [.int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 0, .ref 8], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.int 1, .ref 15], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 16, .ref 10], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 14, .ref 17], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 14], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.int 1, .ref 15], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 20, .ref 10], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 19, .ref 21], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 18, .ref 22], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 13, .ref 23], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 24, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 25], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 26], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 0, .ref 27], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 1, .ref 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 29], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 27, .ref 30], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 7, .ref 31], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 2, .ref 32], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 7, .const ⟨2251799813685249, 2251799813685248⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 7, .ref 34], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.int 1, .ref 35], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 33, .ref 36], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 2, .ref 37], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 38, .ref 2], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 7, .ref 37], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 30, .ref 40], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 2, .ref 41], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 42, .ref 30], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 41, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 37, .ref 44], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 27, .ref 45], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 43, .ref 46], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 39, .ref 47], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 48], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 3, .ref 49], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 0, .ref 50], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 28, .ref 51], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 4, .ref 49], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 1, .ref 53], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 52, .ref 54], (Q.zero, Q.zero, Q.zero)⟩]

/-- `// fi.lowpass at 20 Hz: second-order sections in state-variable form since
// #262, accurate in float at low cutoffs. Pins: stable at the six rates of
// check-precision in exact, double and single arithmetic.
fi = library("filters.lib");
process = fi.lowpass(2, 20);` — output 0 -/
def lowpass_svf_20hz_out0 : Sig :=
  let n0 : Sig := Sig.input 0
  let n1 : Sig := Sig.binop .mul (.int 0) n0
  let n2 : Sig := Sig.ref 1
  let n3 : Sig := Sig.proj 0 n2
  let n4 : Sig := Sig.delay1 n3
  let n5 : Sig := Sig.opaqueN "SIGFCONST" [(.int 0), (.opaque "fSamplingFreq"), (.opaque "<math.h>")]
  let n6 : Sig := Sig.opaqueN "SIGMAX" [(.const ⟨1, 1⟩), n5]
  let n7 : Sig := Sig.opaqueN "SIGMIN" [(.const ⟨192000, 1⟩), n6]
  let n8 : Sig := Sig.binop .div (.const ⟨4421398595017775, 70368744177664⟩) n7
  let n9 : Sig := Sig.opaqueN "SIGTAN" [n8]
  let n10 : Sig := Sig.proj 1 n2
  let n11 : Sig := Sig.delay1 n10
  let n12 : Sig := Sig.binop .sub n0 n11
  let n13 : Sig := Sig.binop .mul n9 n12
  let n14 : Sig := Sig.binop .add n4 n13
  let n15 : Sig := Sig.binop .add n9 (.const ⟨1592262918131443, 1125899906842624⟩)
  let n16 : Sig := Sig.binop .mul n9 n15
  let n17 : Sig := Sig.binop .add (.int 1) n16
  let n18 : Sig := Sig.binop .div n14 n17
  let n19 : Sig := Sig.binop .mul (.int 2) n18
  let n20 : Sig := Sig.binop .sub n19 n4
  let n21 : Sig := Sig.binop .mul n9 n18
  let n22 : Sig := Sig.binop .add n11 n21
  let n23 : Sig := Sig.binop .mul (.int 2) n22
  let n24 : Sig := Sig.binop .sub n23 n11
  let n25 : Sig := Sig.cons n22 (.nil)
  let n26 : Sig := Sig.cons n18 n25
  let n27 : Sig := Sig.cons n0 n26
  let n28 : Sig := Sig.cons n24 n27
  let n29 : Sig := Sig.cons n20 n28
  let n30 : Sig := Sig.recur n29
  let n31 : Sig := Sig.proj 3 n30
  let n32 : Sig := Sig.binop .mul (.int 0) n31
  let n33 : Sig := Sig.binop .add n1 n32
  let n34 : Sig := Sig.proj 4 n30
  let n35 : Sig := Sig.binop .mul (.int 1) n34
  let n36 : Sig := Sig.binop .add n33 n35
  n36

/-- `// fi.lowpass at 20 Hz: second-order sections in state-variable form since
// #262, accurate in float at low cutoffs. Pins: stable at the six rates of
// check-precision in exact, double and single arithmetic.
fi = library("filters.lib");
process = fi.lowpass(2, 20);` — the whole graph, for the rate analysis -/
def lowpass_svf_20hz_dag : Dag := #[
  ⟨.input, [.int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 0, .ref 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.ref, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 2], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 3], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.sr, [.int 0, .other, .other], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.const ⟨1, 1⟩, .ref 5], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.min, [.const ⟨192000, 1⟩, .ref 6], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.const ⟨4421398595017775, 70368744177664⟩, .ref 7], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.tan, [.ref 8], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 1, .ref 2], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 10], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 0, .ref 11], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 9, .ref 12], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 4, .ref 13], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 9, .const ⟨1592262918131443, 1125899906842624⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 9, .ref 15], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.int 1, .ref 16], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 14, .ref 17], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 2, .ref 18], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 19, .ref 4], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 9, .ref 18], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 11, .ref 21], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 2, .ref 22], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 23, .ref 11], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 22, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 18, .ref 25], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 0, .ref 26], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 24, .ref 27], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 20, .ref 28], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 29], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 3, .ref 30], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 0, .ref 31], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 1, .ref 32], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 4, .ref 30], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 1, .ref 34], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 33, .ref 35], (Q.zero, Q.zero, Q.zero)⟩]

/-- `// A delay modulated at every sample inside a feedback loop, as in a
// flanger: y = x + 0.5*y[n - d(n)] with d(n) between 100 and 300 samples.
// Jury cannot read a variable delay; the small-gain test only needs
// d >= 1. Pins: stable. (With de.fdelay, the two interpolation weights
// (1-f) and f are bounded separately, their sum by 2: not proven.)
de = library("delays.lib");
os = library("oscillators.lib");
process = (+ : de.delay(1024, int(200 + 100*os.osc(0.5)))) ~ *(0.5);` — output 0 -/
def modulated_delay_loop_out0 : Sig :=
  let n0 : Sig := Sig.ref 1
  let n1 : Sig := Sig.proj 0 n0
  let n2 : Sig := Sig.delay1 n1
  let n3 : Sig := Sig.binop .mul n2 (.const ⟨1, 2⟩)
  let n4 : Sig := Sig.input 0
  let n5 : Sig := Sig.binop .add n3 n4
  let n6 : Sig := Sig.delay1 (.int 1)
  let n7 : Sig := Sig.binop .add n2 n6
  let n8 : Sig := Sig.binop .rem n7 (.int 65536)
  let n9 : Sig := Sig.cons n8 (.nil)
  let n10 : Sig := Sig.recur n9
  let n11 : Sig := Sig.proj 0 n10
  let n12 : Sig := Sig.opaqueN "SIGFLOATCAST" [n11]
  let n13 : Sig := Sig.binop .mul n12 (.const ⟨884279719003555, 140737488355328⟩)
  let n14 : Sig := Sig.binop .div n13 (.int 65536)
  let n15 : Sig := Sig.opaqueN "SIGSIN" [n14]
  let n16 : Sig := Sig.opaqueN "SIGGEN" [n15]
  let n17 : Sig := Sig.opaqueN "SIGWRTBL" [(.int 65536), n16, (.nil), (.nil)]
  let n18 : Sig := Sig.binop .sub (.int 1) n6
  let n19 : Sig := Sig.opaqueN "SIGBINOP:or" [n18, (.int 0)]
  let n20 : Sig := Sig.opaqueN "SIGFCONST" [(.int 0), (.opaque "fSamplingFreq"), (.opaque "<math.h>")]
  let n21 : Sig := Sig.opaqueN "SIGMAX" [(.const ⟨1, 1⟩), n20]
  let n22 : Sig := Sig.opaqueN "SIGMIN" [(.const ⟨192000, 1⟩), n21]
  let n23 : Sig := Sig.binop .div (.const ⟨1, 2⟩) n22
  let n24 : Sig := Sig.binop .add n2 n23
  let n25 : Sig := Sig.opaqueN "SIGSELECT2" [n19, n24, (.int 0)]
  let n26 : Sig := Sig.opaqueN "SIGFLOOR" [n25]
  let n27 : Sig := Sig.binop .sub n25 n26
  let n28 : Sig := Sig.cons n27 (.nil)
  let n29 : Sig := Sig.recur n28
  let n30 : Sig := Sig.proj 0 n29
  let n31 : Sig := Sig.binop .mul n30 (.int 65536)
  let n32 : Sig := Sig.opaqueN "SIGINTCAST" [n31]
  let n33 : Sig := Sig.opaqueN "SIGRDTBL" [n17, n32]
  let n34 : Sig := Sig.binop .mul (.int 100) n33
  let n35 : Sig := Sig.binop .add (.int 200) n34
  let n36 : Sig := Sig.opaqueN "SIGINTCAST" [n35]
  let n37 : Sig := Sig.opaqueN "SIGMAX" [(.int 0), n36]
  let n38 : Sig := Sig.opaqueN "SIGMIN" [(.int 1024), n37]
  let n39 : Sig := Sig.delay n5 n38
  let n40 : Sig := Sig.cons n39 (.nil)
  let n41 : Sig := Sig.recur n40
  let n42 : Sig := Sig.proj 0 n41
  n42

/-- `// A delay modulated at every sample inside a feedback loop, as in a
// flanger: y = x + 0.5*y[n - d(n)] with d(n) between 100 and 300 samples.
// Jury cannot read a variable delay; the small-gain test only needs
// d >= 1. Pins: stable. (With de.fdelay, the two interpolation weights
// (1-f) and f are bounded separately, their sum by 2: not proven.)
de = library("delays.lib");
os = library("oscillators.lib");
process = (+ : de.delay(1024, int(200 + 100*os.osc(0.5)))) ~ *(0.5);` — the whole graph, for the rate analysis -/
def modulated_delay_loop_dag : Dag := #[
  ⟨.ref, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 2, .const ⟨1, 2⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.input, [.int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 3, .ref 4], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 2, .ref 6], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .rem, [.ref 7, .int 65536], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 8, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 9], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 10], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.floatcast, [.ref 11], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 12, .const ⟨884279719003555, 140737488355328⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 13, .int 65536], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.sin, [.ref 14], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.other "SIGGEN", [.ref 15], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.wrtbl, [.int 65536, .ref 16, .nil, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.int 1, .ref 6], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.bit .or, [.ref 18, .int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.sr, [.int 0, .other, .other], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.const ⟨1, 1⟩, .ref 20], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.min, [.const ⟨192000, 1⟩, .ref 21], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.const ⟨1, 2⟩, .ref 22], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 2, .ref 23], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.select2, [.ref 19, .ref 24, .int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.floor, [.ref 25], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 25, .ref 26], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 27, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 28], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 29], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 30, .int 65536], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.intcast, [.ref 31], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.rdtbl, [.ref 17, .ref 32], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 100, .ref 33], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.int 200, .ref 34], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.intcast, [.ref 35], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.int 0, .ref 36], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.min, [.int 1024, .ref 37], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay, [.ref 5, .ref 38], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 39, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 40], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 41], (Q.zero, Q.zero, Q.zero)⟩]

/-- `// no.noise — the LCG recursion x = 1103515245*x' + 12345 at the heart of
// noises.lib. The generator is only bounded by wrapping int32 semantics,
// which the certified fragment deliberately does not model: the recursion
// is refused ("not recognised"), and that refusal is what this fixture
// pins — if the analysers ever start reading int recursions, the verdict
// flip will surface here.
no = library("noises.lib");
process = no.noise;` — output 0 -/
def noise_lcg_out0 : Sig :=
  let n0 : Sig := Sig.ref 1
  let n1 : Sig := Sig.proj 0 n0
  let n2 : Sig := Sig.delay1 n1
  let n3 : Sig := Sig.binop .mul n2 (.int 1103515245)
  let n4 : Sig := Sig.binop .add n3 (.int 12345)
  let n5 : Sig := Sig.cons n4 (.nil)
  let n6 : Sig := Sig.recur n5
  let n7 : Sig := Sig.proj 0 n6
  let n8 : Sig := Sig.binop .div n7 (.const ⟨2147483647, 1⟩)
  n8

/-- `// no.noise — the LCG recursion x = 1103515245*x' + 12345 at the heart of
// noises.lib. The generator is only bounded by wrapping int32 semantics,
// which the certified fragment deliberately does not model: the recursion
// is refused ("not recognised"), and that refusal is what this fixture
// pins — if the analysers ever start reading int recursions, the verdict
// flip will surface here.
no = library("noises.lib");
process = no.noise;` — the whole graph, for the rate analysis -/
def noise_lcg_dag : Dag := #[
  ⟨.ref, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 2, .int 1103515245], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 3, .int 12345], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 4, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 5], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 6], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 7, .const ⟨2147483647, 1⟩], (Q.zero, Q.zero, Q.zero)⟩]

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

/-- `import("maths.lib");
process = + ~ (*(0.9) : ma.tanh);` — the whole graph, for the rate analysis -/
def nonlinear_dag : Dag := #[
  ⟨.cons, [.other, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.other, .ref 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.other, .ref 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.other, .ref 2], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.int 1, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 3, .ref 4], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.int 1, .ref 5], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.other "FFUN", [.ref 6, .other, .other], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.ref, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 8], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 9], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 10, .const ⟨8106479329266893, 9007199254740992⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 11, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.other "SIGFFUN<math.h>", [.ref 7, .ref 12], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.input, [.int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 13, .ref 14], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 15, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 16], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 17], (Q.zero, Q.zero, Q.zero)⟩]

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

/-- `process = *(0.5) : (+ ~ *(0.7));` — the whole graph, for the rate analysis -/
def onepole_dag : Dag := #[
  ⟨.ref, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 2, .const ⟨3152519739159347, 4503599627370496⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.input, [.int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 4, .const ⟨1, 2⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 3, .ref 5], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 6, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 7], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 8], (Q.zero, Q.zero, Q.zero)⟩]

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

/-- `os = library("oscillators.lib");
process = os.osc(440);` — the whole graph, for the rate analysis -/
def osc_dag : Dag := #[
  ⟨.ref, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 2, .ref 3], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .rem, [.ref 4, .int 65536], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 5, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 6], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 7], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.floatcast, [.ref 8], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 9, .const ⟨884279719003555, 140737488355328⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 10, .const ⟨65536, 1⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.sin, [.ref 11], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.other "SIGGEN", [.ref 12], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.wrtbl, [.int 65536, .ref 13, .nil, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.int 1, .ref 3], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.bit .or, [.ref 15, .int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.sr, [.int 0, .other, .other], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.const ⟨1, 1⟩, .ref 17], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.min, [.const ⟨192000, 1⟩, .ref 18], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.int 440, .ref 19], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 2, .ref 20], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.select2, [.ref 16, .ref 21, .int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.floor, [.ref 22], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 22, .ref 23], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 24, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 25], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 26], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 27, .const ⟨65536, 1⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.intcast, [.ref 28], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.rdtbl, [.ref 14, .ref 29], (Q.zero, Q.zero, Q.zero)⟩]

/-- `// os.osc at a negative frequency: the phase x - floor(x) of a slightly
// negative x rounds to 1.0 in floating point (frac(-1e-9) = 1.0 in single),
// which puts the 65536-entry table index one past the end. Pins: the table
// read is proven in range for os.osc(440) (osc.dsp) in double and single,
// not here.
os = library("oscillators.lib");
process = os.osc(-440);` — output 0 -/
def osc_negative_freq_out0 : Sig :=
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
  let n20 : Sig := Sig.binop .div (.int (-440)) n19
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

/-- `// os.osc at a negative frequency: the phase x - floor(x) of a slightly
// negative x rounds to 1.0 in floating point (frac(-1e-9) = 1.0 in single),
// which puts the 65536-entry table index one past the end. Pins: the table
// read is proven in range for os.osc(440) (osc.dsp) in double and single,
// not here.
os = library("oscillators.lib");
process = os.osc(-440);` — the whole graph, for the rate analysis -/
def osc_negative_freq_dag : Dag := #[
  ⟨.ref, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 2, .ref 3], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .rem, [.ref 4, .int 65536], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 5, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 6], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 7], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.floatcast, [.ref 8], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 9, .const ⟨884279719003555, 140737488355328⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 10, .const ⟨65536, 1⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.sin, [.ref 11], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.other "SIGGEN", [.ref 12], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.wrtbl, [.int 65536, .ref 13, .nil, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.int 1, .ref 3], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.bit .or, [.ref 15, .int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.sr, [.int 0, .other, .other], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.const ⟨1, 1⟩, .ref 17], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.min, [.const ⟨192000, 1⟩, .ref 18], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.int (-440), .ref 19], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 2, .ref 20], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.select2, [.ref 16, .ref 21, .int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.floor, [.ref 22], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 22, .ref 23], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 24, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 25], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 26], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 27, .const ⟨65536, 1⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.intcast, [.ref 28], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.rdtbl, [.ref 14, .ref 29], (Q.zero, Q.zero, Q.zero)⟩]

/-- `// fi.resonlp, a direct-form fi.tf2s section used by filter banks and
// vocoders. Pins the verdict at the six rates.
fi = library("filters.lib");
process = fi.resonlp(1000, 2, 0.8);` — output 0 -/
def resonlp_out0 : Sig :=
  let n0 : Sig := Sig.input 0
  let n1 : Sig := Sig.ref 1
  let n2 : Sig := Sig.proj 0 n1
  let n3 : Sig := Sig.delay1 n2
  let n4 : Sig := Sig.opaqueN "SIGFCONST" [(.int 0), (.opaque "fSamplingFreq"), (.opaque "<math.h>")]
  let n5 : Sig := Sig.opaqueN "SIGMAX" [(.const ⟨1, 1⟩), n4]
  let n6 : Sig := Sig.opaqueN "SIGMIN" [(.const ⟨192000, 1⟩), n5]
  let n7 : Sig := Sig.binop .div (.const ⟨6908435304715273, 2199023255552⟩) n6
  let n8 : Sig := Sig.opaqueN "SIGTAN" [n7]
  let n9 : Sig := Sig.binop .div (.int 1) n8
  let n10 : Sig := Sig.binop .mul n9 n9
  let n11 : Sig := Sig.binop .sub (.int 1) n10
  let n12 : Sig := Sig.binop .mul (.int 2) n11
  let n13 : Sig := Sig.binop .mul (.const ⟨1, 2⟩) n9
  let n14 : Sig := Sig.binop .add (.int 1) n13
  let n15 : Sig := Sig.binop .add n14 n10
  let n16 : Sig := Sig.binop .div n12 n15
  let n17 : Sig := Sig.binop .mul n3 n16
  let n18 : Sig := Sig.delay n3 (.int 1)
  let n19 : Sig := Sig.binop .sub (.int 1) n13
  let n20 : Sig := Sig.binop .add n19 n10
  let n21 : Sig := Sig.binop .div n20 n15
  let n22 : Sig := Sig.binop .mul n18 n21
  let n23 : Sig := Sig.binop .add n17 n22
  let n24 : Sig := Sig.binop .sub n0 n23
  let n25 : Sig := Sig.cons n24 (.nil)
  let n26 : Sig := Sig.recur n25
  let n27 : Sig := Sig.proj 0 n26
  let n28 : Sig := Sig.binop .div (.const ⟨3602879701896397, 4503599627370496⟩) n15
  let n29 : Sig := Sig.binop .mul n27 n28
  let n30 : Sig := Sig.delay n27 (.int 1)
  let n31 : Sig := Sig.binop .div (.const ⟨3602879701896397, 2251799813685248⟩) n15
  let n32 : Sig := Sig.binop .mul n30 n31
  let n33 : Sig := Sig.binop .add n29 n32
  let n34 : Sig := Sig.delay n27 (.int 2)
  let n35 : Sig := Sig.binop .mul n34 n28
  let n36 : Sig := Sig.binop .add n33 n35
  n36

/-- `// fi.resonlp, a direct-form fi.tf2s section used by filter banks and
// vocoders. Pins the verdict at the six rates.
fi = library("filters.lib");
process = fi.resonlp(1000, 2, 0.8);` — the whole graph, for the rate analysis -/
def resonlp_dag : Dag := #[
  ⟨.input, [.int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.ref, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 2], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.sr, [.int 0, .other, .other], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.const ⟨1, 1⟩, .ref 4], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.min, [.const ⟨192000, 1⟩, .ref 5], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.const ⟨6908435304715273, 2199023255552⟩, .ref 6], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.tan, [.ref 7], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.int 1, .ref 8], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 9, .ref 9], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.int 1, .ref 10], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 2, .ref 11], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.const ⟨1, 2⟩, .ref 9], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.int 1, .ref 13], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 14, .ref 10], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 12, .ref 15], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 3, .ref 16], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay, [.ref 3, .int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.int 1, .ref 13], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 19, .ref 10], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 20, .ref 15], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 18, .ref 21], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 17, .ref 22], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 0, .ref 23], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 24, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 25], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 26], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.const ⟨3602879701896397, 4503599627370496⟩, .ref 15], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 27, .ref 28], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay, [.ref 27, .int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.const ⟨3602879701896397, 2251799813685248⟩, .ref 15], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 30, .ref 31], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 29, .ref 32], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay, [.ref 27, .int 2], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 34, .ref 28], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 33, .ref 35], (Q.zero, Q.zero, Q.zero)⟩]

/-- `// si.smoo: a one-pole smoother whose pole exp(-1/(tau*SR)) depends on the
// sample rate. Pins: stable at the six rates in the three arithmetics.
si = library("signals.lib");
process = si.smoo;` — output 0 -/
def smoo_sr_out0 : Sig :=
  let n0 : Sig := Sig.opaqueN "SIGFCONST" [(.int 0), (.opaque "fSamplingFreq"), (.opaque "<math.h>")]
  let n1 : Sig := Sig.opaqueN "SIGMAX" [(.const ⟨1, 1⟩), n0]
  let n2 : Sig := Sig.opaqueN "SIGMIN" [(.const ⟨192000, 1⟩), n1]
  let n3 : Sig := Sig.binop .div (.const ⟨6206523236469965, 140737488355328⟩) n2
  let n4 : Sig := Sig.binop .sub (.int 1) n3
  let n5 : Sig := Sig.binop .sub (.const ⟨1, 1⟩) n4
  let n6 : Sig := Sig.input 0
  let n7 : Sig := Sig.binop .mul n5 n6
  let n8 : Sig := Sig.ref 1
  let n9 : Sig := Sig.proj 0 n8
  let n10 : Sig := Sig.delay1 n9
  let n11 : Sig := Sig.binop .mul n4 n10
  let n12 : Sig := Sig.binop .add n7 n11
  let n13 : Sig := Sig.cons n12 (.nil)
  let n14 : Sig := Sig.recur n13
  let n15 : Sig := Sig.proj 0 n14
  n15

/-- `// si.smoo: a one-pole smoother whose pole exp(-1/(tau*SR)) depends on the
// sample rate. Pins: stable at the six rates in the three arithmetics.
si = library("signals.lib");
process = si.smoo;` — the whole graph, for the rate analysis -/
def smoo_sr_dag : Dag := #[
  ⟨.sr, [.int 0, .other, .other], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.const ⟨1, 1⟩, .ref 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.min, [.const ⟨192000, 1⟩, .ref 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.const ⟨6206523236469965, 140737488355328⟩, .ref 2], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.int 1, .ref 3], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.const ⟨1, 1⟩, .ref 4], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.input, [.int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 5, .ref 6], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.ref, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 8], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 9], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 4, .ref 10], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 7, .ref 11], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 12, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 13], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 14], (Q.zero, Q.zero, Q.zero)⟩]

/-- `// si.smooth with a constant coefficient — the most used smoothing idiom in
// the libraries (si.smoo is the same recursion with an SR-dependent pole).
// Pins: order-1 recursion, a1 = -0.999, Jury => STABLE.
si = library("signals.lib");
process = hslider("g", 0, 0, 1, 0.01) : si.smooth(0.999);` — output 0 -/
def smooth_stable_out0 : Sig :=
  let n0 : Sig := Sig.control "SIGHSLIDER" 0 ⟨0, 1⟩ ⟨1, 1⟩ []
  let n1 : Sig := Sig.binop .mul (.const ⟨9007199254741, 9007199254740992⟩) n0
  let n2 : Sig := Sig.ref 1
  let n3 : Sig := Sig.proj 0 n2
  let n4 : Sig := Sig.delay1 n3
  let n5 : Sig := Sig.binop .mul (.const ⟨8998192055486251, 9007199254740992⟩) n4
  let n6 : Sig := Sig.binop .add n1 n5
  let n7 : Sig := Sig.cons n6 (.nil)
  let n8 : Sig := Sig.recur n7
  let n9 : Sig := Sig.proj 0 n8
  n9

/-- `// si.smooth with a constant coefficient — the most used smoothing idiom in
// the libraries (si.smoo is the same recursion with an SR-dependent pole).
// Pins: order-1 recursion, a1 = -0.999, Jury => STABLE.
si = library("signals.lib");
process = hslider("g", 0, 0, 1, 0.01) : si.smooth(0.999);` — the whole graph, for the rate analysis -/
def smooth_stable_dag : Dag := #[
  ⟨.control, [.int 0], (⟨0, 1⟩, ⟨0, 1⟩, ⟨1, 1⟩)⟩,
  ⟨.binop .mul, [.const ⟨9007199254741, 9007199254740992⟩, .ref 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.ref, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 2], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 3], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.const ⟨8998192055486251, 9007199254740992⟩, .ref 4], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 1, .ref 5], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 6, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 7], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 8], (Q.zero, Q.zero, Q.zero)⟩]

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

/-- `process = rdtable(16, 1.0, min(100, max(0, int(hslider("i",0,0,100,1)))));` — the whole graph, for the rate analysis -/
def table_bad_clamp_dag : Dag := #[
  ⟨.other "SIGGEN", [.const ⟨1, 1⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.wrtbl, [.int 16, .ref 0, .nil, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.control, [.int 0], (⟨0, 1⟩, ⟨0, 1⟩, ⟨100, 1⟩)⟩,
  ⟨.intcast, [.ref 2], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.int 0, .ref 3], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.min, [.int 100, .ref 4], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.rdtbl, [.ref 1, .ref 5], (Q.zero, Q.zero, Q.zero)⟩]

/-- `process = rdtable(16, 1.0, int(hslider("i",0,0,10,1)));` — output 0 -/
def table_good_clamp_out0 : Sig :=
  let n0 : Sig := Sig.opaqueN "SIGGEN" [(.const ⟨1, 1⟩)]
  let n1 : Sig := Sig.opaqueN "SIGWRTBL" [(.int 16), n0, (.nil), (.nil)]
  let n2 : Sig := Sig.control "SIGHSLIDER" 0 ⟨0, 1⟩ ⟨10, 1⟩ []
  let n3 : Sig := Sig.opaqueN "SIGINTCAST" [n2]
  let n4 : Sig := Sig.opaqueN "SIGRDTBL" [n1, n3]
  n4

/-- `process = rdtable(16, 1.0, int(hslider("i",0,0,10,1)));` — the whole graph, for the rate analysis -/
def table_good_clamp_dag : Dag := #[
  ⟨.other "SIGGEN", [.const ⟨1, 1⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.wrtbl, [.int 16, .ref 0, .nil, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.control, [.int 0], (⟨0, 1⟩, ⟨0, 1⟩, ⟨10, 1⟩)⟩,
  ⟨.intcast, [.ref 2], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.rdtbl, [.ref 1, .ref 3], (Q.zero, Q.zero, Q.zero)⟩]

/-- `process = rdtable(16, 1.0, int(hslider("i",0,0,100,1)));` — output 0 -/
def table_unclamped_out0 : Sig :=
  let n0 : Sig := Sig.opaqueN "SIGGEN" [(.const ⟨1, 1⟩)]
  let n1 : Sig := Sig.opaqueN "SIGWRTBL" [(.int 16), n0, (.nil), (.nil)]
  let n2 : Sig := Sig.control "SIGHSLIDER" 0 ⟨0, 1⟩ ⟨100, 1⟩ []
  let n3 : Sig := Sig.opaqueN "SIGINTCAST" [n2]
  let n4 : Sig := Sig.opaqueN "SIGRDTBL" [n1, n3]
  n4

/-- `process = rdtable(16, 1.0, int(hslider("i",0,0,100,1)));` — the whole graph, for the rate analysis -/
def table_unclamped_dag : Dag := #[
  ⟨.other "SIGGEN", [.const ⟨1, 1⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.wrtbl, [.int 16, .ref 0, .nil, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.control, [.int 0], (⟨0, 1⟩, ⟨0, 1⟩, ⟨100, 1⟩)⟩,
  ⟨.intcast, [.ref 2], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.rdtbl, [.ref 1, .ref 3], (Q.zero, Q.zero, Q.zero)⟩]

/-- `// ba.tabulate with C = 1: the library clamps the read index itself
// (rid(x,1) = max(0, min(x, S-1))), and the interval analysis reads that
// clamp: the table verdict is IN RANGE as written, and the clamp oracle
// checks the compiler inserts nothing on top. The stability verdict is a
// pinned refusal: the table *generator* contains ba.time's counter
// recursion, whose pole sits on the unit circle.
ba = library("basics.lib");
process = ba.tabulate(1, sin, 128, 0.0, 10.0, hslider("x", 0, 0, 10, 0.01)).val;` — output 0 -/
def tabulate_protected_out0 : Sig :=
  let n0 : Sig := Sig.ref 1
  let n1 : Sig := Sig.proj 0 n0
  let n2 : Sig := Sig.delay1 n1
  let n3 : Sig := Sig.binop .add n2 (.int 1)
  let n4 : Sig := Sig.cons n3 (.nil)
  let n5 : Sig := Sig.recur n4
  let n6 : Sig := Sig.proj 0 n5
  let n7 : Sig := Sig.delay1 n6
  let n8 : Sig := Sig.opaqueN "SIGMIN" [n7, (.int 127)]
  let n9 : Sig := Sig.opaqueN "SIGMAX" [(.int 0), n8]
  let n10 : Sig := Sig.opaqueN "SIGFLOATCAST" [n9]
  let n11 : Sig := Sig.binop .mul n10 (.const ⟨10, 1⟩)
  let n12 : Sig := Sig.binop .div n11 (.const ⟨127, 1⟩)
  let n13 : Sig := Sig.binop .add (.const ⟨0, 1⟩) n12
  let n14 : Sig := Sig.opaqueN "SIGSIN" [n13]
  let n15 : Sig := Sig.opaqueN "SIGGEN" [n14]
  let n16 : Sig := Sig.opaqueN "SIGWRTBL" [(.int 128), n15, (.nil), (.nil)]
  let n17 : Sig := Sig.control "SIGHSLIDER" 0 ⟨0, 1⟩ ⟨10, 1⟩ []
  let n18 : Sig := Sig.binop .sub n17 (.const ⟨0, 1⟩)
  let n19 : Sig := Sig.binop .div n18 (.const ⟨10, 1⟩)
  let n20 : Sig := Sig.binop .mul n19 (.int 127)
  let n21 : Sig := Sig.binop .add n20 (.const ⟨1, 2⟩)
  let n22 : Sig := Sig.opaqueN "SIGINTCAST" [n21]
  let n23 : Sig := Sig.opaqueN "SIGMIN" [n22, (.int 127)]
  let n24 : Sig := Sig.opaqueN "SIGMAX" [(.int 0), n23]
  let n25 : Sig := Sig.opaqueN "SIGRDTBL" [n16, n24]
  n25

/-- `// ba.tabulate with C = 1: the library clamps the read index itself
// (rid(x,1) = max(0, min(x, S-1))), and the interval analysis reads that
// clamp: the table verdict is IN RANGE as written, and the clamp oracle
// checks the compiler inserts nothing on top. The stability verdict is a
// pinned refusal: the table *generator* contains ba.time's counter
// recursion, whose pole sits on the unit circle.
ba = library("basics.lib");
process = ba.tabulate(1, sin, 128, 0.0, 10.0, hslider("x", 0, 0, 10, 0.01)).val;` — the whole graph, for the rate analysis -/
def tabulate_protected_dag : Dag := #[
  ⟨.ref, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 2, .int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 3, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 4], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 5], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 6], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.min, [.ref 7, .int 127], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.int 0, .ref 8], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.floatcast, [.ref 9], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 10, .const ⟨10, 1⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 11, .const ⟨127, 1⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.const ⟨0, 1⟩, .ref 12], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.sin, [.ref 13], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.other "SIGGEN", [.ref 14], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.wrtbl, [.int 128, .ref 15, .nil, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.control, [.int 0], (⟨0, 1⟩, ⟨0, 1⟩, ⟨10, 1⟩)⟩,
  ⟨.binop .sub, [.ref 17, .const ⟨0, 1⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 18, .const ⟨10, 1⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 19, .int 127], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 20, .const ⟨1, 2⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.intcast, [.ref 21], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.min, [.ref 22, .int 127], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.int 0, .ref 23], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.rdtbl, [.ref 16, .ref 24], (Q.zero, Q.zero, Q.zero)⟩]

/-- `// ba.tabulate with C = 0 and an input range wider than [r0, r1]: the
// library applies no protection and the index can leave the table. The
// affine rangeOf rules (translate / scale / inverse-scale) read the index
// arithmetic ((x-r0)/(r1-r0)*(S-1) + 1/2) exactly, so the as-written
// verdict is a proven CLAMP REQUIRED — and the clamp oracle confirms the
// compiler's -ct clamp is what stands between this real-code site and an
// out-of-bounds read.
ba = library("basics.lib");
process = ba.tabulate(0, sin, 128, 0.0, 10.0, hslider("x", 0, 0, 20, 0.01)).val;` — output 0 -/
def tabulate_unprotected_out0 : Sig :=
  let n0 : Sig := Sig.ref 1
  let n1 : Sig := Sig.proj 0 n0
  let n2 : Sig := Sig.delay1 n1
  let n3 : Sig := Sig.binop .add n2 (.int 1)
  let n4 : Sig := Sig.cons n3 (.nil)
  let n5 : Sig := Sig.recur n4
  let n6 : Sig := Sig.proj 0 n5
  let n7 : Sig := Sig.delay1 n6
  let n8 : Sig := Sig.opaqueN "SIGMIN" [n7, (.int 127)]
  let n9 : Sig := Sig.opaqueN "SIGMAX" [(.int 0), n8]
  let n10 : Sig := Sig.opaqueN "SIGFLOATCAST" [n9]
  let n11 : Sig := Sig.binop .mul n10 (.const ⟨10, 1⟩)
  let n12 : Sig := Sig.binop .div n11 (.const ⟨127, 1⟩)
  let n13 : Sig := Sig.binop .add (.const ⟨0, 1⟩) n12
  let n14 : Sig := Sig.opaqueN "SIGSIN" [n13]
  let n15 : Sig := Sig.opaqueN "SIGGEN" [n14]
  let n16 : Sig := Sig.opaqueN "SIGWRTBL" [(.int 128), n15, (.nil), (.nil)]
  let n17 : Sig := Sig.control "SIGHSLIDER" 0 ⟨0, 1⟩ ⟨20, 1⟩ []
  let n18 : Sig := Sig.binop .sub n17 (.const ⟨0, 1⟩)
  let n19 : Sig := Sig.binop .div n18 (.const ⟨10, 1⟩)
  let n20 : Sig := Sig.binop .mul n19 (.int 127)
  let n21 : Sig := Sig.binop .add n20 (.const ⟨1, 2⟩)
  let n22 : Sig := Sig.opaqueN "SIGINTCAST" [n21]
  let n23 : Sig := Sig.opaqueN "SIGRDTBL" [n16, n22]
  n23

/-- `// ba.tabulate with C = 0 and an input range wider than [r0, r1]: the
// library applies no protection and the index can leave the table. The
// affine rangeOf rules (translate / scale / inverse-scale) read the index
// arithmetic ((x-r0)/(r1-r0)*(S-1) + 1/2) exactly, so the as-written
// verdict is a proven CLAMP REQUIRED — and the clamp oracle confirms the
// compiler's -ct clamp is what stands between this real-code site and an
// out-of-bounds read.
ba = library("basics.lib");
process = ba.tabulate(0, sin, 128, 0.0, 10.0, hslider("x", 0, 0, 20, 0.01)).val;` — the whole graph, for the rate analysis -/
def tabulate_unprotected_dag : Dag := #[
  ⟨.ref, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 2, .int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 3, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 4], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 5], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 6], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.min, [.ref 7, .int 127], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.int 0, .ref 8], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.floatcast, [.ref 9], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 10, .const ⟨10, 1⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 11, .const ⟨127, 1⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.const ⟨0, 1⟩, .ref 12], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.sin, [.ref 13], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.other "SIGGEN", [.ref 14], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.wrtbl, [.int 128, .ref 15, .nil, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.control, [.int 0], (⟨0, 1⟩, ⟨0, 1⟩, ⟨20, 1⟩)⟩,
  ⟨.binop .sub, [.ref 17, .const ⟨0, 1⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 18, .const ⟨10, 1⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 19, .int 127], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 20, .const ⟨1, 2⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.intcast, [.ref 21], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.rdtbl, [.ref 16, .ref 22], (Q.zero, Q.zero, Q.zero)⟩]

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
process = fi.tf2(0.3, 0.2, 0.1, -1.2, 0.5);` — the whole graph, for the rate analysis -/
def tf2_stable_dag : Dag := #[
  ⟨.input, [.int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.ref, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 2], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 3, .const ⟨(-5404319552844595), 4503599627370496⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay, [.ref 3, .int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 5, .const ⟨1, 2⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 4, .ref 6], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 0, .ref 7], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 8, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 9], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 10], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 11, .const ⟨5404319552844595, 18014398509481984⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay, [.ref 11, .int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 13, .const ⟨3602879701896397, 18014398509481984⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 12, .ref 14], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay, [.ref 11, .int 2], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 16, .const ⟨3602879701896397, 36028797018963968⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 15, .ref 17], (Q.zero, Q.zero, Q.zero)⟩]

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

/-- `import("filters.lib");
process = fi.tf2(1, 0, 0, -0.5, -0.8);` — the whole graph, for the rate analysis -/
def tf2_unstable_dag : Dag := #[
  ⟨.input, [.int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.ref, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 2], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 3, .const ⟨(-1), 2⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay, [.ref 3, .int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 5, .const ⟨(-3602879701896397), 4503599627370496⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 4, .ref 6], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 0, .ref 7], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 8, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 9], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 10], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 11, .int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay, [.ref 11, .int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 13, .int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 12, .ref 14], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay, [.ref 11, .int 2], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 16, .int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 15, .ref 17], (Q.zero, Q.zero, Q.zero)⟩]

/-- `// The direct form fi.lowpass used before #262: fi.tf2s at 20 Hz. Its Jury
// margin 1 + a1 + a2 is O(w^2), about 1.7e-6 at 96 kHz, below what the
// rounding of its coefficients in single precision can move. Pins: stable
// in exact and double at every rate, not proven in single from 88.2 kHz.
fi = library("filters.lib");
ma = library("maths.lib");
process = fi.tf2s(0, 0, 1, sqrt(2), 1, 2*ma.PI*20);` — output 0 -/
def tf2s_direct_20hz_out0 : Sig :=
  let n0 : Sig := Sig.input 0
  let n1 : Sig := Sig.ref 1
  let n2 : Sig := Sig.proj 0 n1
  let n3 : Sig := Sig.delay1 n2
  let n4 : Sig := Sig.opaqueN "SIGFCONST" [(.int 0), (.opaque "fSamplingFreq"), (.opaque "<math.h>")]
  let n5 : Sig := Sig.opaqueN "SIGMAX" [(.const ⟨1, 1⟩), n4]
  let n6 : Sig := Sig.opaqueN "SIGMIN" [(.const ⟨192000, 1⟩), n5]
  let n7 : Sig := Sig.binop .div (.const ⟨4421398595017775, 70368744177664⟩) n6
  let n8 : Sig := Sig.opaqueN "SIGTAN" [n7]
  let n9 : Sig := Sig.binop .div (.int 1) n8
  let n10 : Sig := Sig.binop .mul n9 n9
  let n11 : Sig := Sig.binop .sub (.int 1) n10
  let n12 : Sig := Sig.binop .mul (.int 2) n11
  let n13 : Sig := Sig.binop .mul (.const ⟨6369051672525773, 4503599627370496⟩) n9
  let n14 : Sig := Sig.binop .add (.int 1) n13
  let n15 : Sig := Sig.binop .add n14 n10
  let n16 : Sig := Sig.binop .div n12 n15
  let n17 : Sig := Sig.binop .mul n3 n16
  let n18 : Sig := Sig.delay n3 (.int 1)
  let n19 : Sig := Sig.binop .sub (.int 1) n13
  let n20 : Sig := Sig.binop .add n19 n10
  let n21 : Sig := Sig.binop .div n20 n15
  let n22 : Sig := Sig.binop .mul n18 n21
  let n23 : Sig := Sig.binop .add n17 n22
  let n24 : Sig := Sig.binop .sub n0 n23
  let n25 : Sig := Sig.cons n24 (.nil)
  let n26 : Sig := Sig.recur n25
  let n27 : Sig := Sig.proj 0 n26
  let n28 : Sig := Sig.binop .div (.int 1) n15
  let n29 : Sig := Sig.binop .mul n27 n28
  let n30 : Sig := Sig.delay n27 (.int 1)
  let n31 : Sig := Sig.binop .div (.int 2) n15
  let n32 : Sig := Sig.binop .mul n30 n31
  let n33 : Sig := Sig.binop .add n29 n32
  let n34 : Sig := Sig.delay n27 (.int 2)
  let n35 : Sig := Sig.binop .mul n34 n28
  let n36 : Sig := Sig.binop .add n33 n35
  n36

/-- `// The direct form fi.lowpass used before #262: fi.tf2s at 20 Hz. Its Jury
// margin 1 + a1 + a2 is O(w^2), about 1.7e-6 at 96 kHz, below what the
// rounding of its coefficients in single precision can move. Pins: stable
// in exact and double at every rate, not proven in single from 88.2 kHz.
fi = library("filters.lib");
ma = library("maths.lib");
process = fi.tf2s(0, 0, 1, sqrt(2), 1, 2*ma.PI*20);` — the whole graph, for the rate analysis -/
def tf2s_direct_20hz_dag : Dag := #[
  ⟨.input, [.int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.ref, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 2], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.sr, [.int 0, .other, .other], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.const ⟨1, 1⟩, .ref 4], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.min, [.const ⟨192000, 1⟩, .ref 5], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.const ⟨4421398595017775, 70368744177664⟩, .ref 6], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.tan, [.ref 7], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.int 1, .ref 8], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 9, .ref 9], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.int 1, .ref 10], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 2, .ref 11], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.const ⟨6369051672525773, 4503599627370496⟩, .ref 9], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.int 1, .ref 13], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 14, .ref 10], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 12, .ref 15], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 3, .ref 16], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay, [.ref 3, .int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.int 1, .ref 13], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 19, .ref 10], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 20, .ref 15], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 18, .ref 21], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 17, .ref 22], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 0, .ref 23], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 24, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 25], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 26], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.int 1, .ref 15], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 27, .ref 28], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay, [.ref 27, .int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.int 2, .ref 15], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 30, .ref 31], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 29, .ref 32], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay, [.ref 27, .int 2], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 34, .ref 28], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 33, .ref 35], (Q.zero, Q.zero, Q.zero)⟩]

/-- `// fi.tf2snp, normalized-ladder coefficients computed without cancellation
// (tf2snp-exact-coeffs). Pins the verdict at the six rates.
fi = library("filters.lib");
process = fi.tf2snp(0, 0, 1, sqrt(2), 1, 2*3.141592653589793*1000);` — output 0 -/
def tf2snp_exact_out0 : Sig :=
  let n0 : Sig := Sig.input 0
  let n1 : Sig := Sig.opaqueN "SIGFCONST" [(.int 0), (.opaque "fSamplingFreq"), (.opaque "<math.h>")]
  let n2 : Sig := Sig.opaqueN "SIGMAX" [(.const ⟨1, 1⟩), n1]
  let n3 : Sig := Sig.opaqueN "SIGMIN" [(.const ⟨192000, 1⟩), n2]
  let n4 : Sig := Sig.binop .div (.const ⟨6908435304715273, 2199023255552⟩) n3
  let n5 : Sig := Sig.opaqueN "SIGTAN" [n4]
  let n6 : Sig := Sig.binop .mul (.int 1) n5
  let n7 : Sig := Sig.binop .mul n6 n5
  let n8 : Sig := Sig.binop .mul (.const ⟨6369051672525773, 4503599627370496⟩) n5
  let n9 : Sig := Sig.binop .sub n7 n8
  let n10 : Sig := Sig.binop .add n9 (.int 1)
  let n11 : Sig := Sig.binop .add n7 n8
  let n12 : Sig := Sig.binop .add n11 (.int 1)
  let n13 : Sig := Sig.binop .div n10 n12
  let n14 : Sig := Sig.opaqueN "SIGMIN" [(.const ⟨8388607, 8388608⟩), n13]
  let n15 : Sig := Sig.opaqueN "SIGMAX" [(.const ⟨(-8388607), 8388608⟩), n14]
  let n16 : Sig := Sig.binop .mul n0 n15
  let n17 : Sig := Sig.ref 1
  let n18 : Sig := Sig.proj 0 n17
  let n19 : Sig := Sig.delay1 n18
  let n20 : Sig := Sig.binop .sub (.int 0) n15
  let n21 : Sig := Sig.binop .mul n19 n20
  let n22 : Sig := Sig.binop .add n7 (.int 1)
  let n23 : Sig := Sig.binop .mul n8 n22
  let n24 : Sig := Sig.opaqueN "SIGMAX" [(.int 0), n23]
  let n25 : Sig := Sig.opaqueN "SIGSQRT" [n24]
  let n26 : Sig := Sig.binop .mul (.int 2) n25
  let n27 : Sig := Sig.binop .div n26 n12
  let n28 : Sig := Sig.opaqueN "SIGMAX" [(.const ⟨2251799746576383, 4611686018427387904⟩), n27]
  let n29 : Sig := Sig.binop .mul n0 n28
  let n30 : Sig := Sig.binop .add n21 n29
  let n31 : Sig := Sig.binop .sub n7 (.int 1)
  let n32 : Sig := Sig.binop .div n31 n22
  let n33 : Sig := Sig.opaqueN "SIGMIN" [(.const ⟨8388607, 8388608⟩), n32]
  let n34 : Sig := Sig.opaqueN "SIGMAX" [(.const ⟨(-8388607), 8388608⟩), n33]
  let n35 : Sig := Sig.binop .mul n30 n34
  let n36 : Sig := Sig.binop .sub (.int 0) n34
  let n37 : Sig := Sig.binop .mul n19 n36
  let n38 : Sig := Sig.ref 2
  let n39 : Sig := Sig.proj 0 n38
  let n40 : Sig := Sig.delay1 n39
  let n41 : Sig := Sig.binop .mul n40 n20
  let n42 : Sig := Sig.binop .add n41 n29
  let n43 : Sig := Sig.opaqueN "SIGMAX" [(.int 0), n7]
  let n44 : Sig := Sig.opaqueN "SIGSQRT" [n43]
  let n45 : Sig := Sig.binop .mul (.int 2) n44
  let n46 : Sig := Sig.binop .div n45 n22
  let n47 : Sig := Sig.opaqueN "SIGMAX" [(.const ⟨2251799746576383, 4611686018427387904⟩), n46]
  let n48 : Sig := Sig.binop .mul n42 n47
  let n49 : Sig := Sig.binop .add n37 n48
  let n50 : Sig := Sig.cons n49 (.nil)
  let n51 : Sig := Sig.recur n50
  let n52 : Sig := Sig.proj 0 n51
  let n53 : Sig := Sig.delay1 n52
  let n54 : Sig := Sig.binop .mul n53 n47
  let n55 : Sig := Sig.binop .add n35 n54
  let n56 : Sig := Sig.cons n52 (.nil)
  let n57 : Sig := Sig.cons n55 n56
  let n58 : Sig := Sig.recur n57
  let n59 : Sig := Sig.proj 0 n58
  let n60 : Sig := Sig.delay1 n59
  let n61 : Sig := Sig.binop .mul n60 n28
  let n62 : Sig := Sig.binop .add n16 n61
  let n63 : Sig := Sig.binop .mul (.int 0) n5
  let n64 : Sig := Sig.binop .sub n7 n63
  let n65 : Sig := Sig.binop .add n64 (.int 0)
  let n66 : Sig := Sig.binop .div n65 n12
  let n67 : Sig := Sig.binop .mul n62 n66
  let n68 : Sig := Sig.binop .mul n7 n8
  let n69 : Sig := Sig.binop .mul (.int 2) n7
  let n70 : Sig := Sig.binop .add n68 n69
  let n71 : Sig := Sig.binop .mul (.int 0) n7
  let n72 : Sig := Sig.binop .sub n70 n71
  let n73 : Sig := Sig.binop .mul (.int 0) n8
  let n74 : Sig := Sig.binop .sub n72 n73
  let n75 : Sig := Sig.binop .mul n63 n7
  let n76 : Sig := Sig.binop .add n74 n75
  let n77 : Sig := Sig.binop .sub n76 n63
  let n78 : Sig := Sig.binop .mul (.int 2) n77
  let n79 : Sig := Sig.binop .mul n12 n12
  let n80 : Sig := Sig.binop .div n78 n79
  let n81 : Sig := Sig.opaqueN "SIGSQRT" [(.const ⟨16777215, 70368744177664⟩)]
  let n82 : Sig := Sig.opaqueN "SIGMAX" [n81, n27]
  let n83 : Sig := Sig.binop .div n80 n82
  let n84 : Sig := Sig.binop .mul n59 n83
  let n85 : Sig := Sig.binop .add n67 n84
  let n86 : Sig := Sig.proj 1 n58
  let n87 : Sig := Sig.binop .add n8 (.int 1)
  let n88 : Sig := Sig.binop .sub n87 n7
  let n89 : Sig := Sig.binop .mul n7 n88
  let n90 : Sig := Sig.binop .add n8 n7
  let n91 : Sig := Sig.binop .sub n90 (.int 1)
  let n92 : Sig := Sig.binop .mul n71 n91
  let n93 : Sig := Sig.binop .add n89 n92
  let n94 : Sig := Sig.binop .mul (.int 2) n63
  let n95 : Sig := Sig.binop .mul n94 n7
  let n96 : Sig := Sig.binop .add n93 n95
  let n97 : Sig := Sig.binop .mul (.int 4) n96
  let n98 : Sig := Sig.binop .mul n79 n22
  let n99 : Sig := Sig.binop .div n97 n98
  let n100 : Sig := Sig.opaqueN "SIGMAX" [n81, n46]
  let n101 : Sig := Sig.binop .mul n82 n100
  let n102 : Sig := Sig.binop .div n99 n101
  let n103 : Sig := Sig.binop .mul n86 n102
  let n104 : Sig := Sig.binop .add n85 n103
  n104

/-- `// fi.tf2snp, normalized-ladder coefficients computed without cancellation
// (tf2snp-exact-coeffs). Pins the verdict at the six rates.
fi = library("filters.lib");
process = fi.tf2snp(0, 0, 1, sqrt(2), 1, 2*3.141592653589793*1000);` — the whole graph, for the rate analysis -/
def tf2snp_exact_dag : Dag := #[
  ⟨.input, [.int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.sr, [.int 0, .other, .other], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.const ⟨1, 1⟩, .ref 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.min, [.const ⟨192000, 1⟩, .ref 2], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.const ⟨6908435304715273, 2199023255552⟩, .ref 3], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.tan, [.ref 4], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 1, .ref 5], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 6, .ref 5], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.const ⟨6369051672525773, 4503599627370496⟩, .ref 5], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 7, .ref 8], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 9, .int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 7, .ref 8], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 11, .int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 10, .ref 12], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.min, [.const ⟨8388607, 8388608⟩, .ref 13], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.const ⟨(-8388607), 8388608⟩, .ref 14], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 0, .ref 15], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.ref, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 17], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 18], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.int 0, .ref 15], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 19, .ref 20], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 7, .int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 8, .ref 22], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.int 0, .ref 23], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.sqrt, [.ref 24], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 2, .ref 25], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 26, .ref 12], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.const ⟨2251799746576383, 4611686018427387904⟩, .ref 27], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 0, .ref 28], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 21, .ref 29], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 7, .int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 31, .ref 22], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.min, [.const ⟨8388607, 8388608⟩, .ref 32], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.const ⟨(-8388607), 8388608⟩, .ref 33], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 30, .ref 34], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.int 0, .ref 34], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 19, .ref 36], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.ref, [.int 2], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 38], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 39], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 40, .ref 20], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 41, .ref 29], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.int 0, .ref 7], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.sqrt, [.ref 43], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 2, .ref 44], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 45, .ref 22], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.const ⟨2251799746576383, 4611686018427387904⟩, .ref 46], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 42, .ref 47], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 37, .ref 48], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 49, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 50], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 51], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 52], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 53, .ref 47], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 35, .ref 54], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 52, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 55, .ref 56], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 57], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 58], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 59], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 60, .ref 28], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 16, .ref 61], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 0, .ref 5], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 7, .ref 63], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 64, .int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 65, .ref 12], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 62, .ref 66], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 7, .ref 8], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 2, .ref 7], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 68, .ref 69], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 0, .ref 7], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 70, .ref 71], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 0, .ref 8], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 72, .ref 73], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 63, .ref 7], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 74, .ref 75], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 76, .ref 63], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 2, .ref 77], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 12, .ref 12], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 78, .ref 79], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.sqrt, [.const ⟨16777215, 70368744177664⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.ref 81, .ref 27], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 80, .ref 82], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 59, .ref 83], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 67, .ref 84], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 1, .ref 58], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 8, .int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 87, .ref 7], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 7, .ref 88], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 8, .ref 7], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 90, .int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 71, .ref 91], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 89, .ref 92], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 2, .ref 63], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 94, .ref 7], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 93, .ref 95], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 4, .ref 96], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 79, .ref 22], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 97, .ref 98], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.ref 81, .ref 46], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 82, .ref 100], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 99, .ref 101], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 86, .ref 102], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 85, .ref 103], (Q.zero, Q.zero, Q.zero)⟩]

/-- `// fi.tf3slf with its poles at 1 rad/s (0.16 Hz), as in tf3slf_test, which
// check-precision reports non-finite in single at every rate. A third-order
// recursion: refused by the rate analysis (more than 2 states), pinned so
// that extending it shows up here.
fi = library("filters.lib");
process = fi.tf3slf(0, 0, 0, 1, 1, 2, 2, 1);` — output 0 -/
def tf3slf_low_out0 : Sig :=
  let n0 : Sig := Sig.input 0
  let n1 : Sig := Sig.ref 1
  let n2 : Sig := Sig.proj 0 n1
  let n3 : Sig := Sig.delay1 n2
  let n4 : Sig := Sig.opaqueN "SIGFCONST" [(.int 0), (.opaque "fSamplingFreq"), (.opaque "<math.h>")]
  let n5 : Sig := Sig.opaqueN "SIGMAX" [(.const ⟨1, 1⟩), n4]
  let n6 : Sig := Sig.opaqueN "SIGMIN" [(.const ⟨192000, 1⟩), n5]
  let n7 : Sig := Sig.binop .mul (.const ⟨2, 1⟩) n6
  let n8 : Sig := Sig.opaqueN "SIGPOW" [n7, (.int 3)]
  let n9 : Sig := Sig.binop .mul (.int 3) n8
  let n10 : Sig := Sig.opaqueN "SIGPOW" [n7, (.int 2)]
  let n11 : Sig := Sig.binop .mul (.int 2) n10
  let n12 : Sig := Sig.binop .add n9 n11
  let n13 : Sig := Sig.binop .mul (.int 2) n7
  let n14 : Sig := Sig.binop .sub n12 n13
  let n15 : Sig := Sig.binop .sub n14 (.int 3)
  let n16 : Sig := Sig.binop .mul (.int (-1)) n8
  let n17 : Sig := Sig.binop .sub n16 n11
  let n18 : Sig := Sig.binop .sub n17 n13
  let n19 : Sig := Sig.binop .sub n18 (.int 1)
  let n20 : Sig := Sig.binop .div n15 n19
  let n21 : Sig := Sig.binop .mul n3 n20
  let n22 : Sig := Sig.delay n3 (.int 1)
  let n23 : Sig := Sig.binop .mul (.int (-3)) n8
  let n24 : Sig := Sig.binop .add n23 n11
  let n25 : Sig := Sig.binop .add n24 n13
  let n26 : Sig := Sig.binop .sub n25 (.int 3)
  let n27 : Sig := Sig.binop .div n26 n19
  let n28 : Sig := Sig.binop .mul n22 n27
  let n29 : Sig := Sig.binop .add n21 n28
  let n30 : Sig := Sig.delay n3 (.int 2)
  let n31 : Sig := Sig.binop .mul (.int 1) n8
  let n32 : Sig := Sig.binop .sub n31 n11
  let n33 : Sig := Sig.binop .add n32 n13
  let n34 : Sig := Sig.binop .sub n33 (.int 1)
  let n35 : Sig := Sig.binop .div n34 n19
  let n36 : Sig := Sig.binop .mul n30 n35
  let n37 : Sig := Sig.binop .add n29 n36
  let n38 : Sig := Sig.binop .sub n0 n37
  let n39 : Sig := Sig.cons n38 (.nil)
  let n40 : Sig := Sig.recur n39
  let n41 : Sig := Sig.proj 0 n40
  let n42 : Sig := Sig.binop .mul (.int 0) n7
  let n43 : Sig := Sig.binop .sub (.int 0) n42
  let n44 : Sig := Sig.binop .sub n43 (.int 1)
  let n45 : Sig := Sig.binop .div n44 n19
  let n46 : Sig := Sig.binop .mul n41 n45
  let n47 : Sig := Sig.delay n41 (.int 1)
  let n48 : Sig := Sig.binop .sub n43 (.int 3)
  let n49 : Sig := Sig.binop .div n48 n19
  let n50 : Sig := Sig.binop .mul n47 n49
  let n51 : Sig := Sig.binop .add n46 n50
  let n52 : Sig := Sig.delay n41 (.int 2)
  let n53 : Sig := Sig.binop .add (.int 0) n42
  let n54 : Sig := Sig.binop .sub n53 (.int 3)
  let n55 : Sig := Sig.binop .div n54 n19
  let n56 : Sig := Sig.binop .mul n52 n55
  let n57 : Sig := Sig.binop .add n51 n56
  let n58 : Sig := Sig.delay n41 (.int 3)
  let n59 : Sig := Sig.binop .sub n53 (.int 1)
  let n60 : Sig := Sig.binop .div n59 n19
  let n61 : Sig := Sig.binop .mul n58 n60
  let n62 : Sig := Sig.binop .add n57 n61
  n62

/-- `// fi.tf3slf with its poles at 1 rad/s (0.16 Hz), as in tf3slf_test, which
// check-precision reports non-finite in single at every rate. A third-order
// recursion: refused by the rate analysis (more than 2 states), pinned so
// that extending it shows up here.
fi = library("filters.lib");
process = fi.tf3slf(0, 0, 0, 1, 1, 2, 2, 1);` — the whole graph, for the rate analysis -/
def tf3slf_low_dag : Dag := #[
  ⟨.input, [.int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.ref, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 2], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.sr, [.int 0, .other, .other], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.max, [.const ⟨1, 1⟩, .ref 4], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.min, [.const ⟨192000, 1⟩, .ref 5], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.const ⟨2, 1⟩, .ref 6], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.pow, [.ref 7, .int 3], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 3, .ref 8], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.pow, [.ref 7, .int 2], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 2, .ref 10], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 9, .ref 11], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 2, .ref 7], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 12, .ref 13], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 14, .int 3], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int (-1), .ref 8], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 16, .ref 11], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 17, .ref 13], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 18, .int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 15, .ref 19], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 3, .ref 20], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay, [.ref 3, .int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int (-3), .ref 8], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 23, .ref 11], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 24, .ref 13], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 25, .int 3], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 26, .ref 19], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 22, .ref 27], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 21, .ref 28], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay, [.ref 3, .int 2], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 1, .ref 8], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 31, .ref 11], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 32, .ref 13], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 33, .int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 34, .ref 19], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 30, .ref 35], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 29, .ref 36], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 0, .ref 37], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 38, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 39], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 40], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.int 0, .ref 7], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.int 0, .ref 42], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 43, .int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 44, .ref 19], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 41, .ref 45], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay, [.ref 41, .int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 43, .int 3], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 48, .ref 19], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 47, .ref 49], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 46, .ref 50], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay, [.ref 41, .int 2], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.int 0, .ref 42], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 53, .int 3], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 54, .ref 19], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 52, .ref 55], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 51, .ref 56], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay, [.ref 41, .int 3], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .sub, [.ref 53, .int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .div, [.ref 59, .ref 19], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 58, .ref 60], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 57, .ref 61], (Q.zero, Q.zero, Q.zero)⟩]

/-- `// ba.time — the sample counter (+(1) ~ _). Its pole sits exactly on the
// unit circle, and the Jury criterion is strict: an unbounded ramp is not
// certified stable. Pins the strictness of the boundary case on real code.
ba = library("basics.lib");
process = ba.time;` — output 0 -/
def time_marginal_out0 : Sig :=
  let n0 : Sig := Sig.ref 1
  let n1 : Sig := Sig.proj 0 n0
  let n2 : Sig := Sig.delay1 n1
  let n3 : Sig := Sig.binop .add n2 (.int 1)
  let n4 : Sig := Sig.cons n3 (.nil)
  let n5 : Sig := Sig.recur n4
  let n6 : Sig := Sig.proj 0 n5
  let n7 : Sig := Sig.delay1 n6
  n7

/-- `// ba.time — the sample counter (+(1) ~ _). Its pole sits exactly on the
// unit circle, and the Jury criterion is strict: an unbounded ramp is not
// certified stable. Pins the strictness of the boundary case on real code.
ba = library("basics.lib");
process = ba.time;` — the whole graph, for the rate analysis -/
def time_marginal_dag : Dag := #[
  ⟨.ref, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 2, .int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 3, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 4], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 5], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 6], (Q.zero, Q.zero, Q.zero)⟩]

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

/-- `process = + ~ *(1.5);` — the whole graph, for the rate analysis -/
def unstable_dag : Dag := #[
  ⟨.ref, [.int 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.delay1, [.ref 1], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .mul, [.ref 2, .const ⟨3, 2⟩], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.input, [.int 0], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.binop .add, [.ref 3, .ref 4], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.cons, [.ref 5, .nil], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.recur, [.ref 6], (Q.zero, Q.zero, Q.zero)⟩,
  ⟨.proj, [.int 0, .ref 7], (Q.zero, Q.zero, Q.zero)⟩]

/-! ## Certification

Two independent analyses over the same imported graph.
`certifyStableB` reads the feedback coefficients and applies the
Jury criterion. `certifyIndicesB` checks every table read and
delay tap whose range follows from the graph structure alone;
`false` there means *not proven*, never *unsafe*. -/

#eval s!"allpass_comb_out0: " ++ certifyReport allpass_comb_out0
#eval s!"bandpass2matched_float_out0: " ++ certifyReport bandpass2matched_float_out0
#eval s!"bandpass_tpt_out0: " ++ certifyReport bandpass_tpt_out0
#eval s!"dcblocker_out0: " ++ certifyReport dcblocker_out0
#eval s!"delay_sr_out0: " ++ certifyReport delay_sr_out0
#eval s!"fb_comb_out0: " ++ certifyReport fb_comb_out0
#eval s!"fb_comb_unstable_out0: " ++ certifyReport fb_comb_unstable_out0
#eval s!"fb_fcomb_out0: " ++ certifyReport fb_fcomb_out0
#eval s!"fdelay_clamped_out0: " ++ certifyReport fdelay_clamped_out0
#eval s!"lowpass3_out0: " ++ certifyReport lowpass3_out0
#eval s!"lowpass_svf_20hz_out0: " ++ certifyReport lowpass_svf_20hz_out0
#eval s!"modulated_delay_loop_out0: " ++ certifyReport modulated_delay_loop_out0
#eval s!"noise_lcg_out0: " ++ certifyReport noise_lcg_out0
#eval s!"nonlinear_out0: " ++ certifyReport nonlinear_out0
#eval s!"onepole_out0: " ++ certifyReport onepole_out0
#eval s!"osc_out0: " ++ certifyReport osc_out0
#eval s!"osc_negative_freq_out0: " ++ certifyReport osc_negative_freq_out0
#eval s!"resonlp_out0: " ++ certifyReport resonlp_out0
#eval s!"smoo_sr_out0: " ++ certifyReport smoo_sr_out0
#eval s!"smooth_stable_out0: " ++ certifyReport smooth_stable_out0
#eval s!"table_bad_clamp_out0: " ++ certifyReport table_bad_clamp_out0
#eval s!"table_good_clamp_out0: " ++ certifyReport table_good_clamp_out0
#eval s!"table_unclamped_out0: " ++ certifyReport table_unclamped_out0
#eval s!"tabulate_protected_out0: " ++ certifyReport tabulate_protected_out0
#eval s!"tabulate_unprotected_out0: " ++ certifyReport tabulate_unprotected_out0
#eval s!"tf2_stable_out0: " ++ certifyReport tf2_stable_out0
#eval s!"tf2_unstable_out0: " ++ certifyReport tf2_unstable_out0
#eval s!"tf2s_direct_20hz_out0: " ++ certifyReport tf2s_direct_20hz_out0
#eval s!"tf2snp_exact_out0: " ++ certifyReport tf2snp_exact_out0
#eval s!"tf3slf_low_out0: " ++ certifyReport tf3slf_low_out0
#eval s!"time_marginal_out0: " ++ certifyReport time_marginal_out0
#eval s!"unstable_out0: " ++ certifyReport unstable_out0

#eval s!"allpass_comb_out0: " ++ indexReport allpass_comb_out0
#eval s!"bandpass2matched_float_out0: " ++ indexReport bandpass2matched_float_out0
#eval s!"bandpass_tpt_out0: " ++ indexReport bandpass_tpt_out0
#eval s!"dcblocker_out0: " ++ indexReport dcblocker_out0
#eval s!"delay_sr_out0: " ++ indexReport delay_sr_out0
#eval s!"fb_comb_out0: " ++ indexReport fb_comb_out0
#eval s!"fb_comb_unstable_out0: " ++ indexReport fb_comb_unstable_out0
#eval s!"fb_fcomb_out0: " ++ indexReport fb_fcomb_out0
#eval s!"fdelay_clamped_out0: " ++ indexReport fdelay_clamped_out0
#eval s!"lowpass3_out0: " ++ indexReport lowpass3_out0
#eval s!"lowpass_svf_20hz_out0: " ++ indexReport lowpass_svf_20hz_out0
#eval s!"modulated_delay_loop_out0: " ++ indexReport modulated_delay_loop_out0
#eval s!"noise_lcg_out0: " ++ indexReport noise_lcg_out0
#eval s!"nonlinear_out0: " ++ indexReport nonlinear_out0
#eval s!"onepole_out0: " ++ indexReport onepole_out0
#eval s!"osc_out0: " ++ indexReport osc_out0
#eval s!"osc_negative_freq_out0: " ++ indexReport osc_negative_freq_out0
#eval s!"resonlp_out0: " ++ indexReport resonlp_out0
#eval s!"smoo_sr_out0: " ++ indexReport smoo_sr_out0
#eval s!"smooth_stable_out0: " ++ indexReport smooth_stable_out0
#eval s!"table_bad_clamp_out0: " ++ indexReport table_bad_clamp_out0
#eval s!"table_good_clamp_out0: " ++ indexReport table_good_clamp_out0
#eval s!"table_unclamped_out0: " ++ indexReport table_unclamped_out0
#eval s!"tabulate_protected_out0: " ++ indexReport tabulate_protected_out0
#eval s!"tabulate_unprotected_out0: " ++ indexReport tabulate_unprotected_out0
#eval s!"tf2_stable_out0: " ++ indexReport tf2_stable_out0
#eval s!"tf2_unstable_out0: " ++ indexReport tf2_unstable_out0
#eval s!"tf2s_direct_20hz_out0: " ++ indexReport tf2s_direct_20hz_out0
#eval s!"tf2snp_exact_out0: " ++ indexReport tf2snp_exact_out0
#eval s!"tf3slf_low_out0: " ++ indexReport tf3slf_low_out0
#eval s!"time_marginal_out0: " ++ indexReport time_marginal_out0
#eval s!"unstable_out0: " ++ indexReport unstable_out0

theorem allpass_comb_out0_stability : certifyStableB allpass_comb_out0 = false := by decide
theorem bandpass2matched_float_out0_stability : certifyStableB bandpass2matched_float_out0 = false := by decide
theorem bandpass_tpt_out0_stability : certifyStableB bandpass_tpt_out0 = false := by decide
theorem dcblocker_out0_stability : certifyStableB dcblocker_out0 = true := by decide
theorem delay_sr_out0_stability : certifyStableB delay_sr_out0 = false := by decide
theorem fb_comb_out0_stability : certifyStableB fb_comb_out0 = false := by decide
theorem fb_comb_unstable_out0_stability : certifyStableB fb_comb_unstable_out0 = false := by decide
theorem fb_fcomb_out0_stability : certifyStableB fb_fcomb_out0 = false := by decide
theorem fdelay_clamped_out0_stability : certifyStableB fdelay_clamped_out0 = false := by decide
theorem lowpass3_out0_stability : certifyStableB lowpass3_out0 = false := by decide
theorem lowpass_svf_20hz_out0_stability : certifyStableB lowpass_svf_20hz_out0 = false := by decide
theorem modulated_delay_loop_out0_stability : certifyStableB modulated_delay_loop_out0 = false := by decide
theorem noise_lcg_out0_stability : certifyStableB noise_lcg_out0 = false := by decide
theorem nonlinear_out0_stability : certifyStableB nonlinear_out0 = false := by decide
theorem onepole_out0_stability : certifyStableB onepole_out0 = true := by decide
theorem osc_out0_stability : certifyStableB osc_out0 = false := by decide
theorem osc_negative_freq_out0_stability : certifyStableB osc_negative_freq_out0 = false := by decide
theorem resonlp_out0_stability : certifyStableB resonlp_out0 = false := by decide
theorem smoo_sr_out0_stability : certifyStableB smoo_sr_out0 = false := by decide
theorem smooth_stable_out0_stability : certifyStableB smooth_stable_out0 = true := by decide
theorem table_bad_clamp_out0_stability : certifyStableB table_bad_clamp_out0 = false := by decide
theorem table_good_clamp_out0_stability : certifyStableB table_good_clamp_out0 = false := by decide
theorem table_unclamped_out0_stability : certifyStableB table_unclamped_out0 = false := by decide
theorem tabulate_protected_out0_stability : certifyStableB tabulate_protected_out0 = false := by decide
theorem tabulate_unprotected_out0_stability : certifyStableB tabulate_unprotected_out0 = false := by decide
theorem tf2_stable_out0_stability : certifyStableB tf2_stable_out0 = true := by decide
theorem tf2_unstable_out0_stability : certifyStableB tf2_unstable_out0 = false := by decide
theorem tf2s_direct_20hz_out0_stability : certifyStableB tf2s_direct_20hz_out0 = false := by decide
theorem tf2snp_exact_out0_stability : certifyStableB tf2snp_exact_out0 = false := by decide
theorem tf3slf_low_out0_stability : certifyStableB tf3slf_low_out0 = false := by decide
theorem time_marginal_out0_stability : certifyStableB time_marginal_out0 = false := by decide
theorem unstable_out0_stability : certifyStableB unstable_out0 = false := by decide

theorem allpass_comb_out0_indices : certifyIndicesB allpass_comb_out0 = true := by decide
theorem bandpass2matched_float_out0_indices : certifyIndicesB bandpass2matched_float_out0 = true := by decide
theorem bandpass_tpt_out0_indices : certifyIndicesB bandpass_tpt_out0 = true := by decide
theorem dcblocker_out0_indices : certifyIndicesB dcblocker_out0 = true := by decide
theorem delay_sr_out0_indices : certifyIndicesB delay_sr_out0 = true := by decide
theorem fb_comb_out0_indices : certifyIndicesB fb_comb_out0 = true := by decide
theorem fb_comb_unstable_out0_indices : certifyIndicesB fb_comb_unstable_out0 = true := by decide
theorem fb_fcomb_out0_indices : certifyIndicesB fb_fcomb_out0 = true := by decide
theorem fdelay_clamped_out0_indices : certifyIndicesB fdelay_clamped_out0 = true := by decide
theorem lowpass3_out0_indices : certifyIndicesB lowpass3_out0 = true := by decide
theorem lowpass_svf_20hz_out0_indices : certifyIndicesB lowpass_svf_20hz_out0 = true := by decide
theorem modulated_delay_loop_out0_indices : certifyIndicesB modulated_delay_loop_out0 = true := by decide
theorem noise_lcg_out0_indices : certifyIndicesB noise_lcg_out0 = true := by decide
theorem nonlinear_out0_indices : certifyIndicesB nonlinear_out0 = true := by decide
theorem onepole_out0_indices : certifyIndicesB onepole_out0 = true := by decide
theorem osc_out0_indices : certifyIndicesB osc_out0 = true := by decide
theorem osc_negative_freq_out0_indices : certifyIndicesB osc_negative_freq_out0 = true := by decide
theorem resonlp_out0_indices : certifyIndicesB resonlp_out0 = true := by decide
theorem smoo_sr_out0_indices : certifyIndicesB smoo_sr_out0 = true := by decide
theorem smooth_stable_out0_indices : certifyIndicesB smooth_stable_out0 = true := by decide
theorem table_bad_clamp_out0_indices : certifyIndicesB table_bad_clamp_out0 = false := by decide
theorem table_good_clamp_out0_indices : certifyIndicesB table_good_clamp_out0 = true := by decide
theorem table_unclamped_out0_indices : certifyIndicesB table_unclamped_out0 = false := by decide
theorem tabulate_protected_out0_indices : certifyIndicesB tabulate_protected_out0 = true := by decide
theorem tabulate_unprotected_out0_indices : certifyIndicesB tabulate_unprotected_out0 = false := by decide
theorem tf2_stable_out0_indices : certifyIndicesB tf2_stable_out0 = true := by decide
theorem tf2_unstable_out0_indices : certifyIndicesB tf2_unstable_out0 = true := by decide
theorem tf2s_direct_20hz_out0_indices : certifyIndicesB tf2s_direct_20hz_out0 = true := by decide
theorem tf2snp_exact_out0_indices : certifyIndicesB tf2snp_exact_out0 = true := by decide
theorem tf3slf_low_out0_indices : certifyIndicesB tf3slf_low_out0 = true := by decide
theorem time_marginal_out0_indices : certifyIndicesB time_marginal_out0 = true := by decide
theorem unstable_out0_indices : certifyIndicesB unstable_out0 = true := by decide

/-! ## The rates of `check-precision`, in exact, double and single

Per program and precision, at 44.1, 48, 88.2, 96, 176.4 and 192 kHz:

- each recursion group (`n<k>`, the dump index of its `DEBRUIJNREC`):
  `S` stable, `U` linear but not proven stable, `R` refused (the
  reason follows);
- the time-invariant values: `F` finite, `D` an operation may leave
  its domain or overflow, `?` a value the analysis cannot bound;
- each table read and delay tap: `I` index in range, `N` not proven.

In the comments, the three parts are separated by `|`. -/

-- allpass_comb exact: n12:SSSSSS|FFFFFF|n8:IIIIII
-- allpass_comb double: n12:SSSSSS|FFFFFF|n8:IIIIII
-- allpass_comb single: n12:SSSSSS|FFFFFF|n8:IIIIII
-- bandpass2matched_float exact: n85:SSSSSS|FFFFFF|
-- bandpass2matched_float double: n85:SSSSSS|FFFFFF|
-- bandpass2matched_float single: n85:SSSSSS|FDDDDD(n59 SIGSQRT: argument [-0.000068, 0.030299]; n59 SIGSQRT: argument [-0.048690, 0.058005]; n59 SIGSQRT: argument [-0.059483, 0.067374]; n59 SIGSQRT: argument [-0.216843, 0.219202]; n59 SIGSQRT: argument [-0.257729, 0.259712])|
-- bandpass_tpt exact: n47:SSSSSS|FFFFFF|
-- bandpass_tpt double: n47:SSSSSS|FFFFFF|
-- bandpass_tpt single: n47:SSSSSS|FFFFFF|
-- dcblocker exact: n10:SSSSSS|FFFFFF|
-- dcblocker double: n10:SSSSSS|FFFFFF|
-- dcblocker single: n10:SSSSSS|FFFFFF|
-- delay_sr exact: |FFFFFF|n7:IIIIII
-- delay_sr double: |FFFFFF|n7:IIIIII
-- delay_sr single: |FFFFFF|n7:IIIIII
-- fb_comb exact: n10:SSSSSS|FFFFFF|n5:IIIIII
-- fb_comb double: n10:SSSSSS|FFFFFF|n5:IIIIII
-- fb_comb single: n10:SSSSSS|FFFFFF|n5:IIIIII
-- fb_comb_unstable exact: n10:UUUUUU(small-gain test fails (441 states))|FFFFFF|n5:IIIIII
-- fb_comb_unstable double: n10:UUUUUU(small-gain test fails (441 states))|FFFFFF|n5:IIIIII
-- fb_comb_unstable single: n10:UUUUUU(small-gain test fails (441 states))|FFFFFF|n5:IIIIII
-- fb_fcomb exact: n19:SSSSSS|FFFFFF|n5:IIIIII;n12:IIIIII
-- fb_fcomb double: n19:SSSSSS|FFFFFF|n5:IIIIII;n12:IIIIII
-- fb_fcomb single: n19:SSSSSS|FFFFFF|n5:IIIIII;n12:IIIIII
-- fdelay_clamped exact: |FFFFFF|n5:IIIIII;n13:IIIIII
-- fdelay_clamped double: |FFFFFF|n5:IIIIII;n13:IIIIII
-- fdelay_clamped single: |FFFFFF|n5:IIIIII;n13:IIIIII
-- lowpass3 exact: n26:SSSSSS;n49:SSSSSS|FFFFFF|
-- lowpass3 double: n26:SSSSSS;n49:SSSSSS|FFFFFF|
-- lowpass3 single: n26:SSSSSS;n49:SSSSSS|FFFFFF|
-- lowpass_svf_20hz exact: n30:SSSSSS|FFFFFF|
-- lowpass_svf_20hz double: n30:SSSSSS|FFFFFF|
-- lowpass_svf_20hz single: n30:SSSSSS|FFFFFF|
-- modulated_delay_loop exact: n10:RRRRRR(integer recursion (wrapping semantics));n29:RRRRRR(SIGFLOOR applied to the state);n41:SSSSSS|FFFFFF|n33:NNNNNN;n39:IIIIII
-- modulated_delay_loop double: n10:RRRRRR(integer recursion (wrapping semantics));n29:RRRRRR(SIGFLOOR applied to the state);n41:SSSSSS|FFFFFF|n33:IIIIII;n39:IIIIII
-- modulated_delay_loop single: n10:RRRRRR(integer recursion (wrapping semantics));n29:RRRRRR(SIGFLOOR applied to the state);n41:SSSSSS|FFFFFF|n33:IIIIII;n39:IIIIII
-- noise_lcg exact: n6:RRRRRR(integer recursion (wrapping semantics))|FFFFFF|
-- noise_lcg double: n6:RRRRRR(integer recursion (wrapping semantics))|FFFFFF|
-- noise_lcg single: n6:RRRRRR(integer recursion (wrapping semantics))|FFFFFF|
-- nonlinear exact: n17:RRRRRR(SIGFFUN<math.h> applied to the state)|FFFFFF|
-- nonlinear double: n17:RRRRRR(SIGFFUN<math.h> applied to the state)|FFFFFF|
-- nonlinear single: n17:RRRRRR(SIGFFUN<math.h> applied to the state)|FFFFFF|
-- onepole exact: n8:SSSSSS|FFFFFF|
-- onepole double: n8:SSSSSS|FFFFFF|
-- onepole single: n8:SSSSSS|FFFFFF|
-- osc exact: n7:RRRRRR(integer recursion (wrapping semantics));n26:RRRRRR(SIGFLOOR applied to the state)|FFFFFF|n30:NNNNNN
-- osc double: n7:RRRRRR(integer recursion (wrapping semantics));n26:RRRRRR(SIGFLOOR applied to the state)|FFFFFF|n30:IIIIII
-- osc single: n7:RRRRRR(integer recursion (wrapping semantics));n26:RRRRRR(SIGFLOOR applied to the state)|FFFFFF|n30:IIIIII
-- osc_negative_freq exact: n7:RRRRRR(integer recursion (wrapping semantics));n26:RRRRRR(SIGFLOOR applied to the state)|FFFFFF|n30:NNNNNN
-- osc_negative_freq double: n7:RRRRRR(integer recursion (wrapping semantics));n26:RRRRRR(SIGFLOOR applied to the state)|FFFFFF|n30:NNNNNN
-- osc_negative_freq single: n7:RRRRRR(integer recursion (wrapping semantics));n26:RRRRRR(SIGFLOOR applied to the state)|FFFFFF|n30:NNNNNN
-- resonlp exact: n26:SSSSSS|FFFFFF|n18:IIIIII;n30:IIIIII;n34:IIIIII
-- resonlp double: n26:SSSSSS|FFFFFF|n18:IIIIII;n30:IIIIII;n34:IIIIII
-- resonlp single: n26:SSSSSS|FFFFFF|n18:IIIIII;n30:IIIIII;n34:IIIIII
-- smoo_sr exact: n14:SSSSSS|FFFFFF|
-- smoo_sr double: n14:SSSSSS|FFFFFF|
-- smoo_sr single: n14:SSSSSS|FFFFFF|
-- smooth_stable exact: n8:SSSSSS|FFFFFF|
-- smooth_stable double: n8:SSSSSS|FFFFFF|
-- smooth_stable single: n8:SSSSSS|FFFFFF|
-- table_bad_clamp exact: |FFFFFF|n6:NNNNNN
-- table_bad_clamp double: |FFFFFF|n6:NNNNNN
-- table_bad_clamp single: |FFFFFF|n6:NNNNNN
-- table_good_clamp exact: |FFFFFF|n4:IIIIII
-- table_good_clamp double: |FFFFFF|n4:IIIIII
-- table_good_clamp single: |FFFFFF|n4:IIIIII
-- table_unclamped exact: |FFFFFF|n4:NNNNNN
-- table_unclamped double: |FFFFFF|n4:NNNNNN
-- table_unclamped single: |FFFFFF|n4:NNNNNN
-- tabulate_protected exact: n5:RRRRRR(integer recursion (wrapping semantics))|FFFFFF|n25:IIIIII
-- tabulate_protected double: n5:RRRRRR(integer recursion (wrapping semantics))|FFFFFF|n25:IIIIII
-- tabulate_protected single: n5:RRRRRR(integer recursion (wrapping semantics))|FFFFFF|n25:IIIIII
-- tabulate_unprotected exact: n5:RRRRRR(integer recursion (wrapping semantics))|FFFFFF|n23:NNNNNN
-- tabulate_unprotected double: n5:RRRRRR(integer recursion (wrapping semantics))|FFFFFF|n23:NNNNNN
-- tabulate_unprotected single: n5:RRRRRR(integer recursion (wrapping semantics))|FFFFFF|n23:NNNNNN
-- tf2_stable exact: n10:SSSSSS|FFFFFF|n5:IIIIII;n13:IIIIII;n16:IIIIII
-- tf2_stable double: n10:SSSSSS|FFFFFF|n5:IIIIII;n13:IIIIII;n16:IIIIII
-- tf2_stable single: n10:SSSSSS|FFFFFF|n5:IIIIII;n13:IIIIII;n16:IIIIII
-- tf2_unstable exact: n10:UUUUUU(Jury fails on the box)|FFFFFF|n5:IIIIII;n13:IIIIII;n16:IIIIII
-- tf2_unstable double: n10:UUUUUU(Jury fails on the box)|FFFFFF|n5:IIIIII;n13:IIIIII;n16:IIIIII
-- tf2_unstable single: n10:UUUUUU(Jury fails on the box)|FFFFFF|n5:IIIIII;n13:IIIIII;n16:IIIIII
-- tf2s_direct_20hz exact: n26:SSSSSS|FFFFFF|n18:IIIIII;n30:IIIIII;n34:IIIIII
-- tf2s_direct_20hz double: n26:SSSSSS|FFFFFF|n18:IIIIII;n30:IIIIII;n34:IIIIII
-- tf2s_direct_20hz single: n26:SSUUUU(Jury fails on the box)|FFFFFF|n18:IIIIII;n30:IIIIII;n34:IIIIII
-- tf2snp_exact exact: n51:RRRRRR(part of an enclosing group (analysed with it));n58:UUUUUU(small-gain test fails (4 states))|FFFFFF|
-- tf2snp_exact double: n51:RRRRRR(part of an enclosing group (analysed with it));n58:UUUUUU(small-gain test fails (4 states))|FFFFFF|
-- tf2snp_exact single: n51:RRRRRR(part of an enclosing group (analysed with it));n58:UUUUUU(small-gain test fails (4 states))|FFFFFF|
-- tf3slf_low exact: n40:UUUUUU(small-gain test fails (3 states))|FFFFFF|n22:IIIIII;n30:IIIIII;n47:IIIIII;n52:IIIIII;n58:IIIIII
-- tf3slf_low double: n40:UUUUUU(small-gain test fails (3 states))|FFFFFF|n22:IIIIII;n30:IIIIII;n47:IIIIII;n52:IIIIII;n58:IIIIII
-- tf3slf_low single: n40:UUUUUU(small-gain test fails (3 states))|FFFFFF|n22:IIIIII;n30:IIIIII;n47:IIIIII;n52:IIIIII;n58:IIIIII
-- time_marginal exact: n5:RRRRRR(integer recursion (wrapping semantics))|FFFFFF|
-- time_marginal double: n5:RRRRRR(integer recursion (wrapping semantics))|FFFFFF|
-- time_marginal single: n5:RRRRRR(integer recursion (wrapping semantics))|FFFFFF|
-- unstable exact: n7:UUUUUU(Jury fails on the box)|FFFFFF|
-- unstable double: n7:UUUUUU(Jury fails on the box)|FFFFFF|
-- unstable single: n7:UUUUUU(Jury fails on the box)|FFFFFF|

theorem allpass_comb_rates_exact : verdicts allpass_comb_dag .exact = ⟨[(12, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], [(8, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem allpass_comb_rates_double : verdicts allpass_comb_dag .double = ⟨[(12, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], [(8, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem allpass_comb_rates_single : verdicts allpass_comb_dag .single = ⟨[(12, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], [(8, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem bandpass2matched_float_rates_exact : verdicts bandpass2matched_float_dag .exact = ⟨[(85, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem bandpass2matched_float_rates_double : verdicts bandpass2matched_float_dag .double = ⟨[(85, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem bandpass2matched_float_rates_single : verdicts bandpass2matched_float_dag .single = ⟨[(85, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .domain, .domain, .domain, .domain, .domain], []⟩ := by decide +kernel
theorem bandpass_tpt_rates_exact : verdicts bandpass_tpt_dag .exact = ⟨[(47, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem bandpass_tpt_rates_double : verdicts bandpass_tpt_dag .double = ⟨[(47, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem bandpass_tpt_rates_single : verdicts bandpass_tpt_dag .single = ⟨[(47, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem dcblocker_rates_exact : verdicts dcblocker_dag .exact = ⟨[(10, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem dcblocker_rates_double : verdicts dcblocker_dag .double = ⟨[(10, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem dcblocker_rates_single : verdicts dcblocker_dag .single = ⟨[(10, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem delay_sr_rates_exact : verdicts delay_sr_dag .exact = ⟨[], [.finite, .finite, .finite, .finite, .finite, .finite], [(7, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem delay_sr_rates_double : verdicts delay_sr_dag .double = ⟨[], [.finite, .finite, .finite, .finite, .finite, .finite], [(7, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem delay_sr_rates_single : verdicts delay_sr_dag .single = ⟨[], [.finite, .finite, .finite, .finite, .finite, .finite], [(7, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem fb_comb_rates_exact : verdicts fb_comb_dag .exact = ⟨[(10, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], [(5, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem fb_comb_rates_double : verdicts fb_comb_dag .double = ⟨[(10, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], [(5, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem fb_comb_rates_single : verdicts fb_comb_dag .single = ⟨[(10, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], [(5, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem fb_comb_unstable_rates_exact : verdicts fb_comb_unstable_dag .exact = ⟨[(10, [.unproven, .unproven, .unproven, .unproven, .unproven, .unproven])], [.finite, .finite, .finite, .finite, .finite, .finite], [(5, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem fb_comb_unstable_rates_double : verdicts fb_comb_unstable_dag .double = ⟨[(10, [.unproven, .unproven, .unproven, .unproven, .unproven, .unproven])], [.finite, .finite, .finite, .finite, .finite, .finite], [(5, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem fb_comb_unstable_rates_single : verdicts fb_comb_unstable_dag .single = ⟨[(10, [.unproven, .unproven, .unproven, .unproven, .unproven, .unproven])], [.finite, .finite, .finite, .finite, .finite, .finite], [(5, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem fb_fcomb_rates_exact : verdicts fb_fcomb_dag .exact = ⟨[(19, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], [(5, [true, true, true, true, true, true]), (12, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem fb_fcomb_rates_double : verdicts fb_fcomb_dag .double = ⟨[(19, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], [(5, [true, true, true, true, true, true]), (12, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem fb_fcomb_rates_single : verdicts fb_fcomb_dag .single = ⟨[(19, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], [(5, [true, true, true, true, true, true]), (12, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem fdelay_clamped_rates_exact : verdicts fdelay_clamped_dag .exact = ⟨[], [.finite, .finite, .finite, .finite, .finite, .finite], [(5, [true, true, true, true, true, true]), (13, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem fdelay_clamped_rates_double : verdicts fdelay_clamped_dag .double = ⟨[], [.finite, .finite, .finite, .finite, .finite, .finite], [(5, [true, true, true, true, true, true]), (13, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem fdelay_clamped_rates_single : verdicts fdelay_clamped_dag .single = ⟨[], [.finite, .finite, .finite, .finite, .finite, .finite], [(5, [true, true, true, true, true, true]), (13, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem lowpass3_rates_exact : verdicts lowpass3_dag .exact = ⟨[(26, [.stable, .stable, .stable, .stable, .stable, .stable]), (49, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem lowpass3_rates_double : verdicts lowpass3_dag .double = ⟨[(26, [.stable, .stable, .stable, .stable, .stable, .stable]), (49, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem lowpass3_rates_single : verdicts lowpass3_dag .single = ⟨[(26, [.stable, .stable, .stable, .stable, .stable, .stable]), (49, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem lowpass_svf_20hz_rates_exact : verdicts lowpass_svf_20hz_dag .exact = ⟨[(30, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem lowpass_svf_20hz_rates_double : verdicts lowpass_svf_20hz_dag .double = ⟨[(30, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem lowpass_svf_20hz_rates_single : verdicts lowpass_svf_20hz_dag .single = ⟨[(30, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem modulated_delay_loop_rates_exact : verdicts modulated_delay_loop_dag .exact = ⟨[(10, [.refused, .refused, .refused, .refused, .refused, .refused]), (29, [.refused, .refused, .refused, .refused, .refused, .refused]), (41, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], [(33, [false, false, false, false, false, false]), (39, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem modulated_delay_loop_rates_double : verdicts modulated_delay_loop_dag .double = ⟨[(10, [.refused, .refused, .refused, .refused, .refused, .refused]), (29, [.refused, .refused, .refused, .refused, .refused, .refused]), (41, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], [(33, [true, true, true, true, true, true]), (39, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem modulated_delay_loop_rates_single : verdicts modulated_delay_loop_dag .single = ⟨[(10, [.refused, .refused, .refused, .refused, .refused, .refused]), (29, [.refused, .refused, .refused, .refused, .refused, .refused]), (41, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], [(33, [true, true, true, true, true, true]), (39, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem noise_lcg_rates_exact : verdicts noise_lcg_dag .exact = ⟨[(6, [.refused, .refused, .refused, .refused, .refused, .refused])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem noise_lcg_rates_double : verdicts noise_lcg_dag .double = ⟨[(6, [.refused, .refused, .refused, .refused, .refused, .refused])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem noise_lcg_rates_single : verdicts noise_lcg_dag .single = ⟨[(6, [.refused, .refused, .refused, .refused, .refused, .refused])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem nonlinear_rates_exact : verdicts nonlinear_dag .exact = ⟨[(17, [.refused, .refused, .refused, .refused, .refused, .refused])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem nonlinear_rates_double : verdicts nonlinear_dag .double = ⟨[(17, [.refused, .refused, .refused, .refused, .refused, .refused])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem nonlinear_rates_single : verdicts nonlinear_dag .single = ⟨[(17, [.refused, .refused, .refused, .refused, .refused, .refused])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem onepole_rates_exact : verdicts onepole_dag .exact = ⟨[(8, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem onepole_rates_double : verdicts onepole_dag .double = ⟨[(8, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem onepole_rates_single : verdicts onepole_dag .single = ⟨[(8, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem osc_rates_exact : verdicts osc_dag .exact = ⟨[(7, [.refused, .refused, .refused, .refused, .refused, .refused]), (26, [.refused, .refused, .refused, .refused, .refused, .refused])], [.finite, .finite, .finite, .finite, .finite, .finite], [(30, [false, false, false, false, false, false])]⟩ := by decide +kernel
theorem osc_rates_double : verdicts osc_dag .double = ⟨[(7, [.refused, .refused, .refused, .refused, .refused, .refused]), (26, [.refused, .refused, .refused, .refused, .refused, .refused])], [.finite, .finite, .finite, .finite, .finite, .finite], [(30, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem osc_rates_single : verdicts osc_dag .single = ⟨[(7, [.refused, .refused, .refused, .refused, .refused, .refused]), (26, [.refused, .refused, .refused, .refused, .refused, .refused])], [.finite, .finite, .finite, .finite, .finite, .finite], [(30, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem osc_negative_freq_rates_exact : verdicts osc_negative_freq_dag .exact = ⟨[(7, [.refused, .refused, .refused, .refused, .refused, .refused]), (26, [.refused, .refused, .refused, .refused, .refused, .refused])], [.finite, .finite, .finite, .finite, .finite, .finite], [(30, [false, false, false, false, false, false])]⟩ := by decide +kernel
theorem osc_negative_freq_rates_double : verdicts osc_negative_freq_dag .double = ⟨[(7, [.refused, .refused, .refused, .refused, .refused, .refused]), (26, [.refused, .refused, .refused, .refused, .refused, .refused])], [.finite, .finite, .finite, .finite, .finite, .finite], [(30, [false, false, false, false, false, false])]⟩ := by decide +kernel
theorem osc_negative_freq_rates_single : verdicts osc_negative_freq_dag .single = ⟨[(7, [.refused, .refused, .refused, .refused, .refused, .refused]), (26, [.refused, .refused, .refused, .refused, .refused, .refused])], [.finite, .finite, .finite, .finite, .finite, .finite], [(30, [false, false, false, false, false, false])]⟩ := by decide +kernel
theorem resonlp_rates_exact : verdicts resonlp_dag .exact = ⟨[(26, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], [(18, [true, true, true, true, true, true]), (30, [true, true, true, true, true, true]), (34, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem resonlp_rates_double : verdicts resonlp_dag .double = ⟨[(26, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], [(18, [true, true, true, true, true, true]), (30, [true, true, true, true, true, true]), (34, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem resonlp_rates_single : verdicts resonlp_dag .single = ⟨[(26, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], [(18, [true, true, true, true, true, true]), (30, [true, true, true, true, true, true]), (34, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem smoo_sr_rates_exact : verdicts smoo_sr_dag .exact = ⟨[(14, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem smoo_sr_rates_double : verdicts smoo_sr_dag .double = ⟨[(14, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem smoo_sr_rates_single : verdicts smoo_sr_dag .single = ⟨[(14, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem smooth_stable_rates_exact : verdicts smooth_stable_dag .exact = ⟨[(8, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem smooth_stable_rates_double : verdicts smooth_stable_dag .double = ⟨[(8, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem smooth_stable_rates_single : verdicts smooth_stable_dag .single = ⟨[(8, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem table_bad_clamp_rates_exact : verdicts table_bad_clamp_dag .exact = ⟨[], [.finite, .finite, .finite, .finite, .finite, .finite], [(6, [false, false, false, false, false, false])]⟩ := by decide +kernel
theorem table_bad_clamp_rates_double : verdicts table_bad_clamp_dag .double = ⟨[], [.finite, .finite, .finite, .finite, .finite, .finite], [(6, [false, false, false, false, false, false])]⟩ := by decide +kernel
theorem table_bad_clamp_rates_single : verdicts table_bad_clamp_dag .single = ⟨[], [.finite, .finite, .finite, .finite, .finite, .finite], [(6, [false, false, false, false, false, false])]⟩ := by decide +kernel
theorem table_good_clamp_rates_exact : verdicts table_good_clamp_dag .exact = ⟨[], [.finite, .finite, .finite, .finite, .finite, .finite], [(4, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem table_good_clamp_rates_double : verdicts table_good_clamp_dag .double = ⟨[], [.finite, .finite, .finite, .finite, .finite, .finite], [(4, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem table_good_clamp_rates_single : verdicts table_good_clamp_dag .single = ⟨[], [.finite, .finite, .finite, .finite, .finite, .finite], [(4, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem table_unclamped_rates_exact : verdicts table_unclamped_dag .exact = ⟨[], [.finite, .finite, .finite, .finite, .finite, .finite], [(4, [false, false, false, false, false, false])]⟩ := by decide +kernel
theorem table_unclamped_rates_double : verdicts table_unclamped_dag .double = ⟨[], [.finite, .finite, .finite, .finite, .finite, .finite], [(4, [false, false, false, false, false, false])]⟩ := by decide +kernel
theorem table_unclamped_rates_single : verdicts table_unclamped_dag .single = ⟨[], [.finite, .finite, .finite, .finite, .finite, .finite], [(4, [false, false, false, false, false, false])]⟩ := by decide +kernel
theorem tabulate_protected_rates_exact : verdicts tabulate_protected_dag .exact = ⟨[(5, [.refused, .refused, .refused, .refused, .refused, .refused])], [.finite, .finite, .finite, .finite, .finite, .finite], [(25, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem tabulate_protected_rates_double : verdicts tabulate_protected_dag .double = ⟨[(5, [.refused, .refused, .refused, .refused, .refused, .refused])], [.finite, .finite, .finite, .finite, .finite, .finite], [(25, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem tabulate_protected_rates_single : verdicts tabulate_protected_dag .single = ⟨[(5, [.refused, .refused, .refused, .refused, .refused, .refused])], [.finite, .finite, .finite, .finite, .finite, .finite], [(25, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem tabulate_unprotected_rates_exact : verdicts tabulate_unprotected_dag .exact = ⟨[(5, [.refused, .refused, .refused, .refused, .refused, .refused])], [.finite, .finite, .finite, .finite, .finite, .finite], [(23, [false, false, false, false, false, false])]⟩ := by decide +kernel
theorem tabulate_unprotected_rates_double : verdicts tabulate_unprotected_dag .double = ⟨[(5, [.refused, .refused, .refused, .refused, .refused, .refused])], [.finite, .finite, .finite, .finite, .finite, .finite], [(23, [false, false, false, false, false, false])]⟩ := by decide +kernel
theorem tabulate_unprotected_rates_single : verdicts tabulate_unprotected_dag .single = ⟨[(5, [.refused, .refused, .refused, .refused, .refused, .refused])], [.finite, .finite, .finite, .finite, .finite, .finite], [(23, [false, false, false, false, false, false])]⟩ := by decide +kernel
theorem tf2_stable_rates_exact : verdicts tf2_stable_dag .exact = ⟨[(10, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], [(5, [true, true, true, true, true, true]), (13, [true, true, true, true, true, true]), (16, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem tf2_stable_rates_double : verdicts tf2_stable_dag .double = ⟨[(10, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], [(5, [true, true, true, true, true, true]), (13, [true, true, true, true, true, true]), (16, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem tf2_stable_rates_single : verdicts tf2_stable_dag .single = ⟨[(10, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], [(5, [true, true, true, true, true, true]), (13, [true, true, true, true, true, true]), (16, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem tf2_unstable_rates_exact : verdicts tf2_unstable_dag .exact = ⟨[(10, [.unproven, .unproven, .unproven, .unproven, .unproven, .unproven])], [.finite, .finite, .finite, .finite, .finite, .finite], [(5, [true, true, true, true, true, true]), (13, [true, true, true, true, true, true]), (16, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem tf2_unstable_rates_double : verdicts tf2_unstable_dag .double = ⟨[(10, [.unproven, .unproven, .unproven, .unproven, .unproven, .unproven])], [.finite, .finite, .finite, .finite, .finite, .finite], [(5, [true, true, true, true, true, true]), (13, [true, true, true, true, true, true]), (16, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem tf2_unstable_rates_single : verdicts tf2_unstable_dag .single = ⟨[(10, [.unproven, .unproven, .unproven, .unproven, .unproven, .unproven])], [.finite, .finite, .finite, .finite, .finite, .finite], [(5, [true, true, true, true, true, true]), (13, [true, true, true, true, true, true]), (16, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem tf2s_direct_20hz_rates_exact : verdicts tf2s_direct_20hz_dag .exact = ⟨[(26, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], [(18, [true, true, true, true, true, true]), (30, [true, true, true, true, true, true]), (34, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem tf2s_direct_20hz_rates_double : verdicts tf2s_direct_20hz_dag .double = ⟨[(26, [.stable, .stable, .stable, .stable, .stable, .stable])], [.finite, .finite, .finite, .finite, .finite, .finite], [(18, [true, true, true, true, true, true]), (30, [true, true, true, true, true, true]), (34, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem tf2s_direct_20hz_rates_single : verdicts tf2s_direct_20hz_dag .single = ⟨[(26, [.stable, .stable, .unproven, .unproven, .unproven, .unproven])], [.finite, .finite, .finite, .finite, .finite, .finite], [(18, [true, true, true, true, true, true]), (30, [true, true, true, true, true, true]), (34, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem tf2snp_exact_rates_exact : verdicts tf2snp_exact_dag .exact = ⟨[(51, [.refused, .refused, .refused, .refused, .refused, .refused]), (58, [.unproven, .unproven, .unproven, .unproven, .unproven, .unproven])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem tf2snp_exact_rates_double : verdicts tf2snp_exact_dag .double = ⟨[(51, [.refused, .refused, .refused, .refused, .refused, .refused]), (58, [.unproven, .unproven, .unproven, .unproven, .unproven, .unproven])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem tf2snp_exact_rates_single : verdicts tf2snp_exact_dag .single = ⟨[(51, [.refused, .refused, .refused, .refused, .refused, .refused]), (58, [.unproven, .unproven, .unproven, .unproven, .unproven, .unproven])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem tf3slf_low_rates_exact : verdicts tf3slf_low_dag .exact = ⟨[(40, [.unproven, .unproven, .unproven, .unproven, .unproven, .unproven])], [.finite, .finite, .finite, .finite, .finite, .finite], [(22, [true, true, true, true, true, true]), (30, [true, true, true, true, true, true]), (47, [true, true, true, true, true, true]), (52, [true, true, true, true, true, true]), (58, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem tf3slf_low_rates_double : verdicts tf3slf_low_dag .double = ⟨[(40, [.unproven, .unproven, .unproven, .unproven, .unproven, .unproven])], [.finite, .finite, .finite, .finite, .finite, .finite], [(22, [true, true, true, true, true, true]), (30, [true, true, true, true, true, true]), (47, [true, true, true, true, true, true]), (52, [true, true, true, true, true, true]), (58, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem tf3slf_low_rates_single : verdicts tf3slf_low_dag .single = ⟨[(40, [.unproven, .unproven, .unproven, .unproven, .unproven, .unproven])], [.finite, .finite, .finite, .finite, .finite, .finite], [(22, [true, true, true, true, true, true]), (30, [true, true, true, true, true, true]), (47, [true, true, true, true, true, true]), (52, [true, true, true, true, true, true]), (58, [true, true, true, true, true, true])]⟩ := by decide +kernel
theorem time_marginal_rates_exact : verdicts time_marginal_dag .exact = ⟨[(5, [.refused, .refused, .refused, .refused, .refused, .refused])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem time_marginal_rates_double : verdicts time_marginal_dag .double = ⟨[(5, [.refused, .refused, .refused, .refused, .refused, .refused])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem time_marginal_rates_single : verdicts time_marginal_dag .single = ⟨[(5, [.refused, .refused, .refused, .refused, .refused, .refused])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem unstable_rates_exact : verdicts unstable_dag .exact = ⟨[(7, [.unproven, .unproven, .unproven, .unproven, .unproven, .unproven])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem unstable_rates_double : verdicts unstable_dag .double = ⟨[(7, [.unproven, .unproven, .unproven, .unproven, .unproven, .unproven])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel
theorem unstable_rates_single : verdicts unstable_dag .single = ⟨[(7, [.unproven, .unproven, .unproven, .unproven, .unproven, .unproven])], [.finite, .finite, .finite, .finite, .finite, .finite], []⟩ := by decide +kernel

/-! ## Compiler clamp oracle

Per program, Lean's as-written table verdicts confronted with the
clamps the compiler actually inserted (`--dump-sig-dag-prepared`,
`-ct 1` versus `-ct 0`). Recorded by `sig2lean.py`; a defect —
a `clampRequired` table left unclamped — fails generation instead
of being recorded here.

allpass_comb.dsp: no table site
bandpass2matched_float.dsp: no table site
bandpass_tpt.dsp: no table site
dcblocker.dsp: no table site
delay_sr.dsp: no table site
fb_comb.dsp: no table site
fb_comb_unstable.dsp: no table site
fb_fcomb.dsp: no table site
fdelay_clamped.dsp: no table site
lowpass3.dsp: no table site
lowpass_svf_20hz.dsp: no table site
modulated_delay_loop.dsp: missed optimisation: compiler clamps table[65536] though Lean proves it in range
noise_lcg.dsp: no table site
nonlinear.dsp: no table site
onepole.dsp: no table site
osc.dsp: missed optimisation: compiler clamps table[65536] though Lean proves it in range
osc_negative_freq.dsp: missed optimisation: compiler clamps table[65536] though Lean proves it in range
resonlp.dsp: no table site
smoo_sr.dsp: no table site
smooth_stable.dsp: no table site
table_bad_clamp.dsp: agree on table[16]
table_good_clamp.dsp: agree on table[16]
table_unclamped.dsp: agree on table[16]
tabulate_protected.dsp: agree on table[128]
tabulate_unprotected.dsp: agree on table[128]
tf2_stable.dsp: no table site
tf2_unstable.dsp: no table site
tf2s_direct_20hz.dsp: no table site
tf2snp_exact.dsp: no table site
tf3slf_low.dsp: no table site
time_marginal.dsp: no table site
unstable.dsp: no table site
-/

end Faust.Signal.Generated