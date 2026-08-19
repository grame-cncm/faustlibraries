# Pink Trombone → Faust: port notes

Source: <https://dood.al/pinktrombone/> (Neil Thapen, v1.1, March 2017, MIT; the page's
inline JS — save it locally as `tests/pinktrombone/pinktrombone-1.1-original.html`, which is gitignored).
Everything the JS does at audio rate is reproduced; everything it does at *block*
rate (`AudioSystem.blockLength = 512` samples, `finishBlock()`) is done at sample
rate with the constants converted through `blockTime = 512/ma.SR`, so the port
tracks the original at any sample rate the way the original itself depends on it.

## Signal flow (`AudioSystem.doScriptProcessor`)

```
per sample:  glottal = Glottis.runStep()          -> pt.glottis
             Tract.runStep(glottal, noise, λ1)     -> tick 1   (lip + nose out)
             Tract.runStep(glottal, noise, λ2)     -> tick 2   (lip + nose out)
             out = (sum of both) * 0.125
```

`pt.tract` keeps the 144 waveguide states (R[44], L[44], noseR[28], noseL[28]) in a
`~ si.bus(144)` recursion and applies `pt.tractTick` twice per sample
(`twoTicks`), tapping `R[43] + noseR[27]` after each tick. `pt.tractTick` is
written as three `route()` stages (add injections → scattering junctions → back to
state order) so the graph stays O(N); the earlier `ba.selectn`-fan-out formulation
compiled for two minutes.

## Glottis (`Glottis` object)

| JS | Faust | notes |
|---|---|---|
| `setupWaveform` at each period wrap, LF params from `Rd = 3(1-tenseness)` clamped 0.5..2.7 | `lfWaveform(Rd, t)`, `Rd` from `latch(wrap, newTenseness)` | derived coefficients held on the same pulse as Rd; public lfWaveform still accepts audio-rate shape changes |
| `timeInWaveform` / `waveformLength` phasor, frequency latched at wrap | `phaseAndWrap` (`tick ~ (_,_)`) | the JS reuses the leftover time with the *new* period on wrap; ignored (sub-sample) |
| `intensity ± 0.13/0.05 per block`, clamp 0..1 | `moveTowards(0.13/blockTime, 0.05/blockTime, voiced)` | 11.2/s up, 4.3/s down at 44.1 kHz |
| `smoothFrequency *= or /= 1.1 per block`, snap when intensity==0 | log-domain slew `log(1.1)/blockTime` nepers/s with snap (also at t=0) | |
| vibrato `0.005 sin(2π 6 t) + 0.02 s(4.07t) + 0.04 s(2.15t) [+ 0.2 s(0.98t) + 0.4 s(0.5t)]` | same, `simplexNoise(rate) = no.simplex1_lf(noiseSeed, rate)` (real simplex noise, one shared table like the JS) | see simplex-noise-fit.md |
| `newTenseness = UIT + 0.1 s(0.46t) + 0.05 s(0.36t) + (3-UIT)(1-intensity)` (always-voice mode) | same, gated by `voiced` | the last term only matters during the ~90 ms onset ("pressed" attack) |
| `loudness = UIT^0.25` | same | |
| aspiration `intensity (1-√UIT) noiseModulator noise (0.2 + 0.02 s(1.99t))` | same | |
| `getNoiseModulator` | `noiseModulator` output | shared with the tract's turbulence |
| white noise `Math.random()` ∈ [0,1) → BiquadFilter bandpass 500 Hz Q 0.5 (aspiration) and 1000 Hz Q 0.5 (fricative), one shared source | `_whiteNoise = 0.5*no.noise` → `fi.resonbp(fc, Q, 1/Q)` | ×0.5 matches the AC std of uniform[0,1); DC removed by the bandpass anyway |

Not modelled (UI-only): the keyboard `isTouched` state (only "always voice" mode
exists: `voiced` gate); pitch keyboard geometry (use `freq` in Hz; `dm.pink_trombone_demo` exposes
0..20 semitones above F2 = 87.3071 Hz like the keyboard).

## Tract (`Tract` object)

