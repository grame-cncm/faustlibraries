/-
  Deep certification: discharging the Jury obligation with mathlib.

  The Std-only specifications (`signal-import-formal-spec.lean`,
  `tf2s-stability-formal-spec.lean`) record as a *standing obligation* the
  classical equivalence

      order-2 Jury criterion  ⟺  both roots strictly inside the unit disc.

  This file proves it. `juryStableB` — the executable test every `STABLE`
  verdict goes through — is shown to certify exactly "all poles of
  `z² + a₁z + a₂` have norm < 1". The Boolean test is imported unchanged
  from the Std-only prelude (via the `FaustSignal` symlink), so there is no
  copy that could drift.

  Also discharged: positivity of `c = 1/tan(w)` for a cutoff below Nyquist
  (`0 < w < π/2`), the hypothesis `hc : 0 < c` of the `tf2s` theorem.

  This project is optional and heavier than the Std-only flow: it pins
  mathlib and is built by `make certify-deep` only. `make certify` never
  depends on it.
-/
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Basic
import Mathlib.Analysis.Complex.Basic
import Mathlib.Tactic
import FaustSignal

namespace Faust.Signal.Deep
open Faust.Signal

/-- The real value denoted by an exact coefficient. Meaningful under the
    well-formedness assumption `0 < q.d` the whole prelude works under. -/
noncomputable def qval (q : Q) : ℝ := (q.n : ℝ) / (q.d : ℝ)

/-! ## The analytic core: degree-2 Schur-Cohn over ℝ/ℂ -/

/-- Forward: the Jury conditions put every root of `z² + a₁z + a₂` strictly
    inside the unit disc. The imaginary part of the root equation forces
    either a real root (handled through the sign of the polynomial at `±1`)
    or a conjugate pair, whose squared norm is exactly `a₂`. -/
