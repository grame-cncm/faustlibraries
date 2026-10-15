# Faust normalizer rewrites that the libraries work around

Status: analysis, 2026-10-12, on the branch `long-drift`. Line numbers are
those of commit `5c76078f` (`fd.hammer`); later commits of the branch move
`oscillators.lib` by a few lines.

Compiler used for every listing below:

```
FAUST Version 2.90.8
Source commit: e445f3697
```

C++ built with Apple clang 21.0.0 (`-O2`, and `-O3 -ffast-math` where said),
on an Apple M5 (arm64). The names in parentheses (`a_recip_mod.dsp`, ...) are
those of the scratch programs the listings come from; they were not kept, and
each listing quotes the lines that matter, so that it can be redone.

## Introduction

Before generating code, Faust puts every signal expression in a normal form:
it collects monomials, factors common terms, folds constants, merges powers
and quotients, and simplifies a few function identities. On real numbers each
rewrite is an identity. On floating-point numbers some of them change the
result (by moving a rounding onto a small term) or the cost (by putting a
division back where the author had removed it). The libraries work around
these rewrites in about twenty places, mostly with an operation that the
normalizer does not see through: `min(x, ma.MAX)`, or `min(x, 1)` when `x`
is known to be at most 1. This document lists the rewrites, shows each one in
the generated C++, shows that the workaround holds, and says what a compiler
change could offer instead.

The C++ is quoted as generated (`fHslider*`, `fRec*`, `fSlow*`, `fTemp*`),
trimmed to the lines that matter.

## Summary

| # | Mechanism (rewrite) | Sites | Effect | Workaround |
|---|---|---|---|---|
| 1 | `x*(1/c)` back to `x/c`; a control-rate quotient distributed into the per-sample expression | `fi.svf`, `fi.tf2s`, `fi.tf1s`, `fi.tf2_tpt`, `fi.allpass2_noclip`, `_apnoclip_limit`, `fi.peak_eq_rm`, `ts.*` (tonestack), `_sawN_fix` (`os.saw3/4`), `pm.modeFilter`, `_matchedRun` (`ve.*Matched`) | cost: one division per use instead of one per coefficient, and a division on the states' critical path | `1/c : min(ma.MAX)`, `min(a/b, ma.MAX)` |
| 2 | `(a/b)*(a/b)` to `a^2/b^2`; a common divisor factored out of a sum of quotients (`(x/S)^2 + ...` to `(...)/S^2`, `S^4`) | `fi.tf2sb` (`rho1`), `_tf2sbpoles` | NaN (0/0) at `w1 = wc = 0`, single and double; overflow/underflow range of `S^4` | `w1/W1 : min(ma.MAX)`, `w1/S : min(1)` |
| 3 | like terms collected: `a - k*a` to `(1 - k)*a` | `fd.hammer`, `_matchedRun`, `si.smoothq`, (residual in `pm.modeFilter`) | the small `k` is rounded against 1: -3.8 % on the hammer stiffness, +11.6 % on a `smoothq` rate (float) | `(k*a : min(ma.MAX))`, `(step : min(ma.MAX))`; factor the small term out; rewrite the sign (`smoothq`) |
| 4 | sums reassociated, compensation simplified: `((s + y) - s) - y` to `0`, `0.5 - (x - n)` to `n + (0.5 - x)` | `_phasor_fix` (`os.*` in float), `_simplexLattice` (`no.*simplex*`), `_faSin2pi` (`fa.*`), `fd.hammer` (force terms) | Kahan summation becomes the plain sum; an exact range reduction loses up to 6.1e-5 | integer fixed-point accumulators; `min(ma.MAX)` on the reduced value |
| 5 | function identities: `log(exp(x))` to `x`, `(1 + x) - 1` to `x` | `it.interpolate_exponential`, `si.smoothq`, `ma.expm1`, `ma.log1p` | Kahan's `expm1` and Goldberg's `log1p` become the cancelling forms (19 % error at `x = 1e-7`, float) | Taylor series near 0; `sinh`/`atanh` forms |
| 6 | constants folded with a rounded intermediate: `v*SR/44100` to `(v/44100)*SR`; `x/c` to `x*(1/c)` | `re.mono_freeverb`/`stereo_freeverb` (`adaptSR`) | `int` truncates an exact quotient one sample short (1617 to 1616 at 44.1 kHz, float; 225 to 224, double) | integer arithmetic plus rounding (`+ 0.5`) |
| 7 | `x*x` to `x^2` | `_faSq` (`fa.*`) | C++, Rust, Julia, Java, C#, wasm: a multiplication again; Cmajor, JSFX, Codebox: `pow(x, 2)` | `x * (x : min(ma.MAX))` |
| 8 | compile-time evaluation: `1/0` in a constant expression is an error, also in a branch `select2` does not select and behind a `min` barrier; comparisons decided from intervals | `fi.tf2_tpt` (`notchw`, ...), `fi.peak_eq_rm`, `_apnoclip_limit`, `it.interpolate_exponential`, `_faExp2` | compile error for a constant 0 Hz; a NaN guard removed | `max(P, EPSILON^2)`, `select2(d == 0, d, 1)`, `+ (k == 0)`; the test on the unclamped input |

