# Long-render drifts: why 45 tests drift in single precision

Status: analysis, 2026-10-12, with the fixes made on the branch `long-drift`
(see [What the branch changed](#what-the-branch-changed)). The experiments
were run on scratch copies of the libraries.

## Context

`make check-long` (`scripts/check_long.py`, commit `df34da2b`) renders every
test for 120 s at 192 kHz in `-single` and in `-double`, through
`arch/long_arch.cpp`, which streams per-second statistics instead of the samples.
Its `drift` criterion compares the per-second RMS of the two renders. A
second fails when all of the following hold:

- it comes after the 2 s warm-up and is above the 1e-5 RMS floor;
- its relative gap exceeds 1e-2;
- the gap exceeds 10 times the largest gap of the first 8 s after the warm-up.

The first run pinned 134 entries in `tests/long-baseline.json`:

| kind | entries | reason |
|---|---|---|
| `subnormal` | 68 | decays to zero without flushing denormals (`faust -ftz 0`) |
| `drift` | 12 | the RMS compressors' sliding or cumulative sums accumulate their rounding |
| `drift` | 7 | the `os.oscr*` tests: the undamped rotation of `fi.nlf2` |
| `nonfinite` | 2 | `FTZ_test`, `MIN_test`: `ma.MIN * 1e307` is infinite in single precision |
| `drift` (one also `growth`) | **45** | **"cause not analysed"**: the subject of this document |

The 45 are the 32 DX7 `algorithm*_test` plus:

- `operator_modulated`, `flute_ui_MIDI`, `greyhole_demo`, `hammer`, `hammer_slider`;
- `latch_demo`, `lf_imptrain`, `logsweep`, `phasor_modulated`, `saw4_jump`;
- `sawtooth_demo` (`drift` and `growth`), `unwrap`, `virtual_analog_oscillator_demo`.

All 45 now have an identified cause.

## Summary

| Mechanism | Entries | Location | Nature |
|---|---|---|---|
| [1. DX7 operator phasor in plain float](#1-the-dx7-operator-phasor-accumulates-in-plain-float) | 33: `algorithm1..32`, `operator_modulated` | `dx7/operator.lib:173` | library defect |
| [2. Undamped rotation of `fi.nlf2`](#2-the-undamped-rotation-of-finlf2) | 4: `greyhole_demo`, `logsweep`, `latch_demo`, `unwrap` | `filters.lib:1938`, through `os.oscr*` | library defect (`logsweep`, the reverb LFOs); test excitation (`unwrap`, `latch_demo`) |
| [3. Dead band of `si.smooth`](#3-the-dead-band-of-sismooth--sismoo) | 3: `virtual_analog_oscillator_demo`, `sawtooth_demo`, `flute_ui_MIDI` | `signals.lib:381` | library defect, wide reach |
| [4. `f/SR` rounding shown by an exactly periodic excitation](#4-the-rounding-of-fsr-made-visible-by-an-exactly-periodic-excitation) | 3: `phasor_modulated`, `saw4_jump`, `lf_imptrain` | the tests | test artifact; the phasor is exact |
| [5. Hammer oscillator coefficients in float](#5-hammer-the-oscillators-coefficients-lose-its-stiffness-in-float) | 2: `hammer`, `hammer_slider` | `fds.lib:705` | library defect (first taken for a cancellation at release) |
| [6. Program change at release](#6-sawtooth_demo-growth-the-excitation-not-a-drift) | the `growth` of `sawtooth_demo` | the test's switches | expected |

**What they have in common.** No failure comes from a float time counter
saturating after 2^24 frames (87 s at 192 kHz), the first target of
`check-long`.

- **Phase offsets.** Most drifts start from a small constant error in single
  precision: a frequency, a position or an amplitude, which double
  precision does not have. Over a long hold it builds up into a phase offset,
  and the release second or a beat pattern is very sensitive to that phase.
  The gap therefore grows gradually from the first seconds, appears at every
  rate, and changes, sometimes in sign, with the rate.
- **Amplitude.** Only mechanism 2 alters an amplitude directly.

**Method.** Each test was profiled second by second in both precisions, with
the same harness and control schedule as `check-long`. A cause counted as
confirmed in one of these ways:

- replacing one sub-function in a scratch copy removed the gap;
- a float32 C emulation of the generated code reproduced the measured
  values;
- varying the hold length or the rate changed the gap as the cause predicts.

---

## 1. The DX7 operator phasor accumulates in plain float

**Entries:** `algorithm1_test` .. `algorithm32_test`, `operator_modulated_test`.

```faust
// dx7/operator.lib:173
m_hsp_phasor(freq, reset, phase) = (select2(reset, +(freq/ma.SR), phase) : ma.decimal) ~ _;
```

**Mechanism.**

- The phase is a float sum of `freq/SR`, wrapped by `ma.decimal`. The
  rounding of each addition is biased by the magnitude of the phase, so the
  effective frequency is off by a constant amount: 2.5e-3 Hz at 400 Hz and
  192 kHz, 6e-6 relative.
- Over the hold, that is 0.005 cycle of phase error after 2 s and 0.149
  cycle after 60 s.
- The envelope is computed in integers and plays no part. With `R4 = 99` it
  halves every ~80 samples (0.4 ms, a sixth of a period), so the energy of
  the release second is about sin² of the phase at release.

**Evidence.**

- During the hold the per-second gap stays at 7e-5. That is the same
  frequency error, seen in an RMS.
- At release the gap grows with the hold length:

  | hold | 2 s | 20 s | 40 s | 60 s | 80 s |
  |---|---|---|---|---|---|
  | release-second gap | 1.3 % | 12 % | 21 % | 27 % | 31 % |

  The release-second peak grows with it, from 0.44 to 0.73.

**`operator_modulated_test` is the extreme case.** All its pitch-envelope
levels are 0, and `pitchenv_tab(0) = -128` scaled by `*524288.0`
(`dx7/pitchenv.lib:40`) is −2^26, i.e. −4 octaves. With transpose −12 the
carrier runs at 220/16 = 13.75 Hz.

- At that frequency the increment is close to the ulp of the phase. At
  192 kHz, `inc·2^24 = 1201.47` rounds to 1201 in [0.5, 1), a frequency
  error of −2.03e-4, −0.33 cycle in 120 s.
- In double, the per-second RMS alternates between even (0.70324) and odd
  (0.71095) seconds. Single slides from one state to the other, and the
  swap is complete at about 86 s, as a 0.25-cycle slip predicts.
- At 48 and 96 kHz (`inc·2^24` = 4805.9 and 2402.9) the error is 5.4e-6, and
  the gap stays below 5e-5.

**Fix (tested).** `os.lf_sawpos` already uses the exact fixed-point
`_phasor_fix` in single precision (`oscillators.lib:197`):

```faust
m_hsp_phasor(freq, reset, phase) = os.lf_sawpos_phase_reset(freq, phase, reset);
```

On `algorithm1`, after a 60 s hold, the release-second gap drops from 27 %
to 7.2e-5, and the hold gap from 7e-5 to 2.8e-8. The double output moves
slightly, so the dx7 references would be regenerated.

Separately, setting the pitch-envelope levels of `operator_modulated_test`
to the neutral 50 would test a more meaningful carrier.

---

## 2. The undamped rotation of `fi.nlf2`

**Entries:** `greyhole_demo_test`, `logsweep_test`, `latch_demo_test`,
`unwrap_test`. The seven `os.oscr*` entries already in the baseline have
the same cause.

```faust
// filters.lib:1938
nlf2(f,r,x) = ((_<:_,_),(_<:_,_) : (*(s),*(c),*(c),*(0-s)) :> (*(r),+(x))) ~ cross
with { th = 2*ma.PI*f/ma.SR; c = cos(th); s = sin(th); ... };
// oscillators.lib:1929, 1958, 1984, 2013
oscrq(f) = impulse : fi.nlf2(f,1);    oscrs = ... : _,!;    oscrc = ... : !,_;    oscr = oscrs;
```

**Mechanism.**

- With `r = 1`, the gain per sample is `sqrt(c² + s²)`. In float32 the
  rounded `c` and `s` give `c² + s² − 1` of about ±2e-8 instead of 0.
- The amplitude therefore changes as `(c² + s²)^(n/2)`, compounded over 23
  million samples. Its sign, and the drift's direction, depend on how `c`
  and `s` happen to round at that frequency and rate.
- Double precision does the same, about 1e-9 times slower.

**`unwrap_test` = `os.oscrc(100) : ma.unwrap(ma.PI)`** (`tests/maths_tests.dsp:69`)

- `ma.unwrap` plays no part: |x| ≤ 1 < π, so it never adds a 2π correction,
  and the double output is just the cosine (RMS 0.7071).
- At 192 kHz, `c² + s² − 1 = −1.96e-8` predicts a peak of 0.799 at 119 s;
  0.800 is observed.
- At 48 kHz it is +4.11e-8, which predicts 1.093 at 90 s; 1.093 is observed.
- **Verdict:** the test's excitation, not `unwrap`. A phase ramp, which
  would actually exercise `unwrap`, or `os.tosc`, would be a better input.

**`latch_demo_test`** (`demos.lib:2030`)

- `x = os.oscr(f)` with `f = SR/1000` (192 Hz at 192 kHz), latched by a clock
  `0.5*os.oscrs(5*f)`.
- For `x`, `+2.0e-8` predicts a peak of 1.257 at 119 s; 1.254 is observed.
- The clock decays (−5.4e-8, down to about 0.54). The latch only passes on
  `x`'s error, with small shifts of the sampling instants.
- **Verdict:** the demo's sources. Use `os.osc` or `os.tosc`.

**`logsweep_test` = `an.logsweep(20, 2000, 5)`** (`analyzers.lib:2189`)

```faust
logsweep(fs, fe, dur) = fs * (fe/fs) ^ os.lf_sawpos(1/dur) : os.oscrs;
```

- The decay is slow and almost linear, about 9e-5 per second: a gap of 1e-3
  at 8 s, crossing 1e-2 near 105 s. The single-precision peak is 0.989 at
  119 s.
- The phase is integer and wraps; it is not the cause. `c` and `s` are
  recomputed every sample, and their determinant errors partly cancel: the
  average `c² + s² − 1` is −2.5e-10, about 0.25 % of loss by 120 s.
- Rounding inside the float recursion itself adds about 0.75 %. A float32
  C emulation of the generated code gives an RMS of 0.6999 at 120 s, against
  0.6994 measured.
- **Verdict:** a library defect; `logsweep` inherits the undamped rotation.

**`greyhole_demo_test`** (`reverbs.lib:1132`)

```faust
~((de.fdelay4(512, 10 + depth + depth*os.oscrc(freq)), de.fdelay4(512, 10 + depth + depth*os.oscrs(freq))) ...
```

- The single-precision RMS rises linearly from second 0, from 0.9537 to
  0.9641, with no step at 60 s; the gap reaches 1.08e-2 at 119 s.
- At 48 kHz the gap is larger and of opposite sign (−2.9e-2).
- At the LFO's 2 Hz, `c² + s² − 1` is −5.1e-8 at 48 kHz, +1.7e-8 at
  96 kHz and +4.3e-9 at 192 kHz, where `c` rounds to exactly 1.0. A C
  simulation gives an LFO amplitude ×1.051 at 192 kHz and ×0.825 at 48 kHz
  after 120 s, and the chorus depth drifts with it.
- **Proof:** with `mod_depth = 0`, the gap is 2.9e-7 and flat.
- **Verdict:** a library defect. `jpverb`, in the same environment, uses the
  same LFOs.

**Fix options (not measured yet).**

- **Amplitude correction inside the loop**, in `os.oscrq` and so in all of
  `oscr*`. This is the classic AGC of the coupled form: multiply the state
  by `g = 1.5 − 0.5·(y0² + y1²)` every sample. It costs 3 multiplications
  and an addition, no division, and holds the amplitude at 1 in float. The
  references of every `oscr*` test and caller would change: a deliberate
  behavior change.
- **Callers that only need a sine/cosine pair** (the reverb LFOs, `logsweep`)
  switch to a phase accumulator, e.g. `cos(2*ma.PI*os.lf_sawpos(freq))`,
  or to `os.quadosc` (`oscillators.lib:2079`), a shear form whose
  determinant is 1 by construction.
- **Tests and demos:** switch the excitation to `os.tosc` / `os.osc`.

---

## 3. The dead band of `si.smooth` / `si.smoo`

**Entries:** `virtual_analog_oscillator_demo_test`, `sawtooth_demo_test`,
`flute_ui_MIDI_test`.

```faust
// signals.lib:381
(0,s) => \(x).(fb ~ _ with { fb(y) = (1.0 - s) * x + s * y; });
// signals.lib:213
smoo = si.smooth(1 - 44.1/ma.SR);
```

**Mechanism.**

- In float the state stops moving once `(1 − s)·|x − y|` falls below half
  an ulp of `y`. It then sticks up to `ulp(x) / (2(1 − s))` away from its
  target, i.e. about `ulp(x)·tau·SR/2`.
- Like any float one-pole that stores `y`, the error grows with the rate
  and with the time constant. In theory, at the demos' 10 s maximum
  portamento, the dead band reaches about 29 Hz at 192 kHz.

**`virtual_analog_oscillator_demo_test`** (`demos.lib:1836`)

- Code: `sfreq = freq : si.smooth(ba.tau2pole(portamento))`, with a default
  portamento of 0.1 s and `1 − s = 5.2e-5` at 192 kHz.
- In single precision, `sfreq` stalls at 439.65 Hz (−7.9e-4), or 439.71 Hz
  with FMA.
- The three saws at 440 Hz ×0.999, ×1 and ×1.001 share that error, so their
  beat pattern, which repeats every 25 s in double, drifts against double.
  The gap oscillates with the pattern, and its envelope grows linearly:
  1.2e-2 at 15 s, 3.8e-2 around 50 s, 7.9e-2 at 115 s.
- **Proof:**
  - the three saws behind this smoother reproduce the profile (7.86e-2);
  - without the smoother the gap is 4.6e-3, the residue of the increment
    rounding;
  - the stall offset is proportional to SR (−5.2e-6 at 48 kHz).

**`sawtooth_demo_test`** (`demos.lib:1726`)

- Same code. `sfreq` sticks at 440 − 0.293 Hz at 192 kHz (−0.073 Hz at
  48 kHz), 1.15 cent flat.
- The three detuned saws beat at 0.44 / 0.88 Hz. Their beat pattern drifts
  against double by about 0.018 beat cycle per minute, which puts the
  per-second RMS gaps at 1–8 %.
- The oscillators themselves (`_sawN_flt(2)` on the fixed-point phasor) are
  fine. A replica with a constant 440 gives gaps of 4e-4 to 1.5e-3, against
  1.3e-2 to 4.4e-2 with the smoother.
- `oscrs_demo` (`demos.lib:1946`) has the same line.

**`flute_ui_MIDI_test`** (`physmodels.lib:3038-3040`)

- Code: `mouthPosition = hslider(..., 0.5, 0, 1, 0.01) : si.smoo`. In
  single, the smoother sticks at 0.5 − 1.28e-4 at 192 kHz (0.5 − 1.4e-5 at
  48 kHz). That moves the embouchure and slightly retunes the
  self-oscillating tube.
- The oscillation phase then drifts against double, and the state at
  release decorrelates.
  - The gap is not monotonic: it settles around 1–4 % from about 10 s of
    hold (3e-2 at 60 s, 4.8e-2 at 48 kHz).
  - Double's own release RMS swings from 0.0160 to 0.0167 depending on the
    hold length.
- Ruled out one at a time:
  - the vibrato (`os.osc`, fixed-point in single);
  - the breath noise;
  - the `si.polySmooth` bend, which lands exactly on 1;
  - the 1 ms envelope smoother.
- **Open oddity, not investigated:** smoothing `mouthPosition` up from 0
  puts the flute in a different steady state (RMS 0.395) than a constant
  0.5 does (0.316), in both precisions.

**Fix.** Smooth the error rather than the value. A decay toward 0 cannot
stall in float:

```faust
// signals.lib, si.smooth = imp(3)
(3,s) => \(x).(x + (fb ~ _ with { fb(e) = s * (e + (x' - x : min(ma.MAX))); }));
```

- It equals `y[n] = (1 − s)·x[n] + s·y[n−1]` from the first sample, and
  converges exactly to `x`. Its recursion is as short as the former one's
  (an addition and a multiplication); it adds a subtraction and an
  addition outside it.
- Release gaps, before → after (first measured on scratch copies):

  | test | before | after |
  |---|---|---|
  | `flute_ui_MIDI` | 3e-2 | 1.7e-6 (2 s hold), 1.1e-4 (60 s hold) |
  | `sawtooth_demo` | 4.4e-2 | 8.7e-4 (60 s) |

- **`-ffast-math` undid the first version**, `s * (e + x' - x)`: clang
  reassociated `(x' − x) + e'` into `(x' + e') − x`, whose sum rounds at the
  scale of `x` again, and the dead band came back (the smoother stalled at
  0.69998568 for a target of 0.7). `min(ma.MAX)`, a no-op that the
  compiler does not reassociate across, keeps `x' − x` computed first. It
  sits outside the recursion.
- **Pinned** by `smooth_deadband_test`: its second output is 1 where the
  smoother is still more than 1e-15 from a constant target after 0.9 s. It
  is 0 with the new form, in both precisions and under `-ffast-math`; the
  former form stalls a few ulps short of the target, in double as in
  single, and gives 1 for the whole last 0.1 s.
- **Reach.** `si.smooth` / `si.smoo` appear in 16 libraries (49 uses in
  `demos.lib`, 45 in `physmodels.lib`). No double reference of the 2325
  tests changes beyond 1e-5.

---

## 4. The rounding of `f/SR`, made visible by an exactly periodic excitation

**Entries:** `phasor_modulated_test`, `saw4_jump_test`, `lf_imptrain_test`.

**The phasor is not drifting.**

- In `-single`, `_phasor_imp` is `_phasor_fix` (`oscillators.lib:197`), an
  exact integer accumulator. It sums the float increment
  `inc = f/ma.SR` exactly (`oscillators.lib:222`).
- The only error left is the float rounding of that increment, about
  5e-8 relative. The phase drifts linearly with it, while double rounds at
  about 1e-16.
- Each of these tests pins the phase at the moments that dominate the
  per-second measurement. That makes this tiny linear drift visible.

**`phasor_modulated_test`** (`tests/oscillators_tests.dsp:11`;
`os.phasor(1024, 2000*(2*tri − 1))`, a 10 Hz triangle between −2000 and
+2000 Hz)

- Profile: gradual and linear from second 0, unaffected by the release.
  The single-precision RMS climbs from 591.23 to 599.2 while double stays at
  591.19 (a 1.33e-2 gap at 119 s).
- The frequency has zero mean, so in exact arithmetic the phase comes back
  to the same offset every period. The output dwells at the turnarounds,
  where the frequency is 0, so the RMS depends strongly on that offset.
- Measured: the float increments of one period sum to −4.84e-6 cycles
  instead of 0, i.e. −0.0058 cycles over 1200 periods. In a double
  simulation, an offset of −0.005 to −0.0075 cycles gives an RMS of 596 to
  600.6, as observed.
- **Fix (test, done):** build the frequency from integers, so that the
  values ±k occur equally often and round symmetrically. The per-period sum
  is then exactly 0, and the gap stays at 1.5e-4 over two minutes:

  ```faust
  freq = 2000.0*k/P with { k = P - 2*abs(2*ba.period(P) - P); };
  ```

**`saw4_jump_test`** (`tests/oscillators_tests.dsp:67`; the frequency jumps
between 20 and 2000 Hz every 0.1 s)

- Profile: gradual and linear from 0 s, 1e-2 at 53 s and 2.2e-2 at 119 s,
  with the same slope at 48 kHz, so it is not a frame count.
- Each 0.2 s period holds exactly 2 + 200 = 202 cycles, so every jump lands
  on the same phase, 0.
- The output is dominated by the jump transients of `_sawN_fix(4)`, the term
  `(g − g')*R0*0.5*Q2` (`oscillators.lib:1211`), which peaks at about 7e4.
  Q2 depends on the phase at the jump.
- The rounding of `T0 = f/ma.SR` (`oscillators.lib:1193`) shifts that phase
  by 6.0e-6 cycles per period, 0.0036 cycles over 120 s. Through the
  differentiated cascade, that gives about the 2.2 % observed.
- The 7e4 peaks are the genuine response to a 100:1 jump; double shows the
  same peaks.
- **Fix (test): tried, does not work.** With 20.3 / 2030 Hz (205.03 cycles
  per period) or with a period of `P + 7` samples, the gap still reaches
  1.3 %: the phases at the jumps vary, but each still moves with the
  accumulated rounding of `f/SR` (0.012 cycle in two minutes at 2000 Hz),
  and the transients stay as sensitive to it. The entry stays in the
  baseline: it is the float rounding of a frequency, made audible by a
  100:1 jump.

**`lf_imptrain_test` = `os.lf_imptrain(3)`** (`oscillators.lib:741`)

- A single isolated second: second 109 has 4 impulses in single against 3
  in double (gap 0.134), and every other second matches exactly.
- At 3 Hz and 192 kHz the impulses fall every 64000 frames, so every third
  one sits exactly on a one-second boundary.
- `float(3)/192000` is rounded up by 4.75e-8 relative. Impulse k moves one
  frame earlier once k·ε ≥ inc, i.e. k ≥ 329, at about 109.66 s. The
  impulse due at 110.000 s then lands in second 109.
- The onset scales as 1/rate: second 219 at 96 kHz, as predicted.
- **Verdict:** an artifact of measuring per second. A one-sample shift of a
  3.00000014 Hz pulse train is not a defect.
- **Fix (test): none.** 3.1 Hz, first proposed, would not help: an impulse
  lands exactly on a second boundary whenever `m·f` is an integer for a
  whole second `m`, every 10 s at 3.1 Hz. Only a frequency with a
  denominator above the render's length in seconds avoids it. The entry
  stays in the baseline, as a measurement artifact.

**Possible library-side fix, not tested.**

- Feed `_fixpt.split` a compensated increment, `hi = f/SR` plus
  `lo = (f − hi·SR)/SR`. That removes the 5e-8 frequency error, and with it
  the three drifts.
- Caveat: `-ffast-math` may fold `f − (f/SR)·SR` to 0, so it would need
  `make check-precision-matrix`.
- The benefit, an exact frequency rather than one within 5e-8, matters
  little for audio. The test fixes are the proportionate answer.

---

## 5. `hammer`: the oscillator's coefficients lose its stiffness in float

**Entries:** `hammer_test`, `hammer_slider_test` (`tests/fds_tests.dsp:67, 78`).

The first analysis took this for a cancellation at release from the 2.3e8
state of the held trigger. A test where the hammer is struck instead
(`button : ba.impulsify`, as the faust examples do) shows the same 3.5 %
gap from the first second, with a state of only a few units: the state's
size is not the cause.

```faust
// fds.lib, before
hammerModel(in,k,offset) = (_,_,_*forceCoeff,in :> _) ~ (_ <: A*_,B*_') : _-offset;
A = (2-omega0Sqr*k^2)/(1+sigma0*k);
B = (-1)*(1-sigma0*k)/(1+sigma0*k);
```

- The oscillator's stiffness is the small `1 − A − B =
  omega0Sqr·k²/(1 + sigma0·k)`: 4.34e-7 for the tests' `omega0Sqr = 1000`
  and `k = 1/48000`. Rounded near 2 and −1 in float, `A` and `B` give
  4.77e-7: a spring 10 % too stiff.
- The force term, `forceCoeff·F ≈ 4.3e-10·F`, is added to `u`, of which it
  is only one or two ulps.
- **Fix (done):** run the recursion on the step `v = u − u'`:
  `v[n+1] = C·v[n] − D·u[n] + forceCoeff·F + in`, `u[n+1] = u[n] + v[n+1]`,
  with `C = −B` and `D = 1 − A − B` computed directly. The Faust normalizer
  folded `u − D·u` back into `0.9999996f·u`, which loses `D` again: a
  `min(ma.MAX)` on the step keeps it a unit (see
  [faust-normalizer-issues.md](faust-normalizer-issues.md), mechanism 3).
  The gap to double falls from 3.5e-2 to 1.2e-7.

## 6. `sawtooth_demo` growth: the excitation, not a drift

- The harness presses every button and checkbox during the first half.
  During the hold, `sawtooth_demo`'s "Noise" and "External Signal Input"
  checkboxes are on, so the output is the zero input plus 0.001·tosc(110).
- At release they go off, and the −20 dB sawtooth plays: the expected 0.1
  peak.
- This `growth` is a change of program, not a defect.

---

## Lessons for `make check-long`

- **What the `drift` criterion catches.** It mostly catches phase offsets,
  not amplitude errors. A constant frequency error of 1e-6 relative is
  harmless to the ear, but it decorrelates a release tail or a beat pattern
  after a minute.
  - It caught real defects: the DX7 phasor, the `nlf2` LFOs and the
    `si.smooth` dead band.
  - It also flags tests whose excitation is exactly periodic (mechanism 4),
    and self-oscillating models whose state at release is chaotic in both
    precisions (the flute).
  - A baseline reason must therefore say which of the two each entry is.
- **The release second.** It is the most sensitive point of the schedule:
  every DX7 entry, the flute and `hammer` fail there. A second criterion
  that ignores the release second would separate long-run drift from
  release sensitivity. It is not needed to keep the check useful.
- **The 2^24-frame onset.** No test showed one: float time counters are
  gone from the tested code. The `interpolators` tests, fixed in
  `ebc8f294`, were the last.

## What the branch changed

The branch `long-drift` fixes every library defect above and the test
excitations that could be fixed. It removes 50 of the 134 entries of
`tests/long-baseline.json` (47 of the 49 drifts, and one `subnormal`), and
3 of the 26 `level` entries of `tests/precision-baseline.json`
(`latch_demo`, `reverbTank_demo`, `vital_rev_demo`).

### Library and test fixes

| commit | change | entries removed | references |
|---|---|---|---|
| `bf22335d` | DX7: `m_hsp_phasor` is `os.lf_sawpos_phase_reset`, which accumulates in fixed point in single precision (mechanism 1) | 33: `algorithm1..32`, `operator_modulated` | `operator_modulated_test` (3e-5) |
| `5c76078f` | `fd.hammer`: the recursion runs on the step `v = u − u'`, with a `min(ma.MAX)` barrier on the step (mechanism 5) | 2: `hammer`, `hammer_slider` | `hammer*` |
| `d7123142` | `phasor_modulated_test`: its frequency is built from integers (mechanism 4) | 1 | the test's |
| `0f481310` | `unwrap_test` unwraps a wrapped phase, `4*os.tosc(100)`, instead of an `os.oscr*` source (mechanism 2) | 1 | the test's |
| `3b52f5e0` | `dm.latch_demo`: sine sources from `os.osc`, not `os.oscr`/`os.oscrs` (mechanism 2) | 1 | the test's |
| `6a1f00ce` | `no.lfnoise0` triggers on the phase of `os.lf_sawpos`, not on the sign of its float sine: otherwise the next commit makes `lfnoise0_test` fail `check-precision` | 0 | `lfnoise0*` |
| `63a86268` | `os.oscrq` (hence `oscrs`, `oscrc`, `oscrp`, `oscr`): amplitude correction `g = 1.5 − 0.5·(y0² + y1²)` at every step, one Newton step towards a unit radius (mechanism 2) | 9: `greyhole_demo`, `logsweep`, `oscr*` | `oscr*` and their callers |
| `bd8f5ae0` | `si.smooth` is `imp(3)`, the error-state form, with a `min(ma.MAX)` barrier against `-ffast-math` reassociation; `smooth_deadband_test` pins it (mechanism 3) | 4: `flute_ui_MIDI`, `virtual_analog_oscillator_demo`, the `drift` of `sawtooth_demo`, and the `subnormal` of `violin_ui_MIDI` (11.2 million subnormal output samples after the release before, none now; measured, not analysed) | none in double |

The `oscr*` entries were not among the 45: they had been pinned with
"`fi.nlf2` undamped rotation" from the start.

### Harness defects found on the way

- **The DX7 libraries tested were the installed ones.** No harness passed
  `-I dx7`, so every check compiled the `algorithm*` and `operator*` tests
  against `/usr/local/share/faust/dx7`, not the tree's. `d9d06e1a` adds it
  to the Makefile (`FAUST_INCLUDES`), `check_precision.py`,
  `check_cpu.py`, `check_backends.py` and `check_usage.py`.
- **A change in `dx7/` did not rebuild the tests.** `newest_source` in
  `check_precision.py` only looked at the root `*.lib`; `9be9f344` adds the
  subdirectories.
- `check_long.py` was not executable (`3eaba53e`).

### Normalizer workarounds

Two fixes (`fd.hammer`, `si.smooth`) need a `min(ma.MAX)` barrier against a
rewrite that undoes them: the Faust normalizer for the first, clang
`-ffast-math` for the second. The rewrites the libraries work around are
collected in [faust-normalizer-issues.md](faust-normalizer-issues.md)
(`b754ce6e`).

### What stays in the baseline

- `saw4_jump`: the float rounding of `f/SR`, made audible by a 100:1 jump.
  Two other sets of frequencies were tried, without effect.
- `lf_imptrain`: a measurement artifact, one impulse moving across a second
  boundary. 3.1 Hz would not have helped.
- `sawtooth_demo` `growth`: its switches select the noise input during the
  hold; expected.
- The RMS compressors and the other sliding or cumulative sums (12
  entries), the 67 remaining `subnormal` and `FTZ_test`/`MIN_test`: explained before
  the branch.

### Checks

Run on the whole branch, `si.smooth` included:

- `make check`: 2325 tests; the references
  that change are those listed above, regenerated in their commits.
- `make check-precision`, `make check-extremes`, `make check-backends`:
  no new failure.
- `scripts/check_precision.py --matrix all` (C++ `-O3 -ffast-math`,
  Faust `-vec`, `-lang ocpp`) on `signals`, `demos` and `physmodels`: 256
  tests, the only failure is `fdnrev0_demo_test` under `-ffast-math`,
  already on `origin/master`. Not run on the other test files.
- `make check-long` (`-j 6`): 2325 tests, 0 new failure.
- `make check-plots`: 160 figures up to date, all property assertions
  hold.
- `make checkdoc` before each commit.

**The ocpp column of the matrix needs faust with grame-cncm/faust#1347.**
`y = x + e` reads `x` twice, and the ocpp backend inlined the block-rate
tail of a bargraph with no sharing: on `an.mth_octave_spectral_level6e`,
whose band levels feed bargraphs through `si.smooth`, the text grew
eightfold per band and faust past 100 GB on `spectral_level_demo_test`.
With #1347 the test compiles in under 90 MB.

### CPU cost

`scripts/check_cpu.py --matrix all --base origin/master` on the touched
tests and on the callers that multiply them. Ratios new / base, Apple
M5, 48 kHz, `-single`, 3 rounds; load 4.6 at the start (the desktop, no
build), spreads mostly under 5%. No test computes more divisions, square
roots or transcendental calls per sample (`ops` column).

| change | test | fast-math | strict | vec |
|---|---|---|---|---|
| `os.oscrq` | `oscrq_test` (3.1 → 6.1 ns) | 1.97 | 1.82 | 2.32 |
| | `oscrs_test` | 1.81 | 1.40 | 2.33 |
| | `logsweep_test` | 1.92 | 1.67 | 1.45 |
| | `greyhole_demo_test` | 1.04 | 1.06 | 1.04 |
| DX7 phasor | `algorithm1_test` | 1.13 | 1.12 | 1.06 |
| | `operator_modulated_test` | 1.13 (spread 12%) | 1.23 | 1.22 |
| `fd.hammer` | `hammer_test` | 1.12 | 1.12 | 1.27 |
| | `hammer_slider_test` | 1.01 | 1.05 | 1.04 |
| `si.smooth` | `smooth_test` (2.5 → 3.0 ns) | 1.18 (spread 10%) | 1.18 | 1.62 |
| | `smooth_slider_test` | 0.33 | 0.81 | 0.88 |
| | `smooth_modulated_test` | 0.76 | 0.86 | 1.10 |
| | `smoo_test` | 1.00 | 0.99 | 1.58 |
| | `spectral_level_demo_test` (15 smoothers) | 1.02 | 1.03 | 1.01 |
| | `vocoder_demo_test` | 1.01 | 1.01 | 0.99 |
| | `virtual_analog_oscillator_demo_test` | 1.14 | 1.08 | 1.06 |
| | `flute_ui_MIDI_test` | 1.13 | 1.06 | 1.06 |
| `no.lfnoise0` | `lfnoise0_test` | 1.05 | 1.06 | 0.98 |

- **`os.oscrq`** pays three multiplications and two additions for its
  amplitude correction, on an oscillator that had only its rotation:
  about 3 ns per sample, ×1.4 to ×2.3 on the bare oscillator, 4 to 6%
  in `greyhole_demo`. What it buys: a unit amplitude in single precision,
  where the rotation's amplitude drifted by several percent over a
  long render (1.093 after 90 s at 48 kHz, ×0.825 for the 2 Hz reverb
  LFOs after 120 s).
- **`si.smooth`** costs at most 0.5 ns per smoother, and is faster with
  a coefficient from a slider. Its callers move by 1 to 14%.
- **The DX7 phasor and `fd.hammer`** cost 6 to 27% on their tests, for a
  phase and a stiffness exact in single precision.

## Reproducing

- `scripts/check_long.py tests/xx_tests.dsp -k name --json out.json` gives
  the per-second result of a single test, in both precisions.
- The experiments (per-second profiles, sub-function substitutions in
  scratch copies of the libraries, float32 C emulations of the generated
  code) were not kept; each is described above with enough detail to be
  redone.