theorem roots_lt_one_of_jury {a1 a2 : ℝ} (h2 : |a2| < 1) (h1 : |a1| < 1 + a2) :
    ∀ z : ℂ, z ^ 2 + (a1 : ℂ) * z + (a2 : ℂ) = 0 → ‖z‖ < 1 := by
  obtain ⟨h2l, h2r⟩ := abs_lt.mp h2
  obtain ⟨h1l, h1r⟩ := abs_lt.mp h1
  intro z hz
  have hre : z.re ^ 2 - z.im ^ 2 + a1 * z.re + a2 = 0 := by
    have h := congrArg Complex.re hz
    simp only [pow_two, Complex.add_re, Complex.mul_re, Complex.ofReal_re,
      Complex.ofReal_im, Complex.zero_re, zero_mul, sub_zero] at h
    ring_nf at h ⊢
    linarith [h]
  have him : z.im * (2 * z.re + a1) = 0 := by
    have h := congrArg Complex.im hz
    simp only [pow_two, Complex.add_im, Complex.mul_im, Complex.ofReal_re,
      Complex.ofReal_im, Complex.zero_im, zero_mul, add_zero] at h
    ring_nf at h ⊢
    linarith [h]
  have hsq : z.re ^ 2 + z.im ^ 2 < 1 → ‖z‖ < 1 := by
    intro h
    have hlt : ‖z‖ ^ 2 < 1 := by
      rw [Complex.sq_norm, Complex.normSq_apply]
      nlinarith [h]
    have habs := (sq_lt_one_iff_abs_lt_one ‖z‖).mp hlt
    rwa [abs_of_nonneg (norm_nonneg z)] at habs
  apply hsq
  rcases mul_eq_zero.mp him with hy0 | hx0
  · -- real root: x² + a₁x + a₂ = 0 with |x| < 1 forced by the sign at ±1.
    rw [hy0]
    have hre' : z.re ^ 2 + a1 * z.re + a2 = 0 := by
      rw [hy0] at hre
      linarith [hre]
    have hE1 : (1 - z.re) * (1 + z.re + a1) = 1 + a1 + a2 := by
      linear_combination -hre'
    have hE2 : (1 + z.re) * (1 - z.re - a1) = 1 - a1 + a2 := by
      linear_combination -hre'
    have hx1 : z.re < 1 := by
      by_contra hc
      have hc' : 1 ≤ z.re := not_lt.mp hc
      rcases lt_or_eq_of_le hc' with hgt | heq
      · have hneg : 1 + z.re + a1 < 0 := by nlinarith [hE1]
        nlinarith [hre', hneg, hgt]
      · rw [← heq] at hE1
        simp at hE1
        linarith
    have hx2 : -1 < z.re := by
      by_contra hc
      have hc' : z.re ≤ -1 := not_lt.mp hc
      rcases lt_or_eq_of_le hc' with hlt | heq
      · have hneg : 1 - z.re - a1 < 0 := by nlinarith [hE2]
        nlinarith [hre', hneg, hlt]
      · rw [heq] at hE2
        simp at hE2
        linarith
    nlinarith [hx1, hx2]
  · -- conjugate pair: a₁ = -2x, and x² + y² collapses to a₂ < 1.
    have ha1 : a1 = -2 * z.re := by linarith
    nlinarith [hre]

/-- Reverse: if every root is strictly inside the unit disc, the Jury
    conditions hold. The roots are produced explicitly, by case on the sign
    of the discriminant. -/
theorem jury_of_roots_lt_one {a1 a2 : ℝ}
    (h : ∀ z : ℂ, z ^ 2 + (a1 : ℂ) * z + (a2 : ℂ) = 0 → ‖z‖ < 1) :
    |a2| < 1 ∧ |a1| < 1 + a2 := by
  rcases le_or_gt 0 (a1 ^ 2 - 4 * a2) with hd | hd
  · -- nonnegative discriminant: two real roots (-a₁ ± √d)/2.
    have hs2 : Real.sqrt (a1 ^ 2 - 4 * a2) ^ 2 = a1 ^ 2 - 4 * a2 :=
      Real.sq_sqrt hd
    set s := Real.sqrt (a1 ^ 2 - 4 * a2) with hsdef
    have hs2c : ((s : ℂ)) ^ 2 = (a1 : ℂ) ^ 2 - 4 * (a2 : ℂ) := by
      exact_mod_cast congrArg Complex.ofReal hs2
    have hroot1 : (((-a1 + s) / 2 : ℝ) : ℂ) ^ 2
        + (a1 : ℂ) * (((-a1 + s) / 2 : ℝ) : ℂ) + (a2 : ℂ) = 0 := by
      push_cast
      linear_combination hs2c / 4
    have hroot2 : (((-a1 - s) / 2 : ℝ) : ℂ) ^ 2
        + (a1 : ℂ) * (((-a1 - s) / 2 : ℝ) : ℂ) + (a2 : ℂ) = 0 := by
      push_cast
      linear_combination hs2c / 4
    have hr1 : |(-a1 + s) / 2| < 1 := by
      have hb := h _ hroot1
      rwa [Complex.norm_real, Real.norm_eq_abs] at hb
    have hr2 : |(-a1 - s) / 2| < 1 := by
      have hb := h _ hroot2
      rwa [Complex.norm_real, Real.norm_eq_abs] at hb
    obtain ⟨hr1l, hr1r⟩ := abs_lt.mp hr1
    obtain ⟨hr2l, hr2r⟩ := abs_lt.mp hr2
    -- Vieta through explicit sign products; each goal is then linear in
    -- the products, which `nlinarith` closes with `hs2`.
    have hp1 : (0:ℝ) < (1 - (-a1 + s) / 2) * (1 - (-a1 - s) / 2) :=
      mul_pos (by linarith) (by linarith)
    have hp2 : (0:ℝ) < (1 + (-a1 + s) / 2) * (1 + (-a1 - s) / 2) :=
      mul_pos (by linarith) (by linarith)
    have hp3 : (0:ℝ) < (1 - (-a1 + s) / 2) * (1 + (-a1 - s) / 2) :=
      mul_pos (by linarith) (by linarith)
    have hp4 : (0:ℝ) < (1 + (-a1 + s) / 2) * (1 - (-a1 - s) / 2) :=
      mul_pos (by linarith) (by linarith)
    constructor
    · rw [abs_lt]
      constructor
      · nlinarith [hp1, hp2, hs2]
      · nlinarith [hp3, hp4, hs2]
    · rw [abs_lt]
      constructor
      · nlinarith [hp1, hs2]
      · nlinarith [hp2, hs2]
  · -- negative discriminant: conjugate pair -a₁/2 ± i·√(4a₂-a₁²)/2, whose
    -- squared norm is exactly a₂.
    have hpos : (0:ℝ) < 4 * a2 - a1 ^ 2 := by linarith
    have hy2 : (Real.sqrt (4 * a2 - a1 ^ 2) / 2) ^ 2 = (4 * a2 - a1 ^ 2) / 4 := by
      rw [div_pow, Real.sq_sqrt (le_of_lt hpos)]
      ring
    have hy0pos : 0 < Real.sqrt (4 * a2 - a1 ^ 2) / 2 := by
      have := Real.sqrt_pos.mpr hpos
      linarith
    set y0 := Real.sqrt (4 * a2 - a1 ^ 2) / 2 with hy0def
    have hy2c : ((y0 : ℂ)) ^ 2 = (4 * (a2 : ℂ) - (a1 : ℂ) ^ 2) / 4 := by
      exact_mod_cast congrArg Complex.ofReal hy2
    have hI : Complex.I ^ 2 = -1 := Complex.I_sq
    have hroot : (((-a1 / 2 : ℝ) : ℂ) + (y0 : ℂ) * Complex.I) ^ 2
        + (a1 : ℂ) * (((-a1 / 2 : ℝ) : ℂ) + (y0 : ℂ) * Complex.I) + (a2 : ℂ) = 0 := by
      push_cast
      linear_combination (Complex.I ^ 2 : ℂ) * hy2c
        + ((a2 : ℂ) - (a1 : ℂ) ^ 2 / 4) * hI
    have hlt := h _ hroot
    have hn2 : ‖(((-a1 / 2 : ℝ) : ℂ) + (y0 : ℂ) * Complex.I)‖ ^ 2 = a2 := by
      rw [Complex.sq_norm, Complex.normSq_add_mul_I]
      linear_combination hy2
    have ha2nonneg : 0 ≤ a2 := hn2 ▸ sq_nonneg _
    have ha2lt : a2 < 1 := by
      nlinarith [hlt, norm_nonneg (((-a1 / 2 : ℝ) : ℂ) + (y0 : ℂ) * Complex.I), hn2]
    constructor
    · rw [abs_lt]
      exact ⟨by linarith, ha2lt⟩
    · rw [abs_lt]
      constructor
      · nlinarith [hn2, mul_pos hy0pos hy0pos, sq_nonneg (1 + a1 / 2), hy2]
      · nlinarith [hn2, mul_pos hy0pos hy0pos, sq_nonneg (1 - a1 / 2), hy2]

/-! ## The bridge: the executable test computes exactly those conditions -/

/-- `juryStableB` unfolded into the real-valued Jury conditions on the
    denoted coefficients: the four integer comparisons are the two real
    conditions cleared of their (positive) denominators. -/
theorem juryStableB_iff (a : Q × Q) (h1 : 0 < a.1.d) (h2 : 0 < a.2.d) :
    juryStableB a = true ↔ |qval a.2| < 1 ∧ |qval a.1| < 1 + qval a.2 := by
  have hd1 : (0 : ℝ) < (a.1.d : ℝ) := by exact_mod_cast h1
  have hd2 : (0 : ℝ) < (a.2.d : ℝ) := by exact_mod_cast h2
  have hD : (0 : ℤ) < a.1.d * a.2.d := mul_pos h1 h2
  -- |a₂| < 1, cleared of denominators
  have e2 : (a.2.n * a.1.d).natAbs < (a.1.d * a.2.d).natAbs ↔ |qval a.2| < 1 := by
    rw [qval, abs_div, abs_of_pos hd2, div_lt_one hd2,
        ← Nat.cast_lt (α := ℤ), Int.natCast_natAbs, Int.natCast_natAbs,
        abs_of_pos hD, abs_mul, abs_of_pos h1]
    constructor
    · intro hz
      have hzz : |a.2.n| < a.2.d := by nlinarith [hz, h1]
      exact_mod_cast hzz
    · intro hr
      have hzz : |a.2.n| < a.2.d := by exact_mod_cast hr
      nlinarith [hzz, h1, abs_nonneg a.2.n]
  -- a₁ < 1 + a₂, cleared of denominators
  have e3 : (0 : ℤ) < a.1.d * a.2.d + a.2.n * a.1.d - a.1.n * a.2.d ↔
      qval a.1 < 1 + qval a.2 := by
    rw [qval, qval]
    have hone : (1 : ℝ) + (a.2.n : ℝ) / (a.2.d : ℝ) = ((a.2.d : ℝ) + a.2.n) / a.2.d := by
      field_simp
    rw [hone, div_lt_div_iff₀ hd1 hd2]
    constructor
    · intro hz
      have hr : (0:ℝ) < (a.1.d : ℝ) * a.2.d + a.2.n * a.1.d - a.1.n * a.2.d := by
        exact_mod_cast hz
      nlinarith [hr]
    · intro hr
      have hz : (a.1.n : ℤ) * a.2.d < (a.2.d + a.2.n) * a.1.d := by
        exact_mod_cast hr
      nlinarith [hz]
  -- -(1 + a₂) < a₁, cleared of denominators
  have e4 : (0 : ℤ) < a.1.d * a.2.d + a.2.n * a.1.d + a.1.n * a.2.d ↔
      -(1 + qval a.2) < qval a.1 := by
    rw [qval, qval]
    have hone : -((1 : ℝ) + (a.2.n : ℝ) / (a.2.d : ℝ))
        = (-((a.2.d : ℝ) + a.2.n)) / a.2.d := by
      field_simp
    rw [hone, div_lt_div_iff₀ hd2 hd1]
    constructor
    · intro hz
      have hr : (0:ℝ) < (a.1.d : ℝ) * a.2.d + a.2.n * a.1.d + a.1.n * a.2.d := by
        exact_mod_cast hz
      nlinarith [hr]
    · intro hr
      have hz : (-((a.2.d : ℤ) + a.2.n)) * a.1.d < a.1.n * a.2.d := by
        exact_mod_cast hr
      nlinarith [hz]
  simp only [juryStableB, Bool.and_eq_true, decide_eq_true_eq]
  constructor
  · rintro ⟨⟨⟨_, hA⟩, hC3⟩, hC4⟩
    exact ⟨e2.mp hA, abs_lt.mpr ⟨e4.mp hC4, e3.mp hC3⟩⟩
  · rintro ⟨hA, hB⟩
    obtain ⟨hBl, hBr⟩ := abs_lt.mp hB
    exact ⟨⟨⟨hD, e2.mpr hA⟩, e3.mpr hBr⟩, e4.mpr hBl⟩

/-! ## The discharged obligations -/

/-- **The Jury obligation, order 2.** The executable test certifies exactly
    "every pole of `z² + a₁z + a₂` lies strictly inside the unit disc" — the
    equivalence both Std-only specification files record as a standing
    obligation. -/
theorem juryStableB_iff_roots (a : Q × Q) (h1 : 0 < a.1.d) (h2 : 0 < a.2.d) :
    juryStableB a = true ↔
      ∀ z : ℂ, z ^ 2 + (qval a.1 : ℂ) * z + (qval a.2 : ℂ) = 0 → ‖z‖ < 1 := by
  rw [juryStableB_iff a h1 h2]
  constructor
  · rintro ⟨hA, hB⟩
    exact roots_lt_one_of_jury hA hB
  · exact jury_of_roots_lt_one

/-- **The `tf2s` hypothesis.** `c = 1/tan(w)` is positive for any cutoff
    below Nyquist, so `hc : 0 < c` in `tf2s_preserves_stability` is deduced
    rather than assumed. -/
theorem tf2s_c_pos {w : ℝ} (h0 : 0 < w) (h1 : w < Real.pi / 2) :
    0 < 1 / Real.tan w :=
  div_pos one_pos (Real.tan_pos_of_pos_of_lt_pi_div_two h0 h1)

end Faust.Signal.Deep
