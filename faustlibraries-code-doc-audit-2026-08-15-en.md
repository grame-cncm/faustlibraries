# Faust libraries audit — code quality, documentation and DSP coverage

**Repository audited**: `/Users/letz/Developpements/faustlibraries` (HEAD `ccc6030e`)
**Date**: 2026-08-15
**Reference compiler**: FAUST 2.87.4

---

## 1. Scope and method

The audit covers the **43 `.lib` files tracked by git at the repository root**
(the `dx7/`, `modalmodels/`, `embedded/`, `old/` and `unsupported/` subfolders,
along with untracked working files, are excluded), totalling **52,976 lines** and
**~1,350 top-level definitions**.

Measurements performed:

- extraction of top-level definitions and documentation blocks
  (`//---…`(pfx.)name`---`), handling multi-function headers
  (`` `(fi.)tf1`, `(fi.)tf2` and `(fi.)tf3` ``) and generic patterns (`` `(de.)fdelay[N]` ``);
- parse check of every library via `faust -I .`;
- actual execution of a subset of the `make check` harness;
- topic inventory by lexical search, followed by manual verification of every
  reported absence (to rule out false positives — for instance `hann`, which only
  matched inside the word "c**hann**el").

---

## 2. Overview

### What is solid

Taken as a whole, these libraries are of a markedly higher standard than most
open-source DSP ecosystems:

1. **All 43 libraries parse cleanly** with Faust 2.87.4, without a single warning.
2. **A consistent, tooled documentation convention**: 1,028 structured
   documentation blocks (`#### Usage` / `Where:` / `#### Test` /
   `#### References`), turned into an MkDocs site by `doc/scripts/faustlib2md.awk`
   and deployed automatically by GitHub Actions.
3. **Executable examples backed onto the documentation**: 1,001 `xxx_test = …`
   examples are embedded in the `.lib` comments, and **993 of them (99.2%) have a
   matching compiled test** in `tests/*.dsp`. This is a remarkable arrangement,
   and remarkably well kept up to date.
4. **A very clean namespace**: out of ~1,350 symbols, only **4 collisions** across
   libraries (`line`, `bow`, `inverse`, `biquad`), all benign since they are
   isolated by environment prefixes.
5. **Outstanding specialist domains**: physical modelling (`physmodels.lib`
   5,116 l., `mi.lib`, `fds.lib`, `wdmodels.lib` 3,331 l.), virtual analog filters
   (`vaeffects.lib`, 30 topologies: Moog, diode, Korg35, Sallen-Key, Oberheim…),
   antialiased nonlinearities (`aanl.lib`, first- and second-order ADAA) and
   reverberation (15 algorithms) have no equivalent elsewhere.
6. **Per-symbol legal traceability**: 416 symbols carry a
   `declare <name> license "…"`, which feeds `make doc-index-commercial`.

### Documentation coverage table

Coverage = top-level definitions having a documentation block
(`library(...)` aliases excluded).

| Library | Lines | Defs | Doc blocks | Undoc. | Cov. |
|---|---:|---:|---:|---:|---:|
| `wdmodels.lib` | 3,331 | 47 | 48 | 0 | **100%** |
| `fds.lib` / `mi.lib` / `quantizers.lib` | — | 17/15/15 | 17/15/15 | 0 | **100%** |
| `linearalgebra.lib` / `spats.lib` / `hysteresis.lib` / `synths.lib` | — | 7/7/5/9 | same | 0 | **100%** |
| `aanl.lib` | 1,215 | 41 | 40 | 1 | 98% |
| `hoa.lib` | 1,364 | 30 | 29 | 1 | 97% |
| `filters.lib` | 4,829 | 126 | 116 | 5 | 96% |
| `motion.lib` | 855 | 22 | 22 | 1 | 95% |
| `demos.lib` | 2,906 | 48 | 44 | 3 | 94% |
| `maths.lib` | 1,576 | 57 | 54 | 4 | 93% |
| `envelopes.lib` | 822 | 15 | 14 | 1 | 93% |
| `physmodels.lib` | 5,116 | 160 | 150 | 12 | 92% |
| `basics.lib` | 3,742 | 98 | 90 | 9 | 91% |
| `vaeffects.lib` | 2,179 | 34 | 32 | 3 | 91% |
| `signals.lib` | 837 | 22 | 20 | 2 | 91% |
| `compressors.lib` | 1,543 | 29 | 27 | 3 | 90% |
| `oscillators.lib` | 2,715 | 83 | 78 | 9 | 89% |
| `webaudio.lib` | 451 | 9 | 8 | 1 | 89% |
| `reverbs.lib` | 1,291 | 14 | 15 | 2 | 86% |
| `noises.lib` | 642 | 23 | 17 | 5 | 78% |
| `misceffects.lib` | 1,330 | 34 | 25 | 9 | 74% |
| `interpolators.lib` | 1,110 | 30 | 22 | 9 | 70% |
| **`delays.lib`** | 565 | 28 | 8 | 12 | **57%** |
| **`analyzers.lib`** | 1,339 | 57 | 29 | 28 | **51%** |
| **`reducemaps.lib`** | 254 | 10 | 5 | 5 | **50%** |
| **`debug.lib`** | 1,213 | 68 | 33 | 35 | **49%** |
| **`soundfiles.lib`** | 270 | 9 | 3 | 6 | **33%** |
| **`routes.lib`** | 545 | 38 | 10 | 28 | **26%** |
| **`tubes.lib`** | 5,040 | 53 | 0 | 53 | **0%** |
| **`instruments.lib`** | 264 | 17 | 0 | 17 | **0%** |
| **`tonestacks.lib`** | 429 | 26 | 0 | 26 | **0%** |
| **`maxmsp.lib`** | 237 | 13 | 0 | 13 | **0%** |
| **`sf.lib`** | 54 | 28 | 0 | 28 | **0%** |

---

## 3. Documentation quality — defects found

### 3.1 `analyzers.lib`: half the public API is undocumented

This is the most damaging shortfall, because it concerns genuinely public and
widely used functions, not internal helpers:

```
spectral_level, mth_octave_spectral_level_default, mth_octave_analyzer_default,
mth_octave_analyzer3, mth_octave_analyzer5, mth_octave_analyzer6e,
octave_analyzer, third_octave_analyzer, half_octave_analyzer,
octave_filterbank, third_octave_filterbank, half_octave_filterbank,
peak_envelope, fftb, ifftb, rtocv, rtorv, rvtocv,
c_magsq, c_magdb, c_select_pos_freqs, c_bit_reverse_shuffle,
rfft_analyzer_c, rfft_analyzer_db, rfft_analyzer_magsq, rfft_spectral_level
```

The entire FFT subsystem (`fftb`, `ifftb`, the real↔complex conversions
`rtocv`/`rtorv`/`rvtocv`, the `rfft_*` analyzers) therefore **ships without a
single line of explanation**, even though it is precisely the part users cannot
guess: the "N interleaved parallel signals (real, imag)" representation is
documented nowhere.

### 3.2 "Standard" libraries entirely absent from the site

`doc/docs/organization.md` declares `tonestacks.lib` and `tubes.lib` to be part of
the standard libraries, while noting they are "not documented". The result:
**`tubes.lib`, 5,040 lines — the second largest library in the repository — has no
documentation at all**, neither in the sources nor on the site. The same applies
to `tonestacks.lib` (26 amplifier tone stack emulations: Fender, Marshall, Vox,
Mesa, Soldano…), `instruments.lib` (17 Faust-STK primitives) and `maxmsp.lib`
(13 compatibility functions). In total, **9 libraries have no page** in
`doc/docs/libs/`.

### 3.3 15 documentation blocks contain **only** a `#### Test` section

These functions appear in the generated site with no description, no usage and no
parameters — the reader sees a title followed by a code snippet:

```
filters.lib: lowpass0_highpass1, highpass_plus_lowpass, highpass_minus_lowpass,
             highpass_minus_lowpass_even, highpass_plus_lowpass_even, bandstop,
             low_shelf, low_shelf1, low_shelf1_l, lowshelf_other_freq,
             high_shelf, high_shelf1, high_shelf1_l, highshelf_other_freq,
             mth_octave_filterbank_default
```

The complete block as published for `fi.lowpass0_highpass1`:

```faust
//-------------`(fi.)lowpass0_highpass1`--------------
//
// #### Test
// ```
// lowpass0_highpass1_test = src : fi.lowpass0_highpass1(0, 2, 1000);
// ```
//------------------------------
```

The first parameter is a lowpass/highpass selector: impossible to guess. This
looks like a regression from an automated example-insertion pass.

### 3.4 A further 28 blocks without a `#### Usage` section

