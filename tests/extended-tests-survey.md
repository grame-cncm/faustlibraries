# Slider, modulated and jump tests outside filters.lib: survey

2026-10-02. Until now, only `filters.lib` had the extended tests of
`contributing.md` ("Constant, slider, modulated and jump tests"). Outside it,
there were two `tosc`/`tphase` tests in `oscillators.lib` and two
`_modulated_test` in `pinktrombone.lib`.

Every documented function of the other libraries was read: its doc block,
Usage, `Where:` list and implementation. Four parallel passes covered them,
and a few claims were checked with `faustprobe` and `check_precision.py`.
Nothing has been changed in the libraries yet.

Notation, as in `contributing.md`:
- `P = int(ma.SR/10)`;
- `tri = 1 - abs(2*ba.period(P)/P - 1)`, a 10 Hz triangle from 0 to 1;
- `sq = ba.period(2*P) < P`, a 5 Hz square;
- "exp a..b" means `a*pow(b/a, tri)`.

## 1. Bugs found on the way

Fix these first. Each fix comes with a test that the old code gets wrong.

| Function | Problem | Status |
|---|---|---|
| `it.interpolate_exponential` | NaN in single precision when `k` is 0, which is the natural default of a slider. The `1e-9` floor on `abs(k)` does not help in float, since `exp(1e-9) - 1` is 0 there. A floor around 1e-3, or a series expansion for small `abs(k)`, is needed. | **fixed** in eb4bebc0: Kahan's `expm1`, exact at k = 0 |
| `ef.wavefold` | Width 0 is inside the documented range [0, 1]. With a slider at 0 and `abs(x) > 1`, the output is NaN. With a constant 0, the code does not compile ("division by 0"). | **fixed** in 0ab3b798: at width 0 it clips at ±1 |
| `co.peak_expansion_gain_mono_db` and the other expander tests | With `range = +20`, `max(range)` forces a constant +20 dB gain whatever the input, so the tests do not test expansion. With `range = -20` the function expands. Either the tests or the doc of `range` needs a sign. A constant `knee = 0` also fails to compile here (`min(ma.EPSILON, knee*-2)`). | **fixed** in 0f039f3a: the sign of `range` is ignored, the knee guard is negative, and the tests now expand |
| `pm.fof`, `fofSH`, `fofSmooth`, `fofCycle` tests | The tests feed the process input, which the harness sets to zero, so fof outputs 0. The references only hold the added `os.tosc(110)*0.001`. They also pass `fc = 0.3` as the first argument, which looks like a swap. | **fixed** in 8cc9538b: the tests excite fof, whose filter is now two one-poles, accurate in float (five baseline entries removed) |
| `ef.gate_gain_mono` | The integer hold counter decrements forever and wraps after 2^31 samples (12.4 h at 48 kHz). | reported, not checked |
| `re.springreverb` | Its diffusion calls `de.delay(length, max)` with the two arguments swapped. The first taps are clamped. | reported, not checked |
| `os.oscs` | Blows up above SR/π, for example 15.3 kHz at 48 kHz (the magic circle needs `wn < 2`). Not documented. | reported, not checked |
| `pm.*Bell*`, `pm.marimba*` | `modesT60s` turns negative when `t60DecayRatio > 1`, so `pow` gives NaN with the default slopes. | reported, not checked |
| `dx` `lfo` triangle | The falling branch uses the old phase, so the output is one sample late and overshoots 1. | reported, not checked |
| `an.resonator` | The phase output (`atan2`) wraps at ±π. Float and double then differ by 2π at the wraps. | reported (probed) |
| `pm.bridgeFilter` | The doc of `absorption` is inverted: 1 gives 0 s, not 20 s. | reported, not checked |
| `sy.combString` | `maxDel = 1024` clamps the pitch below SR/1024 (188 Hz at 192 kHz), although its slider goes down to 55 Hz. `res` is documented as a T60 but is used as a time constant. | reported, not checked |
| `os.pulsetrainN`, `os.twin_osc`, `re.zita_in_delay`, `ef.doppler_shift` | Hard-coded maximum delays that clip their behavior at 176.4–192 kHz. | reported, not checked |

## 2. Tests that check little today