Reproduced: all rewrites of mechanisms 1 to 8 are reproduced with the
compiler above. Not reproduced: the overflow of `S^4` claimed for `fi.tf2sb`
near Nyquist (mechanism 2), and the cost gains for `fi.tf1s` and `os.saw4` on
this machine (mechanism 1, see the timings).

## 1. Reciprocals turned back into divisions

**Rewrite.** A product by a reciprocal `x*(1/c)` is normalized to `x/c`, and
a quotient `a/b` multiplied into an expression has its divisor moved to the
outside of that expression. Each use of the reciprocal becomes a division.
When `c` changes at every sample, the division lands inside the recursion:
`(x - s)*(1/c)` becomes `(x - s)/c`, so the division waits for the state
instead of being computed in parallel with it. With control-rate parameters,
the slow part stays a single reciprocal in the simplest cases, but not when
the quotient is mixed with sample-rate terms (`pm.modeFilter`,
`_matchedRun`).

**Minimal program** (`a_recip_mod.dsp`, coefficient on an input):

```faust
process(g, x) = x : ((- : *(1/(1 + g))) ~ _);
```

```cpp
fRec0[0] = (fRec0[1] - static_cast<float>(input1[i0])) / (static_cast<float>(input0[i0]) + 1.0f);
```

With the barrier (`a_recip_mod_barrier.dsp`, `*(1/(1 + g) : min(ma.MAX))`):

```cpp
fRec0[0] = (fRec0[1] - static_cast<float>(input1[i0])) * std::min<float>(3.4028235e+38f, 1.0f / (static_cast<float>(input0[i0]) + 1.0f));
```

One reciprocal used twice (`q_recip3.dsp`, `x*r + y*r*r`, `r = 1/c`, `c` an
input) becomes two divisions; with the barrier, one:

```cpp
output0[i0] = (fTemp0 + fTemp1 / fTemp2) / fTemp2;                              // no barrier
float fTemp3 = std::min<float>(3.4028235e+38f, 1.0f / fTemp2);                 // barrier
output1[i0] = fTemp3 * (fTemp0 + fTemp1 * fTemp3);
```

With a slider instead of an input (`a_recip.dsp`, `q_recip2.dsp`), the
reciprocal stays one `fSlow` value and no barrier is needed.

**In the libraries.** `fi.svf.lp` with a modulated cutoff (`s_svf_mod_*.dsp`):

```cpp
// no barrier
float fTemp2 = fTemp0 * (4.656613e-10f * ... - (fTemp1 * fRec0[1] + fRec1[1])) / (1.0f + fTemp0 * fTemp1);
// library (filters.lib:6004)
float fTemp2 = fTemp0 * (4.656613e-10f * ... - (fTemp1 * fRec0[1] + fRec1[1])) * std::min<float>(3.4028235e+38f, 1.0f / (1.0f + fTemp0 * fTemp1));
```

`pm.modeFilter` with a slider frequency (`s_modeFilter_slider_*.dsp`,
`c_mode_*.dsp`): without the barriers two divisions enter the per-sample
recursion, the input gain and `f^2` being distributed around the state terms:

```cpp
// no barrier
fRec1[0] = fRec1[1] + 4.0f * (fSlow0 * (0.2f * (fConst5 * (fTemp0 + fVec0[1]) / fSlow0) - (fRec0[1] + fRec1[1] * fSlow1)) / fConst5);
// library (physmodels.lib:751-753)
fRec1[0] = fRec1[1] + fSlow1 * (fSlow2 * (fTemp0 + fVec0[1]) - (fRec0[1] + fRec1[1] * fSlow3));
```

Division counts in the generated code, `-single`, library vs. a copy with the
barriers removed (`strip.py`; `*_cur.lib` / `*_nob.lib`):

| test (parameter) | per-sample, library | per-sample, no barrier | per-block, library | per-block, no barrier |
|---|---|---|---|---|
| `fi.svf.lp` (modulated) | 1 | 1, on the state path | 0 | 0 |
| `fi.tf2s` (modulated) | 1 | 1, on the state path | 0 | 0 |
| `fi.tf1s` (modulated) | 1 | 1, on the state path | 0 | 0 |
| `fi.notchw` = `tf2_tpt` (modulated) | 4 | 8 | 0 | 0 |
| `fi.peak_eq_rm` (modulated) | 2 | 4 | 0 | 0 |
| `fi.allpass2_noclip` (modulated) | 3 | 6 | 0 | 0 |
| `ts.bassman` (modulated) | 3 | 11 | 0 | 0 |
| `ts.bassman` (sliders) | 0 | 0 | 3 | 10 |
| `os.saw4` (modulated) | 1 | 5 | 0 | 0 |
| `pm.modeFilter` (slider) | 0 | 2, in the recursion | 3 | 1 |
| `ve.lowpass2Matched` (slider) | 0 | 3, in the recursion | 10 | 7 |

Residual: in `fi.peak_eq_rm` with `fx` and `tanPiBT` both modulated, the
library still has one division on the state path, from
`d = cs*cs/(1.0 + tanPiBT)` (filters.lib:5283, not behind a barrier):

```cpp
float fTemp8 = fTemp7 * mydsp_faustpower2_f(fTemp5) * fTemp6 * (fTemp0 - (fTemp6 * (fTemp2 + fTemp7) * fRec2[1] + fRec3[1])) / (1.0f + fTemp2);
```