Notably the 9 `aanl.lib` inverse functions (`Rsqrt`, `Rlog`, `Rtan`, `Racos`,
`Rasin`, `Racosh`, `Rcosh`, `Rsinh`, `Ratanh`), `ba.bpf`, `ba.parallelOp`,
`de.fdelay[N]`, `fi.rev1`, `fi.rev2`, `fi.bandpass6e`, `fi.bandpass12e`,
`pf.phaser2_mono`, `pf.phaser2_stereo`, and the 3 constants of `platform.lib`.
This overlaps with and extends `tests/parameter-doc-report.md`, which listed only 14.

### 3.5 `standardFunctions.md` has drifted from the sources

The "standard functions" index is the entry point for beginners. It is maintained
by hand and has diverged:

- **129 functions** are marked `"X" is a standard Faust function` in the sources;
- **96** are listed in `doc/docs/standardFunctions.md`;
- **42 are marked standard but missing from the index**, including the whole family
  of modern compressors (`co.FFcompressor_N_chan`, `co.FBcompressor_N_chan`,
  `co.FBFFcompressor_N_chan`, `co.RMS_FBFFcompressor_N_chan`,
  `co.RMS_FBcompressor_peak_limiter_N_chan`, `co.expander_N_chan`,
  `co.expanderSC_N_chan`, the 8 `*_compression_gain_*`), the 13 Casio
  phase-distortion oscillators (`os.CZsaw`, `os.CZsquare`, `os.CZpulse`…), the
  complex primitives (`si.cbus`, `si.cmul`, `si.cconj`), `so.loop*`, `ho.rEncoder3D`;
- **9 are listed in the index without being marked in the sources**
  (`fi.fir`, `fi.tf2`, `fi.allpass_fcomb`, `fi.fb_fcomb`, `ba.impulsify`,
  `ba.sec2samp`, `os.oscs`, `an.mth_octave_analyzer[N]`, `sy.popFilterPerc`).

This list should be **generated** from the source markers, not maintained in parallel.

### 3.6 Non-normalised license metadata

Only **416 symbols out of ~1,350 (31%)** carry an explicit license, and the
strings used are not normalised — **16 spellings for ~8 actual licenses**:

| Actual license | Spellings found | Symbols |
|---|---|---|
| MIT | `MIT License` (49), `MIT` (52), `MIT license` (7) | 108 |
| STK-4.3 | `MIT-style STK-4.3 license` (213), `STK-4.3` (49) | 262 |
| GPLv3 | `GPLv3` (18), `GPL-3.0` (9), `GPLv3 license` (5) | 32 |
| AGPL | `AGPL-3.0-only` (1), `AGPL-3.0` (1) | 2 |
| LGPL | `LGPL` (2), `LGPLv2.1` (6), `LGPL v3.0 license` (2) | 10 |

Yet `scripts/build_faust_doc_index.py --license-policy commercial-compatible`
classifies by **string matching**. An unanticipated spelling variant moves a symbol
to the right or the wrong side of the commercial filter — that is, precisely the
use case where an error has legal consequences. The 69% of symbols without an
explicit license implicitly inherit the file header, but `filters.lib` itself
warns: *"Each function in this library has its own license"*. Implicit inheritance
is therefore not safe there.

**SPDX** identifiers (`MIT`, `GPL-3.0-only`, `LGPL-2.1-or-later`) should be
mandated, with CI validation.

---

## 4. Code quality — defects found

### 4.1 Naming conventions: an even split, inconsistent even within a single file

Across symbols longer than 2 characters: **367 in `snake_case`, 382 in `camelCase`**.
This is not a transition in progress but a steady state, and **17 libraries mix
the two internally**:

| Library | snake_case | camelCase |
|---|---:|---:|
| `physmodels.lib` | 10 | **127** |
| `filters.lib` | **50** | 9 |
| `demos.lib` | **45** | 2 |
| `analyzers.lib` | **42** | 4 |
| `basics.lib` | 8 | **33** |
| `oscillators.lib` | **26** | 16 |
| `wdmodels.lib` | 5 | **19** |
| `vaeffects.lib` | 3 | **17** |
| `interpolators.lib` | **16** | 3 |
| `misceffects.lib` | 9 | **14** |

The concrete consequence: in `basics.lib`, users must remember that it is
`ba.sec2samp` but `ba.sAndH`, `ba.countdown` but `ba.downSample`. In
`vaeffects.lib`, `ve.moog_vcf` sits alongside `ve.moogLadder`.

Since Faust cannot rename without breaking compatibility, the realistic fix is:
(a) freeze the convention per library in a contribution guide, (b) add documented
"deprecated" aliases to converge.

### 4.2 Deprecated code kept without a deadline or a machine-readable warning

Three libraries contain a "Deprecated Functions" section inherited from
`music.lib`, with delay sizes hard-coded in samples — **and therefore misleadingly
named**:

```faust
// delays.lib
delay1s(d)  = delay(65536,d);     // 65536 samples = 1.49 s at 44.1 kHz, 1.37 s at 48 kHz
delay43s(d) = delay(2097152,d);
```

The names `delay1s` … `delay43s` suggest a duration in seconds; they are in fact
fixed powers of two whose actual duration depends on `ma.SR`. The same applies to
`basics.lib` (`time1s`…`time43s`, `millisec`) and `misceffects.lib`
(`echo1s`…`echo43s`). These 18 functions are undocumented, carry no
`declare … deprecated`, and remain exported.

`compressors.lib` handles the problem better with its "Original versions" section,
which explains that they are kept both for backward compatibility **and** to
provide a variant under a permissive license.

### 4.3 `ba.downSample`: a misleading name

```faust
downSample(freq) = sAndH(hold) with { hold = time%int(ma.SR/freq) == 0; };
```

This is a **sample-and-hold** with no anti-aliasing filter: it deliberately
produces aliasing (a "lo-fi" effect), it does not reduce the sample rate. The
documentation does not say so, and the index presents it as "Down sample a
signal". A user looking for proper decimation will be sent here by mistake — all
the more so since no true decimation exists in the repository (cf. §6.2).

### 4.4 Residual debt

- 64 `TODO`/`FIXME`/`XXX`/`HACK` markers across 15 libraries
  (`physmodels.lib` 10, `demos.lib` 8, `filters.lib` 7).
- A typo published in the documentation: `filters.lib:189` — *"`dcblocker` is
  **as** standard Faust function"* (instead of "is a").
- `debug.lib` (v0.3.1) exposes 34 `probe_*_impl` symbols that are plainly
  implementation details, in a flat namespace where nothing distinguishes them
  from the public API.
- `routes.lib`: 28 undocumented symbols, i.e. the whole bitonic sorting machinery
  (`bitonicSorterNetwork`, `comparatorDirectionsIdx`…), including `bitonicSort`
  and `bitonicSortIdx` which are, by contrast, the API actually meant for users.

---

## 5. Test infrastructure: the most serious defect

The repository has a complete regression harness — **1,110 tests, ~50 files,
covering every library** — and a `Makefile` with `make reference` / `make check` /
`make bench`. This represents considerable investment.

**It is structurally incapable of detecting any regression.**

### 5.1 `floatdiff.py` always returns 0

```python
    if not diff_found:
        print(f"No differences within tolerance {tol}")
    else:
        print("Differences found.")     # ← no sys.exit(1)
```

`compare_files()` returns `None` and `__main__` ends normally: the exit code is
**0 even when differences are found**.

### 5.2 The `Makefile` swallows the second level of detection

```make
	if ! $(FLOATDIFF) $(REFERENCE_DIR)/$*.ref $@ $(FLOAT_TOL); then \
		echo "[fail] output for $* differs from reference"; \
	fi                                   # ← no exit 1
```

Even if `floatdiff.py` were fixed, the recipe would print `[fail]` and return 0.
And a build failure is explicitly neutralised:

```make
	if ! $(CXX) $(CXXFLAGS) …; then echo "[skip] build failed for $*"; exit 0; fi
```

### 5.3 Empirical verification

```
$ make tests/output/samp2sec_test.out tests/output/dcblocker_test.out tests/output/zcr_test.out
…
Line 48000: file length mismatch
Differences found.
MAKE EXIT=0
```

```
samp2sec_test  floatdiff_exit=0  ref_lines=10000  out_lines=48000
dcblocker_test floatdiff_exit=0  ref_lines=10000  out_lines=48000
zcr_test       floatdiff_exit=0  ref_lines=10000  out_lines=48000
```

