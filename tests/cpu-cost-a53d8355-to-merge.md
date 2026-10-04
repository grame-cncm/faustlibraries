---
title: CPU cost of everything changed since a53d8355
subtitle: master-merge-julius (1d3a01a8) against a53d8355, three compilations
author: GRAME
date: 4 October 2026
document-style: article-a4
language: en
---

::: note [Format]
Written for [markpage](https://markpage.org), following its authoring
guide (`markpage/AI-AUTHORING.md`); it reads as plain Markdown too.

- **Measurements** are `chart bar` figures, one group of bars per test or
  per test file, one colour per compilation, a common scale from 0 to 4,
  and a dashed line at 1. A figure holds at most nine groups, with short
  names.
- **Rows that cannot be drawn** are left out of the figures and listed
  under them: unreliable ratios, non-finite sides, build errors.
- **Dense tables** are `csv` blocks: the summary ranges and the raw data
  (ns per frame, operations per sample).
- **Pipe tables** are used only where a cell needs inline code.
- **Source**: the figures and tables are generated from the JSON output of
  `scripts/check_cpu.py`.
:::

# Method

Measured with `scripts/check_cpu.py` on the whole test suite of
a53d8355, compiled once against the libraries of a53d8355 and once against
those of `master-merge-julius` (1d3a01a8, the merge of #269-#299 on top of
master). Only the tests whose generated C++ differs between the two sides
are timed (`--changed-only`).

```bash
scripts/check_cpu.py --base a53d8355 --new 1d3a01a8 --changed-only --matrix all --json cpu.json <the tests/*.dsp of a53d8355>
```

- **Why the tests of a53d8355.**
  - The current tests take their input from `os.tosc` (#296), which does
    not exist at a53d8355, so they do not compile on the base side.
  - The tests of a53d8355 compile on both sides. Each one is the same
    program, measured with the old and the new library code.
  - The tests added since then (slider, modulated and jump tests, new
    functions) are therefore not in this measurement.
- **Machine**: Apple M5, Darwin 25.6.0, on AC power; Faust 2.90.2, Apple
  clang 21.0.0; 48 kHz.
- **Compilations**:
  - **fast-math**: `faust -single`, `c++ -O3 -ffast-math`, as the faust2xx
    scripts compile;
  - **strict**: the same without `-ffast-math`;
  - **vec**: `faust -single -vec`, `c++ -O3 -ffast-math`.
- **Coverage**: 1266 tests are built in the three compilations, 3798
  builds. Of these, 1182 generate the same code on both sides. The other
  2616 builds, from 872 tests, are timed, 3 rounds each, in about 85
  minutes.
- **Errors**: `stereo_reverb_tester_test` does not build on the new side,
  in any compilation: Faust reports that the reverb it is given "has 2
  inputs". The a53d8355 test passes `!`, and the current test passes `_`.
  `motion_wrapper_demo_test` builds on neither side in `-vec`: its
  `control` primitive is scalar-only.
- **The machine was not idle.** The load average was about 2, with the
  desktop app running.
  - The tool re-raced the measurements whose rounds disagreed. 41 ratios
    still had a spread above 20% (10 in fast-math, 13 in strict, 18 in
    vec). They are marked `?`, and left out of the means and the figures.
  - AGENTS.md rule 10 asks for an idle machine before a ratio is quoted.
    The findings below rest on large and consistent ratios (whole families
    moving together, in all three compilations). Any single ratio within
    10% should be measured again before it is quoted.
- **Reading a ratio**: new / base time per frame. The noise floor, from
  A/A comparisons, is 0.96 to 1.04.
  - Most single filters cost 3 to 8 ns per frame, under 0.05% of a core.
    A ratio of 1.3 there is about 1 ns.
  - Test names drop their `_test` suffix in the figures; `s` stands for
    `_slider`, `m` for `_modulated`, `ui` for `_ui` and `MIDI` for
    `_ui_MIDI`.
- **ops**: the divisions, square roots and transcendental calls that each
  sample executes in the generated loop, as div/sqrt/fn, in the fast-math
  compilation. A desktop core hides most of them; a microcontroller pays
  14 cycles for a float division, and tens to hundreds for a `pow` or a
  `tan`.

# What changed since a53d8355

132 commits. Those that change the generated code of the measured tests:

| Commits | Blocks | Change |
| :-- | :-- | :-- |
| `0965ea28` (#262) | `fi.lowpass`, `fi.highpass` | Butterworth sections as TPT state-variable filters |
| `45ea4638` | `fi.tf2snp`, `fi.tf1snp` | normalized-ladder coefficients without cancellation |
| `4b251bfa`, `281cae4e` (#261), `ff4c711d`-`631c240c` (#292) | `fi.tf2sb`, `fi.tf1sb`, `fi.bandpass`, `fi.bandstop` | band sections as TPT sections, then with output-level inputs and a bandwidth floor |
| `55610543` (#259), `19506f75` | `ve.klonCentaur` | TPT DC blocker, then a faithful port of ChowCentaur |
| `310cf19c` | `an.window_kaiser` | I0 series in Horner form |
| `871cf036`, `15f13da1` (#272) | `fi.tf3slf` | three trapezoidal integrators |
| `91963709` (#273), `06985a1d` (#293) | `fi.tf2s` and its users (`resonlp`/`bp`/`hp`, `peak_eq`, `moog_vcf_2b`, `wah4`, the elliptic filters...) | two trapezoidal integrators, then a reciprocal kept off the critical path |
| `4b137a66` (#277) | `fi.svf` | the delay-free loop solved for the highpass first |
| `ff4c711d` (#292) | `fi.tf1s` and its users | a trapezoidal integrator; prewarping clamped at Nyquist |
| `fed179d2`, `ea760b08` (#282) | `highpass_minus_lowpass(3)`, the filter banks, `levelfilter`, `peak_eq`, `resonhp`, `wgr`, `apnl`, goertzel | the fixes of #282 |
| `b137daed`, `ba96bc50`, `31369386`, `5f75048f` (#283, #294, #297, #299) | `os.osc`, `os.lf_*`, `os.phasor`, `os.sawtooth`, `os.saw3`/`saw4`... | phasors in fixed point in single precision, `saw3`/`saw4` in closed form |
| `15be6acc` (#269) | `pm.modeFilter`, hence the modal models (bells, marimba, djembe) | a Chamberlin state-variable section |
| `ab3a45ab`, `f541c0c0` (#270, #288) | `ve.crybaby`, `ve.autowah` | accurate in float; `wah` clamped |
| `74e7bb45` (#271) | the matched filters of vaeffects.lib | accurate in float |
| `0b7751d4`-`18b2bdce` (#284), `59c15088` (#289), `1ff2523b`-`b54a282f` (#291) | delays, reverbs, demos | prime-power bound, zita fan-out and fsmax, `fdnrev0` `nonl`, zita-rev1 matching |
| `649a5ecd`, `c575fdd1` (#285) | flanger, phaser, `stereo_width`, `uniformPanToStereo` | the fixes of #285 |
| `1fa934bb`, `0525d22b`, `2482e66a`, `d7481b4c`, `ab215987`, `a085925f`, `9daf301d`, `cafb9d6c`, `2095ec0f`, `0bbbc64f` (#296) | `pm.fof`, `ve.moog_vcf`, `os.polyblep_triangle`, `re.mono_freeverb`, `si.smoothq`, `it.interpolate_exponential`, `ef.wavefold`, the expanders, `fd.linInterp1D`, `ef.granular` | the precision fixes of #296 |
| `61d17ea4`, `0e96338c` | `fi.mth_octave_filterbank_alt`, the octave filter banks of analyzers.lib | they compile again (#296) |

The other commits change tests and documentation only.

# Summary

| Compilation | Tests timed | Geometric mean | Median | Total time new / base | Ratios below 0.8 | Ratios above 1.2 |
| :-- | --: | --: | --: | --: | --: | --: |
| fast-math | 860 | **0.67** | 0.94 | **1.015** | 344 | 72 |
| strict | 856 | 0.67 | 0.92 | 1.025 | 321 | 60 |
| vec | 851 | 0.92 | 0.93 | **1.155** | 269 | 138 |

The two means tell different stories:

- **The geometric mean (0.67) is the cost of a typical test**, and it is
  dominated by the input source. Most tests of a53d8355 take an `os.osc`,
  `os.lf_sawpos` or `os.lf_*` oscillator as input, and those are now about
  six times cheaper in single precision (#294, #297). On the 595 tests
  under 5 ns per frame, the geometric mean is 0.56.
- **The total time (1.015, 1.025, 1.155) is the cost of the heavy
  blocks**: the tests above 20 ns per frame (87 in fast-math) have a
  geometric mean of 1.18 in fast-math, 1.15 in strict and 1.26 in vec.
  These are the physical models, the demos, the analyzers and the reverbs.

So the libraries are not slower overall, and much faster where a test is
little more than an oscillator. The rewritten filters cost 10 to 90% more
in scalar code, and up to three times more in `-vec`.

Geometric mean per test file, in the three compilations. The file is that
of the test, not of the code it measures: `debug`, `wdmodels` or `hoa`
move because of their input oscillator.

```chart bar "Geometric mean of the ratios new / base, per test file (1 of 6)" y-max=4 y-ref=1:"no change"
file, fast-math, strict, vec
physmodels, 1.06, 1.03, 1.25
oscs, 0.45, 0.45, 0.79
debug, 0.38, 0.38, 0.80
analyzers, 0.81, 0.85, 0.89
wdmodels, 0.24, 0.25, 0.53
demos, 0.98, 1.00, 1.14
vaeffects, 1.13, 1.13, 1.16
aanl, 0.80, 0.79, 0.88
hoa, 0.37, 0.38, 0.77
```

```chart bar "Geometric mean of the ratios new / base, per test file (2 of 6)" y-max=4 y-ref=1:"no change"
file, fast-math, strict, vec
basics, 0.53, 0.53, 0.80
compressors, 0.95, 0.92, 0.97
tubes, 0.59, 0.61, 0.88
misceffects, 0.59, 0.59, 0.88
f. basic comb, 0.50, 0.47, 0.74
f. dir ladder, 0.96, 0.96, 0.92
f. state var, 0.98, 1.02, 0.96
motion, 0.72, 0.70, 1.06
instruments, 0.54, 0.57, 0.78
```

```chart bar "Geometric mean of the ratios new / base, per test file (3 of 6)" y-max=4 y-ref=1:"no change"
file, fast-math, strict, vec
pinktrombone, 1.00, 0.99, 0.97
reverbs, 1.01, 0.99, 0.95
f. param eq, 1.03, 0.99, 1.10
maxmsp, 0.95, 0.95, 0.81
spats, 0.43, 0.44, 0.80
routes, 0.41, 0.41, 0.74
signals, 0.44, 0.44, 0.81
delays, 0.48, 0.48, 0.80
synths, 1.01, 0.96, 1.11
```

```chart bar "Geometric mean of the ratios new / base, per test file (4 of 6)" y-max=4 y-ref=1:"no change"
file, fast-math, strict, vec
webaudio, 1.00, 0.99, 0.89
f. analog sec, 0.79, 0.94, 1.05
noises, 0.87, 0.89, 1.11
f. delay eq ap, 1.02, 0.94, 1.22
f. ladder ap, 0.88, 0.87, 1.02
f. LR, 0.93, 0.95, 0.80
f. mth oct fbank, 0.71, 0.78, 1.33
f. useful sp, 0.98, 0.98, 1.12
hysteresis, 1.00, 1.00, 1.00
```

```chart bar "Geometric mean of the ratios new / base, per test file (5 of 6)" y-max=4 y-ref=1:"no change"
file, fast-math, strict, vec
reducemaps, 0.79, 0.85, 0.82
envelopes, 0.71, 0.64, 0.86
f. ellip, 1.22, 1.10, 1.60
interpolators, 0.42, 0.43, 0.69
phaflangers, 0.64, 0.70, 0.87
f. bp bs, 0.72, 0.56, 1.47
f. butterworth, 1.12, 0.97, 1.29
f. pospass, 0.95, 1.13, 1.73
f. resonator, 1.43, 1.09, 1.28
```

```chart bar "Geometric mean of the ratios new / base, per test file (6 of 6)" y-max=4 y-ref=1:"no change"
file, fast-math, strict, vec
maths, 0.35, 0.44, 0.62
soundfiles, 1.00, 0.99, 1.14
fds, 0.68, 0.68, 0.95
f. ellip bp, 0.86, 0.84, 1.82
f. filterbank, 0.90, 0.84, 1.31
mi, 0.15, 0.15, 0.59
```

```csv
test file; tests; fast-math; strict; vec
physmodels; 101; 1.06 (0.22–1.91); 1.03 (0.22–1.90); 1.25 (0.56–3.31)
oscillators; 70; 0.45 (0.10–1.40); 0.45 (0.10–2.20); 0.79 (0.51–1.89)
debug; 66; 0.38 (0.16–1.71); 0.38 (0.17–1.73); 0.80 (0.55–1.96)
analyzers; 47; 0.81 (0.13–1.28); 0.85 (0.13–1.49); 0.89 (0.46–2.73)
wdmodels; 46; 0.24 (0.11–1.47); 0.25 (0.11–1.07); 0.53 (0.40–1.15)
demos; 42; 0.98 (0.45–1.55); 1.00 (0.45–1.72); 1.14 (0.59–3.02)
vaeffects; 33; 1.13 (0.92–3.10); 1.13 (0.81–3.18); 1.16 (0.70–2.34)
aanl; 31; 0.80 (0.48–1.01); 0.79 (0.39–1.00); 0.88 (0.79–0.98)
hoa; 29; 0.37 (0.20–1.00); 0.38 (0.22–1.00); 0.77 (0.64–1.09)
basics; 27; 0.53 (0.17–1.19); 0.53 (0.17–1.10); 0.80 (0.45–1.32)
compressors; 27; 0.95 (0.83–1.02); 0.92 (0.73–1.00); 0.97 (0.82–1.15)
tubes; 27; 0.59 (0.20–0.78); 0.61 (0.19–0.82); 0.88 (0.41–1.02)
misceffects; 24; 0.59 (0.22–1.07); 0.59 (0.25–1.10); 0.88 (0.58–1.40)
filters_basic_comb; 23; 0.50 (0.23–1.11); 0.47 (0.23–1.11); 0.74 (0.57–0.99)
filters_direct_ladder; 21; 0.96 (0.66–1.27); 0.96 (0.70–1.07); 0.92 (0.66–1.29)
filters_state_variable; 21; 0.98 (0.80–1.11); 1.02 (0.83–1.44); 0.96 (0.62–1.27)
motion; 20; 0.72 (0.18–1.24); 0.70 (0.20–1.08); 1.06 (0.81–1.28)
instruments; 16; 0.54 (0.22–1.15); 0.57 (0.22–1.06); 0.78 (0.62–1.08)
pinktrombone; 15; 1.00 (0.95–1.10); 0.99 (0.82–1.09); 0.97 (0.74–1.04)
reverbs; 15; 1.01 (0.89–1.13); 0.99 (0.85–1.08); 0.95 (0.81–1.18)
filters_parametric_eq; 14; 1.03 (0.72–1.27); 0.99 (0.75–1.36); 1.10 (0.83–1.71)
maxmsp; 11; 0.95 (0.61–1.01); 0.95 (0.60–1.00); 0.81 (0.70–1.00)
spats; 10; 0.43 (0.18–1.01); 0.44 (0.19–0.99); 0.80 (0.65–1.03)
routes; 9; 0.41 (0.24–0.83); 0.41 (0.28–0.81); 0.74 (0.63–0.91)
signals; 9; 0.44 (0.30–0.99); 0.44 (0.30–1.12); 0.81 (0.70–1.17)
delays; 8; 0.48 (0.23–1.00); 0.48 (0.23–1.00); 0.80 (0.66–1.03)
synths; 8; 1.01 (0.49–1.86); 0.96 (0.51–1.53); 1.11 (0.75–2.29)
webaudio; 8; 1.00 (0.98–1.01); 0.99 (0.97–1.00); 0.89 (0.70–1.26)
filters_analog_sections; 7; 0.79 (0.23–1.68); 0.94 (0.47–1.68); 1.05 (0.67–1.48)
noises; 7; 0.87 (0.60–1.15); 0.89 (0.59–1.26); 1.11 (0.73–3.00)
filters_delay_equalizing_allpass; 6; 1.02 (0.79–1.24); 0.94 (0.83–1.29); 1.22 (0.87–1.44)
filters_ladder_allpass; 6; 0.88 (0.42–1.18); 0.87 (0.42–1.09); 1.02 (0.65–1.19)
filters_linkwitz_riley; 6; 0.93 (0.83–1.04); 0.95 (0.82–1.01); 0.80 (0.73–0.92)
filters_mth_octave_filterbank; 5; 0.71 (0.54–0.92); 0.78 (0.73–0.85); 1.33 (1.17–1.60)
filters_useful_special; 5; 0.98 (0.95–1.00); 0.98 (0.95–1.00); 1.12 (1.01–1.19)
hysteresis; 5; 1.00 (0.97–1.04); 1.00 (0.99–1.01); 1.00 (0.99–1.02)
reducemaps; 5; 0.79 (0.75–0.82); 0.85 (0.74–0.99); 0.82 (0.76–0.88)
envelopes; 4; 0.71 (0.63–1.00); 0.64 (0.47–1.00); 0.86 (0.79–0.98)
filters_elliptic; 4; 1.22 (1.05–1.35); 1.10 (0.92–1.24); 1.60 (1.20–2.40)
interpolators; 4; 0.42 (0.19–0.67); 0.43 (0.21–0.67); 0.69 (0.42–0.87)
phaflangers; 4; 0.64 (0.36–0.98); 0.70 (0.38–0.97); 0.87 (0.68–0.98)
filters_bandpass_bandstop; 3; 0.72 (0.58–0.81); 0.56 (0.50–0.60); 1.47 (1.43–1.55)
filters_butterworth; 3; 1.12 (0.98–1.29); 0.97 (0.80–1.12); 1.29 (1.22–1.41)
filters_pospass; 3; 0.95 (0.75–1.09); 1.13 (0.92–1.61); 1.73 (1.34–2.82)
filters_resonator; 3; 1.43 (1.32–1.50); 1.09 (1.04–1.12); 1.28 (1.03–1.49)
maths; 3; 0.35 (0.12–1.16); 0.44 (0.24–1.15); 0.62 (0.44–0.77)
soundfiles; 3; 1.00 (0.99–1.01); 0.99 (0.98–1.00); 1.14 (1.13–1.15)
fds; 2; 0.68 (0.47–1.00); 0.68 (0.46–1.00); 0.95 (0.81–1.11)
filters_elliptic_bandpass; 2; 0.86 (0.79–0.93); 0.84 (0.63–1.13); 1.82 (1.72–1.92)
filters_filterbank; 2; 0.90 (0.80–1.01); 0.84 (0.79–0.90); 1.31 (1.30–1.31)
mi; 2; 0.15 (0.13–0.17); 0.15 (0.13–0.17); 0.59 (0.55–0.63)
```

# Findings

## Oscillators: six times cheaper in single precision

In single precision, the phasors of #294 (`_phasor_imp`, behind
`os.osc`, `os.lf_*`, `os.phasor`) and of #297 (`os.saw2ptr`) keep their
phase in fixed point, and the generated loop is much shorter:

- `os.osc` and `os.oscsin` go from 3.5 to 0.57 ns per frame: 0.16 in
  fast-math, 0.17 in strict, 0.55 in vec;
- `os.lf_sawpos`, `os.lf_saw`, `os.lf_triangle`: 0.13 to 0.15 (vec 0.53);
- `os.phasor` 0.26, `os.sawtooth` and `os.saw2` 0.17, `os.square` and
  `os.pulsetrain` 0.30, `os.imptrain` 0.41.

Every test that takes one of them as input shows the gain: hundreds of
tests between 0.1 and 0.5 in fast-math, among them all of `wdmodels`,
`debug`, `hoa`, `basics`, `routes`, `spats` and `signals`.

Three oscillators go the other way:

- `os.saw4` costs 1.40 in fast-math, 2.20 in strict and 1.27 in vec, from
  3.6 to 5.0 ns. The closed form of #299 is what makes it accurate in
  float. `os.saw3` and `os.sawN(3)` get faster (0.63).
- `os.triangle` costs 1.34 in fast-math (2.6 to 3.5 ns), but 0.76 in
  strict.
- `os.oscs` is unchanged (1.00).

## Modal models: twice the cost

`pm.modeFilter` as a Chamberlin state-variable section (#269) costs about
twice the direct form once it is multiplied by the number of modes:

- the `*BellModel` tests and `marimbaBarModel`: 1.82 to 1.91 in fast-math
  and strict, 2.2 in vec, from 24 to 46 ns per frame (0.22% of a core at
  48 kHz);
- the complete bells (`*Bell_test`): 1.29 in fast-math, 1.57 in strict,
  1.72 in vec;
- `djembe`: 1.27 to 1.45 in fast-math; `modalModel_test`: 0.71 in
  fast-math but 3.31 in vec.

`modeFilter_test` looks unchanged (0.98), but its input is an `os.osc`,
about 3 ns cheaper now: the section itself costs about 3 ns more. The bells
run 50 sections in parallel on an impulse, so they show the full cost.
#269 measured the direct form as faster only for large mode banks, and
wrong in float exactly there.

## tf2s and its users: +30 to +70%

`fi.tf2s` as two trapezoidal integrators (#273), with the reciprocal kept
off the critical path (#293):

- `tf2s_test`: 1.68 in fast-math and strict, 1.48 in vec (3.5 to 5.9 ns);
- `resonlp`, `resonbp`: 1.50 in fast-math, 1.10 in strict; `resonhp` 1.32;
- `peak_eq` and `peak_eq_cq`: 1.26 in fast-math, 1.71 in vec;
- `ve.moog_vcf_2b`: 1.72 in fast-math, 2.34 in vec; `ve.wah4`: 1.30 in
  fast-math, 1.67 in strict;
- the synths built on `resonbp`/`resonlp`: `popFilterDrum` 1.86 and
  `dubDub` 1.82;
- `an.vocoder`, a bank of `resonbp`: 1.54 in fast-math, 2.28 in vec;
- `violinBody` and the `modularInterp*` instruments: 1.31–1.47 in
  fast-math, up to 2.44 in vec.

These are 2-to-6 ns filters: the absolute cost is 1 to 3 ns per section.
The elliptic `lowpass6e` and `highpass6e`, built on `tf2s`, cost 1.35 in
fast-math and up to 2.40 in vec.

## Filter banks and spectral analyzers

- The multiband probes of debug.lib, built on `fi.bandpass(2, ...)`
  between a `lowpass` and a `highpass`: `probe_multiband` 1.71,
  `probe_spectral_centroid` 1.65 in fast-math (9.2 to 15.7 ns).
- The Mth-octave banks themselves are faster in scalar code:
  `mth_octave_filterbank_alt` and `mth_octave_filterbank3` at 0.54, the
  default bank at 0.82. In vec they are slower (1.17 to 1.60).
- Their demos and the spectral level meters cost more:
  - `filterbank_demo` and `mth_octave_filterbank_demo`: 1.38 in
    fast-math, 1.86 in vec (61.5 to 85 ns);
  - `spectral_level_demo`: 1.37 in fast-math, **3.02 in vec** (114 to
    157 ns in fast-math, 93 to 281 ns in vec);
  - `mth_octave_spectral_level6e`: 1.24 in fast-math, 2.73 in vec.

The SVF lowpass and highpass of #262, then the TPT band sections of #292,
carry this. The `-vec` cost of the SVF lowpass and highpass was already
measured on 2 October (a53d8355 to 9c421426): about 1.5. It now spreads
to more filters. That measurement also found the band sections of #261
faster than the direct form for fixed bands in scalar code.
With the output-level sections of #292, the probes (a lowpass, six
band-passes and a highpass in parallel) come out slower.

## Reverbs and demos

- `fdnrev0_demo`: 1.55 in fast-math, 1.52 in strict, 1.29 in vec, from
  183 to 285 ns, the largest absolute increase (+102 ns, 1.37% of a core).
  The demo drives `nonl` from its Nonlinearity slider, and since #289 the
  passive nonlinear allpass of each delay line is computed whatever its
  value. `fdnrev0_test`, with `nonl` = 0 constant, is unchanged (1.03).
- The zita reverbs are within 0.91–1.07 (#284, #291).
- `compressor_demo` 0.45 and `sawtooth_demo` 0.67 lose divisions and
  transcendental calls in the demo fixes of #284.
  `virtual_analog_oscillator_demo` is slower (1.27), but loses 15 of its
  33 divisions per sample.

## klonCentaur and the operation counts

- `ve.klonCentaur`: 3.10 in fast-math, 3.18 in strict, 2.32 in vec (35 to
  109 ns). It is the faithful ChowCentaur port (`19506f75`), already measured on
  2 October, and
  goes from 17/1/5 to 24/1/11 operations per sample.
- Only 9 tests execute more divisions, square roots or transcendental
  calls per sample, and 21 execute fewer. The 9 are:
  - `klonCentaur`;
  - `autowah`, which goes from 1/0/4 to 3/0/4 (#270): two divisions per
    sample;
  - seven `window_*` tests, with one more `cos` each.
- **The `window_*` cosine is a wasted call.** The windows of `an.window_cosN`
  sum `cos(k*2*PI*x)` from k = 0. The new input phase is an integer cast
  to float (#294), and Faust no longer folds the k = 0 term `cos(0*x)` to
  1: the generated code computes `std::cos(0.0f * fTemp2)` every sample.
  `-ffast-math` lets the C++ compiler fold `0*x` to 0, and the call with
  it. Without it, `0*x` is not 0 for an infinite or NaN `x`, so strict code
  and other targets pay for one `cos` per sample. The ratios
  (`window_hann` 0.58) mostly reflect the cheaper phasor.
- The decreases include `compressor_demo` (5 to 3 calls),
  `virtual_analog_oscillator_demo` (33 to 18 divisions), `sawtooth_demo`
  (18 to 6), `moog_vcf_demo` (29/8/2 to 17/4/2) and `window_kaiser` (36
  calls to 0).

## Fixed NaNs

The base side of `tf3slf_test` (all three compilations) and of
`window_kaiser_test` (strict) is non-finite: these are the float bugs that
#272 and `310cf19c` fixed. Their ratios measure NaN arithmetic and are
left out of the means.

# What to look at next

- **`-vec` remains the compilation where the rewrites cost the most**:
  `spectral_level_demo` 3.02, `vocoder_demo` 2.90, `pospass6e` 2.82,
  `modalModel` 3.31. The coupled two-state recursions of the TPT sections
  do not vectorize as the direct forms did.
- **The modal models** pay twice for their float accuracy. If a cheaper
  coefficient update can be found for `modeFilter` (the bells recompute
  50 sections), that is where it would matter most.
- **`window_cosN`** could start its sum at k = 1, adding the k = 0
  coefficient as a constant, which removes the wasted `cos(0*x)` whatever
  Faust folds.
- **An idle-machine run**, to quote individual ratios (rule 10): the 41
  `?` ratios, and in particular those within 10% of 1.


# All slower measurements

One figure per test file, with the tests whose ratio is 1.10 or more in at
least one compilation (253 of the 872 tests timed). The faster tests are
in the raw data only.

## physmodels


```chart bar "physmodels: ratio new / base (1 of 7)" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
SFFormBP, 0.87, 1.07, 2.47
SFFormBP MIDI, 1.11, 1.16, 1.17
SFFormBP ui, 1.10, 1.12, 1.17
SFFormFofCyc, 0.98, 1.16, 0.92
SFFormFofCyc MIDI, 1.14, 1.22, 0.98
SFFormFofCyc ui, 1.09, 1.22, 1.00
SFFormFofSm MIDI, 1.10, 1.10, 1.00
SFForm, 0.99, 1.15, 0.92
blower, 1.01, 0.76, 1.45
```



```chart bar "physmodels: ratio new / base (2 of 7)" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
blower ui, 0.99, 0.76, 1.33
brass ui, 1.02, 1.04, 1.15
churchBellM, 1.91, 1.90, 2.21
churchBell, 1.29, 1.57, 1.73
churchBell ui, 1.64, 0.97, 1.72
djembeM, 1.35, 1.09, 2.19
djembe, 1.27, 0.99, 1.56
djembe MIDI, 1.45, 1.18, 1.64
englishBellM, 1.91, 1.89, 2.20
```



```chart bar "physmodels: ratio new / base (3 of 7)" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
englishBell, 1.29, 1.57, 1.72
englishBell ui, 1.63, 0.97, 1.74
fofSmooth, 0.77, 0.88, 1.13
fmtFiltBP, 1.49, 1.10, 1.00
fmtFiltFofCyc, 0.99, 1.11, 1.03
fmtFbankBP, 1.10, 1.18, 2.15
fmtFbankFofCyc, 1.04, 1.21, 0.95
fmtFbank, 1.10, 1.18, 2.15
frenchBellM, 1.91, 1.90, 2.22
```



```chart bar "physmodels: ratio new / base (4 of 7)" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
frenchBell, 1.29, 1.57, 1.72
frenchBell ui, 1.64, 0.97, 1.73
germanBellM, 1.90, 1.89, 2.21
germanBell, 1.29, 1.57, 1.72
germanBell ui, 1.63, 0.97, 1.73
marimbaBarM, 1.82, 1.85, 2.22
marimbaM, 1.03, 1.18, 2.20
marimba, 1.32, 1.52, 1.68
marimba MIDI, 0.83, 0.98, 1.71
```



```chart bar "physmodels: ratio new / base (5 of 7)" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
modalM, 0.71, 1.25, 3.31
modeFilter, 0.98, 0.99, 1.16
modeInterpRes, 1.32, 0.95, 1.46
mInterpBody, 1.39, 1.05, 2.44
mInterpInstr, 1.42, 1.20, 1.64
mInterpInstr MIDI, 1.41, 1.09, 1.52
mInterpStringM, 1.47, 1.13, 1.67
openStringPickDown, 1.12, 1.00, 1.01
pluckString, 1.34, 0.94, 1.14
```



```chart bar "physmodels: ratio new / base (6 of 7)" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
russianBellM, 1.90, 1.89, 2.21
russianBell, 1.29, 1.58, 1.73
russianBell ui, 1.63, 0.97, 1.73
standardBellM, 1.91, 1.90, 2.21
standardBell, 1.29, 1.57, 1.71
standardBell ui, 1.63, 0.97, 1.72
strikeM, 1.09, 0.88, 1.44
strike, 1.09, 0.88, 1.44
violinBody, 1.31, 1.17, 2.58
```



```chart bar "physmodels: ratio new / base (7 of 7)" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
violinM, 1.10, 1.05, 1.10
violin ui, 1.11, 1.05, 1.10
```



## oscillators


```chart bar "oscillators: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
hs oscsin, 0.51, 0.51, 1.29
lf sawpos reset, 0.47, 0.47, 1.30
saw2f4, 1.07, 1.00, 1.16
saw4, 1.40, 2.20, 1.27
triangle, 1.34, 0.76, 0.81
```

Left out of this figure (a ratio unreliable, non-finite or in error): `hs_osccos_test`, `hsp_phasor_test`.



## debug


```chart bar "debug: ratio new / base (1 of 3)" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
pr attack state, 0.94, 0.94, 1.26
pr band lo, 1.18, 0.81, 1.52
pr band mid, 0.58, 0.58, 1.17
pr below threshold, 0.99, 1.00, 1.27
pr dc precise, 1.30, 1.10, 1.34
pr disabled tap n, 1.11, 1.12, 1.96
pr env db, 0.98, 0.98, 1.29
pr env lin, 1.11, 1.09, 1.28
pr env, 1.07, 1.05, 1.29
```



```chart bar "debug: ratio new / base (2 of 3)" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
pr freq db, 1.13, 0.93, 1.23
pr freq lin, 1.34, 0.93, 1.56
pr freq ratio, 1.31, 1.17, 1.38
pr max, 1.00, 0.98, 1.25
pr min, 1.05, 1.12, 1.22
pr multiband, 1.71, 1.73, 1.51
pr peak db, 0.95, 0.75, 1.25
pr peak hold, 1.41, 1.13, 0.89
pr peak lin, 1.00, 0.98, 1.21
```



```chart bar "debug: ratio new / base (3 of 3)" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
pr spec centroid, 1.65, 1.65, 1.41
pr time ms, 0.84, 0.82, 1.24
```

Left out of this figure (a ratio unreliable, non-finite or in error): `probe_tap_n_test`.



## analyzers


```chart bar "analyzers: ratio new / base (1 of 3)" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
abs envelope rect, 0.29, 1.20, 0.73
abs envelope t19, 1.19, 1.22, 0.74
abs envelope tau, 1.19, 1.11, 0.73
amp follower ar, 1.05, 1.05, 1.21
amp follower, 1.09, 1.13, 1.16
amp follower ud, 1.01, 1.06, 1.11
analyzer, 0.78, 0.87, 1.37
linsweep, 1.15, 1.08, 0.92
```

Left out of this figure (a ratio unreliable, non-finite or in error): `abs_envelope_t60_test`.



```chart bar "analyzers: ratio new / base (2 of 3)" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
ms envelope rect, 0.32, 1.16, 0.87
ms envelope t19, 1.19, 1.22, 0.76
ms envelope t60, 1.19, 1.22, 0.76
ms envelope tau, 1.19, 1.11, 0.75
mth analyzer, 0.96, 1.02, 1.33
mth spec lvl6e, 1.24, 1.49, 2.73
rms envelope t19, 1.00, 1.10, 0.73
rms envelope t60, 1.00, 1.11, 0.73
rms envelope tau, 1.00, 1.17, 0.46
```



```chart bar "analyzers: ratio new / base (3 of 3)" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
spec centroid, 0.87, 0.86, 1.21
spec flux, 0.94, 0.88, 1.19
spec spread, 0.78, 0.82, 1.15
```

Left out of this figure (a ratio unreliable, non-finite or in error): `window_kaiser_test`.



## wdmodels


```chart bar "wdmodels: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
capacitor Iout, 1.47, 1.07, 1.05
capacitor, 1.02, 1.07, 1.15
```



## demos


```chart bar "demos: ratio new / base (1 of 2)" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
exciter, 1.03, 1.22, 1.10
fdnrev0 demo, 1.55, 1.52, 1.29
fbank demo, 1.38, 1.45, 1.86
jprev demo, 1.26, 1.06, 1.15
moog vcf demo, 1.02, 0.96, 1.33
mth fbank demo, 1.38, 1.45, 1.86
mth spec lvl demo, 1.37, 1.59, 3.02
param eq demo, 1.01, 1.08, 1.63
pospass demo, 1.10, 1.25, 1.62
```



```chart bar "demos: ratio new / base (2 of 2)" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
projGrav demo, 0.96, 0.90, 1.21
sawtooth demo, 0.67, 0.90, 1.18
spec lvl demo, 1.37, 1.59, 3.02
spec tilt demo, 0.81, 0.57, 1.60
VA osc demo, 1.27, 1.49, 1.18
vocoder demo, 1.43, 1.29, 2.90
wah4 demo, 1.11, 1.72, 1.01
```



## vaeffects


```chart bar "vaeffects: ratio new / base (1 of 3)" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
autowah, 1.10, 1.10, 1.11
bp2Matched, 1.09, 0.81, 1.24
crybaby, 1.02, 0.94, 1.21
hp2Matched, 1.05, 1.45, 1.35
highshelf2Matched, 1.35, 1.10, 1.36
klonCentaur, 3.10, 3.18, 2.32
korg35HPF, 0.99, 1.09, 1.13
korg35LPF, 1.09, 0.97, 1.19
lp2Matched, 1.09, 1.46, 1.24
```



```chart bar "vaeffects: ratio new / base (2 of 3)" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
lowshelf2Matched, 1.10, 0.95, 1.36
moog vcf 2b, 1.72, 1.46, 2.34
moog vcf, 1.12, 1.64, 1.07
oberheimBPF, 1.00, 0.97, 1.12
peaking2Matched, 1.14, 0.96, 1.38
sK2BPF, 0.94, 0.97, 1.17
sK1HPF, 1.11, 1.11, 0.85
sK1LPF, 1.20, 1.27, 0.70
sK1, 1.37, 1.40, 0.89
```



```chart bar "vaeffects: ratio new / base (3 of 3)" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
vocoder, 1.54, 1.37, 2.28
wah4, 1.30, 1.67, 1.06
```



## basics


```chart bar "basics: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
bypass fade, 0.74, 0.74, 1.11
line, 1.02, 1.02, 1.32
peakholder, 1.08, 1.09, 1.31
ramp, 1.19, 1.10, 1.11
selectmulti, 0.74, 0.75, 1.12
```



## compressors


```chart bar "compressors: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
limiter lad bw, 0.99, 0.96, 1.15
limiter lad mono, 0.99, 0.97, 1.14
```



## misceffects


```chart bar "misceffects: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
dither shaped, 1.07, 1.03, 1.18
granular, 0.86, 1.03, 1.15
speakerbp, 1.00, 0.87, 1.40
```



## filters_basic_comb


```chart bar "filters_basic_comb: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
allpass fcomb1a, 1.11, 1.10, 0.85
lpt19, 1.04, 1.11, 0.73
lpt60, 1.04, 1.11, 0.72
lptN, 1.04, 1.11, 0.73
lptau, 1.05, 1.11, 0.74
```



## filters_direct_ladder


```chart bar "filters_direct_ladder: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
allpassn1mt, 0.99, 0.99, 1.19
allpassnklt, 1.01, 1.01, 1.25
allpassnnlt, 1.01, 1.00, 1.23
iir kl, 1.00, 0.99, 1.13
iir lat1, 1.05, 1.01, 1.28
iir nl, 1.00, 0.99, 1.13
tf21, 1.00, 1.00, 1.29
tf22t, 1.27, 1.07, 0.91
```



## filters_state_variable


```chart bar "filters_state_variable: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
SVFTPT AP2, 0.94, 1.44, 1.27
SVFTPT BP2Norm, 0.95, 0.95, 1.11
SVFTPT BP2, 1.01, 1.01, 1.21
SVFTPT Notch2, 0.94, 1.43, 1.26
svf hp, 1.11, 1.07, 0.83
svf lp, 0.93, 0.96, 1.17
```



## motion


```chart bar "motion: ratio new / base (1 of 2)" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
accelEnvelopeNeg, 0.84, 0.84, 1.25
accelEnvelopePos, 0.84, 0.84, 1.26
gyroEnvelopeAbs, 1.10, 1.08, 1.09
gyroEnvelopeNeg, 0.89, 0.88, 1.28
gyroEnvelopePos, 0.86, 0.88, 1.28
motEnvRange, 1.11, 1.08, 1.08
projectedGravity, 1.24, 0.67, 0.89
shockTrigger, 0.95, 1.00, 1.16
totalAccelRange, 0.58, 0.66, 1.19
```



```chart bar "motion: ratio new / base (2 of 2)" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
totalAccel, 0.66, 0.68, 1.17
totalGyro, 0.66, 0.67, 1.19
```



## instruments


```chart bar "instruments: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
inst envVibrato, 1.15, 1.06, 1.08
```



## pinktrombone


```chart bar "pinktrombone: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
glottis m, 1.10, 1.09, 0.98
```



## reverbs


```chart bar "reverbs: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
jpverb, 1.13, 1.08, 1.18
satrev, 1.12, 1.08, 0.87
```



## filters_parametric_eq


```chart bar "filters_parametric_eq: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
high shelf1 l, 1.12, 1.36, 0.83
high shelf1, 1.13, 1.36, 0.85
high shelf, 1.07, 0.94, 1.36
highshelf, 1.07, 0.94, 1.36
levelfilterN, 1.14, 1.20, 0.93
low shelf, 1.07, 0.92, 1.17
peak eq cq, 1.27, 1.05, 1.71
peak eq, 1.26, 1.03, 1.71
spec tilt, 0.72, 0.78, 1.17
```



## signals


```chart bar "signals: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
smoothq, 0.99, 1.12, 1.17
```



## synths


```chart bar "synths: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
clap, 1.35, 0.83, 1.76
dubDub, 1.82, 1.51, 1.09
kick, 1.05, 1.23, 0.91
popFilterDrum, 1.86, 1.53, 2.29
```



## webaudio


```chart bar "webaudio: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
highshelf2, 1.01, 1.00, 1.26
```



## filters_analog_sections


```chart bar "filters_analog_sections: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
tf1s, 0.23, 1.12, 0.73
tf1sb, 1.15, 1.38, 1.19
tf2s, 1.68, 1.68, 1.48
tf2sb, 0.75, 0.56, 1.43
tf2snp, 1.00, 1.01, 1.12
```



## noises


```chart bar "noises: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
colored noise, 1.15, 1.26, 3.00
lfnoiseN, 1.09, 0.93, 1.37
lfnoise, 0.99, 1.07, 1.25
```



## filters_delay_equalizing_allpass


```chart bar "filters_delay_equalizing_allpass: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
hp-lp even, 1.00, 0.87, 1.31
hp-lp odd, 1.08, 0.93, 1.16
hp+lp even, 1.01, 0.87, 1.29
hp+lp odd, 1.06, 0.91, 1.34
hp+lp, 1.24, 1.29, 1.44
```



## filters_ladder_allpass


```chart bar "filters_ladder_allpass: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
allpassn1m, 1.01, 1.01, 1.16
allpassn, 1.03, 1.03, 1.15
allpassnkl, 1.00, 1.09, 1.18
allpassnn, 1.18, 0.97, 1.19
```



## filters_mth_octave_filterbank


```chart bar "filters_mth_octave_filterbank: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
mth fbank3, 0.54, 0.73, 1.17
mth fbank5, 0.83, 0.85, 1.60
mth fbank alt, 0.54, 0.73, 1.17
mth fbank default, 0.82, 0.84, 1.59
mth fbank, 0.92, 0.73, 1.18
```



## filters_useful_special


```chart bar "filters_useful_special: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
apnl, 0.95, 0.95, 1.19
bs1770 kfilter, 0.95, 0.96, 1.15
tf2np, 1.00, 1.00, 1.12
wgr, 1.00, 1.00, 1.16
```



## filters_elliptic


```chart bar "filters_elliptic: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
hp3e, 1.17, 0.92, 1.43
lp3e, 1.05, 1.15, 1.20
lp6e, 1.35, 1.12, 2.40
```

Left out of this figure (a ratio unreliable, non-finite or in error): `highpass6e_test`.



## filters_bandpass_bandstop


```chart bar "filters_bandpass_bandstop: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
bp0 bs1, 0.80, 0.60, 1.43
bp, 0.81, 0.60, 1.43
bs, 0.58, 0.50, 1.55
```



## filters_butterworth


```chart bar "filters_butterworth: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
hp, 1.11, 1.02, 1.41
lp0 hp1, 1.29, 1.12, 1.22
lp, 0.98, 0.80, 1.25
```



## filters_pospass


```chart bar "filters_pospass: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
hilbert, 0.75, 0.96, 1.38
pospass6e, 1.04, 1.61, 2.82
pospass, 1.09, 0.92, 1.34
```



## filters_resonator


```chart bar "filters_resonator: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
resonbp, 1.49, 1.10, 1.03
resonhp, 1.32, 1.04, 1.49
resonlp, 1.50, 1.12, 1.38
```



## maths


```chart bar "maths: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
zc, 1.16, 1.15, 0.77
```



## soundfiles


```chart bar "soundfiles: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
loop speed level, 1.01, 0.98, 1.15
loop, 1.00, 1.00, 1.13
```



## fds


```chart bar "fds: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
hammer, 1.00, 1.00, 1.11
```



## filters_elliptic_bandpass


```chart bar "filters_elliptic_bandpass: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
bp12e, 0.93, 1.13, 1.92
bp6e, 0.79, 0.63, 1.72
```



## filters_filterbank


```chart bar "filters_filterbank: ratio new / base" y-max=4 y-ref=1:"no change"
test, fast-math, strict, vec
fbank, 1.01, 0.90, 1.30
fbanki, 0.80, 0.79, 1.31
```



# Raw data

Per test, grouped by test file:

- the fast-math time per frame in ns, base and new;
- the ratio new / base in each compilation: ▲ marks 1.10 or more, ▼ 0.90
  or less, `?` an unreliable ratio, NaN a side that is not finite, and
  `error` a build that failed;
- the operations per sample in fast-math.

## physmodels

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
SFFormantModelBP; 8.1; 7.1; 0.87 ▼; 1.07; 2.47 ▲; 0/0/0; 0/0/0
SFFormantModelBP_ui_MIDI; 39.1; 43.4; 1.11 ▲; 1.16 ▲; 1.17 ▲; 36/0/5; 31/0/5
SFFormantModelBP_ui; 38.5; 42.2; 1.10; 1.12 ▲; 1.17 ▲; 36/0/5; 31/0/5
SFFormantModelFofCycle; 58.9; 57.6; 0.98; 1.16 ▲; 0.92; 0/0/30; 0/0/30
SFFormantModelFofCycle_ui_MIDI; 83.0; 94.5; 1.14 ▲; 1.22 ▲; 0.98; 0/0/30; 0/0/30
SFFormantModelFofCycle_ui; 85.1; 92.7; 1.09; 1.22 ▲; 1.00; 0/0/30; 0/0/30
SFFormantModelFofSmooth; 16.7; 15.9; 0.95; 0.96; 0.88 ▼; 0/0/10; 0/0/10
SFFormantModelFofSmooth_ui_MIDI; 52.8; 58.2; 1.10 ▲; 1.10; 1.00; 0/0/10; 0/0/10
SFFormantModelFofSmooth_ui; 53.3; 56.8; 1.06; 1.08; 1.00; 0/0/10; 0/0/10
SFFormantModel; 58.4; 57.8; 0.99; 1.15 ▲; 0.92; 0/0/30; 0/0/30
blower; 3.5; 3.5; 1.01; 0.76 ▼; 1.45 ▲; 0/0/0; 0/0/0
blower_ui; 3.5; 3.5; 0.99; 0.76 ▼; 1.33 ▲; 0/0/0; 0/0/0
brassLipsTable; 3.5; 3.5; 1.01; 0.99; 0.70 ▼; 0/0/0; 0/0/0
brassModel; 4.6; 4.6; 1.00; 1.01; 0.99; 0/0/0; 0/0/0
brassModel_ui; 8.8; 8.8; 1.00; 1.00; 1.00; 1/0/2; 1/0/2
brass_ui_MIDI; 10.4; 10.5; 1.00; 1.02; 0.94; 1/0/2; 1/0/2
brass_ui; 10.5; 10.7; 1.02; 1.04; 1.15 ▲; 1/0/2; 1/0/2
bridgeFilter; 2.0; 1.6; 0.79 ▼; 0.75 ▼; 0.71 ▼; 0/0/0; 0/0/0
churchBellModel; 24.2; 46.3; 1.91 ▲; 1.90 ▲; 2.21 ▲; 0/0/0; 0/0/0
churchBell; 37.4; 48.2; 1.29 ▲; 1.57 ▲; 1.73 ▲; 0/0/0; 0/0/0
churchBell_ui; 26.1; 42.8; 1.64 ▲; 0.97; 1.72 ▲; 0/0/0; 0/0/0
clarinetModel; 2.8; 2.6; 0.94; 1.00; 1.39 ?; 0/0/0; 0/0/0
clarinetModel_ui; 4.7; 4.8; 1.00; 0.99; 1.00; 0/0/0; 0/0/0
clarinetReed; 2.3; 0.5; 0.23 ▼; 0.24 ▼; 0.64 ▼; 0/0/0; 0/0/0
clarinet_ui_MIDI; 8.4; 7.5; 0.89 ▼; 0.90; 0.92; 1/0/0; 1/0/0
clarinet_ui; 6.1; 6.0; 0.98; 0.91; 1.01; 0/0/0; 0/0/0
djembeModel; 9.7; 13.0; 1.35 ▲; 1.09; 2.19 ▲; 0/0/0; 0/0/0
djembe; 11.9; 15.1; 1.27 ▲; 0.99; 1.56 ▲; 0/0/0; 0/0/0
djembe_ui_MIDI; 12.1; 17.6; 1.45 ▲; 1.18 ▲; 1.64 ▲; 0/0/0; 0/0/0
elecGuitarModel; 7.2; 7.1; 1.00; 1.00; 1.00; 0/0/0; 0/0/0
elecGuitar; 6.8; 7.2; 1.06; 1.04; 1.01; 0/0/0; 0/0/0
elecGuitar_ui_MIDI; 14.1; 14.5; 1.03; 1.02; 1.01; 8/0/1; 3/0/1
englishBellModel; 24.3; 46.4; 1.91 ▲; 1.89 ▲; 2.20 ▲; 0/0/0; 0/0/0
englishBell; 37.4; 48.2; 1.29 ▲; 1.57 ▲; 1.72 ▲; 0/0/0; 0/0/0
englishBell_ui; 26.3; 42.8; 1.63 ▲; 0.97; 1.74 ▲; 0/0/0; 0/0/0
fluteJetTable; 2.4; 0.5; 0.22 ▼; 0.22 ▼; 0.56 ▼; 0/0/0; 0/0/0
fluteModel; 4.9; 4.9; 1.00; 1.01; 1.00; 0/0/0; 0/0/0
fluteModel_ui; 8.7; 8.7; 1.00; 1.00; 1.00; 0/0/0; 0/0/0
flute_ui_MIDI; 11.4; 11.1; 0.98; 1.01; 0.96; 1/0/0; 1/0/0
flute_ui; 10.0; 9.7; 0.97; 0.98; 0.96; 0/0/0; 0/0/0
fofCycle; 9.9; 9.8; 0.99; 1.03; 1.05; 0/0/6; 0/0/6
fofSH; 4.6; 3.3; 0.72 ▼; 0.71 ▼; 0.93; 0/0/2; 0/0/2
fofSmooth; 4.6; 3.5; 0.77 ▼; 0.88 ▼; 1.13 ▲; 0/0/2; 0/0/2
fof; 2.8; 1.8; 0.65 ▼; 0.70 ▼; 0.96; 0/0/0; 0/0/0
formantFilterBP; 3.5; 5.2; 1.49 ▲; 1.10; 1.00; 0/0/0; 0/0/0
formantFilterFofCycle; 10.9; 10.8; 0.99; 1.11 ▲; 1.03; 0/0/6; 0/0/6
formantFilterFofSmooth; 4.5; 3.5; 0.78 ▼; 0.80 ▼; 1.03; 0/0/2; 0/0/2
formantFilterbankBP; 4.9; 5.4; 1.10; 1.18 ▲; 2.15 ▲; 0/0/0; 0/0/0
formantFilterbankFofCycle; 49.2; 51.2; 1.04; 1.21 ▲; 0.95; 0/0/24; 0/0/24
formantFilterbankFofSmooth; 16.7; 15.7; 0.94; 1.02; 0.86 ▼; 0/0/10; 0/0/10
formantFilterbank; 4.9; 5.4; 1.10; 1.18 ▲; 2.15 ▲; 0/0/0; 0/0/0
frenchBellModel; 24.3; 46.4; 1.91 ▲; 1.90 ▲; 2.22 ▲; 0/0/0; 0/0/0
frenchBell; 37.4; 48.1; 1.29 ▲; 1.57 ▲; 1.72 ▲; 0/0/0; 0/0/0
frenchBell_ui; 26.1; 42.9; 1.64 ▲; 0.97; 1.73 ▲; 0/0/0; 0/0/0
germanBellModel; 24.4; 46.3; 1.90 ▲; 1.89 ▲; 2.21 ▲; 0/0/0; 0/0/0
germanBell; 37.4; 48.2; 1.29 ▲; 1.57 ▲; 1.72 ▲; 0/0/0; 0/0/0
germanBell_ui; 26.2; 42.8; 1.63 ▲; 0.97; 1.73 ▲; 0/0/0; 0/0/0
guitarModel; 5.5; 5.6; 1.01; 0.99; 1.00; 0/0/0; 0/0/0
guitar; 6.1; 6.5; 1.06; 1.08; 1.03; 0/0/0; 0/0/0
guitar_ui_MIDI; 14.0; 14.3; 1.02; 0.99; 1.02; 8/0/1; 3/0/1
idealString; 5.0; 5.0; 1.00; 0.97; 1.00; 0/0/0; 0/0/0
ksReflexionFilter; 2.6; 0.8; 0.29 ▼; 0.29 ▼; 0.71 ▼; 0/0/0; 0/0/0
ks; 2.7; 2.7; 1.00; 1.00; 1.01; 0/0/0; 0/0/0
ks_ui_MIDI; 5.6; 5.6; 1.00; 1.00; 1.00; 1/0/0; 1/0/0
marimbaBarModel; 25.4; 46.3; 1.82 ▲; 1.85 ▲; 2.22 ▲; 0/0/0; 0/0/0
marimbaModel; 49.0; 50.5; 1.03; 1.18 ▲; 2.20 ▲; 0/0/0; 0/0/0
marimbaResTube; 2.8; 2.4; 0.84 ▼; 1.00; 1.00; 0/0/0; 0/0/0
marimba; 40.5; 53.2; 1.32 ▲; 1.52 ▲; 1.68 ▲; 0/0/0; 0/0/0
marimba_ui_MIDI; 49.5; 41.2; 0.83 ▼; 0.98; 1.71 ▲; 0/0/0; 0/0/0
modalModel; 4.8; 3.4; 0.71 ▼; 1.25 ▲; 3.31 ▲; 0/0/0; 0/0/0
modeFilter; 3.5; 3.4; 0.98; 0.99; 1.16 ▲; 0/0/0; 0/0/0
modeInterpRes; 10.8; 14.2; 1.32 ▲; 0.95; 1.46 ▲; 0/0/0; 0/0/0
modularInterpBody; 10.0; 13.9; 1.39 ▲; 1.05; 2.44 ▲; 0/0/0; 0/0/0
modularInterpInstr; 31.6; 44.9; 1.42 ▲; 1.20 ▲; 1.64 ▲; 0/0/0; 0/0/0
modularInterpInstr_ui_MIDI; 31.2; 43.9; 1.41 ▲; 1.09; 1.52 ▲; 8/0/1; 3/0/1
modularInterpStringModel; 29.5; 43.3; 1.47 ▲; 1.13 ▲; 1.67 ▲; 0/0/0; 0/0/0
nylonGuitarModel; 5.6; 5.5; 0.99; 1.00; 1.00; 0/0/0; 0/0/0
nylonGuitar; 6.2; 6.5; 1.05; 1.08; 1.03; 0/0/0; 0/0/0
nylonGuitar_ui_MIDI; 13.8; 14.3; 1.03; 0.99; 1.02; 8/0/1; 3/0/1
nylonString; 4.4; 4.5; 1.00; 1.00; 0.97; 0/0/0; 0/0/0
openStringPickDown; 2.5; 2.8; 1.12 ▲; 1.00; 1.01; 0/0/0; 0/0/0
openStringPickUp; 1.7; 1.7; 1.00; 1.00; 0.99; 0/0/0; 0/0/0
openString; 4.4; 4.4; 1.00; 1.00; 0.99; 0/0/0; 0/0/0
openTube; 1.8; 1.8; 1.00; 1.00; 1.00; 0/0/0; 0/0/0
pluckString; 3.5; 4.7; 1.34 ▲; 0.94; 1.14 ▲; 0/0/0; 0/0/0
reedTable; 2.3; 0.5; 0.23 ▼; 0.24 ▼; 0.58 ▼; 0/0/0; 0/0/0
russianBellModel; 24.3; 46.4; 1.90 ▲; 1.89 ▲; 2.21 ▲; 0/0/0; 0/0/0
russianBell; 37.4; 48.2; 1.29 ▲; 1.58 ▲; 1.73 ▲; 0/0/0; 0/0/0
russianBell_ui; 26.3; 42.8; 1.63 ▲; 0.97; 1.73 ▲; 0/0/0; 0/0/0
standardBellModel; 24.3; 46.4; 1.91 ▲; 1.90 ▲; 2.21 ▲; 0/0/0; 0/0/0
standardBell; 37.4; 48.2; 1.29 ▲; 1.57 ▲; 1.71 ▲; 0/0/0; 0/0/0
standardBell_ui; 26.2; 42.8; 1.63 ▲; 0.97; 1.72 ▲; 0/0/0; 0/0/0
steelString; 4.4; 4.5; 1.00; 1.00; 0.97; 0/0/0; 0/0/0
strikeModel; 4.2; 4.5; 1.09; 0.88 ▼; 1.44 ▲; 0/0/0; 0/0/0
strike; 4.2; 4.5; 1.09; 0.88 ▼; 1.44 ▲; 0/0/0; 0/0/0
stringSegment; 1.8; 1.8; 1.00; 1.00; 1.00; 0/0/0; 0/0/0
violinBody; 5.4; 7.0; 1.31 ▲; 1.17 ▲; 2.58 ▲; 0/0/0; 0/0/0
violinBowedString; 3.4; 3.4; 1.00; 1.00; 1.01; 0/0/1; 0/0/1
violinModel; 5.9; 6.5; 1.10; 1.05; 1.10 ▲; 0/0/1; 0/0/1
violin_ui_MIDI; 14.6; 13.9; 0.95; 1.00; 0.98; 1/0/1; 1/0/1
violin_ui; 5.9; 6.5; 1.11 ▲; 1.05; 1.10 ▲; 0/0/1; 0/0/1
```

## oscillators

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
CZhalfSineP; 2.6; 1.8; 0.71 ▼; 0.70 ▼; 0.82 ▼; 0/0/1; 0/0/1
CZhalfSine; 2.5; 1.6; 0.63 ▼; 0.63 ▼; 0.84 ▼; 0/0/1; 0/0/1
CZpulseP; 2.5; 1.6; 0.66 ▼; 0.67 ▼; 0.84 ▼; 0/0/1; 0/0/1
CZpulse; 2.3; 1.4; 0.60 ▼; 0.63 ▼; 0.78 ▼; 0/0/1; 0/0/1
CZresSaw; 2.6; 1.8; 0.68 ▼; 0.69 ▼; 0.93; 0/0/1; 0/0/1
CZresTrap; 2.8; 1.7; 0.62 ▼; 0.63 ▼; 0.87 ▼; 0/0/1; 0/0/1
CZresTriangle; 2.6; 1.9; 0.70 ▼; 0.69 ▼; 0.95; 0/0/1; 0/0/1
CZsawP; 2.5; 1.7; 0.67 ▼; 0.67 ▼; 0.85 ▼; 0/0/1; 0/0/1
CZsaw; 2.4; 1.5; 0.65 ▼; 0.63 ▼; 0.86 ▼; 0/0/1; 0/0/1
CZsinePulseP; 2.7; 1.9; 0.69 ▼; 0.71 ▼; 0.86 ▼; 0/0/1; 0/0/1
CZsinePulse; 2.5; 1.7; 0.69 ▼; 0.69 ▼; 0.87 ▼; 0/0/1; 0/0/1
CZsquareP; 2.7; 1.9; 0.70 ▼; 0.73 ▼; 0.84 ▼; 0/0/1; 0/0/1
CZsquare; 2.5; 1.6; 0.65 ▼; 0.71 ▼; 0.86 ▼; 0/0/1; 0/0/1
SAFE; 5.3; 0.5; 0.10 ▼; 0.10 ▼; 0.51 ▼; 0/0/0; 0/0/0
hs_osccos; 0.5; 0.5; 1.00 ?; 1.05 ?; 1.89 ▲; 0/0/0; 0/0/0
hs_oscsin; 2.3; 1.1; 0.51 ▼; 0.51 ▼; 1.29 ▲; 0/0/0; 0/0/0
hs_phasor; 2.2; 1.1; 0.52 ▼; 0.52 ▼; 1.11 ?; 0/0/0; 0/0/0
hsp_phasor; 0.6; 0.7; 1.12 ▲; 0.79 ?; 2.31 ?; 0/0/0; 0/0/0
imptrainN; 2.6; 2.3; 0.88 ▼; 0.96; 0.90 ▼; 0/0/0; 0/0/0
imptrain; 2.4; 1.0; 0.41 ▼; 0.41 ▼; 0.58 ▼; 0/0/0; 0/0/0
lf_imptrain; 3.9; 0.6; 0.15 ▼; 0.16 ▼; 0.59 ▼; 0/0/0; 0/0/0
lf_pulsetrain; 3.9; 0.5; 0.14 ▼; 0.15 ▼; 0.52 ▼; 0/0/0; 0/0/0
lf_pulsetrainpos; 3.7; 0.5; 0.14 ▼; 0.14 ▼; 0.52 ▼; 0/0/0; 0/0/0
lf_saw; 3.9; 0.5; 0.14 ▼; 0.12 ▼; 0.53 ▼; 0/0/0; 0/0/0
lf_sawpos_phase_reset; 0.7; 0.5; 0.70 ?; 1.04 ?; 2.33 ?; 0/0/0; 0/0/0
lf_sawpos_phase; 4.3; 0.5; 0.13 ▼; 0.12 ▼; 0.52 ▼; 0/0/0; 0/0/0
lf_sawpos_reset; 2.3; 1.1; 0.47 ▼; 0.47 ▼; 1.30 ▲; 0/0/0; 0/0/0
lf_sawpos; 4.3; 0.5; 0.13 ▼; 0.13 ▼; 0.53 ▼; 0/0/0; 0/0/0
lf_squarewave; 3.9; 0.5; 0.14 ▼; 0.17 ▼; 0.52 ▼; 0/0/0; 0/0/0
lf_squarewavepos; 3.7; 0.5; 0.14 ▼; 0.14 ▼; 0.52 ▼; 0/0/0; 0/0/0
lf_triangle; 3.5; 0.5; 0.15 ▼; 0.16 ▼; 0.54 ▼; 0/0/0; 0/0/0
lf_trianglepos; 3.4; 0.5; 0.16 ▼; 0.15 ▼; 0.54 ▼; 0/0/0; 0/0/0
m_osccos; 2.8; 1.8; 0.66 ▼; 0.66 ▼; 0.80 ▼; 0/0/1; 0/0/1
m_oscsin; 2.7; 1.6; 0.59 ▼; 0.58 ▼; 0.78 ▼; 0/0/1; 0/0/1
osc; 3.5; 0.6; 0.16 ▼; 0.17 ▼; 0.55 ▼; 0/0/0; 0/0/0
osccos; 3.2; 0.6; 0.18 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
osci; 2.6; 0.6; 0.23 ▼; 0.22 ▼; 0.62 ▼; 0/0/0; 0/0/0
oscp; 2.5; 1.0; 0.38 ▼; 0.38 ▼; 0.60 ▼; 0/0/0; 0/0/0
oscq; 5.4; 5.4; 1.00; 1.00; 1.00; 0/0/0; 0/0/0
oscs; 3.5; 3.5; 1.00; 1.00; 1.00; 0/0/0; 0/0/0
oscsin; 3.5; 0.6; 0.16 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
oscw; 5.4; 5.4; 1.00; 1.00; 1.00; 0/0/0; 0/0/0
oscwc; 5.4; 5.4; 1.00; 1.00; 1.00; 0/0/0; 0/0/0
oscws; 5.1; 5.1; 1.00; 1.00; 1.00; 0/0/0; 0/0/0
phasor; 2.1; 0.5; 0.26 ▼; 0.26 ▼; 0.52 ▼; 0/0/0; 0/0/0
polyblep_saw; 2.0; 0.6; 0.31 ▼; 0.26 ▼; 0.65 ▼; 0/0/0; 0/0/0
polyblep_square; 2.4; 1.0; 0.40 ▼; 0.40 ▼; 0.82 ▼; 0/0/2; 0/0/0
polyblep; 2.5; 0.6; 0.26 ▼; 0.25 ▼; 0.58 ▼; 0/0/0; 0/0/0
polyblep_triangle; 3.2; 3.2; 1.02; 0.87 ▼; 0.90 ▼; 0/0/2; 0/0/0
pulsetrainN; 2.6; 1.8; 0.67 ▼; 0.83 ▼; 0.99; 0/0/0; 0/0/0
pulsetrain; 2.6; 0.8; 0.30 ▼; 0.29 ▼; 0.67 ▼; 0/0/0; 0/0/0
rpm_sawtooth; 9.6; 9.5; 0.99; 0.99; 1.08; 0/0/1; 0/0/1
rpm_square; 10.3; 10.3; 0.99; 0.99; 1.06; 0/0/1; 0/0/1
saw2; 3.3; 0.6; 0.17 ▼; 0.16 ▼; 0.83 ▼; 0/0/0; 0/0/0
saw2dpw; 2.9; 1.1; 0.40 ▼; 0.38 ▼; 0.62 ▼; 0/0/0; 0/0/0
saw2f2; 4.5; 4.5; 1.00; 1.00; 1.06; 0/0/0; 0/0/0
saw2f4; 6.1; 6.5; 1.07; 1.00; 1.16 ▲; 0/0/0; 0/0/0
saw2ptr; 3.3; 0.6; 0.17 ▼; 0.16 ▼; 0.82 ▼; 0/0/0; 0/0/0
saw3; 2.7; 1.7; 0.63 ▼; 0.78 ▼; 0.96; 0/0/0; 0/0/0
saw4; 3.6; 5.0; 1.40 ▲; 2.20 ▲; 1.27 ▲; 0/0/0; 0/0/0
sawN; 2.7; 1.7; 0.63 ▼; 0.78 ▼; 0.96; 0/0/0; 0/0/0
sawNp; 2.8; 1.7; 0.61 ▼; 0.76 ▼; 0.96; 0/0/0; 0/0/0
sawtooth; 3.3; 0.6; 0.17 ▼; 0.16 ▼; 0.83 ▼; 0/0/0; 0/0/0
squareN; 2.6; 1.7; 0.67 ▼; 0.83 ▼; 1.00; 0/0/0; 0/0/0
square; 2.5; 0.8; 0.30 ▼; 0.29 ▼; 0.67 ▼; 0/0/0; 0/0/0
triangleN; 2.8; 2.3; 0.83 ▼; 0.83 ▼; 1.06; 0/0/0; 0/0/0
triangle; 2.6; 3.5; 1.34 ▲; 0.76 ▼; 0.81 ▼; 0/0/0; 0/0/0
twin_osc_detune; 2.2; 1.8; 0.80 ▼; 0.86 ▼; 0.76 ▼; 0/0/0; 0/0/0
twin_osc_morph; 2.2; 1.8; 0.80 ▼; 0.86 ▼; 0.75 ▼; 0/0/0; 0/0/0
twin_osc_pwm; 2.2; 1.8; 0.80 ▼; 0.87 ▼; 0.76 ▼; 0/0/0; 0/0/0
```

## debug

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
probe_attack_state; 3.9; 3.7; 0.94; 0.94; 1.26 ▲; 0/0/1; 0/0/1
probe_band_hi; 3.6; 3.6; 1.00; 0.92; 1.23 ?; 0/1/0; 0/1/0
probe_band_lo; 3.6; 4.2; 1.18 ▲; 0.81 ▼; 1.52 ▲; 0/1/0; 0/1/0
probe_band_mid; 7.2; 4.1; 0.58 ▼; 0.58 ▼; 1.17 ▲; 0/1/0; 0/1/0
probe_below_threshold; 3.7; 3.7; 0.99; 1.00; 1.27 ▲; 0/0/1; 0/0/1
probe_bool; 2.3; 0.5; 0.23 ▼; 0.23 ▼; 0.64 ▼; 0/0/0; 0/0/0
probe_crest_db; 3.2; 2.8; 0.89 ▼; 0.82 ▼; 1.05; 1/1/1; 1/1/1
probe_dc_precise; 3.5; 4.6; 1.30 ▲; 1.10 ▲; 1.34 ▲; 0/0/0; 0/0/0
probe_dc; 3.1; 2.5; 0.79 ▼; 0.79 ▼; 0.89 ▼; 0/0/0; 0/0/0
probe_disabled_attack_state; 3.1; 0.5; 0.17 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
probe_disabled_band_hi; 3.3; 0.5; 0.16 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
probe_disabled_band_lo; 3.3; 0.5; 0.16 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
probe_disabled_band_mid; 3.3; 0.5; 0.16 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
probe_disabled_below_threshold; 3.1; 0.5; 0.17 ▼; 0.17 ▼; 0.55 ▼; 0/0/0; 0/0/0
probe_disabled_bool; 2.4; 0.5; 0.22 ▼; 0.20 ▼; 0.54 ?; 0/0/0; 0/0/0
probe_disabled_crest_db; 3.3; 0.5; 0.16 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
probe_disabled_dc_precise; 3.1; 0.5; 0.17 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
probe_disabled_dc; 3.3; 0.5; 0.16 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
probe_disabled_env_db; 3.1; 0.5; 0.17 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
probe_disabled_env_lin; 3.1; 0.5; 0.17 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
probe_disabled_env; 3.3; 0.5; 0.16 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
probe_disabled_freq_db; 3.1; 0.5; 0.17 ▼; 0.18 ▼; 0.56 ▼; 0/0/0; 0/0/0
probe_disabled_freq_lin; 3.1; 0.5; 0.17 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
probe_disabled_freq_ratio; 3.1; 0.5; 0.17 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
probe_disabled_max; 3.3; 0.5; 0.16 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
probe_disabled_min; 3.3; 0.5; 0.16 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
probe_disabled_multiband; 3.1; 0.5; 0.17 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
probe_disabled_onset; 3.1; 0.5; 0.17 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
probe_disabled_peak_db; 3.3; 0.5; 0.16 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
probe_disabled_peak_hold; 3.1; 0.5; 0.17 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
probe_disabled_peak_lin; 3.3; 0.5; 0.16 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
probe_disabled_rms_db; 3.3; 0.5; 0.16 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
probe_disabled_rms_lin; 3.3; 0.5; 0.16 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
probe_disabled_sample_count; 3.1; 0.5; 0.17 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
probe_disabled_silence; 3.1; 0.5; 0.17 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
probe_disabled_slew; 3.3; 0.5; 0.16 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
probe_disabled_spectral_centroid; 3.1; 0.5; 0.17 ▼; 0.17 ▼; 0.55 ▼; 0/0/0; 0/0/0
probe_disabled_tap_n; 6.4; 7.1; 1.11 ▲; 1.12 ▲; 1.96 ▲; 0/0/0; 0/0/0
probe_disabled_tap; 3.3; 0.5; 0.16 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
probe_disabled_time_ms; 3.1; 0.5; 0.17 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
probe_disabled_value; 3.3; 0.5; 0.16 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
probe_disabled_zcr; 3.3; 0.5; 0.16 ▼; 0.17 ▼; 0.56 ▼; 0/0/0; 0/0/0
probe_env_db; 3.7; 3.7; 0.98; 0.98; 1.29 ▲; 0/0/1; 0/0/1
probe_env_lin; 4.2; 4.7; 1.11 ▲; 1.09; 1.28 ▲; 0/0/0; 0/0/0
probe_env; 4.4; 4.7; 1.07; 1.05; 1.29 ▲; 0/0/0; 0/0/0
probe_freq_db; 3.7; 4.2; 1.13 ▲; 0.93; 1.23 ▲; 0/1/1; 0/1/1
probe_freq_lin; 3.5; 4.7; 1.34 ▲; 0.93; 1.56 ▲; 0/1/0; 0/1/0
probe_freq_ratio; 3.6; 4.8; 1.31 ▲; 1.17 ▲; 1.38 ▲; 1/2/0; 1/2/0
probe_max; 3.9; 3.9; 1.00; 0.98; 1.25 ▲; 0/0/0; 0/0/0
probe_min; 3.7; 3.8; 1.05; 1.12 ▲; 1.22 ▲; 0/0/0; 0/0/0
probe_multiband; 9.2; 15.7; 1.71 ▲; 1.73 ▲; 1.51 ▲; 0/8/0; 0/8/0
probe_onset; 3.8; 3.7; 0.99; 0.99; 0.99; 0/0/1; 0/0/1
probe_peak_db; 2.9; 2.7; 0.95; 0.75 ▼; 1.25 ▲; 0/0/1; 0/0/1
probe_peak_hold; 2.5; 3.5; 1.41 ▲; 1.13 ▲; 0.89 ▼; 0/0/0; 0/0/0
probe_peak_lin; 3.9; 3.9; 1.00; 0.98; 1.21 ▲; 0/0/0; 0/0/0
probe_rms_db; 2.6; 2.0; 0.74 ▼; 0.74 ▼; 0.85 ▼; 0/1/1; 0/1/1
probe_rms_lin; 2.5; 0.8; 0.33 ▼; 0.33 ▼; 1.03; 0/1/0; 0/1/0
probe_sample_count; 3.1; 0.9; 0.29 ▼; 0.30 ▼; 0.81 ▼; 0/0/0; 0/0/0
probe_silence; 2.7; 2.0; 0.75 ▼; 0.74 ▼; 0.89 ?; 0/1/1; 0/1/1
probe_slew; 2.6; 1.4; 0.53 ▼; 0.50 ▼; 1.00; 0/1/0; 0/1/0
probe_spectral_centroid; 9.3; 15.3; 1.65 ▲; 1.65 ▲; 1.41 ▲; 1/8/0; 1/8/0
probe_tap_n; 7.5; 9.9; 1.31 ?; 1.28 ▲; 1.40 ▲; 0/1/1; 0/1/1
probe_tap; 2.6; 2.0; 0.75 ▼; 0.74 ▼; 0.85 ▼; 0/1/1; 0/1/1
probe_time_ms; 3.1; 2.6; 0.84 ▼; 0.82 ▼; 1.24 ▲; 0/0/0; 0/0/0
probe_value; 2.7; 0.5; 0.19 ▼; 0.25 ▼; 0.69 ▼; 0/0/0; 0/0/0
probe_zcr; 2.5; 2.2; 0.88 ▼; 0.98; 0.80 ▼; 0/0/0; 0/0/0
```

## analyzers

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
abs_envelope_rect; 2.5; 0.7; 0.29 ▼; 1.20 ▲; 0.73 ▼; 0/0/0; 0/0/0
abs_envelope_t19; 2.4; 2.8; 1.19 ▲; 1.22 ▲; 0.74 ▼; 0/0/0; 0/0/0
abs_envelope_t60; 2.4; 2.8; 1.19 ▲; 1.22 ?; 0.74 ▼; 0/0/0; 0/0/0
abs_envelope_tau; 2.4; 2.8; 1.19 ▲; 1.11 ▲; 0.73 ▼; 0/0/0; 0/0/0
amp_follower_ar; 4.6; 4.8; 1.05; 1.05; 1.21 ▲; 0/0/0; 0/0/0
amp_follower; 3.9; 4.2; 1.09; 1.13 ▲; 1.16 ▲; 0/0/0; 0/0/0
amp_follower_ud; 3.5; 3.5; 1.01; 1.06; 1.11 ▲; 0/0/0; 0/0/0
analyzer; 7.9; 6.2; 0.78 ▼; 0.87 ▼; 1.37 ▲; 0/0/0; 0/0/0
fft; 5.4; 4.7; 0.88 ▼; 0.87 ▼; 0.82 ▼; 0/0/0; 0/0/0
goertzelComp; 4.1; 4.1; 1.00; 0.99; 0.80 ▼; 0/1/0; 0/1/0
goertzelOpt; 4.8; 4.8; 1.00; 0.98; 0.79 ▼; 0/1/0; 0/1/0
goertzel; 4.8; 4.8; 1.00; 0.98; 0.79 ▼; 0/1/0; 0/1/0
ifft; 5.7; 4.9; 0.87 ▼; 0.88 ▼; 0.92; 0/0/0; 0/0/0
linsweep; 3.1; 3.6; 1.15 ▲; 1.08; 0.92; 0/0/2; 0/0/2
logsweep; 3.4; 3.2; 0.93; 0.97; 0.93; 0/0/3; 0/0/3
loudness_integrated; 6.4; 6.0; 0.94; 0.95; 1.05; 2/0/1; 2/0/1
loudness_momentary; 4.2; 3.9; 0.94; 0.81 ▼; 0.90 ?; 0/0/1; 0/0/1
loudness_shortterm; 4.2; 3.9; 0.94; 0.80 ▼; 0.99; 0/0/1; 0/0/1
ms_envelope_rect; 2.4; 0.8; 0.32 ▼; 1.16 ▲; 0.87 ▼; 0/0/0; 0/0/0
ms_envelope_t19; 2.4; 2.8; 1.19 ▲; 1.22 ▲; 0.76 ▼; 0/0/0; 0/0/0
ms_envelope_t60; 2.4; 2.8; 1.19 ▲; 1.22 ▲; 0.76 ▼; 0/0/0; 0/0/0
ms_envelope_tau; 2.4; 2.8; 1.19 ▲; 1.11 ▲; 0.75 ▼; 0/0/0; 0/0/0
mth_octave_analyzer; 14.9; 14.2; 0.96; 1.02; 1.33 ▲; 0/0/0; 0/0/0
mth_octave_spectral_level6e; 31.3; 38.8; 1.24 ▲; 1.49 ▲; 2.73 ▲; 0/0/5; 0/0/5
pitchTracker; 23.9; 22.6; 0.94; 0.89 ▼; 1.05; 10/0/1; 2/0/1
resonator; 5.2; 4.8; 0.93; 0.90; 1.06; 0/1/1; 0/1/1
rms_envelope_rect; 2.4; 0.8; 0.31 ▼; 0.29 ▼; 0.84 ▼; 0/1/0; 0/1/0
rms_envelope_t19; 3.9; 3.9; 1.00; 1.10 ▲; 0.73 ▼; 0/1/0; 0/1/0
rms_envelope_t60; 3.9; 3.9; 1.00; 1.11 ▲; 0.73 ▼; 0/1/0; 0/1/0
rms_envelope_tau; 3.9; 3.9; 1.00; 1.17 ▲; 0.46 ▼; 0/1/0; 0/1/0
spectralCentroid; 20.5; 19.2; 0.94; 0.94; 1.02; 2/3/1; 2/3/1
spectral_centroid; 19.1; 16.6; 0.87 ▼; 0.86 ▼; 1.21 ▲; 1/0/0; 1/0/0
spectral_flux; 18.9; 17.8; 0.94; 0.88 ▼; 1.19 ▲; 0/0/0; 0/0/0
spectral_spread; 21.9; 17.1; 0.78 ▼; 0.82 ▼; 1.15 ▲; 2/1/0; 2/1/0
true_peak; 3.1; 2.4; 0.79 ▼; 0.85 ▼; 0.69 ▼; 0/0/0; 0/0/0
window_bartlett; 2.4; 0.6; 0.25 ▼; 0.21 ▼; 0.53 ▼; 0/0/0; 0/0/0
window_blackman_harris; 4.3; 4.2; 0.98; 0.97; 0.91; 0/0/3; 0/0/4
window_blackman; 3.3; 2.8; 0.85 ▼; 0.86 ▼; 0.64 ▼; 0/0/2; 0/0/3
window_cosN; 2.6; 1.5; 0.58 ▼; 0.62 ▼; 0.82 ▼; 0/0/1; 0/0/2
window_flattop; 5.7; 5.6; 0.98; 1.00; 0.91; 0/0/4; 0/0/5
window_hamming; 2.6; 1.5; 0.58 ▼; 0.58 ▼; 0.84 ▼; 0/0/1; 0/0/2
window_hann; 2.6; 1.5; 0.58 ▼; 0.62 ▼; 0.82 ▼; 0/0/1; 0/0/2
window_kaiser; 5.1; 6.5; 1.28 ▲; NaN; 1.04; 0/1/36; 0/1/0
window_nuttall; 4.3; 4.2; 0.98; 0.97; 0.90; 0/0/3; 0/0/4
window_rect; 3.8; 0.5; 0.13 ▼; 0.13 ▼; 0.57 ▼; 0/0/0; 0/0/0
window_tukey; 3.4; 1.2; 0.34 ▼; 0.37 ▼; 0.94; 0/0/1; 0/0/1
zcr; 2.5; 2.2; 0.88 ▼; 1.07; 0.83 ▼; 0/0/0; 0/0/0
```

## wdmodels

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
builddown; 3.0; 0.6; 0.19 ▼; 0.16 ▼; 0.41 ▼; 0/0/0; 0/0/0
buildout; 3.0; 0.6; 0.19 ▼; 0.16 ▼; 0.67 ?; 0/0/0; 0/0/0
buildtree; 3.5; 0.6; 0.16 ▼; 0.19 ▼; 0.42 ▼; 0/0/0; 0/0/0
buildup; 3.0; 0.6; 0.19 ▼; 0.16 ▼; 0.41 ▼; 0/0/0; 0/0/0
capacitor_Iout; 3.0; 4.4; 1.47 ▲; 1.07; 1.05; 0/0/0; 0/0/0
capacitor_Vout; 4.7; 4.4; 0.93; 1.07; 1.04; 0/0/0; 0/0/0
capacitor; 3.7; 3.8; 1.02; 1.07; 1.15 ▲; 0/0/0; 0/0/0
genericNode_Iout; 3.4; 0.6; 0.17 ▼; 0.16 ▼; 0.41 ▼; 0/0/0; 0/0/0
genericNode_Vout; 3.4; 0.6; 0.17 ▼; 0.16 ▼; 0.41 ▼; 0/0/0; 0/0/0
genericNode; 3.5; 0.6; 0.16 ▼; 0.17 ▼; 0.42 ▼; 0/0/0; 0/0/0
getres; 3.5; 0.6; 0.16 ▼; 0.19 ▼; 0.41 ▼; 0/0/0; 0/0/0
inductor_Iout; 4.7; 5.0; 1.05; 1.07; 0.96; 0/0/0; 0/0/0
inductor_Vout; 4.7; 4.4; 0.93; 1.07; 1.05; 0/0/0; 0/0/0
inductor; 3.2; 3.4; 1.05; 1.07; 0.90; 0/0/0; 0/0/0
lambert; 3.1; 0.5; 0.17 ▼; 0.16 ▼; 0.41 ▼; 0/0/0; 0/0/0
parallel2Port; 3.4; 0.6; 0.17 ▼; 0.17 ▼; 0.87 ▼; 0/0/0; 0/0/0
parallelCurrent; 3.5; 0.6; 0.16 ▼; 0.17 ▼; 0.78 ?; 0/0/0; 0/0/0
parallel; 3.3; 0.6; 0.17 ▼; 0.17 ▼; 0.54 ▼; 0/0/0; 0/0/0
resCurrent; 2.4; 0.8; 0.32 ▼; 0.32 ▼; 0.70 ▼; 0/0/0; 0/0/0
resVoltage_Vout; 2.4; 0.7; 0.31 ▼; 0.29 ▼; 0.64 ▼; 0/0/0; 0/0/0
resVoltage; 2.4; 0.8; 0.32 ▼; 0.30 ▼; 0.65 ▼; 0/0/0; 0/0/0
resistor_Iout; 2.3; 0.5; 0.23 ▼; 0.23 ▼; 0.74 ▼; 0/0/0; 0/0/0
resistor_Vout; 3.3; 0.5; 0.16 ▼; 0.19 ▼; 0.42 ▼; 0/0/0; 0/0/0
resistor; 3.2; 0.6; 0.18 ▼; 0.16 ▼; 0.42 ▼; 0/0/0; 0/0/0
series2Port; 3.0; 0.6; 0.19 ▼; 0.25 ▼; 0.42 ▼; 0/0/0; 0/0/0
seriesVoltage; 3.0; 0.6; 0.19 ▼; 0.23 ▼; 0.41 ▼; 0/0/0; 0/0/0
series; 3.4; 0.6; 0.17 ▼; 0.16 ▼; 0.44 ▼; 0/0/0; 0/0/0
transformerActive; 3.5; 0.6; 0.16 ▼; 0.19 ▼; 0.41 ▼; 0/0/0; 0/0/0
transformer; 3.5; 0.6; 0.16 ▼; 0.19 ▼; 0.41 ▼; 0/0/0; 0/0/0
u_chua; 3.4; 0.5; 0.15 ▼; 0.19 ▼; 0.42 ▼; 0/0/0; 0/0/0
u_current; 3.3; 0.5; 0.16 ▼; 0.19 ▼; 0.42 ▼; 0/0/0; 0/0/0
u_diodeAntiparallel_omega; 3.1; 0.5; 0.17 ▼; 0.16 ▼; 0.41 ▼; 0/0/0; 0/0/0
u_diodeAntiparallel; 3.1; 0.5; 0.17 ▼; 0.16 ▼; 0.41 ▼; 0/0/0; 0/0/0
u_diodePair; 3.2; 0.5; 0.17 ▼; 0.16 ▼; 0.40 ▼; 0/0/0; 0/0/0
u_diodeSingle; 3.4; 0.6; 0.17 ▼; 0.16 ▼; 0.41 ▼; 0/0/0; 0/0/0
u_genericNode; 3.5; 0.6; 0.16 ▼; 0.17 ▼; 0.42 ▼; 0/0/0; 0/0/0
u_idealDiode; 3.5; 0.5; 0.15 ▼; 0.19 ▼; 0.42 ▼; 0/0/0; 0/0/0
u_parallel2Port; 2.6; 0.7; 0.29 ▼; 0.31 ▼; 0.71 ▼; 0/0/0; 0/0/0
u_resCurrent; 3.3; 0.5; 0.16 ▼; 0.19 ▼; 0.33 ?; 0/0/0; 0/0/0
u_resVoltage; 3.3; 0.5; 0.16 ▼; 0.19 ▼; 0.42 ▼; 0/0/0; 0/0/0
u_series2Port; 2.6; 0.8; 0.30 ▼; 0.29 ▼; 0.71 ▼; 0/0/0; 0/0/0
u_sixportPassive; 4.9; 0.6; 0.11 ▼; 0.11 ▼; 0.54 ▼; 0/0/0; 0/0/0
u_switch; 3.3; 0.5; 0.16 ▼; 0.19 ▼; 0.43 ▼; 0/0/0; 0/0/0
u_transformerActive; 2.4; 1.1; 0.46 ▼; 0.44 ▼; 0.73 ▼; 0/0/0; 0/0/0
u_transformer; 2.4; 1.0; 0.43 ▼; 0.41 ▼; 0.72 ▼; 0/0/0; 0/0/0
u_voltage; 3.3; 0.5; 0.16 ▼; 0.19 ▼; 0.43 ▼; 0/0/0; 0/0/0
```

## demos

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
colored_noise_demo; 43.2; 41.6; 0.96; 0.92; 0.86 ▼; 23/0/27; 12/0/27
compressor_demo; 11.3; 5.1; 0.45 ▼; 0.45 ▼; 0.59 ▼; 0/0/5; 0/0/3
crybaby_demo; 3.5; 3.2; 0.91; 0.98; 1.06; 0/0/0; 0/0/0
dattorro_rev_demo; 13.2; 13.2; 1.00; 0.98; 0.97; 0/0/0; 0/0/0
exciter; 12.8; 13.2; 1.03; 1.22 ▲; 1.10; 0/0/5; 0/0/5
fdnrev0_demo; 183.5; 285.2; 1.55 ▲; 1.52 ▲; 1.29 ▲; 0/0/0; 0/0/0
filterbank_demo; 61.5; 84.9; 1.38 ▲; 1.45 ▲; 1.86 ▲; 0/0/10; 0/0/10
flanger_demo; 4.7; 3.9; 0.82 ▼; 0.82 ▼; 0.84 ▼; 0/0/0; 0/0/0
freeverb_demo; 20.1; 19.1; 0.95; 0.97; 1.00; 0/0/0; 0/0/0
greyhole_demo; 50.5; 51.3; 1.02; 1.01; 0.96; 33/0/6; 33/0/6
ja_transformer_demo; 61.1; 61.1; 1.00; 1.00; 0.94; 27/0/4; 27/0/4
jprev_demo; 71.0; 89.4; 1.26 ▲; 1.06; 1.15 ▲; 32/0/0; 32/0/0
kb_rom_rev1_demo; 19.7; 19.4; 0.98; 0.97; 0.94; 0/0/0; 0/0/0
moog_vcf_demo; 12.8; 13.0; 1.02; 0.96; 1.33 ▲; 29/8/2; 17/4/2
motion_wrapper_demo; 149.5; 150.8; 1.01; 1.02; error; 0/39/6; 0/39/6
mth_octave_filterbank_demo; 61.6; 85.0; 1.38 ▲; 1.45 ▲; 1.86 ▲; 0/0/10; 0/0/10
mth_octave_spectral_level_demo; 114.3; 156.6; 1.37 ▲; 1.59 ▲; 3.02 ▲; 0/0/15; 0/0/15
orientation6_demo; 11.0; 9.1; 0.83 ▼; 0.85 ▼; 0.94; 0/6/0; 0/6/0
parametric_eq_demo; 11.1; 11.2; 1.01; 1.08; 1.63 ▲; 9/0/3; 6/0/3
phaser2_demo; 12.7; 12.4; 0.98; 0.99; 0.99; 0/0/8; 0/0/8
pink_trombone_demo; 224.8; 223.9; 1.00; 1.00; 1.02; 64/0/9; 64/0/9
pospass_demo; 10.0; 11.1; 1.10 ▲; 1.25 ▲; 1.62 ▲; 0/0/3; 0/0/3
projected_gravity_demo; 5.3; 5.1; 0.96; 0.90 ▼; 1.21 ▲; 2/0/2; 1/0/2
reverbTank_demo; 69.4; 64.6; 0.93; 0.92; 0.94; 26/0/9; 4/0/9
reverse_echo_demo; 1.4; 1.4; 1.00; 1.00; 1.07; 0/0/0; 0/0/0
sawtooth_demo; 12.7; 8.5; 0.67 ▼; 0.90; 1.18 ▲; 18/0/0; 6/0/0
shock_trigger_demo; 3.8; 2.4; 0.63 ▼; 0.64 ▼; 1.06; 0/0/0; 0/0/0
spectral_level_demo; 114.2; 156.7; 1.37 ▲; 1.59 ▲; 3.02 ▲; 0/0/15; 0/0/15
spectral_tilt_demo; 4.0; 3.2; 0.81 ▼; 0.57 ▼; 1.60 ▲; 0/0/0; 0/0/0
springreverb_demo; 23.7; 22.6; 0.95; 0.96; 1.00; 8/0/0; 8/0/0
stereo_reverber; 7.5; —; error; error; error; 0/0/0; —
tapeStop_demo; 6.2; 6.0; 0.97; 0.95; 0.84 ▼; 0/0/2; 0/0/2
total_accel_demo; 3.6; 2.2; 0.62 ▼; 0.63 ▼; 0.89 ▼; 0/1/0; 0/1/0
twin_osc_demo; 8.2; 8.0; 0.98; 0.96; 0.94; 3/0/0; 3/0/0
velvet_noise_demo; 3.2; 1.9; 0.58 ▼; 0.64 ▼; 0.73 ▼; 0/0/0; 0/0/0
virtual_analog_oscillator_demo; 21.4; 27.1; 1.27 ▲; 1.49 ▲; 1.18 ▲; 33/0/0; 18/0/0
vital_rev_demo; 156.1; 147.1; 0.94; 0.95; 0.95; 107/0/39; 5/0/39
vocoder_demo; 55.4; 79.1; 1.43 ▲; 1.29 ▲; 2.90 ▲; 0/0/0; 0/0/0
wah4_demo; 4.3; 4.8; 1.11 ▲; 1.72 ▲; 1.01; 0/0/0; 0/0/0
zita_light; 22.7; 22.9; 1.01; 1.06; 0.95; 0/0/0; 0/0/0
zita_rev1; 21.3; 21.3; 1.00; 0.98; 0.96; 0/0/0; 0/0/0
zita_rev_fdn_demo; 23.4; 24.7; 1.06; 1.03; 0.95; 0/0/0; 0/0/0
```

## vaeffects

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
autowah; 8.1; 8.9; 1.10 ▲; 1.10 ▲; 1.11 ▲; 1/0/4; 3/0/4
bandpass2Matched; 4.2; 4.6; 1.09; 0.81 ▼; 1.24 ▲; 0/0/0; 0/0/0
biquad; 3.3; 3.3; 0.99; 1.01; 0.91; 0/0/0; 0/0/0
crybaby; 3.7; 3.8; 1.02; 0.94; 1.21 ▲; 0/0/0; 0/0/0
diodeLadder; 11.9; 11.7; 0.98; 0.98; 1.06; 0/0/0; 0/0/0
highpass2Matched; 4.2; 4.4; 1.05; 1.45 ▲; 1.35 ▲; 0/0/0; 0/0/0
highshelf2Matched; 3.6; 4.8; 1.35 ▲; 1.10; 1.36 ▲; 0/0/0; 0/0/0
klonCentaur; 35.1; 109.0; 3.10 ▲; 3.18 ▲; 2.32 ▲; 17/1/5; 24/1/11
korg35HPF; 6.3; 6.3; 0.99; 1.09; 1.13 ▲; 0/0/0; 0/0/0
korg35LPF; 5.5; 6.0; 1.09; 0.97; 1.19 ▲; 0/0/0; 0/0/0
lowpass2Matched; 4.3; 4.7; 1.09; 1.46 ▲; 1.24 ▲; 0/0/0; 0/0/0
lowpassLadder4; 7.1; 7.5; 1.06; 1.04; 1.08; 0/0/0; 0/0/0
lowshelf2Matched; 3.6; 3.9; 1.10 ▲; 0.95; 1.36 ▲; 0/0/0; 0/0/0
moogHalfLadder; 6.5; 6.6; 1.02; 0.99; 1.08; 0/0/0; 0/0/0
moogLadder; 7.1; 7.2; 1.02; 1.05; 1.07; 0/0/0; 0/0/0
moog_vcf_2b; 3.5; 6.1; 1.72 ▲; 1.46 ▲; 2.34 ▲; 0/0/0; 0/0/0
moog_vcf_2bn; 3.6; 3.3; 0.92; 0.93; 1.07; 0/0/0; 0/0/0
moog_vcf; 4.7; 5.3; 1.12 ▲; 1.64 ▲; 1.07; 0/0/0; 0/0/0
oberheimBPF; 8.0; 8.0; 1.00; 0.97; 1.12 ▲; 0/0/0; 0/0/0
oberheimBSF; 8.0; 7.9; 0.98; 1.00; 1.06; 0/0/0; 0/0/0
oberheimHPF; 7.9; 8.1; 1.02; 1.04; 1.06; 0/0/0; 0/0/0
oberheimLPF; 7.9; 8.1; 1.02; 1.02; 1.06; 0/0/0; 0/0/0
oberheim; 6.7; 7.3; 1.09; 0.88 ▼; 1.04; 0/0/0; 0/0/0
peaking2Matched; 4.2; 4.8; 1.14 ▲; 0.96; 1.38 ▲; 1/0/0; 0/0/0
sallenKey2ndOrderBPF; 4.7; 4.4; 0.94; 0.97; 1.17 ▲; 0/0/0; 0/0/0
sallenKey2ndOrderHPF; 4.5; 4.4; 0.99; 1.01; 0.89 ▼; 0/0/0; 0/0/0
sallenKey2ndOrderLPF; 4.4; 4.4; 0.99; 0.99; 1.01; 0/0/0; 0/0/0
sallenKey2ndOrder; 4.1; 4.1; 1.00; 1.00; 1.00; 0/0/0; 0/0/0
sallenKeyOnePoleHPF; 2.5; 2.7; 1.11 ▲; 1.11 ▲; 0.85 ▼; 0/0/0; 0/0/0
sallenKeyOnePoleLPF; 2.4; 2.9; 1.20 ▲; 1.27 ▲; 0.70 ▼; 0/0/0; 0/0/0
sallenKeyOnePole; 2.5; 3.4; 1.37 ▲; 1.40 ▲; 0.89 ▼; 0/0/0; 0/0/0
vocoder; 12.6; 19.4; 1.54 ▲; 1.37 ▲; 2.28 ▲; 0/0/0; 0/0/0
wah4; 4.7; 6.1; 1.30 ▲; 1.67 ▲; 1.06; 0/0/0; 0/0/0
```

## aanl

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
ADAA1; 2.7; 1.3; 0.48 ▼; 0.48 ▼; 0.79 ▼; 1/0/0; 1/0/0
ADAA2; 2.6; 2.2; 0.84 ▼; 0.75 ▼; 0.82 ▼; 2/0/0; 2/0/0
acosh1; 5.7; 4.5; 0.79 ▼; 0.81 ▼; 0.95; 1/4/3; 1/4/3
acosh2; 10.1; 9.4; 0.93; 0.99; 0.91; 2/6/8; 2/6/8
arccos2; 8.2; 7.8; 0.95; 0.96; 0.91; 2/3/8; 2/3/8
arccos; 4.8; 3.6; 0.76 ▼; 0.74 ▼; 0.91; 1/2/3; 1/2/3
arcsin2; 6.7; 6.3; 0.94; 0.92; 0.98; 2/3/5; 2/3/5
arcsin; 4.9; 3.4; 0.69 ▼; 0.82 ▼; 0.93; 1/2/3; 1/2/3
arctan2; 7.2; 7.2; 0.99; 0.99; 0.94; 2/0/8; 2/0/8
arctan; 5.7; 5.7; 0.99; 0.99; 0.91; 1/0/5; 1/0/5
asinh1; 4.8; 3.7; 0.77 ▼; 0.75 ▼; 0.92; 1/2/3; 1/2/3
asinh2; 7.3; 6.9; 0.95; 0.96; 0.96; 2/3/5; 2/3/5
atanh1; 11.9; 11.6; 0.98; 1.00; 0.94; 1/0/5; 1/0/5
atanh2; 10.8; 11.0; 1.01; 0.97; 0.90; 2/0/14; 2/0/14
cosine1; 4.6; 2.7; 0.58 ?; 0.68 ?; 0.83 ▼; 1/0/3; 1/0/3
cosine2; 4.7; 4.3; 0.92; 0.99; 0.93; 2/0/8; 2/0/8
cubic1; 2.9; 1.7; 0.60 ▼; 0.39 ▼; 0.84 ▼; 1/0/0; 1/0/0
hardclip2; 2.6; 2.2; 0.83 ▼; 0.76 ▼; 0.82 ▼; 2/0/0; 2/0/0
hardclip; 2.6; 1.3; 0.50 ▼; 0.48 ▼; 0.79 ▼; 1/0/0; 1/0/0
hyperbolic2; 5.3; 4.9; 0.92; 0.91; 0.94; 4/0/3; 4/0/3
hyperbolic; 3.4; 3.2; 0.95 ?; 0.82 ?; 0.90 ▼; 2/0/2; 2/0/2
parabolic2; 6.4; 5.6; 0.87 ▼; 0.86 ▼; 0.85 ▼; 2/0/0; 2/0/0
parabolic; 2.8; 1.5; 0.54 ▼; 0.54 ▼; 0.85 ▼; 1/0/0; 1/0/0
sinarctan2; 4.2; 3.1; 0.75 ?; 0.84 ?; 0.93; 4/5/3; 4/5/3
sinarctan; 2.5; 1.8; 0.70 ▼; 0.68 ▼; 0.79 ▼; 2/3/0; 2/3/0
sine2; 4.5; 4.2; 0.95; 0.99; 0.90 ▼; 2/0/8; 2/0/8
sine; 3.8; 2.5; 0.67 ?; 0.60 ?; 0.83 ▼; 1/0/3; 1/0/3
softclipQuadratic1; 2.8; 1.6; 0.57 ▼; 0.56 ▼; 0.81 ▼; 1/0/0; 1/0/0
softclipQuadratic2; 4.6; 3.6; 0.77 ▼; 0.80 ▼; 0.84 ▼; 2/0/0; 2/0/0
tangent; 5.0; 4.8; 0.95; 0.98; 0.92; 1/0/5; 1/0/5
tanh1; 5.5; 5.5; 0.99; 0.98; 0.93; 1/0/5; 1/0/5
```

## hoa

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
circularScaledVBAP; 2.4; 0.6; 0.24 ▼; 0.23 ▼; 0.70 ▼; 0/0/0; 0/0/0
decoderStereo; 2.6; 0.5; 0.20 ▼; 0.22 ▼; 0.65 ▼; 0/0/0; 0/0/0
decoder; 2.4; 0.7; 0.30 ▼; 0.30 ▼; 0.75 ▼; 0/0/0; 0/0/0
encoder3D; 2.3; 0.7; 0.29 ▼; 0.29 ▼; 0.74 ▼; 0/0/0; 0/0/0
encoder; 2.7; 0.6; 0.21 ▼; 0.23 ▼; 0.65 ▼; 0/0/0; 0/0/0
fxDecorrelation; 6.7; 6.2; 0.92; 0.94; 0.92; 0/0/0; 0/0/0
fxRingMod; 3.5; 1.5; 0.44 ▼; 0.51 ▼; 0.90; 0/0/0; 0/0/0
iBasicDecoder; 2.3; 0.6; 0.25 ▼; 0.25 ▼; 0.71 ▼; 0/0/0; 0/0/0
iDecoder; 2.3; 0.6; 0.27 ▼; 0.27 ▼; 0.71 ▼; 0/0/0; 0/0/0
imlsDecoder; 2.4; 0.7; 0.30 ▼; 0.30 ▼; 0.73 ▼; 0/0/0; 0/0/0
map; 2.3; 0.6; 0.24 ▼; 0.24 ▼; 0.75 ▼; 0/0/0; 0/0/0
mirror; 2.5; 0.6; 0.23 ▼; 0.25 ▼; 0.69 ▼; 0/0/0; 0/0/0
multiEncoder; 3.8; 2.7; 0.71 ▼; 0.69 ▼; 0.99; 0/0/6; 0/0/6
optim3D; 2.9; 2.9; 1.00; 1.00; 0.79 ▼; 0/0/0; 0/0/0
optimBasic3D; 2.3; 0.7; 0.29 ▼; 0.29 ▼; 0.75 ▼; 0/0/0; 0/0/0
optimBasic; 2.7; 0.6; 0.21 ▼; 0.23 ▼; 0.64 ▼; 0/0/0; 0/0/0
optimInPhase3D; 2.4; 0.7; 0.28 ▼; 0.28 ▼; 0.74 ▼; 0/0/0; 0/0/0
optimInPhase; 2.3; 0.6; 0.25 ▼; 0.25 ▼; 0.75 ▼; 0/0/0; 0/0/0
optimMaxRe3D; 2.3; 0.7; 0.29 ▼; 0.29 ▼; 0.74 ▼; 0/0/0; 0/0/0
optimMaxRe; 2.3; 0.6; 0.25 ▼; 0.25 ▼; 0.76 ▼; 0/0/0; 0/0/0
optim; 2.9; 2.9; 1.00; 1.00; 0.80 ▼; 0/0/0; 0/0/0
rEncoder3D; 6.0; 4.4; 0.73 ▼; 0.74 ▼; 0.83 ▼; 0/1/7; 0/1/7
rEncoder; 3.4; 1.9; 0.58 ▼; 0.58 ▼; 0.75 ▼; 0/0/3; 0/0/3
rotate; 2.3; 0.6; 0.25 ▼; 0.24 ▼; 0.71 ▼; 0/0/0; 0/0/0
scope; 3.7; 2.7; 0.74 ▼; 0.79 ▼; 1.09; 1/2/2; 1/2/2
stereoEncoder; 2.5; 0.8; 0.33 ▼; 0.33 ▼; 0.86 ▼; 0/0/0; 0/0/0
synDecorrelation; 8.9; 8.7; 0.98; 0.98; 0.94; 0/0/0; 0/0/0
synRingMod; 5.3; 3.7; 0.71 ▼; 0.68 ▼; 0.82 ▼; 0/0/0; 0/0/0
wider; 2.4; 0.6; 0.24 ▼; 0.24 ▼; 0.72 ▼; 0/0/0; 0/0/0
```

## basics

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
bitcrusher; 2.3; 0.5; 0.23 ▼; 0.23 ▼; 0.45 ▼; 0/0/0; 0/0/0
bypass1; 3.1; 0.5; 0.17 ▼; 0.17 ▼; 0.67 ▼; 0/0/0; 0/0/0
bypass1to2; 2.7; 0.5; 0.19 ▼; 0.22 ▼; 0.72 ▼; 0/0/0; 0/0/0
bypass2; 1.9; 0.8; 0.43 ▼; 0.42 ▼; 0.84 ▼; 0/0/0; 0/0/0
bypass_fade; 3.0; 2.2; 0.74 ▼; 0.74 ▼; 1.11 ▲; 0/0/0; 0/0/0
downSampleCV; 2.8; 0.8; 0.28 ▼; 0.28 ▼; 0.73 ▼; 0/0/0; 0/0/0
downSample; 2.7; 0.7; 0.28 ▼; 0.26 ▼; 0.72 ▼; 0/0/0; 0/0/0
impulsify; 2.6; 0.8; 0.29 ▼; 0.32 ▼; 0.77 ▼; 0/0/0; 0/0/0
latch; 3.2; 1.1; 0.34 ▼; 0.34 ▼; 0.72 ▼; 0/0/0; 0/0/0
line_frac; 2.5; 1.3; 0.53 ▼; 0.52 ▼; 0.75 ▼; 1/0/0; 1/0/0
line; 4.3; 4.3; 1.02; 1.02; 1.32 ▲; 1/0/0; 1/0/0
mulaw_bitcrusher; 3.1; 3.1; 0.99; 0.97; 0.97; 0/0/2; 0/0/2
peakhold; 2.5; 2.5; 0.99; 0.96; 0.66 ▼; 0/0/0; 0/0/0
peakholder; 4.5; 4.9; 1.08; 1.09; 1.31 ▲; 0/0/0; 0/0/0
ramp; 3.3; 3.9; 1.19 ▲; 1.10 ▲; 1.11 ▲; 0/0/0; 0/0/0
sAndH; 2.7; 1.0; 0.37 ▼; 0.37 ▼; 0.69 ▼; 0/0/0; 0/0/0
selectmulti; 3.0; 2.2; 0.74 ▼; 0.75 ▼; 1.12 ▲; 0/0/0; 0/0/0
slidingMax; 4.2; 3.7; 0.88 ▼; 0.91; 0.71 ▼; 0/0/0; 0/0/0
slidingMean; 2.4; 0.7; 0.28 ▼; 0.28 ▼; 0.66 ▼; 0/0/0; 0/0/0
slidingMeanp; 4.2; 3.6; 0.86 ▼; 0.85 ▼; 0.78 ▼; 0/0/0; 0/0/0
slidingMin; 4.2; 3.7; 0.89 ▼; 0.91; 0.80 ▼; 0/0/0; 0/0/0
slidingRMS; 2.4; 0.7; 0.31 ▼; 0.29 ▼; 0.74 ▼; 0/1/0; 0/1/0
slidingRMSp; 3.8; 3.2; 0.83 ▼; 0.83 ▼; 0.85 ▼; 0/1/0; 0/1/0
slidingReduce; 4.2; 3.6; 0.87 ▼; 0.90; 0.71 ▼; 0/0/0; 0/0/0
slidingSum; 2.4; 0.7; 0.28 ▼; 0.28 ▼; 0.72 ▼; 0/0/0; 0/0/0
slidingSump; 4.0; 3.5; 0.89 ▼; 0.89 ▼; 0.76 ▼; 0/0/0; 0/0/0
tAndH; 2.6; 2.5; 0.94; 0.94; 0.76 ▼; 0/0/0; 0/0/0
```

## compressors

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
FBFFcompressor_N_chan; 28.5; 28.3; 0.99; 1.00; 0.99; 0/0/6; 0/0/6
FBcompressor_N_chan; 25.0; 25.0; 1.00; 0.92; 1.04; 0/0/4; 0/0/4
FFcompressor_N_chan; 7.3; 7.3; 1.00; 0.99; 0.88 ▼; 0/0/4; 0/0/4
RMS_FBFFcompressor_N_chan; 29.5; 29.5; 1.00; 0.98; 0.97; 0/2/4; 0/2/4
RMS_FBcompressor_peak_limiter_N_chan; 30.3; 30.4; 1.00; 0.94; 1.02; 0/2/8; 0/2/8
RMS_compression_gain_N_chan_db; 5.9; 5.6; 0.95; 0.94; 0.99; 0/2/2; 0/2/2
RMS_compression_gain_N_chan; 8.5; 8.4; 0.99; 0.99; 0.98; 0/2/4; 0/2/4
RMS_compression_gain_mono_db; 3.3; 2.8; 0.83 ▼; 0.79 ▼; 0.82 ▼; 0/1/1; 0/1/1
RMS_compression_gain_mono; 4.2; 4.0; 0.96; 0.94; 0.89 ▼; 0/1/2; 0/1/2
compression_gain_mono; 4.3; 4.0; 0.93; 0.98; 1.04; 0/0/2; 0/0/2
compressor_lad_mono; 4.1; 3.9; 0.94; 0.88 ▼; 0.95; 0/0/2; 0/0/2
compressor_mono; 4.4; 4.0; 0.93; 0.96; 0.97; 0/0/2; 0/0/2
compressor_stereo; 5.1; 4.4; 0.86 ▼; 0.87 ▼; 0.94; 0/0/2; 0/0/2
expanderSC_N_chan; 12.2; 11.6; 0.95; 0.93; 0.86 ▼; 0/0/4; 0/0/4
expander_N_chan; 18.3; 17.4; 0.95; 0.93 ?; 0.98; 0/0/4; 0/0/4
limiter_1176_R4_mono; 4.3; 4.0; 0.93; 0.96; 0.97; 0/0/2; 0/0/2
limiter_1176_R4_stereo; 5.1; 4.4; 0.85 ▼; 0.86 ▼; 0.95; 0/0/2; 0/0/2
limiter_lad_N; 4.3; 4.0; 0.93; 0.73 ▼; 0.96; 1/0/0; 1/0/0
limiter_lad_bw; 4.0; 3.9; 0.99; 0.96; 1.15 ▲; 1/0/0; 1/0/0
limiter_lad_mono; 4.0; 3.9; 0.99; 0.97; 1.14 ▲; 1/0/0; 1/0/0
limiter_lad_quad; 5.9; 4.9; 0.83 ▼; 0.85 ▼; 0.88 ▼; 1/0/0; 1/0/0
limiter_lad_stereo; 4.3; 4.0; 0.93; 0.73 ▼; 0.93; 1/0/0; 1/0/0
peak_compression_gain_N_chan_db; 5.1; 4.7; 0.92; 0.96; 0.97; 0/0/2; 0/0/2
peak_compression_gain_N_chan; 7.2; 7.1; 0.98; 0.98; 0.97; 0/0/4; 0/0/4
peak_compression_gain_mono_db; 3.8; 3.8; 1.02; 1.00; 1.05; 0/0/1; 0/0/1
peak_compression_gain_mono; 4.1; 4.0; 0.97; 0.99; 1.09; 0/0/2; 0/0/2
peak_expansion_gain_N_chan_db; 15.5; 15.7; 1.01; 0.97; 0.98; 0/0/2; 0/0/2
```

## tubes

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
T1_12AT7; 11.5; 8.9; 0.78 ▼; 0.82 ▼; 1.02; 0/0/0; 0/0/0
T1_12AU7; 11.5; 8.9; 0.78 ▼; 0.82 ▼; 1.02; 0/0/0; 0/0/0
T1_12AX7; 11.5; 8.9; 0.78 ▼; 0.82 ▼; 1.02; 0/0/0; 0/0/0
T1_6C16; 11.5; 8.9; 0.78 ▼; 0.82 ▼; 1.02; 0/0/0; 0/0/0
T1_6DJ8; 11.5; 8.9; 0.78 ▼; 0.82 ▼; 1.02; 0/0/0; 0/0/0
T1_6V6; 11.5; 8.9; 0.78 ▼; 0.82 ▼; 1.02; 0/0/0; 0/0/0
T2_12AT7; 11.5; 8.9; 0.78 ▼; 0.82 ▼; 1.02; 0/0/0; 0/0/0
T2_12AU7; 11.5; 8.9; 0.78 ▼; 0.82 ▼; 1.02; 0/0/0; 0/0/0
T2_12AX7; 11.5; 8.9; 0.78 ▼; 0.82 ▼; 1.02; 0/0/0; 0/0/0
T2_6C16; 11.5; 8.9; 0.78 ▼; 0.82 ▼; 1.02; 0/0/0; 0/0/0
T2_6DJ8; 11.5; 8.9; 0.78 ▼; 0.82 ▼; 1.02; 0/0/0; 0/0/0
T2_6V6; 11.5; 8.9; 0.78 ▼; 0.82 ▼; 1.02; 0/0/0; 0/0/0
T3_12AT7; 11.5; 8.9; 0.78 ▼; 0.82 ▼; 1.02; 0/0/0; 0/0/0
T3_12AU7; 11.5; 8.9; 0.78 ▼; 0.82 ▼; 1.02; 0/0/0; 0/0/0
T3_12AX7; 11.5; 8.9; 0.78 ▼; 0.82 ▼; 1.02; 0/0/0; 0/0/0
T3_6C16; 11.5; 8.9; 0.78 ▼; 0.82 ▼; 1.02; 0/0/0; 0/0/0
T3_6DJ8; 11.5; 8.9; 0.78 ▼; 0.82 ▼; 1.02; 0/0/0; 0/0/0
T3_6V6; 11.5; 8.9; 0.78 ▼; 0.82 ▼; 1.02; 0/0/0; 0/0/0
tu_ccopysign; 2.6; 0.5; 0.20 ▼; 0.19 ▼; 0.43 ▼; 0/0/0; 0/0/0
tu_getFactor; 2.4; 0.5; 0.22 ▼; 0.22 ▼; 0.49 ▼; 0/0/0; 0/0/0
tu_inverse; 2.4; 0.5; 0.22 ▼; 0.22 ▼; 0.69 ▼; 0/0/0; 0/0/0
tu_invsign; 2.6; 0.5; 0.20 ▼; 0.19 ▼; 0.41 ▼; 0/0/0; 0/0/0
tu_sign; 2.6; 0.5; 0.20 ▼; 0.19 ▼; 0.41 ▼; 0/0/0; 0/0/0
tu_tubeF; 2.4; 0.8; 0.35 ▼; 0.37 ▼; 0.79 ▼; 0/0/0; 0/0/0
tubestage130_20; 11.5; 8.9; 0.78 ▼; 0.82 ▼; 1.02; 0/0/0; 0/0/0
tubestageF; 11.5; 8.9; 0.78 ▼; 0.82 ▼; 1.02; 0/0/0; 0/0/0
tubestage; 11.5; 8.9; 0.78 ▼; 0.82 ▼; 1.02; 0/0/0; 0/0/0
```

## misceffects

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
cubicnl_nodc; 3.5; 3.4; 0.96; 0.92; 0.77 ▼; 0/0/0; 0/0/0
cubicnl; 2.4; 0.5; 0.22 ▼; 0.28 ▼; 0.58 ▼; 0/0/0; 0/0/0
dither_shaped; 5.8; 6.2; 1.07; 1.03; 1.18 ▲; 0/0/0; 0/0/0
dither; 2.5; 1.0; 0.40 ▼; 0.39 ▼; 0.61 ?; 0/0/0; 0/0/0
doppler_shift; 3.9; 2.7; 0.69 ▼; 0.72 ▼; 0.85 ▼; 0/0/0; 0/0/0
dryWetMixerConstantPower; 2.9; 2.9; 1.00; 1.02; 0.91; 0/0/0; 0/0/0
dryWetMixer; 3.0; 3.1; 1.02; 1.02; 0.92; 0/0/0; 0/0/0
echo; 2.6; 0.6; 0.25 ▼; 0.25 ▼; 0.70 ▼; 0/0/0; 0/0/0
gate_mono; 3.9; 3.9; 1.01; 1.10; 0.99 ?; 0/0/0; 0/0/0
gate_stereo; 4.2; 4.3; 1.02; 0.96 ?; 0.97 ?; 0/0/0; 0/0/0
granular; 7.5; 6.5; 0.86 ▼; 1.03; 1.15 ▲; 0/0/2; 0/0/2
ms_dec; 2.7; 0.9; 0.33 ▼; 0.35 ▼; 0.85 ▼; 0/0/0; 0/0/0
ms_enc; 2.7; 0.9; 0.32 ▼; 0.33 ▼; 0.87 ▼; 0/0/0; 0/0/0
piano_dispersion_filter; 5.3; 4.6; 0.86 ▼; 0.85 ▼; 0.90 ▼; 2/0/2; 2/0/2
reverseDelayRamped; 2.6; 0.7; 0.26 ▼; 0.26 ▼; 0.73 ▼; 0/0/0; 0/0/0
reverseEchoN; 2.8; 1.1; 0.39 ▼; 0.39 ▼; 0.80 ▼; 0/0/0; 0/0/0
softclipQuadratic; 3.1; 0.9; 0.28 ?; 0.21 ?; 0.74 ▼; 0/0/0; 0/0/0
speakerbp; 4.2; 4.2; 1.00; 0.87 ▼; 1.40 ▲; 0/0/0; 0/0/0
stereo_width; 2.5; 0.8; 0.34 ▼; 0.33 ▼; 0.86 ▼; 0/0/0; 0/0/0
tapeStop; 5.0; 4.3; 0.85 ▼; 0.85 ▼; 0.89 ▼; 0/0/0; 0/0/0
transpose; 3.3; 3.2; 0.96; 1.00; 1.06; 0/0/1; 0/0/1
transpose_windowed; 4.7; 4.9; 1.05; 1.01; 0.98; 0/0/2; 0/0/2
uniformPanToStereo; 3.4; 1.2; 0.36 ▼; 0.37 ▼; 0.83 ▼; 0/0/0; 0/0/0
wavefold; 2.8; 1.1; 0.40 ▼; 0.50 ▼; 0.77 ▼; 0/0/0; 0/0/0
```

## filters_basic_comb

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
allpass_comb; 2.5; 0.9; 0.38 ▼; 0.38 ▼; 0.69 ▼; 0/0/0; 0/0/0
allpass_fcomb1a; 2.7; 3.0; 1.11 ▲; 1.10 ▲; 0.85 ▼; 0/0/0; 0/0/0
allpass_fcomb5; 2.5; 1.1; 0.43 ▼; 0.41 ▼; 0.72 ▼; 0/0/0; 0/0/0
allpass_fcomb; 2.4; 1.0; 0.40 ▼; 0.39 ▼; 0.69 ▼; 0/0/0; 0/0/0
dcblocker; 3.2; 3.5; 1.10; 0.57 ▼; 0.90; 0/0/0; 0/0/0
dcblockerat; 3.5; 3.2; 0.91; 0.91; 0.99; 0/0/0; 0/0/0
fb_comb_common; 2.4; 0.6; 0.23 ▼; 0.23 ▼; 0.77 ▼; 0/0/0; 0/0/0
fb_comb; 2.4; 0.6; 0.26 ▼; 0.26 ▼; 0.73 ▼; 0/0/0; 0/0/0
fb_fcomb; 2.5; 0.7; 0.27 ▼; 0.27 ▼; 0.81 ▼; 0/0/0; 0/0/0
fbcombfilter; 2.5; 0.9; 0.35 ▼; 0.35 ▼; 0.67 ▼; 0/0/0; 0/0/0
ff_comb; 1.9; 0.6; 0.29 ▼; 0.23 ▼; 0.72 ▼; 0/0/0; 0/0/0
ff_fcomb; 2.4; 0.6; 0.25 ▼; 0.25 ▼; 0.67 ▼; 0/0/0; 0/0/0
ffbcombfilter; 2.4; 0.9; 0.36 ▼; 0.35 ▼; 0.57 ▼; 0/0/0; 0/0/0
ffcombfilter; 1.9; 0.6; 0.29 ▼; 0.23 ▼; 0.72 ▼; 0/0/0; 0/0/0
integrator; 2.5; 2.5; 0.99; 0.99; 0.67 ▼; 0/0/0; 0/0/0
lpt19; 2.4; 2.5; 1.04; 1.11 ▲; 0.73 ▼; 0/0/0; 0/0/0
lpt60; 2.4; 2.5; 1.04; 1.11 ▲; 0.72 ▼; 0/0/0; 0/0/0
lptN; 2.4; 2.5; 1.04; 1.11 ▲; 0.73 ▼; 0/0/0; 0/0/0
lptau; 2.4; 2.5; 1.05; 1.11 ▲; 0.74 ▼; 0/0/0; 0/0/0
pole; 2.6; 2.5; 0.99; 0.97; 0.76 ▼; 0/0/0; 0/0/0
rev1; 2.4; 0.6; 0.26 ▼; 0.26 ▼; 0.86 ▼; 0/0/0; 0/0/0
rev2; 2.5; 0.9; 0.38 ▼; 0.38 ▼; 0.68 ▼; 0/0/0; 0/0/0
zero; 2.8; 0.8; 0.27 ▼; 0.27 ▼; 0.70 ▼; 0/0/0; 0/0/0
```

## filters_direct_ladder

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
TF2_legacy; 3.5; 3.5; 1.00; 1.00; 0.77 ▼; 0/0/0; 0/0/0
allpassn1mt; 5.7; 5.6; 0.99; 0.99; 1.19 ▲; 0/0/0; 0/0/0
allpassnklt; 3.7; 3.7; 1.01; 1.01; 1.25 ▲; 0/0/0; 0/0/0
allpassnnlt; 3.7; 3.7; 1.01; 1.00; 1.23 ▲; 0/0/0; 0/0/0
allpassnt; 4.3; 4.3; 1.00; 1.00; 0.86 ▼; 0/0/0; 0/0/0
convN; 2.4; 1.6; 0.66 ▼; 0.77 ▼; 0.66 ▼; 0/0/0; 0/0/0
conv; 2.1; 1.5; 0.71 ▼; 0.70 ▼; 0.67 ▼; 0/0/0; 0/0/0
fir; 1.9; 1.7; 0.90 ▼; 1.03; 0.67 ▼; 0/0/0; 0/0/0
iir_kl; 4.8; 4.8; 1.00; 0.99; 1.13 ▲; 0/0/0; 0/0/0
iir_lat1; 4.4; 4.6; 1.05; 1.01; 1.28 ▲; 0/0/0; 0/0/0
iir_lat2; 2.9; 3.0; 1.03; 0.99; 0.92; 0/0/0; 0/0/0
iir_nl; 4.8; 4.8; 1.00; 0.99; 1.13 ▲; 0/0/0; 0/0/0
iir; 2.8; 2.2; 0.79 ▼; 0.79 ▼; 0.76 ▼; 0/0/0; 0/0/0
notchw; 3.5; 3.5; 0.99; 0.99; 0.78 ▼; 0/0/0; 0/0/0
tf1; 2.7; 2.7; 0.99; 1.03; 1.01; 0/0/0; 0/0/0
tf21; 4.9; 4.9; 1.00; 1.00; 1.29 ▲; 0/0/0; 0/0/0
tf21t; 3.5; 3.5; 1.00; 0.99; 0.72 ▼; 0/0/0; 0/0/0
tf22; 2.5; 2.4; 1.00; 1.00; 0.83 ▼; 0/0/0; 0/0/0
tf22t; 2.7; 3.4; 1.27 ▲; 1.07; 0.91; 0/0/0; 0/0/0
tf2; 3.5; 3.5; 1.00; 1.00; 0.76 ▼; 0/0/0; 0/0/0
tf3; 6.8; 6.7; 1.00; 0.99; 1.10; 0/0/0; 0/0/0
```

## filters_state_variable

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
SVFTPT_AP2; 4.8; 4.5; 0.94; 1.44 ▲; 1.27 ▲; 0/0/0; 0/0/0
SVFTPT_BP2Norm; 4.7; 4.5; 0.95; 0.95; 1.11 ▲; 0/0/0; 0/0/0
SVFTPT_BP2; 4.6; 4.6; 1.01; 1.01; 1.21 ▲; 0/0/0; 0/0/0
SVFTPT_HP2; 4.0; 4.2; 1.04; 1.04; 0.98; 0/0/0; 0/0/0
SVFTPT_LP2; 4.5; 4.5; 1.00; 1.00; 1.00; 0/0/0; 0/0/0
SVFTPT_Notch2; 4.8; 4.5; 0.94; 1.43 ▲; 1.26 ▲; 0/0/0; 0/0/0
SVFTPT_Peaking2; 3.8; 3.0; 0.80 ▼; 0.83 ▼; 0.62 ▼; 0/0/0; 0/0/0
SVFTPT_SVF; 3.9; 3.6; 0.91; 0.90; 0.94; 0/0/0; 0/0/0
dynamicSmoothing; 15.0; 14.9; 1.00; 1.00; 1.08; 1/0/1; 1/0/1
oneEuro; 8.7; 8.8; 1.01; 1.03; 1.10; 3/0/0; 3/0/0
svf_ap; 4.5; 4.5; 1.00; 0.96; 0.86 ▼; 0/0/0; 0/0/0
svf_bell; 4.5; 4.5; 1.00; 0.96; 0.86 ▼; 0/0/0; 0/0/0
svf_bp; 4.5; 4.6; 1.02; 0.99; 0.93; 0/0/0; 0/0/0
svf_hp; 3.9; 4.3; 1.11 ▲; 1.07; 0.83 ▼; 0/0/0; 0/0/0
svf_hs; 3.9; 4.0; 1.02; 1.03; 0.88 ▼; 0/0/0; 0/0/0
svf_lp; 4.8; 4.5; 0.93; 0.96; 1.17 ▲; 0/0/0; 0/0/0
svf_ls; 4.2; 4.1; 0.98; 1.03; 0.89 ▼; 0/0/0; 0/0/0
svf_morph; 4.5; 4.7; 1.05; 0.99; 0.93; 0/0/0; 0/0/0
svf_notch_morph; 4.5; 4.5; 1.00; 1.00; 0.86 ▼; 0/0/0; 0/0/0
svf_notch; 4.5; 4.5; 1.00; 0.96; 0.86 ▼; 0/0/0; 0/0/0
svf_peak; 3.9; 4.0; 1.03; 1.04; 0.84 ▼; 0/0/0; 0/0/0
```

## motion

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
accelEnvelopeAbs; 1.7; 3.6; 2.08 ?; 0.90 ▼; 1.07; 0/0/0; 0/0/0
accelEnvelopeNeg; 3.1; 2.6; 0.84 ▼; 0.84 ▼; 1.25 ▲; 0/0/0; 0/0/0
accelEnvelopePos; 3.1; 2.6; 0.84 ▼; 0.84 ▼; 1.26 ▲; 0/0/0; 0/0/0
gyroEnvelopeAbs; 3.3; 3.6; 1.10 ▲; 1.08; 1.09; 0/0/0; 0/0/0
gyroEnvelopeNeg; 3.1; 2.8; 0.89 ▼; 0.88 ▼; 1.28 ▲; 0/0/0; 0/0/0
gyroEnvelopePos; 3.2; 2.8; 0.86 ▼; 0.88 ▼; 1.28 ▲; 0/0/0; 0/0/0
inclineBalance; 3.4; 2.6; 0.76 ▼; 0.69 ▼; 1.05; 0/0/0; 0/0/0
inclineSymmetric; 4.6; 4.3; 0.92; 0.58 ▼; 1.07; 0/0/0; 0/0/0
inclinometer; 2.5; 2.4; 0.99; 0.74 ▼; 0.90 ▼; 0/0/0; 0/0/0
motionEnvelopeRange; 3.2; 3.6; 1.11 ▲; 1.08; 1.08; 0/0/0; 0/0/0
motionEnvelopeUD; 3.6; 3.1; 0.86 ▼; 0.86 ▼; 1.03; 0/0/0; 0/0/0
orientation6; 8.3; 6.7; 0.81 ▼; 0.84 ▼; 0.92; 0/6/0; 0/6/0
projectedGravity; 3.5; 4.3; 1.24 ▲; 0.67 ▼; 0.89 ▼; 0/0/1; 0/0/1
scale_narrow; 2.9; 0.5; 0.19 ▼; 0.20 ▼; 0.82 ▼; 0/0/0; 0/0/0
scale; 2.9; 0.5; 0.18 ▼; 0.20 ▼; 0.81 ▼; 0/0/0; 0/0/0
shockTrigger; 4.0; 3.9; 0.95; 1.00; 1.16 ▲; 0/0/0; 0/0/0
totalAccelRange; 4.1; 2.4; 0.58 ▼; 0.66 ▼; 1.19 ▲; 0/1/0; 0/1/0
totalAccelUD; 4.4; 2.9; 0.65 ▼; 0.69 ▼; 0.97; 0/1/0; 0/1/0
totalAccel; 4.0; 2.6; 0.66 ▼; 0.68 ▼; 1.17 ▲; 0/1/0; 0/1/0
totalGyro; 4.0; 2.6; 0.66 ▼; 0.67 ▼; 1.19 ▲; 0/1/0; 0/1/0
```

## instruments

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
inst_bandPassH; 3.5; 3.5; 1.00; 1.00; 0.72 ▼; 0/0/0; 0/0/0
inst_bandPass; 3.5; 3.5; 1.00; 1.00; 0.70 ▼; 0/0/0; 0/0/0
inst_bow; 2.2; 0.7; 0.33 ▼; 0.84 ▼; 0.62 ▼; 0/0/1; 0/0/1
inst_envVibrato; 4.9; 5.6; 1.15 ▲; 1.06; 1.08; 0/0/0; 0/0/0
inst_instrReverb; 19.1; 18.6; 0.98; 0.96; 0.93; 0/0/0; 0/0/0
inst_jetTable; 2.4; 0.9; 0.37 ▼; 0.39 ▼; 0.78 ▼; 0/0/0; 0/0/0
inst_nonLinearModulator; 4.2; 4.2; 0.99; 1.00; 1.01; 0/0/2; 0/0/2
inst_onePoleSwep; 2.6; 0.7; 0.29 ▼; 0.29 ▼; 0.71 ▼; 0/0/0; 0/0/0
inst_onePole; 2.6; 2.6; 0.98; 1.00; 0.77 ▼; 0/0/0; 0/0/0
inst_oneZero0; 3.0; 3.0; 0.99; 0.99; 0.76 ▼; 0/0/0; 0/0/0
inst_oneZero1; 2.6; 0.8; 0.29 ▼; 0.29 ▼; 0.71 ▼; 0/0/0; 0/0/0
inst_poleZero; 3.4; 3.4; 1.00; 1.00; 1.00; 0/0/0; 0/0/0
inst_reed; 2.4; 0.9; 0.37 ▼; 0.37 ▼; 0.73 ▼; 0/0/0; 0/0/0
inst_saturationNeg; 2.4; 0.5; 0.22 ▼; 0.22 ▼; 0.70 ▼; 0/0/0; 0/0/0
inst_saturationPos; 2.4; 0.5; 0.22 ▼; 0.22 ▼; 0.68 ▼; 0/0/0; 0/0/0
inst_stereoizer; 2.4; 0.6; 0.26 ▼; 0.26 ▼; 0.70 ▼; 0/0/0; 0/0/0
```

## pinktrombone

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
glottis_modulated; 41.2; 45.5; 1.10 ▲; 1.09; 0.98; 12/2/10; 12/2/10
glottis; 27.6; 27.6; 1.00; 0.82 ▼; 0.99; 12/0/9; 12/0/9
lfWaveform_modulated; 9.6; 9.2; 0.95; 1.00; 0.74 ▼; 12/0/7; 12/0/7
lfWaveform; 5.7; 5.4; 0.95; 0.96; 0.91; 0/0/9; 0/0/9
pinkTrombone2; 196.6; 193.2; 0.98; 1.01; 1.01; 56/0/9; 56/0/9
pinkTrombone; 189.5; 184.8; 0.98; 1.00; 1.01; 52/0/9; 52/0/9
pt_noiseSeed; 33.5; 33.0; 0.98; 0.94; 1.04; 12/0/9; 12/0/9
pt_ticksPerSample; 155.5; 155.9; 1.00; 1.00; 1.01; 49/0/9; 49/0/9
tract2Ext; 159.5; 159.2; 1.00; 1.00; 1.00; 43/0/0; 43/0/0
tract2; 159.4; 161.0; 1.01; 1.00; 1.00; 43/0/0; 43/0/0
tractExt; 155.2; 155.5; 1.00; 1.01; 1.00; 40/0/0; 40/0/0
tract_closure; 157.2; 158.2; 1.01; 1.01; 0.99; 44/0/0; 44/0/0
tract_nasal; 152.8; 154.2; 1.01; 1.00; 1.00; 40/0/0; 40/0/0
tract_release; 154.6; 157.1; 1.02; 1.02; 0.99; 40/0/0; 40/0/0
tract; 153.6; 156.2; 1.02; 1.00; 0.99; 40/0/0; 40/0/0
```

## reverbs

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
dattorro_rev_default; 9.9; 8.8; 0.89 ▼; 0.85 ▼; 0.89 ▼; 0/0/0; 0/0/0
dattorro_rev; 9.9; 9.1; 0.92; 0.93; 0.99; 0/0/0; 0/0/0
fdnrev0; 9.1; 9.4; 1.03; 0.98; 1.02; 0/0/0; 0/0/0
greyhole; 48.0; 48.4; 1.01; 1.02; 0.98; 33/0/6; 33/0/6
jcrev; 4.4; 4.0; 0.91; 0.89 ▼; 0.81 ▼; 0/0/0; 0/0/0
jpverb; 71.2; 80.7; 1.13 ▲; 1.08; 1.18 ▲; 32/0/0; 32/0/0
kb_rom_rev1; 18.5; 17.8; 0.96; 0.95; 0.88 ▼; 0/0/0; 0/0/0
mono_freeverb; 10.5; 10.8; 1.04; 1.04; 0.99; 0/0/0; 0/0/0
satrev; 4.7; 5.3; 1.12 ▲; 1.08; 0.87 ▼; 0/0/0; 0/0/0
springreverb; 22.1; 22.9; 1.03; 1.01; 0.97; 8/0/0; 8/0/0
stereo_freeverb; 19.7; 20.6; 1.05; 1.05; 0.97; 0/0/0; 0/0/0
vital_rev; 108.0; 101.7; 0.94; 0.95; 0.89 ▼; 0/0/8; 0/0/8
zita_rev1_ambi; 18.4; 19.1; 1.04; 1.01; 0.91; 0/0/0; 0/0/0
zita_rev1_stereo; 18.2; 18.2; 1.00; 0.97; 0.93; 0/0/0; 0/0/0
zita_rev_fdn; 23.2; 24.4; 1.05; 1.07; 0.95; 0/0/0; 0/0/0
```

## filters_parametric_eq

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
high_shelf1_l; 3.1; 3.5; 1.12 ▲; 1.36 ▲; 0.83 ▼; 0/0/0; 0/0/0
high_shelf1; 3.1; 3.5; 1.13 ▲; 1.36 ▲; 0.85 ▼; 0/0/0; 0/0/0
high_shelf; 3.7; 3.9; 1.07; 0.94; 1.36 ▲; 0/0/0; 0/0/0
highshelf; 3.7; 3.9; 1.07; 0.94; 1.36 ▲; 0/0/0; 0/0/0
levelfilterN; 3.1; 3.6; 1.14 ▲; 1.20 ▲; 0.93; 0/0/0; 0/0/0
levelfilter; 3.3; 3.0; 0.90; 0.87 ▼; 0.93; 0/0/0; 0/0/0
low_shelf1_l; 2.8; 2.5; 0.91; 0.75 ▼; 0.93; 0/0/0; 0/0/0
low_shelf1; 2.8; 2.5; 0.88 ▼; 0.87 ▼; 0.90 ▼; 0/0/0; 0/0/0
low_shelf; 3.6; 3.9; 1.07; 0.92; 1.17 ▲; 0/0/0; 0/0/0
lowshelf; 3.6; 3.9; 1.07; 0.92; 1.15 ?; 0/0/0; 0/0/0
peak_eq_cq; 4.2; 5.3; 1.27 ▲; 1.05; 1.71 ▲; 0/0/0; 0/0/0
peak_eq_rm; 3.9; 3.9; 1.01; 1.01; 0.93; 0/0/0; 0/0/0
peak_eq; 4.2; 5.3; 1.26 ▲; 1.03; 1.71 ▲; 0/0/0; 0/0/0
spectral_tilt; 4.0; 2.9; 0.72 ▼; 0.78 ▼; 1.17 ▲; 0/0/0; 0/0/0
```

## maxmsp

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
mm_APF; 4.2; 4.1; 0.98; 0.99; 0.89 ▼; 0/0/0; 0/0/0
mm_BPF; 3.5; 3.5; 1.00; 1.00; 0.78 ▼; 0/0/0; 0/0/0
mm_HPF; 3.5; 3.5; 1.00; 0.97; 0.70 ▼; 0/0/0; 0/0/0
mm_LPF; 3.5; 3.5; 1.00; 1.00; 0.70 ▼; 0/0/0; 0/0/0
mm_biquad; 3.6; 3.6; 1.00; 1.00; 1.00; 0/0/0; 0/0/0
mm_highShelf; 3.5; 3.5; 1.00; 1.00; 0.72 ▼; 0/0/0; 0/0/0
mm_line_frac; 2.5; 1.5; 0.61 ▼; 0.60 ▼; 0.73 ▼; 1/0/0; 1/0/0
mm_lowShelf; 3.5; 3.5; 1.01; 1.00; 0.71 ▼; 0/0/0; 0/0/0
mm_notch; 4.2; 4.1; 0.98; 0.99; 0.95; 0/0/0; 0/0/0
mm_peakNotch; 4.2; 4.1; 0.99; 1.00; 0.92; 0/0/0; 0/0/0
mm_peakingEQ; 4.2; 4.1; 0.99; 0.99; 0.91; 0/0/0; 0/0/0
```

## spats

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
binauralFir; 2.1; 1.7; 0.82 ▼; 0.90; 0.71 ▼; 0/0/0; 0/0/0
binauralModel; 4.2; 2.8; 0.67 ▼; 0.92; 1.03; 0/0/0; 0/0/0
constantPowerPan; 4.3; 0.8; 0.18 ▼; 0.19 ▼; 0.77 ▼; 0/0/0; 0/0/0
panner; 2.3; 0.5; 0.23 ▼; 0.23 ▼; 0.75 ▼; 0/0/0; 0/0/0
spat; 3.3; 3.3; 1.00; 0.99; 0.90; 0/0/0; 0/0/0
spcap; 2.3; 0.7; 0.31 ▼; 0.31 ▼; 0.78 ▼; 0/0/0; 0/0/0
spcap_ui; 2.0; 0.9; 0.44 ▼; 0.43 ▼; 0.77 ▼; 0/0/0; 0/0/0
stereoize; 2.5; 0.8; 0.31 ▼; 0.30 ▼; 0.80 ▼; 0/0/0; 0/0/0
wfs; 2.3; 0.5; 0.22 ▼; 0.20 ▼; 0.65 ▼; 0/0/0; 0/0/0
wfs_ui; 3.6; 3.6; 1.01; 0.99; 0.95; 0/0/0; 0/0/0
```

## routes

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
butterfly; 4.7; 1.5; 0.31 ▼; 0.29 ▼; 0.68 ▼; 0/0/0; 0/0/0
cross1n; 3.5; 1.4; 0.41 ▼; 0.40 ▼; 0.67 ▼; 0/0/0; 0/0/0
crossNM; 4.8; 1.7; 0.35 ▼; 0.35 ▼; 0.80 ▼; 0/0/0; 0/0/0
cross; 4.3; 1.0; 0.24 ▼; 0.28 ▼; 0.63 ▼; 0/0/0; 0/0/0
crossn1; 3.5; 1.3; 0.39 ▼; 0.38 ▼; 0.73 ▼; 0/0/0; 0/0/0
crossnn; 3.5; 1.5; 0.44 ▼; 0.44 ▼; 0.74 ▼; 0/0/0; 0/0/0
hadamard; 3.1; 1.7; 0.54 ▼; 0.51 ▼; 0.90 ▼; 0/0/0; 0/0/0
interleave; 4.4; 1.4; 0.31 ?; 0.38 ?; 0.66 ▼; 0/0/0; 0/0/0
recursivize; 3.9; 3.2; 0.83 ▼; 0.81 ▼; 0.91; 0/0/0; 0/0/0
```

## signals

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
bpar; 3.3; 1.0; 0.30 ▼; 0.30 ▼; 0.71 ▼; 0/0/0; 0/0/0
bsum; 2.6; 1.1; 0.43 ▼; 0.39 ▼; 0.70 ▼; 0/0/0; 0/0/0
cbus; 3.5; 1.5; 0.42 ▼; 0.42 ▼; 0.70 ▼; 0/0/0; 0/0/0
cconj; 2.3; 0.8; 0.34 ▼; 0.33 ▼; 0.87 ▼; 0/0/0; 0/0/0
cmul; 3.1; 1.6; 0.50 ▼; 0.49 ▼; 0.75 ▼; 0/0/0; 0/0/0
dot; 3.4; 2.0; 0.57 ▼; 0.54 ▼; 0.80 ▼; 0/0/0; 0/0/0
interpolate; 2.6; 0.8; 0.32 ▼; 0.32 ▼; 0.76 ▼; 0/0/0; 0/0/0
rev; 2.5; 1.0; 0.40 ▼; 0.39 ▼; 0.90; 0/0/0; 0/0/0
smoothq; 3.7; 3.7; 0.99; 1.12 ▲; 1.17 ▲; 0/0/0; 0/0/0
```

## delays

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
delay; 2.4; 0.6; 0.23 ▼; 0.23 ▼; 0.74 ▼; 0/0/0; 0/0/0
fdelay2a; 3.9; 3.9; 1.00; 1.00; 0.88 ▼; 0/0/0; 0/0/0
fdelay; 2.4; 0.6; 0.25 ▼; 0.25 ▼; 0.66 ▼; 0/0/0; 0/0/0
fdelaylti; 2.5; 1.3; 0.49 ▼; 0.44 ▼; 0.76 ▼; 0/0/0; 0/0/0
fdelayltv; 2.4; 0.7; 0.30 ▼; 0.31 ▼; 0.68 ▼; 0/0/0; 0/0/0
multiTapSincDelay; 2.4; 0.8; 0.34 ▼; 0.34 ▼; 0.76 ▼; 0/0/0; 0/0/0
prime_power_delays; 0.1; 0.1; 1.00; 1.00; 1.00; 0/0/0; 0/0/0
sdelay; 3.6; 3.6; 1.00; 1.00; 1.03; 0/0/0; 0/0/0
```

## synths

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
additiveDrum; 3.5; 1.7; 0.49 ▼; 0.51 ▼; 0.75 ▼; 0/0/0; 0/0/0
clap; 3.7; 5.0; 1.35 ▲; 0.83 ▼; 1.76 ▲; 0/0/1; 0/0/1
dubDub; 3.5; 6.4; 1.82 ▲; 1.51 ▲; 1.09; 0/0/0; 0/0/0
fm; 3.3; 2.3; 0.69 ▼; 0.69 ▼; 0.84 ▼; 0/0/0; 0/0/0
hat; 17.5; 17.9; 1.02; 1.01; 1.00; 0/0/2; 0/0/2
kick; 2.7; 2.9; 1.05; 1.23 ▲; 0.91; 0/0/1; 0/0/1
popFilterDrum; 3.5; 6.5; 1.86 ▲; 1.53 ▲; 2.29 ▲; 0/0/0; 0/0/0
sawTrombone; 6.9; 4.6; 0.67 ▼; 0.83 ▼; 0.93; 7/0/1; 2/0/1
```

## webaudio

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
allpass2; 4.6; 4.5; 0.98; 0.99; 0.94; 0/0/0; 0/0/0
bandpass2; 3.8; 3.8; 1.00; 0.99; 0.81 ▼; 0/0/0; 0/0/0
highpass2; 3.8; 3.8; 1.00; 0.97; 0.70 ▼; 0/0/0; 0/0/0
highshelf2; 3.8; 3.8; 1.01; 1.00; 1.26 ▲; 0/0/0; 0/0/0
lowpass2; 3.8; 3.8; 1.00; 0.99; 0.70 ▼; 0/0/0; 0/0/0
lowshelf2; 3.8; 3.8; 1.01; 1.00; 0.88 ▼; 0/0/0; 0/0/0
notch2; 4.5; 4.5; 0.98; 0.98; 0.97; 0/0/0; 0/0/0
peaking2; 4.5; 4.5; 0.99; 0.99; 0.95; 0/0/0; 0/0/0
```

## filters_analog_sections

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
tf1s; 3.4; 0.8; 0.23 ▼; 1.12 ▲; 0.73 ▼; 0/0/0; 0/0/0
tf1sb; 4.2; 4.8; 1.15 ▲; 1.38 ▲; 1.19 ▲; 0/0/0; 0/0/0
tf1snp; 2.9; 2.1; 0.71 ▼; 0.47 ▼; 0.67 ▼; 0/0/0; 0/0/0
tf2s; 3.5; 5.9; 1.68 ▲; 1.68 ▲; 1.48 ▲; 0/0/0; 0/0/0
tf2sb; 5.2; 3.9; 0.75 ▼; 0.56 ▼; 1.43 ▲; 0/0/0; 0/0/0
tf2snp; 5.4; 5.5; 1.00; 1.01; 1.12 ▲; 0/0/0; 0/0/0
tf3slf; 5.9; 7.1; NaN; NaN; NaN; 0/0/0; 0/0/0
```

## noises

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
colored_noise; 3.6; 4.2; 1.15 ▲; 1.26 ▲; 3.00 ▲; 0/0/0; 0/0/0
lfnoiseN; 3.8; 4.2; 1.09; 0.93; 1.37 ▲; 0/0/0; 0/0/0
lfnoise; 5.1; 5.0; 0.99; 1.07; 1.25 ▲; 0/0/0; 0/0/0
simplex1; 4.6; 4.2; 0.91; 0.93; 0.86 ▼; 0/0/0; 0/0/0
simplex2; 4.7; 4.4; 0.92; 0.96; 0.88 ▼; 0/0/0; 0/0/0
sparse_noise; 3.1; 1.9; 0.60 ▼; 0.59 ▼; 0.73 ▼; 0/0/0; 0/0/0
velvet_noise; 3.2; 2.0; 0.62 ▼; 0.64 ▼; 0.75 ▼; 0/0/0; 0/0/0
```

## filters_delay_equalizing_allpass

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
highpass_minus_lowpass_even; 4.2; 4.2; 1.00; 0.87 ▼; 1.31 ▲; 0/0/0; 0/0/0
highpass_minus_lowpass_odd; 3.6; 3.9; 1.08; 0.93; 1.16 ▲; 0/0/0; 0/0/0
highpass_minus_lowpass; 3.2; 2.5; 0.79 ▼; 0.83 ▼; 0.87 ▼; 0/0/0; 0/0/0
highpass_plus_lowpass_even; 4.2; 4.3; 1.01; 0.87 ▼; 1.29 ▲; 0/0/0; 0/0/0
highpass_plus_lowpass_odd; 3.6; 3.9; 1.06; 0.91; 1.34 ▲; 0/0/0; 0/0/0
highpass_plus_lowpass; 4.2; 5.2; 1.24 ▲; 1.29 ▲; 1.44 ▲; 0/0/0; 0/0/0
```

## filters_ladder_allpass

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
allpassn1m; 5.5; 5.6; 1.01; 1.01; 1.16 ▲; 0/0/0; 0/0/0
allpassn; 4.2; 4.4; 1.03; 1.03; 1.15 ▲; 0/0/0; 0/0/0
allpassnkl; 4.3; 4.3; 1.00; 1.09; 1.18 ▲; 0/0/0; 0/0/0
allpassnn; 3.6; 4.3; 1.18 ▲; 0.97; 1.19 ▲; 0/0/0; 0/0/0
scatN; 1.9; 0.8; 0.42 ▼; 0.42 ▼; 0.92; 0/0/0; 0/0/0
scat; 2.6; 2.4; 0.91; 0.91; 0.65 ▼; 0/0/0; 0/0/0
```

## filters_linkwitz_riley

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
crossover2LR4; 6.1; 5.1; 0.83 ▼; 0.98; 0.88 ▼; 0/0/0; 0/0/0
crossover3LR4; 9.6; 8.3; 0.87 ▼; 0.82 ▼; 0.73 ▼; 0/0/0; 0/0/0
crossover4LR4; 15.1; 13.5; 0.89 ▼; 0.90 ▼; 0.74 ▼; 0/0/0; 0/0/0
crossover8LR4; 35.8; 36.6; 1.02; 1.00; 0.75 ▼; 0/0/0; 0/0/0
highpassLR4; 4.1; 4.3; 1.04; 1.01; 0.92; 0/0/0; 0/0/0
lowpassLR4; 4.4; 4.1; 0.95; 1.00; 1.04 ?; 0/0/0; 0/0/0
```

## filters_mth_octave_filterbank

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
mth_octave_filterbank3; 7.8; 4.2; 0.54 ▼; 0.73 ▼; 1.17 ▲; 0/0/0; 0/0/0
mth_octave_filterbank5; 6.6; 5.5; 0.83 ▼; 0.85 ▼; 1.60 ▲; 0/0/0; 0/0/0
mth_octave_filterbank_alt; 7.8; 4.2; 0.54 ▼; 0.73 ▼; 1.17 ▲; 0/0/0; 0/0/0
mth_octave_filterbank_default; 6.6; 5.4; 0.82 ▼; 0.84 ▼; 1.59 ▲; 0/0/0; 0/0/0
mth_octave_filterbank; 4.6; 4.2; 0.92; 0.73 ▼; 1.18 ▲; 0/0/0; 0/0/0
```

## filters_useful_special

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
apnl; 4.0; 3.8; 0.95; 0.95; 1.19 ▲; 0/0/0; 0/0/0
itu_r_bs_1770_4_kfilter; 3.6; 3.4; 0.95; 0.96; 1.15 ▲; 0/0/0; 0/0/0
nlf2; 3.7; 3.7; 1.00; 0.98; 1.01; 0/0/0; 0/0/0
tf2np; 4.8; 4.8; 1.00; 1.00; 1.12 ▲; 0/0/0; 0/0/0
wgr; 5.3; 5.3; 1.00; 1.00; 1.16 ▲; 0/0/0; 0/0/0
```

## hysteresis

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
ja_hysteresis; 64.9; 64.4; 0.99; 1.01; 1.02; 12/0/4; 12/0/4
ja_processor_stereo; 60.8; 61.1; 1.01; 1.00; 0.99; 24/0/8; 24/0/8
ja_processor_stereo_ui; 63.5; 63.7; 1.00; 1.01; 0.99; 53/0/8; 53/0/8
ja_processor; 57.2; 59.8; 1.04; 0.99; 0.99; 12/0/4; 12/0/4
ja_processor_ui; 61.3; 59.6; 0.97; 1.00; 0.99; 27/0/4; 27/0/4
```

## reducemaps

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
RMS; 2.5; 1.9; 0.75 ▼; 0.74 ▼; 0.78 ▼; 0/1/0; 0/1/0
maxn; 3.2; 2.7; 0.82 ▼; 0.99; 0.87 ▼; 0/0/0; 0/0/0
mean; 2.5; 1.9; 0.77 ▼; 0.77 ▼; 0.88 ▼; 0/0/0; 0/0/0
minn; 3.2; 2.7; 0.82 ▼; 0.99; 0.81 ▼; 0/0/0; 0/0/0
sumn; 3.5; 2.8; 0.80 ▼; 0.80 ▼; 0.76 ▼; 0/0/0; 0/0/0
```

## envelopes

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
adsr_velocity; 2.6; 1.6; 0.64 ▼; 0.53 ▼; 0.79 ▼; 0/0/0; 0/0/0
ahdsre; 2.5; 2.5; 1.00; 1.00; 0.90 ▼; 1/0/1; 1/0/1
asr_velocity; 2.5; 1.6; 0.65 ▼; 0.47 ▼; 0.80 ▼; 0/0/0; 0/0/0
dx7envelope; 2.6; 1.7; 0.63 ▼; 0.67 ▼; 0.98; 0/0/0; 0/0/0
```

## filters_elliptic

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
highpass3e; 3.5; 4.1; 1.17 ▲; 0.92; 1.43 ▲; 0/0/0; 0/0/0
highpass6e; 4.2; 5.7; 1.35 ▲; 1.24 ▲; 1.84 ?; 0/0/0; 0/0/0
lowpass3e; 3.5; 3.7; 1.05; 1.15 ▲; 1.20 ▲; 0/0/0; 0/0/0
lowpass6e; 4.2; 5.7; 1.35 ▲; 1.12 ▲; 2.40 ▲; 0/0/0; 0/0/0
```

## interpolators

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
frdtable; 2.3; 1.2; 0.50 ▼; 0.49 ▼; 0.87 ▼; 0/0/0; 0/0/0
frwtable; 2.5; 1.3; 0.50 ▼; 0.51 ▼; 0.74 ▼; 0/0/0; 0/0/0
piecewise; 2.3; 1.5; 0.67 ▼; 0.67 ▼; 0.83 ▼; 1/0/0; 1/0/0
remap; 2.8; 0.5; 0.19 ▼; 0.21 ▼; 0.42 ▼; 0/0/0; 0/0/0
```

## phaflangers

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
flanger_mono; 2.5; 0.9; 0.36 ▼; 0.38 ▼; 0.68 ▼; 0/0/0; 0/0/0
flanger_stereo; 3.6; 1.8; 0.49 ▼; 0.62 ?; 0.88 ▼; 0/0/0; 0/0/0
phaser2_mono; 9.4; 9.0; 0.96; 0.97; 0.97; 0/0/4; 0/0/4
phaser2_stereo; 13.6; 13.3; 0.98; 0.95; 0.98; 0/0/8; 0/0/8
```

## filters_bandpass_bandstop

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
bandpass0_bandstop1; 5.3; 4.2; 0.80 ▼; 0.60 ▼; 1.43 ▲; 0/0/0; 0/0/0
bandpass; 5.2; 4.2; 0.81 ▼; 0.60 ▼; 1.43 ▲; 0/0/0; 0/0/0
bandstop; 5.3; 3.1; 0.58 ▼; 0.50 ▼; 1.55 ▲; 0/0/0; 0/0/0
```

## filters_butterworth

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
highpass; 4.2; 4.6; 1.11 ▲; 1.02; 1.41 ▲; 0/0/0; 0/0/0
lowpass0_highpass1; 3.5; 4.5; 1.29 ▲; 1.12 ▲; 1.22 ▲; 0/0/0; 0/0/0
lowpass; 4.2; 4.1; 0.98; 0.80 ▼; 1.25 ▲; 0/0/0; 0/0/0
```

## filters_pospass

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
hilbert; 6.2; 4.7; 0.75 ▼; 0.96; 1.38 ▲; 0/0/0; 0/0/0
pospass6e; 7.8; 8.1; 1.04; 1.61 ▲; 2.82 ▲; 0/0/0; 0/0/0
pospass; 4.4; 4.8; 1.09; 0.92; 1.34 ▲; 0/0/0; 0/0/0
```

## filters_resonator

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
resonbp; 3.5; 5.2; 1.49 ▲; 1.10 ▲; 1.03; 0/0/0; 0/0/0
resonhp; 3.5; 4.6; 1.32 ▲; 1.04; 1.49 ▲; 0/0/0; 0/0/0
resonlp; 3.5; 5.2; 1.50 ▲; 1.12 ▲; 1.38 ▲; 0/0/0; 0/0/0
```

## maths

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
diffn; 2.4; 0.7; 0.31 ▼; 0.30 ▼; 0.70 ▼; 0/0/0; 0/0/0
isnan; 3.9; 0.5; 0.12 ▼; 0.24 ▼; 0.44 ▼; 0/1/0; 0/1/0
zc; 2.4; 2.8; 1.16 ▲; 1.15 ▲; 0.77 ▼; 0/0/0; 0/0/0
```

## soundfiles

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
loop_speed_level; 6.2; 6.2; 1.01; 0.98; 1.15 ▲; 0/0/1; 0/0/1
loop_speed; 6.3; 6.2; 0.99; 1.00; 1.14 ?; 0/0/1; 0/0/1
loop; 6.2; 6.2; 1.00; 1.00; 1.13 ▲; 0/0/1; 0/0/1
```

## fds

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
bow; 2.5; 1.1; 0.47 ▼; 0.46 ▼; 0.81 ▼; 0/0/1; 0/0/1
hammer; 5.4; 5.4; 1.00; 1.00; 1.11 ▲; 0/0/0; 0/0/0
```

## filters_elliptic_bandpass

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
bandpass12e; 9.1; 8.5; 0.93; 1.13 ▲; 1.92 ▲; 0/0/0; 0/0/0
bandpass6e; 5.8; 4.6; 0.79 ▼; 0.63 ▼; 1.72 ▲; 0/0/0; 0/0/0
```

## filters_filterbank

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
filterbank; 7.9; 8.0; 1.01; 0.90 ▼; 1.30 ▲; 0/0/0; 0/0/0
filterbanki; 8.3; 6.7; 0.80 ▼; 0.79 ▼; 1.31 ▲; 0/0/0; 0/0/0
```

## mi

```csv
test; base ns; new ns; fast-math; strict; vec; ops base; ops new
nlPluck; 4.3; 0.6; 0.13 ▼; 0.13 ▼; 0.63 ▼; 0/0/0; 0/0/0
posInput; 3.1; 0.5; 0.17 ▼; 0.17 ▼; 0.55 ▼; 0/0/0; 0/0/0
```