- **Feature never exercised.**
  - The `limiter_lad_*` tests never limit: a sine at 1 against a ceiling of 1.
  - The gate tests never close the gate.
  - `tapeStop_test` never stops: its `button` is at 0.
  - No compressor or expander test uses `prePost = 1`.
  - Every compressor test uses a steady sine, so release is hardly exercised.
- **Near-silent references.**
  - `dx` `env_test` peaks at 6.4e-5, and `operator_test` at 3.2e-5 (its L1..L4 are all 0).
  - `violin_ui_test` tests `violinModel`, not `violin_ui`.
- **No real constant test.** The `_test`s of `vaeffects.lib` and `synths.lib` already use unsmoothed `hslider`s: they are slider tests under the `_test` name. Choose between:
  - adding `_slider_test` copies;
  - converting the `_test`s to constants, which changes their references.
- **No test at all.**
  - `tonestacks.lib` has no Test section and no `tests/tonestacks_tests.dsp`.
  - `de.fdelay[N]` has no Test section.
  - Of the `fdelay[N]a`, only `fdelay2a` is tested.
  - In `motion.lib`, `motionEnvelope`, `envelopeAbs`, `envelopePos`, `envelopeNeg`, `pita3` and `totalEnvelope` have none.
- **Modulators that drift in float.** `pinktrombone.lib`'s two `_modulated_test` use `os.tosc` as their modulator, not the integer triangle.

## 3. Tooling and rule 8

**Fixed** in ab3dec00 (the cut doc blocks, all twelve of them, the genericNode tests and the stray section) and 1b3ba475 (`lib_tests.py inventory`: titles without prefix, generic `[N]` symbols, alias-prefixed and disabled tests). The JSON export leaves out tubes.lib, tonestacks.lib, instruments.lib and maxmsp.lib by design: it follows the libraries that stdfaust.lib imports, which these are not.

- **Doc blocks cut by an empty line that is not a comment.** The Test section, and possibly the Usage section, becomes invisible to `lib_tests.py`, to the documentation and to the JSON export (rule 7). Affected:
  - `de.delay`;
  - `ef.speakerbp`, `ef.echo`, `ef.tapeStop`, `ef.transpose`;
  - `ve.sallenKeyOnePole`;
  - `os.lf_imptrain`;
  - `ba.slidingRMS`;
  - `aanl.ADAA1`.
- **`scripts/lib_tests.py inventory` crashes** on `tubes.lib`, `tonestacks.lib` and `instruments.lib`, whose titles have no `(xx.)` prefix: `max()` of an empty sequence.
- **Other gaps:**
  - The generic `[N]` symbols (`fdelay[N]`) are not listed.
  - The `genericNode_Vout`/`Iout` tests sit inside `genericNode`'s block.
  - A stray `#### Test` in the oscillators section header repeats `sawNp_test`.

## 4. Where the extended tests belong

### 4.1 Likely to pass now (high value)

**vaeffects.lib**: TPT and ladder filters, modulated and jump tests.
- `moogLadder`, `moogHalfLadder`, `diodeLadder`, `korg35LPF`/`HPF`, `oberheim`, `sallenKeyOnePole`, `sallenKey2ndOrder`: normFreq `0.8*tri` (20 Hz–5 kHz), Q high (about 20, or 9.5 for korg35).
- `lowpassLadder4`: CF exp 20..5000, k = 3.9.
- `moog_vcf`: fr exp 50..5000, res 0.9.
- `moog_vcf_2bn`: protected normalized ladder.
- `klonCentaur`: gain `0.1 + 0.9*tri`, jump 0.1↔1. Its 50 ms ramp only runs when a control moves.
- `lowshelf2Matched`/`highshelf2Matched`: G crossing 1, where the `safeG` branch is almost 0/0. Measured: non-finite, even in double. Deferred, see 5.2.

**signals.lib, analyzers.lib**: the smoothers and followers everything else uses.
- `si.smooth`: slider, modulated (s 0.9..0.9999), jump.
- `si.onePoleSwitching`: att exp 0.001..1; probed, passes.
- `si.smoothq`: time 0.001..1, with a square target.
- `an.amp_follower`: rel exp 0.001..1, jump.
- `an.amp_follower_ud`: att.
- `an.resonator`: f exp 20..5000, magnitude only.
- Slider only: `an.pitchTracker`, `an.spectralCentroid` (t).