Three tests fail over 48,000 lines each; `make` returns 0.

### 5.4 The golden references are neither versioned nor reproducible

- `tests/reference/` holds 1,110 files on disk and **0 files tracked by git**. A
  fresh clone therefore cannot run `make check`: everything must be regenerated
  from the current code, which makes the reference tautological.
- `make clean` does `rm -rf $(REFERENCE_DIR)`: the only copy of the reference data
  is destroyed by the cleanup target.
- The local references are 10,000 lines long while `NUM_SAMPLES ?= 48000`: they
  were produced with different parameters and are stale. Nothing flagged it,
  precisely because of 5.1/5.2.

### 5.5 CI tests nothing

`.github/workflows/` contains a single workflow, `docs.yml`, which builds and
deploys MkDocs. **No job compiles the libraries or runs the tests.** A DSP
regression can be merged with no signal whatsoever.

> **This is the first thing to fix.** The cost is low (one `sys.exit(1)`, one
> `exit 1`, a CI workflow, and versioning the references produced with frozen
> parameters) and it determines the trustworthiness of everything else.

---

## 6. Important DSP topics poorly covered or missing

Every absence below was verified by hand against the sources.

### P0 — Critical gaps

#### 6.1 Windowing and frame-based spectral processing (STFT)

**Missing: Hann, Hamming, Blackman, Blackman-Harris, Kaiser, Tukey, Bartlett,
Nuttall, flat-top.** No window function in any of the 43 libraries.

`analyzers.lib` provides an FFT (`an.fft(N)`, `an.ifft(N)`, `an.goertzel`), but:

- it operates on **N fully unrolled parallel signals**, not on frames;
- there is **no framing, no windowing, no overlap, no overlap-add/overlap-save,
  and no hop size handling**;
- this representation is documented nowhere (cf. §3.1).

Consequence: **spectral processing is not practical in standard Faust**. Phase
vocoder, spectral denoising, spectral freeze, morphing, cross-synthesis, fast
convolution — all depend on it. This is the most structurally significant gap in
the repository.

*Relationship to `faust-rs`: the P3/P4 work on clock domains and `fft_framed(N)`
(`porting/ondemand-vec-fad-interleave-synthesis-2026-07-07-fr.md`) addresses
exactly this gap on the compiler side. An `an.window*` family would be a natural
complement, and useful independently.*

#### 6.2 Oversampling and multirate processing

**Missing: `upsample`, anti-aliased `downsample`, decimators, polyphase
interpolators, an `oversample(N, f)` wrapper.**

This is all the more notable in that the `aanl.lib` header explicitly recommends
the practice:

> *"effective if combined with low-factor oversampling"*

…without providing any way to carry it out. The only other occurrence in the code
is a comment in `vaeffects.lib` noting that the original ChowCentaur uses 2×
oversampling — which the Faust implementation does not have.

Every high-quality nonlinear process (saturation, distortion, clipping,
waveshaping, tube filters) depends on it. `ba.downSample` does not meet the need
(cf. §4.3).

#### 6.3 Fast / partitioned convolution

`fi.conv(kv)` and `fi.convN(N,kv)` are **direct-form FIRs**, at O(N) operations
per sample:

```faust
convN(N,kv) = sum(i,N, @(i)*ba.take(i+1,kv));
```

For a typical room impulse response (1 to 3 s, i.e. 48,000–144,000 coefficients),
this is unusable in real time. **There is no block convolution, no zero-latency
partitioned convolution (Gardner), and no overlap-save.**

Consequences: **no convolution reverb, no IR cabinet emulation, no HRIR-based
binaural rendering** — three of the most requested uses in applied audio. The
repository offers 15 algorithmic reverbs, which makes the contrast all the more
visible.

#### 6.4 Sample rate conversion

**Missing.** `interpolators.lib` (1,110 lines: Lagrange, Catmull-Rom splines,
B-splines, cubic/cosine interpolation) mentions resampling in its header but
exposes no converter: no arbitrary-ratio SRC, no polyphase filter, no
windowed-sinc interpolation. `ba.downSample` is a sample-and-hold. Variable-speed
file playback (`so.loop_speed`) performs no anti-aliasing filtering.

### P1 — Important gaps

#### 6.5 Normalised loudness measurement

**Missing: LUFS, EBU R128 / ITU-R BS.1770, K-weighting, absolute and relative
gating (−70 LUFS / −10 LU), LRA, inter-sample true peak (ISP, 4× oversampled).**

`compressors.lib` is one of the most accomplished libraries (1,543 lines,
feed-forward/feedback compressors, expanders, lookahead limiters), and
`an.amp_follower_*` provides RMS and peak detectors. But nothing measures loudness
**to the standard** — which is a regulatory requirement for any broadcast or
streaming delivery. The contrast between the maturity of the dynamics processing
and the complete absence of normalised metering is striking.

Contrary to what one might assume, **this gap is not blocked by the absence of
oversampling** (6.2): the standardised 4× interpolator reduces to 4 FIR phases
evaluated in parallel, which is strictly monorate. See §7.3.

#### 6.6 Dither and noise shaping

**Missing: TPDF/RPDF dither, flat or psychoacoustically weighted noise shaping,
requantisation.**

`noises.lib` provides 23 generators (white, pink, brown, velvet, Gaussian,
multi-noise) but no bit-depth reduction facility. `ba.bitcrusher` exists as a
creative effect, not as correct requantisation. Any chain ending in 16 bits needs
this.

#### 6.7 High-quality pitch shifting and time stretching

The only primitive is `ef.transpose(w, x, s, sig)`: two crossfaded delay lines.
This is the historical algorithm — comb artefacts and a "flutter" effect on
pronounced transpositions.

**Missing: phase vocoder, PSOLA/TD-PSOLA, phase locking (identity/scaled),
pitch-independent time stretching, formant preservation.** `ef.doppler_shift`
addresses a different need. `ve.vocoder` is a filterbank vocoder (an effect), not
a phase vocoder.

#### 6.8 Robust pitch detection

`an.pitchTracker(N, tau)` relies on the **zero-crossing rate** with lowpass
filtering — sensitive to noise and to dominant harmonics, and unusable on
polyphonic or rich signals.

**Missing: autocorrelation, YIN, average magnitude difference (AMDF), MPM
(McLeod), harmonic product spectrum, f0 tracking with a confidence measure.**
Required for tuning, pitch correction, voice-driven synthesis and MIDI extraction.

#### 6.9 Analysis descriptors (MIR) and onset detection

The spectral centroid exists only in `debug.lib` (`probe_spectral_centroid_impl`,
undocumented, debugging-oriented), and onset detection likewise
(`probe_onset_impl`).

**Missing from the public API: spectral flux, roll-off, flatness (Wiener
entropy), spread, skewness, kurtosis, MFCC, chroma, onset detection functions
(HFC, complex domain, spectral difference), tempo detection.**

These descriptors underpin adaptive audio, segmentation and embedded
classification.

#### 6.10 Binaural / HRTF rendering

**Missing.** `hoa.lib` (1,364 lines) covers ambisonics up to 3rd order in 3D with
encoders, decoders, rotations and optimisations (in-phase, max-rE), and
`spats.lib` provides a constant-power panner, WFS, SPCAP and
`ho.circularScaledVBAP` (2D circular VBAP only).

But there is **no binaural decoding**: no HRIR convolution, no virtual ambisonic
decoder to headphones, no spherical head model, no parametric ITD/ILD. This is
today the dominant listening mode for spatialised content.

Unlike convolution reverb, **this gap does not depend on 6.3**: HRIRs are 128 to
256 coefficients, a length at which direct FIR convolution is perfectly viable in
monorate. See §7.3.

3D VBAP (loudspeaker triplets) and DBAP are also missing.

#### 6.11 Adaptive filtering

`filters.lib` contains a **Kalman** filter (`fi.kalman`, `fi.kalmanEnv`).
**Missing: LMS, NLMS, recursive least squares (RLS), frequency-domain LMS,
acoustic echo cancellation, adaptive equalisation, adaptive feedback
suppression.** `an.pitchTracker` and `an.adaptive*` perform adaptive analysis, not
adaptive filtering.

*Note: `faust-rs` covers this ground via `rad`/`fad` and `optimizers.lib`
(LMS/FxLMS, adaptive notch). Those primitives are not available in upstream Faust,
so the gap remains real for the standard libraries.*

#### 6.12 FIR filter design