| JS | Faust |
|---|---|
| `n=44, bladeStart=10, tipStart=32, lipStart=39, noseLength=28, noseStart=17` | constants |
| `glottalReflection 0.75`, `lipReflection -0.85` (also used at the nostrils), 0.999 damping in the mouth, `fade=1` in the nose | constants |
| `reflection[i] = (A[i-1]-A[i])/(A[i-1]+A[i])`, `0.999` if `A[i]==0` | `tractReflections` (per sample) |
| nose junction `reflectionLeft/Right/Nose` from `A[17], A[18], noseA[0]` | `noseJunctionRefl` |
| `noseReflection[i]` computed **once at init with noseA[0] = 0.4² = 0.16** (never recomputed even though the velum moves) | `noseReflection(i)` constants — reproduced faithfully |
| linear interpolation of reflections over the block (λ) — with old/new swapped at the nose junction | not needed: coefficients update every sample |
| `reshapeTract`: `moveTowards(d, target, slowReturn·amount, 2·amount)` per block | per-sample `moveTowards` with the same rates (cm/s): opening 0.6..1.0 × 15, closing 30 |
| velum `noseDiameter[0]` → target 0.01 / 0.4 at rates 0.25·15 up, 0.1·15 down | same |
| transients: fired when `lastObstruction` clears and `noseA[0] < 0.05`, `0.3·2^(-200 t)`, added ½ to R and L at the obstruction index each tick | `releaseTrig`/`transEnv`; delayed by one block (512 samples) because the JS detects the release one block after the diameter became positive — this makes the release burst amplitude match (0.155 vs 0.145 peak in the test) |
| turbulence: `0.66·noise·fricative_intensity·noiseModulator·thinness·openness`, split between `index+1`/`index+2` by the fractional part, ½ to R and L | `turbulenceInj(k)`; `fricative_intensity` = 0.1 s linear attack/release of the `cActive` gate; the JS `if (touch.diameter <= 0) continue` guard is **not** ported because it is dead code — `openness = clamp(30(d-0.3),0,1)` is already 0 for `d <= 0.3` (checked: dropping it is bit-identical over a `d` sweep from -1 to 3) |
| `updateAmplitudes` / `maxAmplitude` (drawing only) | dropped |

## Tract shape (`TractUI`)

- `setRestDiameter` (tongue) and the initial diameters (0.6 / 1.1 / 1.5 by region):
  `restDiameter(tongueIndex, tongueDiameter, i)`.
- Constriction (`handleTouches` loop): `constrictedDiameter(index, diameter, active, i, rest)`
  with `diameter -= 0.3`, width 10 / 5 / interpolated, raised-cosine `shrink`; exact
  for every section (the JS loop bounds only skip sections where `shrink = 1`).
- Two simultaneous constrictions are supported (`tract2` / `pinkTrombone2` /
  `tractDiameters2`, 2026-08-19), applied in touch order like the JS loop, each with
  its own turbulence tap and 0.1 s intensity ramp; validated against the multi-touch
  reference to ~2e-6. The single-constriction functions are wrappers with the second
  constriction inactive (bit-exact with the previous version).
- Not modelled: the tongue-control "fromPoint" kludge narrowing the reachable index
  range near the inner radius (`tongueIndex` is simply clamped to 12..29 by the UI);
  the fact that a finger on the tongue control *also* acts as a (wide, shallow)
  constriction while it is held; more than two simultaneous constrictions; touching
  *below* the tract to open the velum (`nasal` is a separate gate).

## Validation (`validate.py`, float32 DawDreamer vs float64 `ptref.py`)

| test | result |
|---|---|
| `lfWaveform` vs `lf_wave`, tenseness 0…1 | max abs err 2e-4 … 1.3e-3 (float32 phasor × steep slope near Te) |
| single `tractTick` from a random-ish state incl. injections and nose | 3e-8 |
| pulse train through the rest tract, after 0.25 s | 8e-7 relative |
| three other tongue shapes, nasal on/off, last 150 ms of 1 s | 6e-7 … 1.3e-6 |
| fricative constriction (index 30.4, d 0.55) with a shared noise array, after 0.25 s | 2e-6 |
| closure at index 30 for 0.25 s then release | closure floor identical; release peak 0.156 vs 0.145 (timing identical to the sample); 8e-7 after 0.3 s |
| glottis RMS / f0 / peak / 3–8 kHz RMS at tenseness 0.2, 0.6, 0.9 (statistical, drift on) | within 1 % |