**delays.lib, phaflangers.lib, misceffects.lib**: fractional and moving delays.
- `de.fdelay`: slider and modulated d `16 + 112*tri`.
- `de.fdelaylti`/`fdelayltv`: d `2 + 62*tri`. The modulated test is what separates the two.
- `de.fdelay[N]a` (Thiran, recursive): d `1.5 + 30*tri`, jump 1.6↔40.
- `de.sdelay`: jump on the exact integer d 1000↔3000 (the crossfade state machine).
- `de.multiTapSincDelay`: alpha `tri`; tau2 near tau1.
- `pf.flanger_mono`: curdel `1 + 255*tri`, fb 0.7.
- `ef.transpose`, `ef.transpose_windowed`: s −12..12.
- `ef.granular`: pos and ratio.
- `ef.doppler_shift`: ratio through 1.
- `ef.gate_gain_mono`: rel, with an input that crosses the threshold.
- `ef.piano_dispersion_filter`: f0 exp 27.5..4186.
- `ef.tapeStop`: stop = `sq`.

**reverbs.lib**:
- `re.zita_rev_fdn`: t60m exp 1..20 s, jump. Highest value: `special_lowpass` computes `mbo2 - sqrt(mbo2^2 - 1)` in the FDN loop.
- `re.mono_freeverb`: damp, jump on fb1.
- `re.jpverb`: size or t60, jump on damp; `mod_depth = 0`.
- `re.greyhole`: size, jump on dt.
- `re.vital_rev`: size, jump on time; `chorus_amt = 0`.
- `re.fdnrev0`: one t60.
- `re.dattorro_rev`: damping, jump on decay.
- `re.springreverb`: tone only. Do not modulate tension, which is rounded to integer delays.
- Slider only: `re.zita_rev1_stereo`, `re.kb_rom_rev1`.

**compressors.lib**: the input must have dynamics, for example `no.noise*(0.05 + tri)`.
- `co.peak_compression_gain_mono_db`: slider, rel exp 0.001..1 modulated, jump; with a `prePost = 1` variant.
- `co.compression_gain_mono`: att and rel.
- `co.peak_expansion_gain_mono_db`: after the sign issue above.
- `co.limiter_lad_N`: release, with an input above the ceiling.
- `co.FBcompressor_N_chan`: att and rel.
- `co.RMS_compression_gain_mono_db`: att only. Its rel is an integer window length.
- Slider tests for the N-channel wrappers.

**oscillators.lib**:
- `os.phasor`, `os.lf_sawpos`: freq exp 0.01..100, and a through-zero sweep `2000*(2*tri - 1)`. They cover the whole `_phasor_imp` family.
- `os.osc`/`os.oscsin`: through zero. A negative phase can index one past the table.
- `os.saw2ptr`: documented as modulatable "arbitrarily fast".
- `os.sawN` (N = 3), `os.saw2dpw`, `os.polyblep_*`: freq exp 20..20000.
- `os.pulsetrain(N)`: PWM duty `0.05 + 0.9*tri`.
- `os.quadosc`: designed for a time-varying frequency.
- `os.oscs`: slider maximum below SR/π.
- `os.twin_osc`: amt `0.05 + 0.9*tri`.
- `os.rpm`: beta `1.5*tri`, jump.
- `os.dsf`: a `0.95*tri`.
- The CZ family: index `tri`, res `1 + 15*tri`. Build their phase from `os.tphase`.

**noises.lib, envelopes.lib, synths.lib, dx7**:
- `no.lfnoise0`/`lfnoiseN`/`lfnoise`: rate exp 1..100, jump.
- `no.colored_noise`: alpha −1..1, jump.
- `no.simplex1_lf`: rate through zero.
- Envelopes: slider tests for `en.ar`, `asr`, `adsr`, `asrfe`, `adsre`, `ahdsre`, `adsrf_bias`, `ahdsrf_bias`, `dx7envelope` and `smoothEnvelope`. Modulated tests for `en.asrfe` (T60s) and the bias parameters.
- `sy.fm`: through-zero FM.
- `sy.combString`: freq, jump. Its feedback is about 0.995.
- `sy.dubDub`: modulated only; its jump would hit `fi.resonlp`.
- dx7 `operator`: phaseMod.
- dx7 `env`, `pitchenv`: slider tests.

