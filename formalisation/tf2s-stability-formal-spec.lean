/-
  Lean 4 specification for:

    faustlibraries-code-doc-audit-2026-08-15-en.md, §10.2

  Scope
  -----
  Pilot formalization of one library-level DSP property: the bilinear
  transform performed by `(fi.)tf2s` in `filters.lib` maps a stable analog
  second-order section to a stable digital one.

  It mechanizes:

  * `Section`, a digital second-order denominator `1 + a1·z⁻¹ + a2·z⁻²` kept
    over a common denominator, which clears every division from the statements;
  * `JuryStable` / `juryStableB`, the order-2 Jury (Schur-Cohn) criterion as a
    relational judgment and as an executable checker, with the theorem binding
    them;
  * `tf2sDen`, the denominator mapping transcribed from `filters.lib`;
  * `tf2s_preserves_stability`, the main result, and a rejecting witness.

  The scale factor `c = 1/tan(w1/(2·SR))` enters the argument **only through
  its sign**, so the transcendental is not modelled: `c` is an opaque
  parameter constrained by `0 < c`, which holds exactly for cutoffs below
  Nyquist. The statement is therefore exact rational arithmetic.

  Deliberately out of scope: the frequency response itself, the numerator
  mapping, and floating-point behaviour. This file says nothing about whether
  `filters.lib` *computes* this mapping — that is the numerical oracle's job
  (§10.4). It only says that the mapping, as specified, preserves stability.

  Standing obligation
  -------------------
  The classical equivalence "order-2 Jury criterion ⟺ both roots strictly
  inside the unit disc" is assumed, not proved: proving it needs complex
  analysis, hence mathlib, which this file deliberately avoids. It is recorded
  here as a named obligation rather than silently relied upon.

  This file uses only Lean's bundled Std library. It contains no `sorry` and
  no axioms beyond `propext`, `Classical.choice` and `Quot.sound`. Validate it
  with:

      lean tf2s-stability-formal-spec.lean      # Lean 4.31, bundled Std

  Naming conventions
  ------------------
  Names ending in `B` return `Bool` and can be evaluated. Properties are
  stated and proved on the `Prop` side and reached in `Bool` form through
  `juryStableB_iff`: `decide` does not reduce through `Rat.instDecidableLt`,
  so evaluating the checker on rational literals gets stuck in the kernel.
-/

import Std

namespace Faust.Filters.Bilinear

/-! ## A digital second-order section

Keeping the two denominator coefficients over a common denominator `d` means
every statement below is polynomial: no division, no field reasoning. -/

/-- A digital second-order section with denominator `1 + a1·z⁻¹ + a2·z⁻²`,
    represented as `a1 = n1/d`, `a2 = n2/d`. -/
structure Section where
  n1 : Rat
  n2 : Rat
  d  : Rat

/-! ## The Jury / Schur-Cohn criterion

For `z² + a1·z + a2` the criterion is `|a2| < 1` together with `|a1| < 1 + a2`.
Multiplying through by `d > 0` gives the four polynomial inequalities below. -/

/-- Order-2 Jury criterion, cleared of denominators. -/
def JuryStable (s : Section) : Prop :=
  0 < s.d ∧ 0 < s.d + s.n2 ∧ 0 < s.d - s.n2 ∧
  0 < s.d + s.n2 - s.n1 ∧ 0 < s.d + s.n2 + s.n1

/-- Executable form of the criterion. This is the shape a Rust-side or
    Faust-side oracle must agree with. -/
def juryStableB (s : Section) : Bool :=
  decide (0 < s.d) && decide (0 < s.d + s.n2) && decide (0 < s.d - s.n2) &&
  decide (0 < s.d + s.n2 - s.n1) && decide (0 < s.d + s.n2 + s.n1)

theorem juryStableB_iff (s : Section) : juryStableB s = true ↔ JuryStable s := by
  simp [juryStableB, JuryStable, and_assoc]

/-! ## The `tf2s` denominator mapping -/

/-- Transcribed from `filters.lib`:

        c   = 1/tan(w1*0.5/ma.SR)     -- bilinear-transform scale factor
        d   = a0 + a1*c + c*c
        a1d = 2*(a0 - c*c)/d
        a2d = (a0 - a1*c + c*c)/d

    `a0` and `a1` are the analog denominator coefficients of `s² + a1·s + a0`. -/
def tf2sDen (a0 a1 c : Rat) : Section :=
  { n1 := 2 * (a0 - c * c)
    n2 := a0 - a1 * c + c * c
    d  := a0 + a1 * c + c * c }

/-! ## Main result

The five goals are linear once the products `a1*c` and `c*c` are known
positive, because they collapse to closed forms:

    d + n2      = 2·a0 + 2·c²
    d - n2      = 2·a1·c
    d + n2 - n1 = 4·c²
    d + n2 + n1 = 4·a0

which is why `grind` closes them without a mathlib-grade `linarith`. -/

/-- **The bilinear transform preserves stability.**

    `0 < a0` and `0 < a1` are exactly the Hurwitz conditions for the analog
    prototype `s² + a1·s + a0`; `0 < c` holds for any cutoff below Nyquist.
    The conclusion therefore covers every filter in `filters.lib` built on
    `tf2s`, at any sample rate. -/
theorem tf2s_preserves_stability (a0 a1 c : Rat)
    (ha0 : 0 < a0) (ha1 : 0 < a1) (hc : 0 < c) :
    JuryStable (tf2sDen a0 a1 c) := by
  have hP : 0 < a1 * c := Rat.mul_pos ha1 hc
  have hQ : 0 < c * c := Rat.mul_pos hc hc
  refine ⟨?_, ?_, ?_, ?_, ?_⟩ <;> simp only [tf2sDen] <;> grind

/-- The same conclusion through the executable checker. -/
theorem tf2s_preserves_stability_exec (a0 a1 c : Rat)
    (ha0 : 0 < a0) (ha1 : 0 < a1) (hc : 0 < c) :
    juryStableB (tf2sDen a0 a1 c) = true :=
  (juryStableB_iff _).mpr (tf2s_preserves_stability a0 a1 c ha0 ha1 hc)

/-- A rejecting witness: an unstable analog prototype (`a0 < 0`) must not be
    certified. Without it, a criterion that accepted everything would pass. -/
theorem tf2sDen_rejects_unstable : ¬ JuryStable (tf2sDen (-1) 1 1) := by
  simp only [JuryStable, tf2sDen]
  grind

end Faust.Filters.Bilinear

-- Self-check: no `sorryAx`, no `Lean.ofReduceBool`.
#print axioms Faust.Filters.Bilinear.tf2s_preserves_stability
#print axioms Faust.Filters.Bilinear.tf2s_preserves_stability_exec
#print axioms Faust.Filters.Bilinear.tf2sDen_rejects_unstable