The remaining differences are all explained by (a) the JS's block-0 reflection
interpolation from zero, (b) block-rate vs sample-rate diameter movement, and
(c) float32.

## Block-diagram size (online IDE "memory access out of bounds", fixed 2026-08-19)

Faust substitutes `with`-definitions and function arguments *textually*: a
definition referenced N times becomes N copies of its whole subgraph in the box
graph. The signal compiler CSEs the duplicates away, but **SVG diagram
generation does not** — and the Faust Web IDE generates the diagram alongside
the audio compile. The first version of this port let each of the 44 injection
taps close over the transient/diameter graph and let the glottis reference its
phasor (containing the whole vibrato/simplex graph) four times; `faust -svg`
took 2 minutes natively, and the IDE's WASM compiler aborted at its 2 GB heap
cap ("memory access out of bounds").

Fix: every multiply-used signal is now computed once and distributed as *wires* —
sequential composition into lambda/function parameters (`sig : \(x).(...)`), and
`bus <: consumers` for fan-out. Applied to `tractN` (excitation bus built once,
duplicated with `<:` for the two ticks), `glottis` (staged pipeline), `lfWaveform`
(staged coefficients) and `no.simplex2` (staged corners). Result: `faust -svg` on
`pt.ui` runs in ~1 s / 148 MB natively and ~2 s in the IDE's own libfaust-wasm
(verified against the engine downloaded from faustide.grame.fr, 2.86.2); DSP
compile time dropped 4.6 s → 2.0 s in WASM. Output verified identical (the tract
refactor was bit-exact; the glottis changed only by the wrap fix below).

While restaging, a real bug was found and fixed: `phaseAndWrap : (_,_,!)` kept
(phase, latchedFrequency) so `wrap` was the always-positive latched frequency and
the level-triggered `latch` re-sampled the tenseness *every sample* instead of
once per glottal period. Now `(_,!,_)` keeps the true wrap impulse; Rd is sampled
per period as in the original's `setupWaveform`. Glottis statistics vs the
reference remain within drift variance (rms/peak/high-band within a few %).

## Library-reuse survey (2026-08-19)

Existing faustlibraries code examined for replacing parts of the tract:

- `pm.chain` / `pm.waveguide` / `pm.*Termination` (physmodels.lib) — the natural home
  for bidirectional waveguides, but `chain` generalises the one-sample delay of `~`
  to the left/right-going waves, i.e. **every block costs one sample at audio rate**.
  Pink Trombone ticks its 44 sections **twice per audio sample** (the state update is
  the unit delay, at 2x rate), and has a 3-port nose branch mid-chain, which `chain`'s
  linear left/right bus cannot express. Not usable without changing the model.
- `fi.scatN(N, av, filter)` — JOS's N-port junction computes `out_j = sum_i(alpha_i*in_i) - in_j`
  (per-*input* weighting of the junction sum). Pink Trombone's nose junction is
  `out_j = alpha_j*sum_i(in_i) - in_j` with `alpha_j = 2*A_j/S` (per-*output* weighting
  - expand `r*L + (1+r)*(R + noseL)` with `r = (2A - S)/S` to see it). The two agree
  only when all alphas are equal, so `scatN` cannot substitute without changing the model.
- `fi.iir_kl` / `fi.allpassnklt` — Kelly-Lochbaum *ladder filters* realising transfer
  functions; one-directional signal flow, no per-section injection, no side branch. No.

Helpers that DID replace local definitions: `aa.clip` (identical to the local `clamp`),
`ba.sAndH` (inside `latch`), `ba.parallelMax` (obstruction scan), and a 2-tap `route()`
instead of two `ba.selectn(144, .)` selection trees for the lip/nose output taps.
`moveTowards` (asymmetric *linear* slew) has no library equivalent (`si.lag_ud` /
`si.onePoleSwitching` are exponential).

## Speech sequencing (`speak.py`, 2026-08-19)

The port is driven programmatically through `pt.ui` automation. `speak.py` holds the
empirically calibrated vowel map (grid sweep -> LPC F1/F2 -> matched to canonical
male formant targets; all residuals < 0.15 log units once rounded vowels got a lip
constriction on bus 2) and a segment compiler whose smoothing is the tract's own
`moveTowards` dynamics — no extra parameter filtering except a 30 ms hann on pitch
and tenseness. Voicelessness is `tenseness -> 0.05` (pulse amplitude scales with
`tenseness^0.25`, aspiration remains), voiced/unvoiced gating of the utterance uses
`always voice`. Known limits: no laterals or trills (1-D tract), [l]/[r] are
approximant stand-ins.