**Other libraries**:
- `webaudio.lib`: the 8 filters, slider, modulated and jump (f0 exp 20..5000). Measured: `lowpass2` modulated, and `lowpass2` and `peaking2` jumps, pass.
- `instruments.lib`: `bandPass`/`bandPassH` (resonance 50..5000, radius 0.99); `onePole`, `poleZero`, `oneZero0` (coefficient −0.5..−0.999, jump); `asympT60` slider.
- `hysteresis.lib`: `ja_hysteresis` (k or Ms), `ja_processor` (drive).
- `mi.lib`: `oscil` (k, z, with an impulse excitation and more damping; at the threshold today); `springDamper`.
- `spats.lib`: `binauralModel` (az −90..90, jump; probed, passes); `wfs` (source position).
- `wdmodels.lib`: component values (R exp 100..100k, C 1e-9..1e-6), inside the existing small trees. These are time-varying port resistances.
- `basics.lib`:
  - `tabulate`/`tabulateNd` `.lin`/`.cub` with a moving index;
  - the `sliding*` functions, slider on n, and modulated with an exact integer n;
  - `line`, `downSampleCV`, slider.
- `interpolators.lib`: slider tests for the `interpolate_*` (all their tests are constant-folded today); `lagrangeCoeffs` with a moving x; `interpolate_exponential` after its fix.
- `fds.lib`: moving `point` for the `linInterp*` functions; `hammer` slider.
- `pinktrombone.lib`: `tract`/`tract2` tongue parameters. Redo the two existing tests with the integer triangle.
- `tonestacks.lib`: a constant, a modulated and a jump test on a representative model, for example `ts.bassman(0.5, 0.5, tri)` on `no.noise`. All three were measured and pass. The library has no test at all today.
- Also passing: `pm.modeFilter` modulated (freq exp 50..5000), `os.oscrs` modulated and jump, `pf.vibrato2_mono` jump on fb.
- `hoa.lib`: `encoder3D` elevation; the decorrelation functions, slider.

### 4.2 Blocked by existing precision debt

These need a better realization first, as the ten `tf2s` jump tests of
`filters.lib` do (rule 9: no new baseline entry). The tests below were
written and run through `check_precision.py` at the six rates on
2026-10-02; section 5 gives their text.

- **Fail today: deferred, see section 5.2.**
  - `ve.crybaby`: modulated 2.8e-3, jump 9.2e-3. Its constant test already
    carries 0.0306.
  - The Vicanek `*2Matched` filters, non-finite when the frequency or the gain
    moves:
    - `lowpass2Matched` and `bandpass2Matched`, in double, at 176.4–192 kHz;
    - `lowshelf2Matched` and `highshelf2Matched` (G crossing 1), in double,
      from 48 kHz;
    - `highpass2Matched` and `peaking2Matched`, in single, at every rate.

    The non-finite double outputs are a bug, not a precision limit. The open
    PR #271 (Vicanek's matched filters accurate in float, and in double at a
    low CF) is the place to check them.
  - `pm.modeFilter`, jump: 0.12. It is behind every bell, the marimba and
    the djembe.
  - `ve.moog_vcf_2b`, jump: 0.27. Two direct-form `tf2s` sections.
  - `os.oscq`, modulated: 8.9e-3. It is `fi.wgr`, as is `wgr_jump_test`.
  - `an.goertzel`, slider at 50 Hz with n = 4096: 1.3e-3.
- **Pass today, contrary to the first reading: they move to 4.1.**
  - `pm.modeFilter` modulated.
  - `os.oscrs` modulated and jump.
  - The `webaudio.lib` jumps (`lowpass2`, `peaking2` tried).
  - `pf.vibrato2_mono` jump on fb.
  - `ts.bassman` (`tonestacks.lib`), as a constant test, a modulated test on
    L and a jump test on L.
- **Not tried, since their constant tests already exceed the threshold.**
  Extended tests would only fail the same way:
  - `os.oscr*` (2.05e-3);
  - `os.saw4` (0.193);
  - `os.imptrain*` and `os.lf_imptrain` (0.225);
  - `no.sparse_noise` (0.393);
  - dx7 `lfo` (4.25e-3);
  - `mi.oscil`, which is at the threshold with its current excitation.