`filters.lib` is very rich in analytically designed IIRs (Butterworth, Cauer
elliptic, Linkwitz-Riley, parametric equalisers, Mth-octave filterbanks). On the
FIR side: only `fi.fir(bv)`, which **applies** coefficients supplied by the user.

**Missing: window-method design, Parks-McClellan/Remez, least squares, linear
phase FIR, FIR Hilbert transform, differentiators, half-band filters** (the last
being the building block of oversampling, cf. 6.2). `fi.highpass_plus_lowpass` and
its relatives cover perfect reconstruction in IIR only.

**`fi.hilbert` does not exist either**: the documentation of `fi.pospass`
(`filters.lib:2931-2936`) gives the complete definition inside a code block, yet
the symbol is defined nowhere (`grep -rn '^hilbert' *.lib` returns nothing). One
line to write, already written — cf. §7.2.

### P2 — Desirable gaps

#### 6.13 Control and sequencing utilities

- **Slew rate limiter**: exists only as a debugging probe (`probe_slew_impl`), not
  as a public function.
- **Portamento / glide**: only inside `demos.lib`, not reusable.
- **Step sequencer, arpeggiator, musical clock**: entirely missing. `ba.beat`,
  `ba.tempo`, `ba.pulse` provide the timing blocks, but nothing above them.
- **Arbitrary multi-segment envelope generator**: `envelopes.lib` offers
  ADSR/AR/ASR/exponentials; no list-driven breakpoint envelope.

#### 6.14 Tuning systems and microtonality

`quantizers.lib` (v1.1.2) contains **15 hard-coded scales** (Ionian, Dorian,
Phrygian, Lydian, Mixolydian, Aeolian, Locrian, pentatonic, dodecaphonic,
diminished…), all in 12-tone equal temperament.

**Missing: generic N-EDO, just intonation, historical temperaments (Pythagorean,
meantone, Werckmeister), Scala `.scl`/`.kbm` file import, configurable reference
frequency, arbitrary cents.** A recurring request from the composition community.

Also worth noting: `old-quantizers.lib` and `new-quantizers.lib` sit at the root
(untracked by git) alongside `quantizers.lib` — the transition appears unfinished.

#### 6.15 Sample playback

`soundfiles.lib` (270 lines) exposes only **3 documented functions**: `so.loop`,
`so.loop_speed`, `so.loop_speed_level`.

**Missing: granular synthesis, multisample playback with velocity zones and key
mapping, crossfaded loop points, reverse playback, scrubbing, file time
stretching.** The word "granular" appears only in a comment in
`interpolators.lib`. This is well below the general standard of the repository.

#### 6.16 Restoration and corrective processing

**Missing: de-esser, spectral denoising / spectral gate, declicking, decrackling,
bandwidth restoration (psychoacoustic exciter), DC correction with phase
compensation, mains hum removal (adaptive harmonic notch).** `fi.dcblocker`
covers the DC case alone.

#### 6.17 Mid/side processing

`ef.stereo_width` (Blumlein shuffling) exists and is well documented. But there is
**no explicit M/S encode/decode pair** allowing arbitrary processing to be
inserted in the M/S domain — a basic mastering pattern (M/S compression, M/S EQ,
frequency-dependent widening).

### Gap summary

The last column gives monorate feasibility in Faust, detailed in §7:
**A** = directly writable, **B** = writable via a specific monorate algorithm,
**C** = requires the multirate extension.