## Faust lessons

- Numeric comparisons (`k <= 17`) fold at box level and can be used inside `route()`
  positions; `select2`/`ba.if` do **not** — use `cif(c,a,b) = c*a + (1-c)*b`.
- Pattern-match on the literal index (`blockR(17) = …`) to give one element of a
  `par` a different arity.
- Don't reference a wide bus through `ba.selectn` N times inside another `par`
  (O(N²) boxes; the first version took 2 min to compile) — route pairs instead.
- `sum` is a keyword. Unary minus in front of a function call (`-exp(x)`) is a
  syntax error; write `0 - exp(x)`.
- 2nd-order `fi.lowpass` at sub-hertz cutoffs is useless in float32.
- Keep the *box* graph small, not just the signal graph: compose shared signals
  into function parameters instead of referencing `with`-definitions repeatedly
  (see the block-diagram section above) — otherwise `-svg` and the online IDE blow up.
- `^` is power, not XOR (`xor`); `waveform{…}, idx : rdtable` is the table idiom.
- Because `moveTowards` starts *on* its target, freezing the articulation freezes
  every derived coefficient from sample 0: `tractN2` with `fricNoise = 0` and
  constant shape arguments is exactly LTI from `glottalOutput` to the output (no
  start-up ramp, no release transient). Measured at 44.1 kHz: shifting an impulse
  by 1000 samples reproduces the response bit-exactly, superposition holds to
  float32 rounding (~1e-6 on a peak of 2.7), and convolving with the first 4000
  samples of the impulse response matches the live tract to the same accuracy.
  So a fixed vocal-tract shape can be analysed or replaced by an FIR in a
  ten-line `.dsp` — no reimplementation needed.

## Regression and documentation cleanup (2026-09-18)

The supported core API and `noiseSeed` configuration are unchanged. Internal
helpers now have underscore names. The canonical UI lives in
`dm.pink_trombone_demo`; the sequencer uses it, with the same automation paths.

Since the library had not been published yet, the deprecated aliases for the old
helper names and the `pt.ui` copy of the demo were dropped before the first
release (1.0.0) instead of being carried as API. The demo's "always voice"
control became an on/off menu defaulting to on, as `alwaysVoice = true` in the
original (a Faust checkbox always starts at 0, which left the demo, and its
regression test, silent).

The numerical reference script now asserts finite output and error bounds:
2e-3 absolute for the LF waveform, 1e-4 relative for settled tract comparisons,
15% for the release peak and two samples for release timing. These budgets
allow the documented float32 and block-rate/sample-rate differences. They do
not assert sample-for-sample equivalence during moving articulation.

## LF coefficient reuse (2026-09-18)

`lfWaveform` now separates its pure shape-coefficient calculation from its phase
calculation. `glottis` holds the seven coefficients on the same wrap/initial
sample as Rd, so its per-sample waveform evaluation can reuse them. The parameter
formulas, latching schedule and public API are unchanged. This uses ordinary
sample-and-hold, preserving scalar and vector compilation; Faust's conditional
`control`/`enable` primitives were excluded because they reject vector compilation.

On this machine with Faust 2.80.4, C++ `-O2`, single precision, 48 kHz and 256-frame
blocks, nine alternating benchmark rounds gave these median times:

| case | before (ns/sample) | after (ns/sample) | time reduction |
|---|---:|---:|---:|
| glottis | 74.84 | 58.78 | 21.5% |
| fixed two-constriction voice | 252.32 | 234.88 | 6.9% |
| moving pitch/tenseness/tongue | 316.76 | 301.56 | 4.8% |

These are local throughput measurements, not guaranteed improvements on every
backend or machine. `benchmark.py` and `benchmark.cpp` reproduce the procedure.
Five-second baseline/candidate comparisons of the waveform, glottis and full
voice with changing controls passed at 44.1, 48 and 96 kHz in single and double
precision. Existing references remain unchanged; the added modulation tests
use references from the pre-optimization implementation. The representative
voice's SVG graph stayed approximately 21.3 MB and generated in under one second
with the native compiler in both versions.