### 4.3 Not relevant

Most of the libraries' symbols fall here:
- **Compile-time parameters**: orders, sizes, number of voices, bands or speakers, layouts.
- **Stateless arithmetic**: plain gains and mixes, tables and nonlinearities.
- **Routing and conversions.**
- **UI and demo wrappers** that build their own sliders.
- **Thin wrappers** whose core function gets the tests: `motion.lib`, the `abs_`/`ms_`/`rms_envelope_*` analyzers, the linear-output compressor gains, the output selections of `oberheim` and `sallenKey`.
- **Nondeterministic functions**: the `no.r*` noises.

## 5. Deferred tests to reactivate

The tests below are written, and they fail `make check-precision` today.
None of them may land with a baseline entry (rule 9). Each lands once the
realization it tests passes it. The PR that fixes the function adds the
test, under the procedure below, and removes it from this list.

**To reactivate one:**
1. Put the line in the `#### Test` section of the function's doc block, after
   its `_modulated_test`.
2. Copy it, verbatim, into the test file given, after the same test (rule 8).
   Add the `ma`/`ba` imports where missing.
3. Run `make reference` for that test, and check that its reference is
   nonzero and finite.
4. Run `make check-precision PRECISION_ARGS="tests/<file>.dsp"`. It must pass
   with no baseline entry.
5. Remove the test from this list. For the `filters.lib` ones, also remove it
   from the paragraph on the excluded jump tests in `contributing.md`
   (section *Constant, slider, modulated and jump tests*).

### 5.1 filters.lib: the ten `_jump_test` left out of bfba8892

They are generated from each function's `_modulated_test`: the triangle is
replaced by the square `sq`. All but `wgr` are built on the direct-form
`fi.tf2s`. Expect them to pass with the TPT `tf2s` of #273, stacked on #272.
The level gap is the worst float/double gap over the six rates, measured
2026-10-02.

| Test | Test file | Level gap (rate) |
|---|---|---|
| `resonlp_jump_test` | `filters_resonator_tests.dsp` | 1.1e-01 (96 kHz) |
| `resonhp_jump_test` | `filters_resonator_tests.dsp` | 1.1e-01 (96 kHz) |
| `resonbp_jump_test` | `filters_resonator_tests.dsp` | 1.1e-01 (96 kHz) |
| `peak_eq_jump_test` | `filters_parametric_eq_tests.dsp` | 2.9e-01 (96 kHz) |
| `peak_eq_cq_jump_test` | `filters_parametric_eq_tests.dsp` | 3.0e-01 (96 kHz) |
| `peak_eq_rm_jump_test` | `filters_parametric_eq_tests.dsp` | 1.5e-01 (192 kHz) |
| `highpass3e_jump_test` | `filters_elliptic_tests.dsp` | 4.7e-01 (176.4 kHz) |
| `highpass6e_jump_test` | `filters_elliptic_tests.dsp` | 5.3e-01 (192 kHz) |
| `highpass_plus_lowpass_jump_test` | `filters_delay_equalizing_allpass_tests.dsp` | 4.3e-02 (96 kHz) |
| `wgr_jump_test` | `filters_useful_special_tests.dsp` | 1.1e-03 (176.4 kHz) |

At constant settings, at either end of the range, these filters stay
within 1.7e-4. The two exceptions are `resonlp` at 20 Hz (3.1e-2, the #263
weakness) and `wgr` at 100 Hz (1.3e-3). The jump is what breaks them.

```
resonlp_jump_test = no.noise : fi.resonlp(20*pow(250, sq), 2, 0.8) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
resonhp_jump_test = no.noise : fi.resonhp(20*pow(250, sq), 2, 0.8) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
resonbp_jump_test = no.noise : fi.resonbp(20*pow(250, sq), 2, 0.8) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
peak_eq_jump_test = no.noise : fi.peak_eq(6, fx, fx/5) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; fx = 20*pow(250, sq); };
peak_eq_cq_jump_test = no.noise : fi.peak_eq_cq(6, 20*pow(250, sq), 4) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
peak_eq_rm_jump_test = no.noise : fi.peak_eq_rm(6, fx, tan(ma.PI*fx/5/ma.SR)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; fx = 20*pow(250, sq); };
highpass3e_jump_test = no.noise : fi.highpass3e(20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
highpass6e_jump_test = no.noise : fi.highpass6e(20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
highpass_plus_lowpass_jump_test = no.noise : fi.highpass_plus_lowpass(3, 20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
wgr_jump_test = fi.wgr(100*pow(20, sq), 0.995, no.noise) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
```