| # | Topic | Priority | State | Blocks | Mono |
|---|---|---|---|---|---|
| 6.1 | Window functions | **P0** | Missing | Spectral processing, grains, FIR | **A** |
| 6.1 | Sliding spectral analysis (SDFT) | **P0** | `goertzel` only | — | **B** |
| 6.1 | Frame-based STFT | **P0** | Missing | Phase vocoder | **C** |
| 6.2 | Oversampling / multirate | **P0** | Missing | Quality nonlinearities | **C** |
| 6.3 | Partitioned convolution | **P0** | Direct O(N) | Convolution reverb, IR cabinet | **C** |
| 6.3 | Velvet-noise convolution | **P0** | Missing | — | **B** |
| 6.4 | Sample rate conversion | **P0** | Missing | — | **C** |
| 6.4 | Anti-aliased variable-speed playback | **P0** | Aliases | Clean sampler | **B** |
| 6.5 | LUFS / EBU R128 / true peak | P1 | Missing | Broadcast compliance | **B** |
| 6.6 | Dither / noise shaping | P1 | Missing | Correct 16-bit output | **A** |
| 6.7 | Improved granular pitch shifting | P1 | 2 taps | — | **B** |
| 6.7 | Phase vocoder / time stretch | P1 | Missing | Independent stretching | **C** |
| 6.8 | Pitch detection | P1 | ZCR only | Tuning, correction | **B** |
| 6.9 | MIR descriptors / onsets | P1 | In `debug.lib` | Adaptive audio | **B** |
| 6.10 | Binaural / HRTF | P1 | Missing | Headphone listening | **B** |
| 6.11 | Adaptive filtering (LMS/NLMS) | P1 | Kalman only | Echo cancellation | **B** |
| 6.12 | Window-method FIR design | P1 | Application only | Half-band filters | **A** |
| 6.12 | Parks-McClellan / Remez | P1 | Missing | — | **C** |
| — | `fi.hilbert` | P1 | Documented, undefined | Frequency shifting | **A** |
| 6.13 | Sequencing / control | P2 | Partial | — | **A** |
| 6.14 | Tuning / microtonality | P2 | 15 scales, 12-TET | Microtonal composition | **A** |
| 6.15 | Sample playback / granular | P2 | 3 functions | Sample-based instruments | **B** |
| 6.16 | Restoration | P2 | `dcblocker` only | — | **A**/**B** |
| 6.17 | M/S encode/decode | P2 | `stereo_width` only | M/S mastering | **A** |

---

## 7. What can reasonably be written in monorate Faust

Not all the gaps in §6 are equivalent: some are blocked by the language's
execution model, others are not blocked at all and are simply waiting for someone
to write them. This section sorts the 17 topics by that criterion.

### 7.1 The criterion used

"Monorate" = one input sample produces one output sample per cycle, with no block
processing and no clock rate change. Available, therefore:

- the `~` recursion (one-sample-delay state, feedback loops);
- `rdtable` / `rwtable` / `waveform` / `soundfile` (indexable memory, including
  writable — `rwtable` is currently used only in `basics.lib` and
  `interpolators.lib`);
- compile-time unrolling (`par`, `seq`, `sum`, `prod`) and constant folding, which
  allow arbitrarily complex coefficients to be precomputed at no runtime cost;
- `ba.tabulate` / `ba.tabulateNd` to tabulate any pure function.

Unavailable: framing and hop, any rate change, and any compile-time iteration
whose trip count depends on the data.

**The key point**: for several of the gaps in §6, the "DSP textbook" version is
block-based, but **an equivalent or sufficient monorate formulation exists** and
must be sought deliberately. This is the case for true peak, spectral descriptors,
binaural and sliding spectral analysis.

### 7.2 Category A — directly writable, low effort

Nothing stands in the way; it is pure arithmetic or a one-sample recursion. These
are the highest-return items in the repository.

| Gap | Monorate formulation | Note |
|---|---|---|
| **6.1a Window functions** | `w(N,i)` = sum of cosines of a normalised index | Hann, Hamming, Blackman, Blackman-Harris, Bartlett, Nuttall, flat-top, Tukey: pure arithmetic. Usable in indexed form (table filling) **and** in signal form driven by a phasor (grains, crossfades). |
| **6.6 Dither + noise shaping** | TPDF = sum of two independent `no.noise`; shaping = one-sample error feedback loop | A textbook case of Faust recursion. The psychoacoustic curves (Lipshitz, Shibata…) are constant coefficient sets. |
| **6.13 Control / sequencing** | Slew limiter, portamento, step sequencer, arpeggiator, breakpoint envelopes | Purely monorate. The timing blocks (`ba.beat`, `ba.tempo`, `ba.pulse`) already exist. |
| **6.17 M/S encode/decode** | `(l+r)/2, (l-r)/2` and its inverse | One line each. |
| **6.16a De-esser** | Sidechain bandpass + existing compressor | All the pieces are already in `compressors.lib` and `filters.lib`. |
| **6.14 Tuning / microtonality** | Constant tables + arithmetic | N-EDO, just intonation, historical temperaments. Only Scala `.scl` file import falls outside the language. |
| **6.12a Window-method FIR design** | `h[n] = ideal[n] × w[n]`, entirely constant-folded | Depends on 6.1a. No runtime cost. |

**Special case — `fi.hilbert` does not exist.** The documentation of `fi.pospass`
(`filters.lib:2931-2936`) gives the definition, verbatim, inside a code block:

```faust
// An approximation to the Hilbert transform is given by the
// imaginary output signal:
//
// ```
// hilbert(N) = pospass(N) : !,*(2);
// ```
```

…yet `hilbert` is **defined nowhere** in the repository (`grep -rn '^hilbert' *.lib`
returns nothing). A Hilbert transform unlocks single-sideband frequency shifting,
analytic envelope detection and instantaneous phase tracking. It is one line to
write, already written.

**A caveat on the Kaiser window.** It requires the **modified** Bessel function
I₀. `maths.lib` provides `ma.J0`, `ma.J1`, `ma.Jn` — but these are Bessel
functions of the **first kind** (J), not the modified ones (I), and they are
`ffunction` bindings to `j0()` from `<math.h>`, hence unavailable on backends
without libm (WASM in particular). I₀ must therefore be written as a series
expansion; for a constant β it folds entirely at compile time, at no runtime cost.

### 7.3 Category B — writable, but requiring a different monorate algorithm

Here the block-based version is out of reach, but a monorate formulation gives an
equivalent or sufficient result. This is the category that calls for a design
decision, not merely writing effort.

#### 6.5 LUFS / EBU R128 — largely feasible, true peak included

- **K-weighting**: two biquads (shelf + highpass), directly `fi.high_shelf` /
  `fi.tf2s`. Trivial.
- **Momentary (400 ms) and short-term (3 s)**: sliding mean square, a monorate
  recursion. Trivial.
- **Integrated with gating**: the 400 ms blocks at 75% overlap are realised as
  **4 phase-staggered rectangular integrators in parallel** — monorate.
- **True peak (ISP)**: this is the counter-intuitive point. ITU-R BS.1770
  specifies a precise 4× polyphase interpolator; **it is not necessary to run at
  4× to apply it** — it suffices to evaluate the **4 FIR phases in parallel** at
  each input sample and take the maximum. This is strictly monorate. §6.2
  wrongly concludes that true peak is blocked by the absence of oversampling: it
  is not.
- **LRA**: requires percentiles over the whole programme → a fixed-bin histogram
  in an `rwtable`, monorate but heavier.

**This is the best candidate in the repository**: high value (broadcast
compliance), near-complete feasibility, and strong complementarity with the
already mature `compressors.lib`.

#### 6.9 MIR descriptors — via the existing filterbanks, not via the FFT

Centroid, spread, flux, roll-off and flatness can be computed just as well from
**band energies** as from an FFT spectrum. And `an.mth_octave_spectral_level` and
the `an.*_octave_analyzer` filterbanks already provide those energies, in
monorate. Onset detection follows (band flux + adaptive threshold). Even **MFCCs**
are within reach: a monorate mel filterbank followed by a DCT over ~40 bands, i.e.
a constant-coefficient matrix product unrolled at compile time. An expensive but
entirely monorate approach — and one that **reuses what already exists** rather
than waiting for the STFT.

#### 6.10 Binaural / HRTF — the §6.3 verdict is too pessimistic here

HRIRs are **short**: 128 to 256 coefficients per ear. A direct FIR convolution
therefore costs ~2×256 MACs per sample — entirely reasonable in monorate, with no
need for partitioned convolution at all. Add to this:

- the parametric route (ITD via fractional delay + ILD via a shelving filter),
  trivial in monorate;
- ambisonic-to-binaural decoding via virtual loudspeakers + HRIR, which plugs
  straight into `hoa.lib`.

In other words, the absence of fast convolution blocks convolution reverb and IR
cabinets (§6.3), **but not binaural**.

#### 6.11 LMS / NLMS — no automatic differentiation required

For a linear FIR, the gradient is exactly the delayed input vector:
`w[k] += μ·e·x[n−k]`. These are N parallel one-sample-delay recursions — the most
canonical monorate pattern there is. NLMS adds normalisation by the running power
(a recursive sliding sum). Entirely feasible **without `rad`/`fad`**: the
`faust-rs` AD work is useful for nonlinear cases, but LMS/NLMS/FxLMS do not need
it. RLS requires a matrix update, which is heavier, but `linearalgebra.lib`
provides the primitives.

#### Other category B items

| Gap | Monorate formulation adopted |
|---|---|
| **6.1b Spectral analysis** | **Sliding DFT (SDFT)**: recursive update at O(1) per bin per sample, spectrum available at every sample, no framing. `an.goertzel` is already the single-bin case. Requires the guaranteed-stable variant (modulated SDFT) to avoid the accumulation drift of the naive version. This is **the** monorate answer to spectral analysis. |
| **6.3b Convolution reverb** | **Velvet noise** convolution (sparse FIR) for the late field — monorate and inexpensive. `no.velvet_noise` already exists (undocumented, `noises.lib:539`). It does not replace a measured IR, but covers the main use case. |
| **6.4b Variable-speed playback** | A windowed-sinc kernel whose bandwidth tracks the playback ratio: one output sample per cycle, table read at a fractional position. Fixes the aliasing of `so.loop_speed` without any rate conversion. |
| **6.7b Pitch shifting** | A granular shifter with 3–4 overlapping windowed taps (instead of the 2 taps in `ef.transpose`). Markedly better, monorate, depends on 6.1a. |
| **6.8b Pitch detection** | A PLL and an adaptive notch filter (ANF) are the natural monorate estimators. Autocorrelation and AMDF remain expressible with recursive sliding sums, at O(L) per sample — heavy for low f0 (L ≈ 1000) but real. |
| **6.15 Granular / sampler** | Overlapping table readers with independent phasors + windows. One of the most idiomatic monorate patterns in Faust. Depends on 6.1a. |
| **6.16b Denoising** | A multiband expander on a filterbank, instead of an FFT spectral gate. |

### 7.4 Category C — out of reach for monorate

| Gap | Reason |
|---|---|
| **6.2 Oversampling / multirate** | By definition. Note: `aanl.lib` (ADAA) and the antialiased oscillators exist precisely **as monorate substitutes**. Computing half-band filter coefficients is itself monorate — it is the rate change that is not. |
| **6.1c Frame-based STFT** | Framing, hop and overlap-add presuppose a frame rate. |
| **6.3a Partitioned convolution** | Presupposes a block FFT. Remains blocking for long room IRs (48,000–144,000 coefficients) and cabinet IRs. |
| **6.4a Sample rate conversion** | Output rate ≠ input rate. |
| **6.7a Phase vocoder, time stretching** | Presupposes the STFT (6.1c). |
| **6.12b Parks-McClellan / Remez** | An iterative exchange algorithm with data-dependent control flow: not expressible within Faust's constant folding. |

These six points are the ones — and the only ones — that justify the multirate
extension. They coincide exactly with the scope of the clock-domain and
`fft_framed` work in `faust-rs`
(`porting/ondemand-vec-fad-interleave-synthesis-2026-07-07-fr.md`).

### 7.5 Consequence for priorities

§6 ranked by DSP importance. Crossed with feasibility, the order of attack
becomes:

1. **Window functions (6.1a)** — minimal effort, unblocks 6.7b, 6.12a, 6.15 and
   finally makes the existing FFT usable.
2. **`fi.hilbert`** — one line, already written in the documentation.
3. **Dither / noise shaping (6.6)** and **M/S (6.17)** — minimal effort, immediate
   value.
4. **LUFS / R128 + true peak (6.5)** — the best value-to-feasibility ratio in the
   repository, and not blocked, contrary to what §6 implied.
5. **LMS / NLMS (6.11)** and **filterbank-based MIR descriptors (6.9)** — feasible
   today, reusing what exists.
6. **Parametric binaural + HRIR by direct FIR (6.10)** — feasible without fast
   convolution.
7. **Granular (6.15)** and **improved pitch shifter (6.7b)** — after the windows.
8. **Sliding DFT (6.1b)** — the real monorate answer to spectral analysis, to be
   pursued alongside the multirate extension rather than while waiting for it.

Only the six category C items must wait for multirate. **Eleven of the seventeen
gaps are writable today**, the first four of them in a few hours each.

---

## 8. Recommendations, in order of return

### Immediate — restore the ability to detect anything (cost: a few hours)

1. Add `sys.exit(1 if diff_found else 0)` to `scripts/floatdiff.py`.
2. Add `exit 1` to the `[fail]` branch of the `Makefile`, and remove the `exit 0`
   that masks build failures.
3. Remove `$(REFERENCE_DIR)` from the `clean` target (or introduce a separate
   `distclean`).
4. Version `tests/reference/`, regenerated with `NUM_SAMPLES`/`SAMPLE_RATE`/
   `FAUST_OPT` frozen and documented in the file.
5. Add a CI workflow running `make check` on every PR.

*Without these five points, every other improvement rests on an unverifiable base.*

### Short term — documentation (cost: a few days)

6. Document the `analyzers.lib` FFT subsystem (§3.1), starting with the complex
   representation convention.
7. Complete the 15 blocks reduced to a `#### Test` and the 28 blocks without a
   `#### Usage` (§3.3, §3.4).
8. **Generate** `standardFunctions.md` from the source markers, and add a CI check
   (§3.5).
9. Normalise licenses to SPDX identifiers + CI validation; extend coverage beyond
   31% or explicitly document the inheritance rule (§3.6).
10. Add pages for `tubes.lib` and `tonestacks.lib`, or explicitly declare them out
    of standard scope in `organization.md` (§3.2).
11. Mark the 18 deprecated `delay1s`/`time1s`/`echo1s`… functions and document
    that their names denote powers of two, not seconds (§4.2). Fix the
    `ba.downSample` documentation (§4.3).

### Medium term — filling the gaps that are writable today

Order derived from importance × monorate feasibility (§7.5). **None of these
points waits for the multirate extension.**

12. `an.window*`: a window family (Hann, Hamming, Blackman, Blackman-Harris,
    Bartlett, Nuttall, flat-top, Tukey; Kaiser via a series for I₀, `ma.J0` being
    neither the right function nor portable). Self-contained, pure arithmetic,
    unblocks 6.7b, 6.12a, 6.15 and finally makes the existing FFT usable.
13. Define `fi.hilbert` — one line, already written in the `fi.pospass`
    documentation (§6.12).
14. `dither` + noise shaping, and the M/S encode/decode pair. Minimal effort,
    immediate value.
15. Normalised loudness: K-weighting, momentary / short-term / integrated LUFS
    with gating, and **true peak via 4 parallel FIR phases** — all monorate. The
    best value-to-feasibility ratio in the repository (§7.3).
16. LMS / NLMS (parallel weight recursions, no AD), then MIR descriptors computed
    on the existing filterbanks rather than on an FFT.
17. Binaural: the parametric route (ITD/ILD) and HRIR by direct FIR — HRIRs are
    short enough not to depend on partitioned convolution (§7.3).
18. Granular synthesis and a windowed overlapping-tap pitch shifter, once 12 is in
    place.

### Medium/long term — what genuinely requires multirate

Six points only (category C of §7.4):

19. Half-band filters + `oversample(N, f)` / `upsample` / anti-aliased
    `downsample` — determines the quality of `aanl.lib`, `vaeffects.lib`,
    `tubes.lib`.
20. An STFT framework (framing, overlap, overlap-add) — to be articulated with the
    `fft_framed` work in `faust-rs` (P3/P4). In the meantime, a guaranteed-stable
    **sliding DFT** provides usable monorate spectral analysis (§7.3).
21. Partitioned convolution, once 20 is available; unblocks convolution reverb and
    cabinet IRs — but not binaural, which does not depend on it.
22. Sample rate conversion, phase vocoder and time stretching. Parks-McClellan
    remains out of the language's reach independently of multirate.

### Structural

23. A `CONTRIBUTING.md` fixing: the naming convention per library, the mandatory
    documentation block format (description + `#### Usage` + `Where:` +
    `#### Test`), a mandatory SPDX identifier, and a regression test requirement
    for every new function.
24. A documentation checker run in CI, by extending `scripts/audit2.py` (already
    provided), rejecting any new undocumented symbol or any block reduced to a
    `#### Test` section.
25. A prefix convention (`_name`) or a sub-environment for internal symbols —
    `debug.lib` (34 `probe_*_impl`) and `routes.lib` (28 bitonic sorting symbols)
    show the need.

---

## 9. Could these libraries become a reference corpus?

Worth stating explicitly, because the answer changes how several of the findings
above should be ranked: could the Faust libraries occupy, for audio DSP, the
position mathlib occupies for mathematics?

### 9.1 Where the analogy holds

Faust has something no other DSP ecosystem has: **a real denotational semantics**.
A Faust program *is* a function over signals ℤ→ℝ, and the five composition
operators form an algebra. That is not a metaphor — it is what makes the compiler
possible, and it is the same kind of foundation mathlib is built on. SciPy, JUCE
and the DAFx book code are collections of functions in a general-purpose language;
there is nothing there to reason over.

Two further mathlib-like properties genuinely hold: a single repository checked by
a single tool (§2 — all 43 libraries parse under one compiler), and one source
projecting to C++, LLVM, WASM and Rust. The source is the artefact.

And for one sub-domain it is already partly true: `filters.lib` largely encodes
Julius Smith's online books. When someone asks for "the" Butterworth or "the" zita
reverb, the answer is already, in practice, here.

### 9.2 Where it breaks structurally

**There is no kernel.** mathlib asserts "this proof is correct", and a small kernel
decides it. What do these libraries assert? That `fi.lowpass(3, 1000)` *is* a
third-order Butterworth lowpass at 1 kHz — and **nothing checks that claim**. The
type system checks arity and rates, not DSP semantics. The name is a promise kept
by human vigilance alone.

§5 showed that even the weak check — numerical non-regression — is inoperative. A
reference library whose tests always pass is not a reference.

And even once repaired, that check would remain **tautological**: the `.ref` files
are generated from the very code they are meant to validate. Lean's kernel is
*independent* of the theorem it checks. That is the whole difference.

**Deduplication is the wrong move here.** mathlib fights for *the* right definition
and refactors globally. A DSP corpus must do the opposite: the 30 VA topologies in
`vaeffects.lib` and the 15 reverbs are not redundancy to be eliminated, they *are*
the content. They trade off differently between CPU, latency, artefacts and
character. "Better" is not a theorem here.

**Floating point.** mathlib works over ℝ exactly. Here the same source yields
bit-different results across backends and flags — §5.4 found references produced at
a different `NUM_SAMPLES` passing silently, a class of drift ℝ simply does not have.

**Perceptual acceptance.** Whether a reverb is good is partly psychoacoustic. No
kernel decides that.

### 9.3 The achievable form

Not "mathlib for DSP" in the strong sense, but something real that nothing
currently occupies: **the executable, composable, multi-target reference corpus
with machine-checked properties**.

The missing brick is not proof, it is **specification**. The 1,028 documentation
blocks say in prose what functions do; none states a checkable property. Becoming a
reference means writing, alongside `fi.lowpass`, something like: −3 dB at fc within
±0.1 dB, 6N dB/oct rolloff, all poles inside the unit circle — and making CI fail
when it is false. An **analytic** oracle, derived from the theory, not from the code.

This is exactly the producer / independent-checker / rejecting-mutation discipline:
the independence of the checker is the kernel's role transposed to DSP.

**Where Lean genuinely applies.** Not to proving that a reverb sounds good, but to
the statements that *are* theorems over the signal algebra: stability of a structure
under coefficient constraints, **equivalence of two block-diagram expressions**
(which would validate compiler rewrites and library refactorings at once),
convergence of first-order ADAA to the ideal nonlinearity, waveguide identities.
The `faust-rs` Lean work targets the compiler; the same semantics would carry
library-level statements.

### 9.4 How this re-ranks the findings above

This is the operationally useful part. Read as ordinary quality review, three
findings are tidiness. Under the reference-corpus ambition, they become **blocking**:

- **§4.1 naming conventions** (367 snake_case vs 382 camelCase, 17 libraries mixing
  both) and **§3.5 `standardFunctions.md` drift**. mathlib's discoverability rests
  on naming conventions strict enough to be mechanically derivable from the
  statement. A corpus where one hesitates between `ba.sec2samp` and `ba.sAndH`
  cannot be cited as an authority.
- **§3.6 license metadata** (16 spellings, 31% coverage). mathlib is uniformly
  Apache 2.0. A corpus that industry depends on cannot carry legal traceability in
  this state.

Conversely, one finding softens: the plurality of algorithms — and part of the
duplication noted in §4.2 — is not a defect under this reading, provided each
variant documents the trade-off it makes.

### 9.5 Order of work

The sequence is constrained and does not admit reordering:

1. `make check` must be able to fail (§8, items 1–5). Until then, everything else
   is decorative.
2. Independent analytic oracles replacing self-generated references — one
   specification per function, starting where the theory is sharpest (`filters.lib`).
3. Formal statements in Lean over the signal algebra, for the properties that are
   genuinely theorems.

Lean is step 3. Starting there would be building the roof first.

---

## 10. Testing DSP properties with Lean

§9.5 places formal statements third, after a harness that can fail and after
independent analytic oracles. This section makes that third step concrete: what
can actually be stated, at what cost, and how it attaches to a `.lib` file.

It builds on the existing `faust-rs` formalization (`docs/lean-usage-methodology-en.md`
and the four `porting/*-formal-spec.lean` files), whose house rules are adopted
unchanged: Lean 4.31 with the bundled `Std` only, no `mathlib`, no `sorry`, no
axioms beyond the standard three, `Prop` judgment + `Bool` checker + a theorem
binding them, names ending in `B` returning `Bool`.

Note that those four specifications deliberately stop short of signal semantics —
`bda-typing-formal-spec.lean` states that `Box` is "an arity skeleton, not a shadow
AST". Library properties are therefore new territory, not an extension of existing
files.

### 10.1 Three tiers of properties

The instinct is to aim at "prove `fi.lowpass` is a Butterworth", which needs real
analysis, complex numbers and the z-transform — hence mathlib, hence a break with
the Std-only rule. But many genuinely useful DSP properties are not analytic.

**Tier 1 — structural and arithmetic (Std only, current house style unchanged)**

- index bounds on delay lines and `rwtable`: `de.fdelay(maxdel, d)` never reads out
  of range for `d ∈ [0, maxdel]`;
- correctness of coefficient recurrences (Butterworth, Chebyshev) as exact arithmetic;
- structural identities between block-diagram expressions — the same activity as
  `normalization-rewrites-formal-spec.lean`, applied to library-level identities;
- **finite-form stability criteria**: Jury/Schur-Cohn, and `|reflection coefficient| < 1`
  for lattice forms, are finite arithmetic tests, not root-finding.

**Tier 2 — algebraic identities over rational functions**

Several analytic-*looking* properties are in fact polynomial identities. "Allpass"
is `H(z)·H(1/z) = 1`. "Perfect reconstruction" is `H_lp(z) + H_hp(z) = z⁻ᵏ`.
Power complementarity likewise. Stated that way they leave analysis for decidable
algebra.

**Tier 3 — analytic (mathlib required)**

Frequency response in dB, "−3 dB at fc", ADAA convergence. Best treated as a
separate, opt-in stream: mathlib costs build time and version churn, and review
capacity is the scarce resource.

### 10.2 A kernel-checked pilot: `fi.tf2s` preserves stability

`fi.tf2s` is the bilinear transform of an analog section, and most of `filters.lib`
is built on it:

```faust
c   = 1/tan(w1*0.5/ma.SR);
d   = a0 + a1 * c + csq;
a1d = 2 * (a0 - csq)/d;
a2d = (a0 - a1*c + csq)/d;
```

The `tan` looks disqualifying. It is not: **`c` enters the stability argument only
through its sign.** Below Nyquist, `c > 0`, and that is all the proof needs — so
the transcendental is never modelled, and the statement becomes exact rational
arithmetic. Keeping the section over a common denominator clears every division:

```lean
structure Section where
  n1 : Rat
  n2 : Rat
  d  : Rat

/-- Jury / Schur-Cohn criterion at order 2, cleared of denominators. -/
def JuryStable (s : Section) : Prop :=
  0 < s.d ∧ 0 < s.d + s.n2 ∧ 0 < s.d - s.n2 ∧
  0 < s.d + s.n2 - s.n1 ∧ 0 < s.d + s.n2 + s.n1

/-- The `fi.tf2s` denominator mapping; `c` is opaque, only `0 < c` is used. -/
def tf2sDen (a0 a1 c : Rat) : Section :=
  { n1 := 2 * (a0 - c * c)
    n2 := a0 - a1 * c + c * c
    d  := a0 + a1 * c + c * c }

theorem tf2s_preserves_stability (a0 a1 c : Rat)
    (ha0 : 0 < a0) (ha1 : 0 < a1) (hc : 0 < c) :
    JuryStable (tf2sDen a0 a1 c) := by
  have hP : 0 < a1 * c := Rat.mul_pos ha1 hc
  have hQ : 0 < c * c := Rat.mul_pos hc hc
  refine ⟨?_, ?_, ?_, ?_, ?_⟩ <;> simp only [tf2sDen] <;> grind
```

`0 < a0` and `0 < a1` are exactly the Hurwitz conditions for the analog prototype
`s² + a1·s + a0`. The theorem therefore reads: **the bilinear transform maps a
stable analog second-order section to a Jury-stable digital one, at any sample rate
and any cutoff below Nyquist** — one theorem covering every `tf2s`-based filter in
the library.

The proof works because the five goals, after abstracting the products `a1·c` and
`c·c`, are *linear* in the atoms. They reduce to closed forms:
`d + n2 = 2a0 + 2c²`, `d − n2 = 2a1c`, `d + n2 − n1 = 4c²`, `d + n2 + n1 = 4a0`.

The complete file is `tf2s-stability-formal-spec.lean`, next to this report. It was
checked with Lean 4.31 and bundled `Std`: **exit 0 in 3.9 s, no `sorry`, axioms
limited to `propext`, `Classical.choice`, `Quot.sound`** — the same budget as the
existing `faust-rs` specifications.

```bash
lean tf2s-stability-formal-spec.lean
```

Two practical findings for whoever writes the next one:

- `Std`'s ordered-field API for `Rat` is thin — `Rat.mul_pos` exists, `Rat.add_pos`
  does not — but **`grind` closes linear rational goals**, which removes the need
  for a mathlib-grade `linarith`. This is what makes Tier 1 affordable.
- `decide` does not reduce through `Rat`'s decidability instances (it gets stuck on
  `Rat.instDecidableLt`). State and prove properties on the `Prop` side, and reach
  the `Bool` checker through the soundness theorem rather than by evaluation.

The classical equivalence "Jury criterion ⟺ roots inside the unit disc" stays a
**named obligation** — precisely the *obligation ledger* slot the methodology
already provides — provable later if the mathlib stream opens.

### 10.3 Binding Lean to the `.lib`

Lean knows nothing about `filters.lib`. Three architectures:

| | Approach | Cost | Weakness |
|---|---|---|---|
| **A** | Model by hand in Lean; the executable checker is the reference oracle the Faust code is tested against on fixtures | Low; *is* the existing producer/checker pattern | The hand model can drift from the `.lib` |
| **B** | Import the compiled signal graph into Lean; properties bear on the graph actually produced | Higher | None structural — drift disappears |
| **C** | Write the DSP in Lean, extract to Faust | — | Unrealistic over an existing 53,000-line corpus |

B is the analogue of the roadmap's "S0 importer", and **`faust-rs` has an advantage
upstream Faust does not**: it already emits structural FIR dumps. A for the pilot,
B as the target.

### 10.4 What Lean does not replace

A distinction to hold firmly, or the exercise becomes self-deception:

- Lean proves that **the specified formula** has the intended property;
- the numerical test proves that **the `.lib` computes that formula**.

Neither is sufficient alone. This is why the ordering in §9.5 holds: Lean without a
harness that can fail would produce true theorems about code nobody checks.

### 10.5 A working prototype of the import path

§10.3 presented architecture B — importing the compiled signal graph — as the
target rather than the starting point. It turns out to be reachable now:

```
.dsp  →  faust-rs --dump-sig  →  parser  →  Lean Sig term  →  theorem … := by decide
```

**No change to `faust-rs` was required.** The `--dump-sig` flag already exists and
emits a clean S-expression (`SIGBINOP(op=add (+), …)`, `int(n)`,
`float_bits(0x…)`, `DEBRUIJNREC`, `DEBRUIJNREF`), which was the main unknown.

The prototype ships as:

| File | Role |
|---|---|
| `signal-import-formal-spec.lean` | Hand-written, reviewed prelude: the `Sig` inductive, the linear-recursion extractor, the Jury criterion, the standing obligations |
| `scripts/sig2lean.py` | Dump parser and Lean emitter; runs Lean once to read each verdict, then emits a `by decide` theorem pinning it |
| `tests/lean-examples/` | Five `.dsp` inputs and the generated `certified.lean` |

Results, all verdicts correct:

| DSP | extracted `a₁`, `a₂` | verdict |
|---|---|---|
| `+ ~ *(0.7)` | −0.7, 0 | stable |
| `fi.tf2(…, −1.2, 0.5)` | −1.2, 1/2 | stable |
| `fi.tf2(…, −0.5, −0.8)` | −1/2, −0.8 | not stable |
| `+ ~ *(1.5)` | −3/2, 0 | not stable |
| `+ ~ (*(0.9) : ma.tanh)` | — | refused: not linear |

The five theorems check in 4.2 s and **depend only on `propext`**.

#### What building it revealed

- **The recursion is not at the root.** The first design assumed the exported
  graph would be `SIGPROJ(0, SIGREC(…))`. `fi.tf2` — the first real library
  function tried — puts the `SIGREC` *below* the numerator, as
  `b₀w[n] + b₁w[n-1] + b₂w[n-2]`. The certifier must **search** for the
  recursion, not presume its position. A prototype exercised only on toy
  expressions would have looked correct.
- **`Rat` is unusable in a decidable checker.** Neither `decide` nor `grind` nor
  `rfl` reduces through `Rat.instDecidableLt` in Std 4.31. Coefficients are
  therefore carried as integer pairs — and since every IEEE-754 double is exactly
  `m/2ᵏ`, the import is **exact**, not approximate.
- **`deriving DecidableEq` does not apply to the nested inductive**
  (`opaqueN … (kids : List Sig)`), so the recursions found cannot be deduplicated
  structurally. Comparing their *analyses* instead is cheaper, and happens to be
  stronger: a verdict is accepted only when every recursion in the graph agrees.
- **Totality buys one-sided soundness.** Every unmodelled tag becomes `opaqueN`,
  which the analysis can never read as a linear term. Adding a tag can only widen
  what is accepted, never make it accept something wrong.

#### What it is not

The prototype implements architecture B's *import* but keeps architecture A's
adequacy gap: `feedbackOf` is asserted, not proved, to return the feedback
coefficients of the recursion it was handed. Proving that needs a denotation
`Sig → (ℕ → ℝ)`, hence mathlib, hence Tier 3 (§10.1). Until then the guarantee is
one-sided: the extractor returns `none` on anything it does not recognise exactly,
so a positive verdict never comes from a graph it misread.

It also handles only single-output recursions of order ≤ 2, and certifies the
**exact rationals** denoted by the exported coefficients — not the behaviour of
the filter as executed in floating point (§9.2).

### 10.6 A second analysis over the same import: index bounds

Stability is one property; the import path is worth more than one. The second
analysis added to the same prelude answers: **are table reads and delay taps
addressed within range?**

#### A hypothesis that did not survive contact

The analysis was motivated by an expected bug: a slider declared `0..100`
indexing a 16-entry table. That DSP does compile without a warning, and the
signal graph is a bare `SIGRDTBL(SIGWRTBL(int(16), …), SIGINTCAST(SIGHSLIDER(int(0))))`
with no bound in sight. But the generated C++ is

```cpp
float fSlow0 = ftbl0mydspSIG0[std::min<int>(((int)(((float)(fHslider0)))), 15)];
```

The backend inserts the clamp from the compiler's interval analysis of the
index — which draws on the slider's declared range. **There is no bug**, and the
safety of a Faust table read is in general *not* visible in the signal graph.

That reframes the analysis. It is not a bug finder; it is a **classifier**,
separating addressing sites whose safety follows from the graph alone from
those that delegate it to metadata the graph does not carry. Sites of the second
kind are reported as *not proven*, never as unsafe.

The distinction is real and falls along library lines: `delays.lib` writes its
clamp in Faust source, so `de.fdelay` is certifiable from the graph, whereas a
bare `rdtable` is not.

#### Results

| DSP | verdict |
|---|---|
| `de.fdelay(1024, hslider(…))` | `delay tap in [0, 1025] => BOUNDED` |
| `rdtable(16, 1.0, min(15, max(0, …)))` | `table[16] index in [0, 15] => IN RANGE` |
| `rdtable(16, 1.0, min(100, max(0, …)))` | `table[16] index in [0, 100] => OUT OF RANGE` |
| `rdtable(16, 1.0, int(hslider(…)))` | `not bounded by structure => not proven` |
| `os.osc(440)` | `table[65536] not bounded by structure => not proven` |
| `fi.tf2(…)` | `delay tap in [1, 1] … [2, 2] => BOUNDED` |

The third row is the rejecting witness: a clamp that is present but too wide is
caught. The fourth and fifth are the honest abstentions. 20 theorems across the
two analyses check in 4.3 s, depending only on `propext`.

#### Two Lean findings

- **`partial def` is invisible to the kernel.** The range function first descended
  into the children of an `opaqueN` list, which Lean does not accept as
  structurally decreasing on a nested inductive, so it was written `partial`.
  `#eval` then worked and `decide` did not. Recursion on an explicit fuel
  counter fixes it; running out of fuel yields the unknown range, which is the
  safe answer.
- **A range needs two independently optional sides.** With `Option (Int × Int)`,
  `max 0 x` — which bounds the low side and leaves the high side unknown —
  cannot be expressed, and a correct clamp was misreported as out of range.
  `{lo : Option Int, hi : Option Int}` with `min` meeting on the high side and
  joining on the low side (and dually for `max`) is the right lattice.

#### Where it stops

`os.osc` is bounded in reality by a `%` on a counter whose invariant is
`0 ≤ c < 65536`, but that invariant lives in a recursion the analysis does not
enter: proving it needs a fixpoint, not a walk. Certifying the remaining sites
would need the control table exported alongside the graph, since
`SIGHSLIDER(int(0))` carries an identifier and not its declared range — a minor
extension to `--dump-sig`, and the prerequisite for any interval-based analysis
(§10.1, tier 2).

---

## Appendix — reproducing the measurements

```bash
cd /Users/letz/Developpements/faustlibraries

# Check that every library parses
for f in *.lib; do b=${f%.lib}; printf 'process = 0; l = library("%s");\n' "$f" > /tmp/lt.dsp; \
  faust -I . /tmp/lt.dsp -o /dev/null || echo "FAILED: $f"; done

# Reproduce the test harness defect
make tests/output/dcblocker_test.out; echo "EXIT=$?"
./scripts/floatdiff.py tests/reference/dcblocker_test.ref tests/output/dcblocker_test.out 1e-5 > /dev/null; echo "floatdiff EXIT=$?"

# Confirm the absence of window functions
grep -rE '^\s*(hann|hamming|blackman|kaiser|tukey|bartlett|nuttall)[a-zA-Z0-9_]*\s*[(=]' *.lib

# fi.hilbert: documented inside fi.pospass but never defined
sed -n '2931,2936p' filters.lib   # the definition, in a comment
grep -rn '^hilbert' *.lib          # no match

# ma.J0 is an ffunction over j0(): Bessel of the 1st kind, not the modified I0
grep -n 'ffunction' maths.lib | grep -i 'j0\|j1\|jn'
```

### The Lean pilot

```bash
lean tf2s-stability-formal-spec.lean   # Lean 4.31, bundled Std; exit 0, ~4 s
```

The file ends with three `#print axioms` self-checks: the expected output names
only `propext`, `Classical.choice` and `Quot.sound`. Any `sorryAx` or
`Lean.ofReduceBool` in that output means the file no longer meets the house rule.

### Documentation coverage

The §2 table and the lists in §3.1, §3.3 and §3.4 are reproduced by
`scripts/audit2.py`, runnable from any directory:

```bash
scripts/audit2.py                    # table + the 15 blocks reduced to a #### Test
scripts/audit2.py /tmp/audit.json    # with a detailed JSON export
```

It accounts for the conventions actually in use: multi-function headers
(`` `(fi.)tf1`, `(fi.)tf2` and `(fi.)tf3` ``), generic patterns
(`` `(de.)fdelay[N]` ``) and exclusion of `library()` aliases — without which every
import (`ba`, `fi`, `ma`…) is counted as an undocumented symbol.

`scripts/audit.py` is the naive first version, kept for comparison: the gap
between the two outputs measures what the marker conventions cost a parser that
ignores them (for instance `filters.lib` at 79% instead of 96%, `delays.lib` at
16% instead of 57%).

### Unscripted measurements

The report's three other measurements — naming conventions (§4.1), license
normalisation (§3.6) and `standardFunctions.md` consistency (§3.5) — were obtained
with throwaway scripts that were not kept. They remain reproducible from the
definitions given in the corresponding sections; folding them into `audit2.py`
would turn it into a documentation checker usable in CI (cf. recommendation 24).