**Cost.** The commit messages report 10-35 % for `fi.svf`/`fi.tf2s` with a
modulated cutoff (06985a1d), and for a modulated `fi.lowpass(1)` 5.1
ns/sample with the former direct form against 3.7 with the reciprocal kept
behind the barrier (ff4c711d). Measured here (best of 11 alternated runs, 2M samples,
`-single -O2`, Apple M5, load average about 7 from other work: indicative
only), no-barrier time / library time: `fi.svf.lp` modulated 1.07 (1.13 with
`-O3 -ffast-math`), `ts.bassman` modulated 1.75 (1.46 with fast-math), but
`fi.tf1s` modulated 0.81 and `os.saw4` modulated 0.71 (1.01 with fast-math).
On this core, removing the barrier made those two faster: the barrier is not
free (`std::min<float>` compiles to a compare and a select on arm64, on the
value's dependency chain). Not re-measured on an idle machine or on x86.

**Workaround cost.** One `min` per reciprocal, per block for control-rate
coefficients, per sample for modulated ones.

**Semantics.** `x*(1/c)` and `x/c` differ by one rounding (the reciprocal's),
so the rewrite is not exact in IEEE arithmetic. It is the direction a
compiler takes for correctness (`x/c` is the correctly rounded one); the
libraries ask for the other direction for speed, which only the author can
choose. A compiler change could stop rewriting `x*(1/c)` when `c` is not
constant (keep the author's reciprocal), or keep the factor that the author
named and multiplied, instead of redistributing it.

## 2. Quotients merged and divisors factored out

**Rewrite.** A product of quotients sharing a divisor is merged into one
quotient of powers: `(a/b)*(a/b)` becomes `a^2/b^2`, and a sum of products of
`x/S` terms is put over a common denominator `S^2` or `S^4`. The author's
normalization (computing the ratios first, which are bounded) disappears.

**Minimal program** (`i_ratio_sq.dsp`):

```faust
W1 = max(w1, wc) : max(ma.MIN);
rho1 = w1/W1;
process(x, y) = x*rho1*rho1, y*rho1b*rho1b;   // rho1b = w1/W1 : min(ma.MAX)
```

```cpp
float fSlow2 = mydsp_faustpower2_f(fSlow0) / mydsp_faustpower2_f(fSlow1);                 // rho1*rho1
float fSlow3 = mydsp_faustpower2_f(std::min<float>(3.4028235e+38f, fSlow0 / fSlow1));     // rho1b*rho1b
```

At `w1 = wc = 0`, `W1 = ma.MIN` and `W1^2` underflows to 0: the first output
is NaN at every sample, in `-single` and in `-double`; the barrier version
gives 0 (checked with the harness).

`_tf2sbpoles` without its `min(1)` (`j_poles_nob.dsp`): `S` is factored out
and `S^4` formed:

```cpp
float fSlow11 = std::max<float>(1.1754944e-38f, std::sqrt(0.5f * (std::sqrt((mydsp_faustpower2_f(fSlow4) + 0.9999999f * mydsp_faustpower4_f(fSlow0)) / mydsp_faustpower4_f(fSlow2)) + std::fabs(-fSlow6))));
```

With `min(1)` (`j_poles_bar.dsp`) the ratios `w1/S`, `wc/S` are computed
first and only their powers appear. At `w1 = wc = 0` the stand-alone function
returns NaN on its second output without the barrier and 1 with it. In the
full `fi.bandpass(2, fl, fu)` (copy `filters_nomin1.lib`) the NaN did not
reach the output at `fl = fu = 0` (`std::max<float>(ma.MIN, NaN)` returns
`ma.MIN` in this C++, which absorbs it), and the outputs at `fu = 0.499*SR`
and `0.4999*SR`, 48 and 192 kHz, were identical to the library's. **Not
reproduced:** the overflow of `w1^4` at `fu = 0.499*SR` reported in ff4c711d;
with the current clamp of the prewarping angle, `S` stays below about 1.2e8
rad/s (`2*SR*tan(0.499*PI)` at 192 kHz), and `S^4` overflows a float only above `S = 1.4e9`. It underflows below
`S = 3e-10` (normal range) and is 0 below about `3e-12`.

**Workaround.** `rho1 = w1/W1 : min(ma.MAX)` (filters.lib:3178),
`r1 = w1/S : min(1)`, `rc = wc/S : min(1)` (filters.lib:3210-3213); `min(1)`
is a no-op because `S = max(w1, wc)`. Cost: one `min` per coefficient update.

**Semantics.** `(a/b)^2 = a^2/b^2` holds on reals; in IEEE it changes the
overflow and underflow range (squares of the operands instead of the bounded
ratio) and turns 0*finite into 0/0. A compiler that keeps a named quotient as
a unit (no merging of a quotient's divisor into a product of quotients) would
avoid it.

## 3. Like terms collected: `a - k*a` to `(1 - k)*a`

**Rewrite.** Monomials of the same signal are collected: `a + k*a`,
`a - k*a` become `(1 + k)*a`, `(1 - k)*a`, and `1 - k` is then folded into
one constant or one `fSlow`. When `k` is small, `1 - k` is rounded at the
precision of 1: the small term keeps only `ulp(1)/k` of relative accuracy.
This undoes the classic increment form of a recursion (`y + v`, `v` small),
which exists to keep small coefficients off the states.

**Minimal program** (`d_collect.dsp`, the increment form of a biquad):

```faust
tick(y, v, x) = y + vn, vn with { vn = v + x - P*y - fq*v; };
```

```cpp
float fSlow1 = 1.0f - static_cast<float>(fHslider1);   // 1 - fq
float fSlow2 = 1.0f - fSlow0;                           // 1 - P
float fTemp1 = fSlow1 * fRec0[1];                       // v*(1 - fq)
fRec1[0] = fTemp0 + fTemp1 + fSlow2 * fRec1[1];         // y*(1 - P)
```

Both small coefficients are collected against 1, and `y + vn` is not formed
as an increment. `-double` gives the same rewrite (`1.0 - fSlow0`), with
`ulp(1) = 2.2e-16`.

**`fd.hammer`** (fds.lib:705-725, commit 5c76078f). The step form
`u[n+1] = u + v[n+1]`, `v[n+1] = C*v - D*u + forceCoeff*F + in`, compiled
without its barriers (`e_hc_fds_nob.dsp`, `omega0Sqr = 1000`):

```cpp
fRec1[0] = fSlow0 + fTemp3 + fTemp0 + 0.9999996f * fRec1[1];   // u - D*u folded to (1 - D)*u
```

`D = 4.3394e-7`; `float(1 - D) = 0.9999996` gives an effective
`D = 4.1723e-7`, a stiffness 3.8 % too small. In `-double` the same line reads
`0.9999995660626259 * fRec1[1]` (relative error on `D` at most about 2.6e-10). The
library keeps the step a unit with one barrier, `u + (vn : min(ma.MAX))`:

```cpp
float fTemp2 = fSlow0 - 4.3393737e-07f * fRec1[1] + 0.9995834f * fRec0[1] + 4.3393739e-10f * fTemp1;
fRec1[0] = fRec1[1] + std::min<float>(3.4028235e+38f, fTemp2);
```

Rendered 2 s (`e_hc_*.dsp`, RMS of the difference to `-double`, relative):
with the barrier 6.5e-6, without 9.4e-5, former `A*u + B*u'` form 0.157;
the same with `-O3 -ffast-math` (6.7e-6, 9.4e-5, 0.161). A barrier on `D*u`
alone does not protect the step (`fds_onlyD.lib`: `u_new` is computed by
re-adding the terms of the step, not from the stored step), and adds nothing
to the barrier on the step: the first version of the rewrite had both, the
second one was dropped.

**`si.smoothq`** (signals.lib:447-450). The step `base + cY*coef`, with
`om = 1 - coef` computed directly, is written `cY - (cY*om - base)`. Written
`cY + (base - cY*om)` (`signals_naive.lib`), the generated code forms
`1 + em1` (`om = -em1`):

```cpp
float fSlow9 = fSlow6 + 1.0f;                       // naive form
float fTemp5 = fTemp3 + fSlow9 * fRec4[1];
float fTemp5 = fRec4[1] + fTemp3 + fSlow6 * fRec4[1];  // library form
```

With `q = 1` (`ratio = 32`), `time = 1 s` at 192 kHz, `om = 1.6e-7` and
`float(1 - om)` gives a rate 11.6 % too high (`time = 0.25 s` at 48 kHz:
5e-4). A 1 s glide at 192 kHz (`t_sq_*.dsp`): RMS gap to double 1.2e-4
(library form) vs. 1.2e-3 (naive form), unchanged with `-O3 -ffast-math`.

Fragility: the library form survives only because of the expression's shape.
With `om` a plain slider (`f_smoothq.dsp`), both spellings are collected:

```cpp
float fSlow1 = 1.0f - static_cast<float>(fHslider1);
fRec0[0] = fSlow0 + fSlow1 * fRec0[1];     // cY + (base - cY*om)
fRec1[0] = fSlow0 + fSlow1 * fRec1[1];     // cY - (cY*om - base)
```

and with `om = 0 - x` (`f_smoothq2.dsp`) only the first is. The protection
is a property of the current normalizer's term ordering, not of the
expression.

**`_matchedRun`** (vaeffects.lib:1415-1446): the recursion is written
`v + P*(g0*x + g1*x' + g2*x'' - y - qq*v)` with `P` factored out, so that
`P` and `fq` never meet a 1 in a sum. For a 20 Hz, Q = 5 biquad, collecting
`y - P*y` costs 3.6e-4 relative on `P` at 48 kHz and 2.6 % at 192 kHz;
`v - fq*v` costs 2.6e-5 on `fq`. (`d_collect_lib.dsp` shows the library
form's code: `fTemp0 = P*(g0*x - (y + qq*v))`, `y_new = fTemp0 + v + y`.)

Residual: `pm.modeFilter` still forms `l + (1 + qq)*bp` (`fSlow3 = min(t/B0,
ma.MAX) + 1.0f` in `c_mode_bar.dsp`, from `ln + qq*bp` with `ln = l + bp`).
The damping `qq` is rounded against 1, a relative error about
`6e-8/qq`: 1e-6 for `modeFilter_test` (440 Hz, t60 1.5 s), up to about 1e-3
for a high frequency and long t60 at 48 kHz (estimate, not rendered).

**Semantics.** Collecting `a - k*a` into `(1 - k)*a` is exact on reals and
rounds differently in IEEE; with `k` a constant it is not even a cost
saving (one multiplication either way). A compiler could keep the author's
order of additions in float (no collection of a signal with coefficients of
different magnitudes), or collect only when both coefficients are exact
constants whose combination is exact.

## 4. Reassociated sums and folded compensations

**Rewrite.** Sums are reordered, and `(s + y) - s` simplifies to `y`. A
Kahan-compensated sum is therefore simplified to the plain sum, and an exact
range reduction (`r = x - rint(x)`, exact by Sterbenz's lemma, then `0.5 - r`,
exact) is reassociated into rounded operations on `x`.

**Kahan** (`m_kahan.dsp`):

```faust
loop(s, c) = t, (t - s) - y with { y = x - c; t = s + y; };
```

```cpp
fRec0[0] = fTemp0 + fRec0[1];        // the compensation c is gone: the plain sum
```

A barrier on `t` alone (`m_kahan_bar.dsp`) is not enough: the compensation is
reassociated into `c + t - (x + s)`:

```cpp
float fTemp1 = std::min<float>(3.4028235e+38f, fTemp0 - fRec1[1] + fRec0[1]);
fRec1[0] = fRec1[1] + fTemp1 - (fTemp0 + fRec0[1]);
```

Barriers on `t` and on `t - s` (`m_kahan_bar2.dsp`) keep it:

```cpp
fRec1[0] = fRec1[1] + std::min<float>(3.4028235e+38f, fTemp1 - fRec0[1]) - fTemp0;
```

Summing `0.1f` 10^6 times: exact value 100000.0015; plain sum, normalized
Kahan and one-barrier Kahan give 100958.344; two-barrier Kahan gives 100000,
also with `-O3 -ffast-math` (the two `fminnm` survive in the arm64 assembly).

**In the libraries.** `_phasor_fix` (oscillators.lib:202-228) and
`_simplexLattice` (noises.lib:980-993) accumulate in integer fixed point
instead; commit ba96bc50 reports that the Kahan attempt generated code
identical to the uncompensated one, which matches the above. Integer
additions are not reassociated by the normalizer and not by `-ffast-math`.

**Range reduction** (`n_rint.dsp`, the fold of `_faSin2pi`, fastmath.lib:239-245):

```cpp
// no barrier: 0.5 - (x - rint(x)) became rint(x) + (0.5 - x)
output0[i0] = ((fTemp2 > 0.25f) ? fTemp1 + (0.5f - fTemp0) : ((fTemp2 < -0.25f) ? fTemp1 + (-0.5f - fTemp0) : fTemp2));
// r = x - rint(x) : min(ma.MAX)
output1[i0] = ((fTemp3 > 0.25f) ? 0.5f - fTemp3 : ((fTemp3 < -0.25f) ? -0.5f - fTemp3 : fTemp3));
```

Emulated in numpy float32 on 200000 uniform `x` in [-2000, 2000]: the
reassociated fold is off by up to 6.1e-5 (2048 ulps of 0.25); the barrier
form is exact.

**`fd.hammer`'s force terms**: in the former `A*u + B*u' + forceCoeff*F`
form the force (an ulp or two of `u`) was added to a `u`-sized sum; the step
form adds it to the small step, and the barrier on the step keeps the step a
unit (see 3).

**Semantics.** Simplifying `(s + y) - s` to `y` is invalid in IEEE
arithmetic: the whole point of the expression is its rounding error. No C
compiler does it without `-ffast-math` (`-fassociative-math`). A compiler fix
is not to reassociate float additions (keep the user's parenthesization), or
at least to recognize `(a + b) - a` and leave it alone.

## 5. Function identities: `log(exp(x))`, `(1 + x) - 1`

**Rewrite.** `log(exp(x))` is simplified to `x` and `(1 + x) - 1` to `x`.
Kahan's `expm1(x) = (u - 1)*x/log(u)`, `u = exp(x)`, and Goldberg's
`log1p(x) = log(u)*x/(u - 1)`, `u = 1 + x`, then become `exp(x) - 1` and
`log(1 + x)`, the cancelling forms they avoid.

**Minimal program** (`g_logexp.dsp`):

```faust
u = exp(x); kahan_expm1 = (u - 1)*x/log(u);
v = 1 + x;  goldberg_log1p = log(v)*x/(v - 1);
```

```cpp
float fSlow1 = std::exp(fSlow0) + -1.0f;      // Kahan's expm1
float fSlow2 = std::log(fSlow0 + 1.0f);       // Goldberg's log1p
```

With `u = exp(x) : min(ma.MAX)` and `v = 1 + x : min(ma.MAX)`
(`g_logexp_bar.dsp`) both formulas survive:

```cpp
float fSlow1 = std::min<float>(3.4028235e+38f, std::exp(fSlow0));
float fSlow2 = fSlow0 * (fSlow1 + -1.0f) / std::log(fSlow1);
```

At `x = 1e-7` (float): exact `expm1` 1.00000006e-7; normalized 1.1920929e-7
(19 % off); with the barrier 1.00000008e-7; `log1p`: exact 9.9999996e-8,
normalized 1.19209282e-7, barrier 9.99999941e-8. Same results with
`-O3 -ffast-math`. (These barrier forms still need Kahan's and Goldberg's
`u == 1` branch, not shown.)

**In the libraries.** `it.interpolate_exponential` (interpolators.lib:411-421)
and `si.smoothq` (signals.lib:430-437) use a Taylor series below |x| = 0.1;
`ma.expm1` and `ma.log1p` (maths.lib:730, 615) use `2*exp(x/2)*sinh(x/2)`
and `2*atanh(x/(2 + x))` (commit f014604c). No barrier there.

**Semantics.** `log(exp(x)) = x` fails in IEEE when `exp(x)` overflows
(`x > 88.7` in float: `log(inf) = inf`) or underflows (`x < -103.3`:
`log(0) = -inf`), and for NaN payloads; `(1 + x) - 1 = x` is the textbook
counterexample of float associativity. `log(exp(x))` is simplified even with
normalization disabled (`FAUST_OPT=FAUST_SIG_NO_NORM`, see below), so it lives
in another simplification pass. A fix: apply it only when the interval of `x`
keeps `exp(x)` finite and normal, and never simplify `(1 + x) - 1` in float.

## 6. Constants folded with a rounded intermediate

**Rewrite.** `val*SR/44100` is reassociated into `(val/44100)*SR`, and
`val/44100` folded into one rounded constant; a division by a constant `c`
becomes a multiplication by the rounded `1/c`.

**Minimal program** (`l_adaptsr.dsp`):

```faust
naive(val) = val*ma.SR/origSR : int;                                     // origSR = 44100
lib(val) = int((m - m % origSR)/origSR + 0.5) with { m = val*int(ma.SR); };  // reverbs.lib:925
```

```cpp
iConst1 = static_cast<int>(0.036666665f * fConst0);                                                    // naive(1617)
iConst4 = static_cast<int>(2.2675737e-05f * static_cast<float>(faust_wrap_sub(iConst3, iConst3 % 44100)) + 0.5f);  // lib(1617)
```

Results: `naive(1617)` gives 1616 at 44.1 kHz, 1759 at 48 kHz, 3233 at 88.2,
6467 at 176.4, 7039 at 192 kHz in `-single`; `naive(225)` gives 224 at 44.1,
449 at 88.2 and 899 at 176.4 kHz in `-double` (the exact values 1617, 1760,
3234, 6468, 7040; 225, 450, 900). `lib` gives the exact value everywhere. Note
that the library form is itself rewritten (its `/origSR` became
`* 2.2675737e-05f`); the `+ 0.5` makes it insensitive to that rounding.

**Semantics.** Reassociating `(v*SR)/c` into `(v/c)*SR` changes the result
in IEEE even when every operand is an exact integer; `x/c` to `x*(1/c)` is
exact only for `c` a power of two. A compiler could fold only the exact
cases, or keep the author's order. With normalization disabled, `naive` is
emitted as `1617.0f * fConst0 / 4.41e+04f` and is right in double, but
still gives 1616 at 44.1 kHz in single (`1617*44100` is not exact in float):
the integer form is needed anyway.

## 7. `x*x` to `x^2`

**Rewrite.** A product of a signal by itself becomes a power (`h_square.dsp`):

```cpp
output0[i0] = mydsp_faustpower2_f(fTemp0);                          // x*x
output1[i0] = fTemp0 * std::min<float>(3.4028235e+38f, fTemp0);    // x * (x : min(ma.MAX))
```

**Effect today.** `mydsp_faustpower2_f` is `value_f * value_f` in C++, and C,
Rust, Julia, Java and C# use the same helper; the WebAssembly backend emits
`f32.mul`. Cmajor, JSFX and Codebox emit a call:

```
output0 <- pow (fTemp0, 2.0f);                                     // Cmajor
obj[dsp.output0] = pow(fTemp0, 2.0000000000000000);                // JSFX
output0_cb = pow(fTemp0_cb, 2.0f);                                 // Codebox
```

The fastmath.lib comment (lines 55-60) cites the WebAssembly backend of older
compilers (`Math.pow`); with this compiler the barrier matters on Cmajor,
JSFX and Codebox, and costs one `f32.min` elsewhere.

**Workaround.** `_faSq(x) = x * (x : min(ma.MAX))` (fastmath.lib:123-124).

**Semantics.** `x*x = x^2` is exact; the issue is only how a backend emits
the power. The fix belongs in the backends: emit `x*x` (and `x*x*x`) for
small integer powers everywhere.

## 8. Compile-time evaluation and interval decisions

**Rewrite.** Constant expressions are evaluated at compile time, and a
division by a constant 0 is an error, including in the branch that a
`select2` does not select and behind a `min` barrier (`u_constdiv*.dsp`):

```faust
process = *(1/P : min(ma.MAX));                  // P = 0: ERROR : division by 0 in 1 / 0
process = *(select2(P == 0, 1/P, 1));            // P = 0: ERROR : division by 0 in 1 / 0
process = *(1/max(P, ma.EPSILON*ma.EPSILON) : min(ma.MAX));   // compiles: 7.0368744e+13f * x
```

Comparisons whose operand has a known interval are decided and removed
(`o_interval.dsp`):

```cpp
output0[i0] = ((1) ? fTemp1 : -126.0f);                       // test on the clamped xc
output1[i0] = ((fTemp0 >= -126.0f) ? fTemp1 : -126.0f);       // test on x
```

**Workarounds.** `Pc = max(P, ma.EPSILON*ma.EPSILON)`, `Sc` likewise
(filters.lib:1230-1234, commit 786b850e: `notchw` and `peak_eq_rm` at a
constant 0 Hz or SR/2 stopped compiling); `sn = max(sin(th), ma.EPSILON)`
(filters.lib:5277); `ds = select2(d == 0, d, 1)` (filters.lib:2424) and
`tcs` (2411); `em1(k) + (k == 0)` (interpolators.lib:418-421); misceffects.lib:1662.
In `_faExp2` (fastmath.lib:203-213) the NaN guard tests `x`, not the clamped
`xc`, whose interval would remove it (WebAssembly's `f32.min/max` let a NaN
through, and the table index conversion then traps).

**Semantics.** IEEE gives `1/0 = inf` and `select2` discards it; the compile
error is stricter than the run-time semantics. A warning, or evaluating to
`inf` in a non-selected branch, would remove these guards. The interval
decision is valid only if the interval accounts for NaN, which a clamp by
`max`/`min` does not exclude on every backend.

## The barrier and its fragility

`min(x, ma.MAX)` is used as an identity that the normalizer treats as an
opaque operation. It is not quite an identity, and its opacity is a property
of the current compiler:

- **Values.** It maps `+inf` to `ma.MAX`. NaN depends on the argument order
  and the backend (`p_nan.dsp`, C++ `-O2`): `x : min(ma.MAX)` generates
  `std::min<float>(3.4028235e+38f, x)`, which returns `ma.MAX` for a NaN;
  `min(x, ma.MAX)` generates `std::min<float>(x, 3.4028235e+38f)`, which
  returns the NaN. With `-O3 -ffast-math` both returned `ma.MAX`. WebAssembly
  `f32.min` propagates NaN; the ocpp backend emits `fminf`, which returns the
  non-NaN operand. The libraries use both spellings.
- **Cost.** A compare and a select (or `fminnm` under fast-math) per use; on
  the measured core, enough to make `fi.tf1s` and `os.saw4` slower than
  their unprotected versions (mechanism 1).
- **Interval analysis.** The compiler already decides comparisons from
  intervals (mechanism 8), but it does not remove `min` when the interval is
  below the bound: `min(slider in [0, 1], ma.MAX)`, `min(clamped x, ma.MAX)`,
  `min(sin(x), 1)` and `x : max(0) : min(1) : min(1)` all keep their `min`
  (`o_minmax.dsp`). A rule `min(x, c) -> x when hi(x) <= c` would be valid on
  intervals for most barrier sites (any finite slider-derived value is below
  `ma.MAX`; `1/(1 + g)` with `g` in [0, 1] is in [0.5, 1]), and IEEE-correct
  only if the interval also excludes `inf` and NaN. The `min(1)` barriers of
  `_tf2sbpoles` (`w1/max(w1, wc)`) could survive it, since an interval of a
  quotient does not know that the numerator is at most the denominator.
- **What would break** if such a rule landed: every barrier-protected
  rewrite above comes back at once, with no compile error. Mechanisms 2 and 3
  change outputs (NaN at `w1 = wc = 0`; the precision losses), so the
  precision tests may show them; which tests would fail was not checked.
  Mechanism 1 changes no output (only rounding) and would show only in a CPU
  measurement (`make check-cpu`); mechanism 7 only in the Cmajor, JSFX and
  Codebox code. The workarounds that do not use a barrier (integer
  accumulators, Taylor series, the integer `adaptSR`, the sign trick of
  `si.smoothq`) would not be affected by such a rule.
- **`-ffast-math`.** Checked numerically with `-O3 -ffast-math`: the
  two-barrier Kahan sum, `fd.hammer`, the `si.smoothq` glide and the barrier
  forms of Kahan's `expm1` and Goldberg's `log1p` give the same results as
  `-O2`; `fminnm` survives in the assembly. Fast-math did not undo any of the
  workarounds tested, and did not repair any normalized form either. (Only
  these cases were tested; `make check-precision-matrix` covers the library
  tests.)

## What a compiler change could offer

- **An explicit opaque identity.** A primitive (or an attribute on a
  definition) that the normalizer keeps as a unit and the backends emit as
  nothing. It would replace every `min(ma.MAX)`/`min(1)` without their
  run-time cost and without changing `inf` and NaN.
- **Normalization off.** `FAUST_OPT=FAUST_SIG_NO_NORM` already exists
  (`faust --help`). Tested on the minimal programs: it keeps `x*(1/c)`,
  `v - fq*v`, `cY + (base - cY*om)`, the Kahan compensation, `(1 + x) - 1`,
  `0.5 - r`, `rho1*rho1`, the `w1/S` ratios and `x*x` as written, and
  `fd.hammer` without barriers then matches the library (6.7e-6 against
  double). It does not stop `log(exp(x))` to `x` or `x*0` to `0`. It is
  global and loses the useful rewrites: `ts.bassman` modulated without
  barriers has 6 divisions per sample with it, against 3 for the library
  and 11 normalized. Not tested on the whole test suite.
- **IEEE-respecting normalization.** Keep the user's parenthesization of
  floating-point sums and products, as C does without `-ffast-math`, while
  still folding exact cases (`x + 0`, `x*1`, constants whose result is
  exact). This alone removes mechanisms 3, 4 and 6, and most of 2.
- **Narrower rules.** Do not turn `x*(1/c)` into `x/c` when `c` is not a
  constant; do not merge a named quotient into a product of quotients; do not
  collect `a + k*a` unless `k` and `1 + k` are exact; never simplify
  `(a + b) - a`; restrict `log(exp(x)) -> x` to an interval where `exp(x)` is
  finite and normal.
- **IEEE-questionable simplifications seen on the way** (`v_semantics.dsp`):
  `(a - b)/(a - b)` to `1`, `log(a) - log(a)` to `0`, `a*(1/b)*b` to `a`,
  `(a - b)*0` to `0`. All four are NaN or inf in IEEE for some inputs
  (`a = b`; `a <= 0`; `b = 0`; `a - b` infinite). The first three are
  normalizer rewrites (they disappear with `FAUST_SIG_NO_NORM`), the last is
  not.
- **Backends.** Emit `x*x` rather than `pow(x, 2)` in Cmajor, JSFX and
  Codebox.
- **Constant `1/0`.** A warning and `inf`, or no evaluation of a branch that
  a constant `select2` does not select.

## Sites

Line numbers at `5c76078f`.

| File:line | Function | Mechanism | Workaround |
|---|---|---|---|
| fastmath.lib:55-60 | (library comment) | 4, 7 | describes both barriers |
| fastmath.lib:123-124 | `_faSq` (all `fa.*` polynomials) | 7 | `x * (x : min(ma.MAX))` |
| fastmath.lib:203-213 | `_faExp2` | 8 (interval) | NaN test on `x`, not `xc` |
| fastmath.lib:239-245 | `_faSin2pi` | 4 | `r = x - rint(x) : min(ma.MAX)` |
| fds.lib:705-725 | `fd.hammer` | 3, 4 | step form, `(vn : min(ma.MAX))` |
| filters.lib:1230-1246 | `fi.tf2_tpt` (`notchw`, `peak_eq_rm`-like sections) | 1, 8 | four reciprocals behind `min(ma.MAX)`; `max(P, EPSILON^2)` |
| filters.lib:2409-2413 | `fi.allpass2_noclip` | 1, 8 | `rtc = 1/tcs : min(ma.MAX)`; `tcs = select2(tc == 0, tc, 1)` |
| filters.lib:2421-2432 | `_apnoclip_limit` | 1, 8 | `r = share/ds : min(ma.MAX)`; `ds = select2(d == 0, d, 1)` |
| filters.lib:2576 | `fi.tf2s` | 1 | `*(1/(...) : min(ma.MAX))` |
| filters.lib:2860-2863 | `fi.tf1s` | 1 | `k = 1/(...) : min(ma.MAX)` |
| filters.lib:3178 | `_tf2sbr` (`fi.tf2sb`, `bandpass`, `bandstop`, ...) | 2 | `rho1 = w1/W1 : min(ma.MAX)` |
| filters.lib:3210-3213 | `_tf2sbpoles` | 2 | `w1/S : min(1)`, `wc/S : min(1)` |
| filters.lib:5272-5283 | `fi.peak_eq_rm` | 1, 8 | `isc = 1/(sn*cs) : min(ma.MAX)`; `sn = max(sin(th), EPSILON)`; residual division `d` |
| filters.lib:5997-6004 | `fi.svf` | 1 | `*(1/(1 + g*(g+k)) : min(ma.MAX))` |
| interpolators.lib:411-421 | `it.interpolate_exponential` | 5, 8 | Taylor series; `+ (k == 0)` |
| maths.lib:615, 730 | `ma.log1p`, `ma.expm1` | 5 | `atanh`, `sinh` forms (commit f014604c) |
| misceffects.lib:1662 | (comment) | 8 | constant 0 guarded |
| noises.lib:980-993 | `_simplexLattice` | 4 | 30-bit fixed point |
| oscillators.lib:202-228 | `_phasor_fix` (float `os.*` phasors) | 4 | integer phase |
| oscillators.lib:1194 | `_sawN_fix` (`os.saw3`, `os.saw4`) | 1 | `R0 = SR/f : min(ma.MAX)` |
| physmodels.lib:744-758 | `pm.modeFilter` | 1, (3 residual) | `min(..., ma.MAX)` on `f2`, `qq`, `gi` |
| reverbs.lib:919-925 | `adaptSR` (`re.mono_freeverb`, `re.stereo_freeverb`) | 6 | integer form with `+ 0.5` |
| signals.lib:430-437 | `si.smoothq` (`em1`) | 5 | Taylor series |
| signals.lib:447-450 | `si.smoothq` (step) | 3 | `cY - (cY*om - base)` (shape-dependent, see 3) |
| tonestacks.lib:148-156 | `_tonestack` (`ts.*`) | 1 | `r2`, `r3`, `dn` behind `min(ma.MAX)` |
| vaeffects.lib:1415-1446 | `_matchedRun` (`ve.*Matched`) | 1, 3 | `P` factored out; `min(x/P, ma.MAX)` |

Related commits: 06985a1d (svf/tf2s reciprocals), ff4c711d (tf1s, tf2sb
barriers), 786b850e (constant 0 Hz), 5094e45a (allpass noclip reciprocals),
69cc662a (tonestacks), 5f75048f (saw3/saw4), 15be6acc (modeFilter),
ba96bc50 (fixed-point phasor, Kahan folded), d7481b4c (freeverb lengths),
ab215987 (smoothq), a085925f (interpolate_exponential), f014604c
(expm1/log1p), 37b82142 (fastmath), 5c76078f (hammer), 11a469c4 (precision
matrix).