### 5.2 Other libraries

These are new tests: the functions have none of the kind. The imports they
need are the libraries' usual prefixes (`ve`, `pm`, `os`, `an`, `no`, `ba`,
`ma`). The level gaps and non-finite outputs were measured on 2026-10-02.

| Test | Library and test file | Fails today with | Unblocked by |
|---|---|---|---|
| `crybaby_modulated_test` | `vaeffects.lib`, `vaeffects_tests.dsp` | 2.8e-3 | #270 (crybaby accurate in float) |
| `crybaby_jump_test` | `vaeffects.lib`, `vaeffects_tests.dsp` | 9.2e-3 | #270 |
| `lowpass2Matched_modulated_test` | `vaeffects.lib`, `vaeffects_tests.dsp` | non-finite in double, 176.4–192 kHz | #271, to be checked |
| `highpass2Matched_modulated_test` | `vaeffects.lib`, `vaeffects_tests.dsp` | non-finite in single, every rate | #271, to be checked |
| `bandpass2Matched_modulated_test` | `vaeffects.lib`, `vaeffects_tests.dsp` | non-finite in double, 192 kHz | #271, to be checked |
| `peaking2Matched_modulated_test` | `vaeffects.lib`, `vaeffects_tests.dsp` | non-finite in single, every rate | #271, to be checked |
| `lowshelf2Matched_modulated_test` | `vaeffects.lib`, `vaeffects_tests.dsp` | non-finite in double, 48–192 kHz | #271, to be checked |
| `highshelf2Matched_modulated_test` | `vaeffects.lib`, `vaeffects_tests.dsp` | non-finite in double, 48–192 kHz | #271, to be checked |
| `moog_vcf_2b_jump_test` | `vaeffects.lib`, `vaeffects_tests.dsp` | 0.27 | a TPT `tf2s` (#273) |
| `modeFilter_jump_test` | `physmodels.lib`, `physmodels_tests.dsp` | 0.12 | #269 (modeFilter as a Chamberlin state-variable section) |
| `oscq_modulated_test` | `oscillators.lib`, `oscillators_tests.dsp` | 8.9e-3 | a better `fi.wgr` (with `wgr_jump_test`) |
| `goertzel_slider_test` | `analyzers.lib`, `analyzers_tests.dsp` | 1.3e-3 | a Goertzel recursion accurate in float at low frequency, or a smaller n |

```
crybaby_modulated_test = no.noise : ve.crybaby(tri) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
crybaby_jump_test = no.noise : ve.crybaby(sq) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
lowpass2Matched_modulated_test = no.noise : ve.lowpass2Matched(20*pow(250, tri), 5) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
highpass2Matched_modulated_test = no.noise : ve.highpass2Matched(20*pow(250, tri), 5) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
bandpass2Matched_modulated_test = no.noise : ve.bandpass2Matched(20*pow(250, tri), 5) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
peaking2Matched_modulated_test = no.noise : ve.peaking2Matched(2, 20*pow(250, tri), 5) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
lowshelf2Matched_modulated_test = no.noise : ve.lowshelf2Matched(0.25*pow(16, tri), 1000) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
highshelf2Matched_modulated_test = no.noise : ve.highshelf2Matched(0.25*pow(16, tri), 1000) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
moog_vcf_2b_jump_test = no.noise : ve.moog_vcf_2b(0.95, 20*pow(500, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
modeFilter_jump_test = 0.01*no.noise : pm.modeFilter(50*pow(100, sq), 1, 0.8) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
oscq_modulated_test = os.oscq(20*pow(500, tri)) : _, ! with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
goertzel_slider_test = an.goertzel(hslider("freq", 50, 20, 1000, 1), 4096, no.noise);
```

The PR numbers are open PRs that rewrite these structures. Whether a
given PR makes its test pass is to be checked when it lands, by running
the test.
