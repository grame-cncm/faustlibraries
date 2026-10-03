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
| `it.interpolate_exponential` | NaN in single precision when `k` is 0, which is the natural default of a slider. The `1e-9` floor on `abs(k)` does not help in float, since `exp(1e-9) - 1` is 0 there. A floor around 1e-3, or a series expansion for small `abs(k)`, is needed. | **fixed**: `exp(x) - 1` by its Taylor series below `abs(x)` = 0.1, exact at k = 0 (Kahan's `expm1` was tried first: the Faust normalizer simplifies its `log(exp(x))` to `x`) |
| `ef.wavefold` | Width 0 is inside the documented range [0, 1]. With a slider at 0 and `abs(x) > 1`, the output is NaN. With a constant 0, the code does not compile ("division by 0"). | **fixed**: at width 0 it clips at ±1 |
| `co.peak_expansion_gain_mono_db` and the other expander tests | With `range = +20`, `max(range)` forces a constant +20 dB gain whatever the input, so the tests do not test expansion. With `range = -20` the function expands. Either the tests or the doc of `range` needs a sign. A constant `knee = 0` also fails to compile here (`min(ma.EPSILON, knee*-2)`). | **fixed**: the sign of `range` is ignored, the knee guard is negative, and the tests now expand |
| `pm.fof`, `fofSH`, `fofSmooth`, `fofCycle` tests | The tests feed the process input, which the harness sets to zero, so fof outputs 0. The references only hold the added `os.tosc(110)*0.001`. They also pass `fc = 0.3` as the first argument, which looks like a swap. | **fixed**: the tests excite fof, whose filter is now two one-poles, accurate in float (five baseline entries removed) |
| `ef.gate_gain_mono` | The integer hold counter decrements forever and wraps after 2^31 samples (12.4 h at 48 kHz). | reported, not checked |
| `re.springreverb` | Its diffusion calls `de.delay(length, max)` with the two arguments swapped. The first taps are clamped. | reported, not checked |
| `os.oscs` | Blows up above SR/π, for example 15.3 kHz at 48 kHz (the magic circle needs `wn < 2`). Not documented. | reported, not checked |
| `pm.*Bell*`, `pm.marimba*` | `modesT60s` turns negative when `t60DecayRatio > 1`, so `pow` gives NaN with the default slopes. | reported, not checked |
| `dx` `lfo` triangle | The falling branch uses the old phase, so the output is one sample late and overshoots 1. | reported, not checked |
| `an.resonator` | The phase output (`atan2`) wraps at ±π. Float and double then differ by 2π at the wraps. | reported (probed) |
| `pm.bridgeFilter` | The doc of `absorption` is inverted: 1 gives 0 s, not 20 s. | reported, not checked |
| `sy.combString` | `maxDel = 1024` clamps the pitch below SR/1024 (188 Hz at 192 kHz), although its slider goes down to 55 Hz. `res` is documented as a T60 but is used as a time constant. | reported, not checked |
| `os.pulsetrainN`, `os.twin_osc`, `re.zita_in_delay`, `ef.doppler_shift` | Hard-coded maximum delays that clip their behavior at 176.4–192 kHz. | reported, not checked |
| `re.greyhole` | `dt` is documented from 0.1 to 60 s, but its `de.sdelay` holds 65533 samples: 1.36 s at 48 kHz, 0.34 s at 192 kHz. Its crossfade is a fixed 22050 samples, 0.5 s at 44.1 kHz and 0.11 s at 192 kHz. | reported, not checked |

## 2. Tests that check little today

- **Feature never exercised.**
  - The `limiter_lad_*` tests never limit: a sine at 1 against a ceiling of 1 (`limiter_lad_N_modulated_test` and `_jump_test` now do).
  - The gate tests never close the gate (the `gate_gain_mono` modulated and jump tests now do).
  - `tapeStop_test` held its `stop` button down for the whole run, like every button of every test (#281, below): the tape stopped at the start and never resumed. The harnesses now release it halfway, and `tapeStop_jump_test` stops and resumes every 0.25 s.
  - No compressor or expander test used `prePost = 1` (`peak_compression_gain_mono_db_post_test` now does).
  - Every compressor test uses a steady sine, so release is hardly exercised (the modulated and jump tests now move it on noise bursts).
- **Near-silent references.**
  - `dx` `env_test` peaks at 6.4e-5, and `operator_test` at 3.2e-5 (its L1..L4 are all 0).
  - `violin_ui_test` tests `violinModel`, not `violin_ui`.
- **No real constant test.** The `_test`s of `vaeffects.lib` and `synths.lib` already used unsmoothed `hslider`s: they were slider tests under the `_test` name (both libraries now split them). Choose between:
  - adding `_slider_test` copies;
  - converting the `_test`s to constants, which changes their references.
- **No test at all.**
  - `tonestacks.lib` has no Test section and no `tests/tonestacks_tests.dsp`.
  - In `motion.lib`, `motionEnvelope`, `envelopeAbs`, `envelopePos`, `envelopeNeg`, `pita3` and `totalEnvelope` have none.
- **Modulators that drift in float.** `pinktrombone.lib`'s two `_modulated_test` use `os.tosc` as their modulator, not the integer triangle.

## 3. Tooling and rule 8

**Fixed** (the cut doc blocks, all twelve of them, the genericNode tests and the stray section; `lib_tests.py inventory`: titles without prefix, generic `[N]` symbols, alias-prefixed and disabled tests). The JSON export leaves out tubes.lib, tonestacks.lib, instruments.lib and maxmsp.lib by design: it follows the libraries that stdfaust.lib imports, which these are not.

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

**Buttons and checkboxes (#281).** Both harnesses (`arch/print_arch.cpp` for `make check`, `arch/precision_arch.cpp` for `make check-precision`) held every button and checkbox at 1 for the whole run: a checkbox was registered as a button, and the "OFF" step called `buttonON()`. Bypassed effects were never tested, nor a release, a note-off or the other state of a checkbox. **Fixed**: every button and checkbox is ON for the first half of the render and OFF for the second half. 115 references change, all in their second half only. `check-precision` then found:
- `crybaby_demo_test`, 4.6e-3: the demo now runs `ve.crybaby`, whose float debt is pinned for `crybaby_test` (0.0306). Pinned the same way, to be removed with #270.
- `hammer_test` and `hammer_slider_test`, 9.3e-3 and 2.6e-2: once released, the nearly undamped hammer (`sigma0 = 0.01`) bounces freely on the string, and each contact crosses the `(uh - u) > 0` threshold one sample apart in float and double. The tests now use `sigma0 = 10`, at which the released hammer settles (8.2e-6).
- `orientation6_demo_test` no longer needs its baseline entry.

## 4. Where the extended tests belong

### 4.1 Likely to pass now (high value)

**vaeffects.lib**: TPT and ladder filters, modulated and jump tests. **Done**: 13 modulated and 12 jump tests, and every `_test` that took sliders split into a constant `_test` and a `_slider_test`. The jump test found a real bug, fixed: `ve.moog_vcf` output 2.6e6 after a jump of its frequency.
- `moogLadder`, `moogHalfLadder`, `diodeLadder`, `korg35LPF`/`HPF`, `oberheim`, `sallenKeyOnePole`, `sallenKey2ndOrder`: normFreq `0.8*tri` (20 Hz–5 kHz), Q high (about 20, or 9.5 for korg35).
- `lowpassLadder4`: CF exp 20..5000, k = 3.9.
- `moog_vcf`: fr exp 50..5000, res 0.9.
- `moog_vcf_2bn`: protected normalized ladder.
- `klonCentaur`: gain `0.1 + 0.9*tri`, jump 0.1↔1. Its 50 ms ramp only runs when a control moves.
- `lowshelf2Matched`/`highshelf2Matched`: G crossing 1, where the `safeG` branch is almost 0/0. Measured: non-finite, even in double. Deferred, see 5.2; reactivated with #271.

**signals.lib, analyzers.lib**: the smoothers and followers everything else uses. **Done**: 5 slider, 3 modulated and 3 jump tests in analyzers.lib, 3 of each in signals.lib, all passing without a baseline entry.
- `si.smooth`: slider, modulated (s 0.9..0.9999), jump, on `no.noise`.
- `si.onePoleSwitching`: att and rel exp 0.001..1, in opposite directions.
- `si.smoothq`: time 0.001..1, on a random target that steps 30 times a second. The controls at their extremes found a real bug, fixed: in float, `1 - coef` was rounded coarsely for long times, a linear glide (q = 1, 1 s) 11% too fast at 192 kHz. `smoothq_linear_test` pins it.
- `an.amp_follower`: rel exp 0.001..1; `an.amp_follower_ud`: att 0.5..10 ms. Their input is noise bursts decaying 60 dB in 0.25 s, so that the release is measured.
- `an.resonator`: f exp 20..5000, magnitude only.
- Slider only: `an.pitchTracker`, `an.spectralCentroid` (tau).
- Left as they are, found with the controls at their extremes:
  - a one-pole from `ba.tau2pole` with a long time constant (`si.smooth(ba.tau2pole(1))`, `si.onePoleSwitching` with att 1 s, `an.pitchTracker` with tau 1 s): level gap 3.4e-3 at 192 kHz. The pole, 1 - 5e-6, cannot be represented more closely in float; a fix would pass `1 - p` instead of `p`, an interface change for every user of `tau2pole`.
  - `si.smoothq` after its fix, at time 1 s and q = 1: 6.7e-3. The float accumulator itself, which adds an increment of a few tens of ulps per sample.
  - `an.spectralCentroid(0, 0.001)` diverges; its doc already says to use the nonlinearity for such short times.

**delays.lib, phaflangers.lib, misceffects.lib**: fractional and moving delays. **Done**: 16 slider, 16 modulated and 12 jump tests, plus the constant tests that were missing (`fdelay1`..`fdelay5`, `fdelay1a`, `fdelay3a`, `fdelay4a`) and `multiTapSincDelay_near_test` (tau2 = tau1 + 0.001); all pass without a baseline entry. `ef.granular` failed (3.9e-2): its float grain phase wrapped one sample apart in float and double, latching another jitter. Fixed with an integer phase, which also removes the baseline entry of `granular_test`. As planned below, except:
- `pf.flanger_stereo`, `pf.phaser2_mono`: slider tests too; `pf.vibrato2_mono`: slider, and jump on fb (-0.9 to 0.9).
- `ef.gate_gain_mono`: the modulated and jump tests close the gate (noise bursts decaying 60 dB in 0.25 s, threshold -30 dB).
- `ef.tapeStop`: its jump test stops and resumes every 0.25 s.
- Left as they are, found with the controls at their extremes:
  - `pf.vibrato2_mono` with fb 0.99 and 50 Hz notches: level gap 2.4e-2 (9.4e-2 at fb -0.99). Without its LFO (speed 0) the gap is 4e-6: the cause is the recursive float LFO (`os.oscrc`/`os.oscrs`, the `os.oscr*` debt of 4.2), amplified by the feedback.
  - `ef.doppler_shift` at 2 kHz, ratio 0.5: 1.6e-3, its `os.phasor` drifting in float.
  - `de.multiTapSincDelay` at alpha 0.5 with K = 2 has a gain of 1.10, the sum of its truncated sincs, for any tau2 - tau1 above `ma.EPSILON` (1 below). A property of the method, not of the precision.
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

**reverbs.lib**: **Done**: 9 slider, 8 modulated and 8 jump tests, all passing without a baseline entry. `re.mono_freeverb` failed in all three (1e-2): its Freeverb lengths, scaled from 44.1 kHz and truncated, lost one sample in single precision where the quotient is an integer (1617 at 44.1 kHz, 1760 at 48 kHz). Fixed with an exact integer scaling, which also removes three baseline entries (`mono_freeverb_test`, `stereo_freeverb_test`, `freeverb_demo_test`). Changes to the plan below:
- `re.zita_rev_fdn`: t60m from 1 to 20 s, modulated and jumping. `re.fdnrev0`: the mid t60 from 0.5 to 5 s.
- `re.jpverb`: t60 from 0.5 to 10 s modulated, damp jumping; `re.greyhole`: feedback from 0.2 to 0.9, modulated and jumping. Their `size` is deferred, as is greyhole's `dt` (5.2).
- `re.vital_rev`: size modulated, time jumping, chorus at 0. Its slider test is deferred (5.2).
- `re.springreverb`: tone modulated and jumping.
- Slider tests for every function with run-time parameters, except `re.vital_rev`.
- Left as they are, found with the controls at their extremes: `re.jpverb` and `re.greyhole` with mod_depth 1 at 10 Hz reach 8.7e-3 and 1.7e-3, from their `os.oscrs`/`os.oscrc` LFOs (the `os.oscr*` debt of 4.2).

The plan was:
- `re.zita_rev_fdn`: t60m exp 1..20 s, jump. Highest value: `special_lowpass` computes `mbo2 - sqrt(mbo2^2 - 1)` in the FDN loop.
- `re.mono_freeverb`: damp, jump on fb1.
- `re.jpverb`: size or t60, jump on damp; `mod_depth = 0`.
- `re.greyhole`: size, jump on dt.
- `re.vital_rev`: size, jump on time; `chorus_amt = 0`.
- `re.fdnrev0`: one t60.
- `re.dattorro_rev`: damping, jump on decay.
- `re.springreverb`: tone only. Do not modulate tension, which is rounded to integer delays.
- Slider only: `re.zita_rev1_stereo`, `re.kb_rom_rev1`.

**compressors.lib**: the input must have dynamics, for example `no.noise*(0.05 + tri)`. **Done**: 25 slider tests (every function with run-time parameters, from its constant test), 6 modulated and 6 jump tests, and `peak_compression_gain_mono_db_post_test` (prePost = 1); all pass without a baseline entry. The modulated and jump tests run on noise bursts decaying 60 dB in 0.25 s, with the threshold at -24 dB (-40 dB for the expander), so that the gain moves. Changes to the plan below: `co.limiter_lad_N` limits a doubled input against a 0.5 ceiling; `co.FBcompressor_N_chan` and `co.compression_gain_mono` move att and rel in opposite directions. Left as they are: with an attack or a release of 1 s, the level gap reaches 1e-3 to 1e-2 at 192 kHz (`limiter_lad_N`, the soft-knee post mode, `RMS_compression_gain_mono_db` with a 1 s post attack): the float limit of a one-pole from `ba.tau2pole` at 1 s, as in signals.lib.

The plan was:
- `co.peak_compression_gain_mono_db`: slider, rel exp 0.001..1 modulated, jump; with a `prePost = 1` variant.
- `co.compression_gain_mono`: att and rel.
- `co.peak_expansion_gain_mono_db`: after the sign issue above.
- `co.limiter_lad_N`: release, with an input above the ceiling.
- `co.FBcompressor_N_chan`: att and rel.
- `co.RMS_compression_gain_mono_db`: att only. Its rel is an integer window length.
- Slider tests for the N-channel wrappers.

**oscillators.lib**: **Done**: 30 slider and 30 modulated tests, 2 jump tests (`rpm`), all passing without a baseline entry. `os.polyblep_triangle` peaked at 84 under a frequency sweep and 165 after a jump: it scaled its leaky integrator by `4*freq/SR` at the output. Fixed by scaling at the input; its modulated and jump tests pin it. Changes to the plan below:
- `os.phasor`, `os.osc`, `os.oscsin`: through zero (`2000*(2*tri - 1)`); `os.lf_sawpos`: exp 0.01..100.
- `os.sawN(3)`: exp 50..20000, not 20..20000. At 20 Hz and 192 kHz its level gap is 8e-2: the DPW method differentiates a cubic of the ramp twice and scales by `(SR/freq)^2`, which cancels in float at low frequencies (the doc already warns about orders 5 and 6). `sawN(2)` passes from 20 Hz.
- `os.dsf`: `oscc`, `oscs` and `osccN` with `a = 0.95*tri`; `os.rpm`: `sawtooth` and `square`, modulated and jumping.
- Left as they are: `os.polyblep_triangle` jumping between 20 Hz and 20 kHz reaches 0.17 at 48 kHz, where 20 kHz is a period of 2.4 samples; and `ma.frac` of a negative phase above about -3e-8 is exactly 1 in float, so `os.osc` through zero can index `tablesize`. Faust's default table check (`-ct 1`) clamps the index, which reads the last entry (about -1e-4) instead of the first (0); with `-ct 0` it reads one past the table.

The plan was:
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

**noises.lib, envelopes.lib, synths.lib, dx7**: **Done**: 33 tests, all passing without a baseline entry. The `_test`s of `synths.lib` that took sliders are split, as in `vaeffects.lib`, into a constant `_test` and a `_slider_test`. Changes to the plan below:
- `no.lfnoise0`, `lfnoiseN`, `lfnoise`: deferred (5.2). They latch white noise at the zero crossings of `os.oscrs`: a crossing one sample apart in float and double latches another noise value, and at a low rate a few values make the whole level. A rate jumping between 1 and 100 Hz gives level gaps of 0.19 to 0.24, `lfnoise0` from a slider 3.9e-3; their modulated tests pass, by chance.
- `no.colored_noise`: alpha from a slider, modulated and jumping over [-1, 1]. `no.simplex1_lf`: rate from a slider, and through zero (`20*(2*tri - 1)`).
- Envelopes: slider tests for the 10 planned; `en.asrfe` with its attack and release T60s modulated from 10 ms to 1 s in opposite directions; `en.adsrf_bias` and `en.ahdsrf_bias` with their three bias parameters modulated.
- `sy.fm`: the modulation index from 0 to 1000 Hz on a 440 Hz carrier, through zero. `sy.combString`: freq from 220 to 880 Hz (within its 1024-sample line up to 192 kHz), modulated and jumping. `sy.dubDub`: cutoff from 100 Hz to 6 kHz.
- dx7: `operator_modulated_test` with its envelope levels at 99 (audible, unlike `operator_test`) and phaseMod over [-1, 1]; `env` and `pitchenv` slider tests.
- Left as they are, found with the controls at their extremes: `en.smoothEnvelope` at 5 s reaches 2.5e-2 at 192 kHz, `en.asrfe` and `en.adsre` with 5 s T60s 2e-3 (the float limit of a slow one-pole, as in signals.lib); `sy.dubDub` at q = 10, 5.8e-3, from `fi.resonlp` (the direct-form debt of 4.2).

The plan was:
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
- `webaudio.lib`: the 8 filters, slider, modulated and jump (f0 exp 20..5000). **Done**: 24 tests, all passing. The jumps peak at 11 to 49 on noise: the transient of a direct-form biquad whose coefficients jump, exact in float.
- `instruments.lib`: `bandPass`/`bandPassH` (resonance 50..5000, radius 0.99); `onePole`, `poleZero`, `oneZero0` (coefficient −0.5..−0.999, jump); `asympT60` slider. **Done**: 16 tests (named `inst_*`), all passing.
- `hysteresis.lib`: `ja_hysteresis` (k or Ms), `ja_processor` (drive). **Done**: slider tests, `ja_hysteresis` with k from 100 to 1000, `ja_processor` with its drive from 0 to 20 dB.
- `mi.lib`: `oscil` (k, z, with an impulse excitation and more damping; at the threshold today); `springDamper`. **Done**: slider tests; `oscil` with k from 0.05 to 0.5 on an impulse every 0.1 s, z = 0.02; `springDamper` with k from 1 to 10.
- `spats.lib`: `binauralModel` (az −90..90, jump; probed, passes); `wfs` (source position). **Done**: `binauralModel` modulated and jumping, `wfs` with its source x from -1 to 1.
- `wdmodels.lib`: component values (R exp 100..100k, C 1e-9..1e-6), inside the existing small trees. These are time-varying port resistances. **Done**: the resistor (100 to 100k), the capacitor (1 nF to 1 µF, modulated and jumping) and the inductor (1 to 100 mH), each in a voltage divider driven by noise.
- `basics.lib`:
  - `tabulate`/`tabulateNd` `.lin`/`.cub` with a moving index;
  - the `sliding*` functions, slider on n, and modulated with an exact integer n;
  - `line`, `downSampleCV`, slider.

  **Done**: 24 tests. The modulated `sliding*` tests take n = 16..128 exact, with an explicit `: max(16) : min(128)` (the interval analysis loses the bound otherwise). `tabulateNd` is swept where its test function `sin(pow(x, y))` is well conditioned (x 2..3, y 3..2): at the corner (8, 8) of its table, `sin(8^8)` has no meaning in float.
- `interpolators.lib`: slider tests for the `interpolate_*` (all their tests are constant-folded today); `lagrangeCoeffs` with a moving x; `interpolate_exponential` after its fix. **Done**: 17 tests, slider and modulated dv for the eight `interpolate_*`, and `lagrangeCoeffs` modulated.
- `fds.lib`: moving `point` for the `linInterp*` functions; `hammer` slider. **Done**: 5 tests. `fd.linInterp1D` dropped an output to 0 for one sample when the point crossed an integer from below in float (`int(point+1)`, with point+1 rounded up): fixed, `int(point)+1`, as `linInterp2D` already wrote.
- `pinktrombone.lib`: `tract`/`tract2` tongue parameters. Redo the two existing tests with the integer triangle. **Done**: `lfWaveform_modulated_test` and `glottis_modulated_test` redone on the triangle (same ranges); `tract` with its tongue index (12..29) and diameter (2.05..3.5) modulated, no constriction. With an active constriction the tongue sweep fails (`tract` 4.0e-3, `tract2` 1.4e-3): the turbulence noise is gated by area thresholds, and a decision one sample apart in float and double injects another noise. `tract2_modulated_test` is deferred (5.2).
- `tonestacks.lib`: a constant, a modulated and a jump test on a representative model, for example `ts.bassman(0.5, 0.5, tri)` on `no.noise`. **Done**: `bassman` constant, slider, modulated and jump tests, in its doc block and in a new `tests/tonestacks_tests.dsp`; the jump test passes at 7.3e-4, close to the threshold (the third-order direct form of `tonestack`).
- Also passing: `pm.modeFilter` modulated (freq exp 50..5000; done, 7.3e-4, close to the threshold), `os.oscrs` modulated (done) and jump (it fails today at 1.7e-3, the `os.oscr*` debt: deferred, 5.2); `pf.vibrato2_mono` jump on fb (done).
- `hoa.lib`: `encoder3D` elevation; the decorrelation functions, slider. **Done**: `encoder3D` with azimuth and elevation moving, `fxDecorrelation` and `synDecorrelation` slider tests.

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
    low CF) is the place to check them. Reactivated with #271: the six
    `_modulated_test` are finite in both precisions, level gap 7.3e-7 at
    most.
  - `pm.modeFilter`, jump: 0.12. It is behind every bell, the marimba and
    the djembe.
  - `ve.moog_vcf_2b`, jump: 0.27. Two direct-form `tf2s` sections.
  - `os.oscq`, modulated: 8.9e-3. It is `fi.wgr`, as is `wgr_jump_test`.
  - `an.goertzel`, slider at 50 Hz with n = 4096: 1.3e-3.
- **Pass today, contrary to the first reading: they move to 4.1.**
  - `pm.modeFilter` modulated.
  - `os.oscrs` modulated (its jump fails since the triangle is tied to the rate: 1.7e-3).
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

### 5.1 filters.lib: the ten `_jump_test` left out of the filters.lib jump tests

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
need are the libraries' usual prefixes (`ve`, `pm`, `os`, `an`, `re`, `no`,
`pt`, `ba`, `ma`). The level gaps and non-finite outputs were measured on 2026-10-02 and 2026-10-03.

| Test | Library and test file | Fails today with | Unblocked by |
|---|---|---|---|
| `crybaby_modulated_test` | `vaeffects.lib`, `vaeffects_tests.dsp` | 2.8e-3 | #270 (crybaby accurate in float) |
| `crybaby_jump_test` | `vaeffects.lib`, `vaeffects_tests.dsp` | 9.2e-3 | #270 |
| `moog_vcf_2b_jump_test` | `vaeffects.lib`, `vaeffects_tests.dsp` | 0.27 | a TPT `tf2s` (#273) |
| `moog_vcf_2b_modulated_test` | `vaeffects.lib`, `vaeffects_tests.dsp` | 2.1e-3 | a TPT `tf2s` (#273) |
| `autowah_slider_test`, `crybaby_slider_test` | `vaeffects.lib`, `vaeffects_tests.dsp` | the debt of their `_test` (2.3e-3, 3.1e-2) | #270 |
| `modeFilter_jump_test` | `physmodels.lib`, `physmodels_tests.dsp` | 0.12 | #269 (modeFilter as a Chamberlin state-variable section) |
| `oscq_modulated_test` | `oscillators.lib`, `oscillators_tests.dsp` | 8.9e-3 | a better `fi.wgr` (with `wgr_jump_test`) |
| `goertzel_slider_test` | `analyzers.lib`, `analyzers_tests.dsp` | 1.3e-3 | a Goertzel recursion accurate in float at low frequency, or a smaller n |
| `lfnoise0_slider_test`, `lfnoise0_jump_test`, `lfnoiseN_jump_test`, `lfnoise_jump_test` (and their modulated and slider siblings, which pass by chance) | `noises.lib`, `noises_tests.dsp` | 3.9e-3; 0.24, 0.20, 0.19 | a trigger exact in both precisions: the zero crossings of `os.oscrs` move by one sample between float and double, and each latches another noise value |
| `oscrs_jump_test` | `oscillators.lib`, `oscillators_tests.dsp` | 1.7e-3 | the `os.oscr*` debt (`oscrs_test` carries 2.05e-3 in the baseline) |
| `tract2_modulated_test` | `pinktrombone.lib`, `pinktrombone_tests.dsp` | 1.4e-3 | a turbulence source whose gating does not depend on the precision (constriction area thresholds) |
| `vital_rev_slider_test` | `reverbs.lib`, `reverbs_tests.dsp` | 3.1e-3, the debt of `vital_rev_test` | a chorus LFO whose phase does not drift in float (its `m_lfo_sine` accumulates `freq/SR`, and the chorus moves the delays by up to 2500 samples) |
| `jpverb_size_modulated_test`, `greyhole_size_modulated_test` | `reverbs.lib`, `reverbs_tests.dsp` | 4.6e-3, 7.1e-3 (a jump of size between 1 and 2: 3.8e-3, 5.2e-3) | delay lengths smoothed accurately in float: `smooth_init(0.9999)` and `(0.995)` glide each prime length to the next, and a 2e-4 relative difference of `1 - s` between float and double moves the fractional delays of the whole network |
| `greyhole_dt_jump_test` | `reverbs.lib`, `reverbs_tests.dsp` | 1.7e-3 at 176.4 kHz (0.25 to 0.5 s; 8.7e-4 from 0.125 to 0.25 s) | a `de.sdelay` crossfade exact in float: it steps by 1/22050 |

```
crybaby_modulated_test = no.noise : ve.crybaby(tri) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
crybaby_jump_test = no.noise : ve.crybaby(sq) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
moog_vcf_2b_jump_test = no.noise : ve.moog_vcf_2b(0.95, 20*pow(500, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
moog_vcf_2b_modulated_test = no.noise : ve.moog_vcf_2b(0.95, 20*pow(500, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
modeFilter_jump_test = 0.01*no.noise : pm.modeFilter(50*pow(100, sq), 1, 0.8) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
oscq_modulated_test = os.oscq(20*pow(500, tri)) : _, ! with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
goertzel_slider_test = an.goertzel(hslider("freq", 50, 20, 1000, 1), 4096, no.noise);
lfnoise0_slider_test = no.lfnoise0(hslider("lfnoise0:freq", 10.1, 0.1, 1000, 0.1));
lfnoiseN_slider_test = no.lfnoiseN(3, hslider("lfnoiseN:freq", 10.1, 0.1, 1000, 0.1));
lfnoise_slider_test = no.lfnoise(hslider("lfnoise:freq", 10.1, 0.1, 1000, 0.1));
lfnoise0_modulated_test = no.lfnoise0(pow(100, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
lfnoise0_jump_test = no.lfnoise0(pow(100, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
lfnoise_modulated_test = no.lfnoise(pow(100, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
lfnoise_jump_test = no.lfnoise(pow(100, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
lfnoiseN_modulated_test = no.lfnoiseN(3, pow(100, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
lfnoiseN_jump_test = no.lfnoiseN(3, pow(100, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
oscrs_jump_test = os.oscrs(20*pow(1000, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
tract2_modulated_test = (os.lf_imptrain(140), 0.3) : pt.tract2(12 + 17*tri, 2.43, 36.3, 0.5, 1, 20.6, 0.8, 1, 0) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
vital_rev_slider_test = (os.tosc(330), os.tosc(440)) : re.vital_rev(hslider("vital_rev:prelow", 0.2, 0, 1, 0.01), hslider("vital_rev:prehigh", 0.8, 0, 1, 0.01), hslider("vital_rev:lowcutoff", 0.5, 0, 1, 0.01), hslider("vital_rev:highcutoff", 0.7, 0, 1, 0.01), hslider("vital_rev:lowgain", 0.4, 0, 1, 0.01), hslider("vital_rev:highgain", 0.6, 0, 1, 0.01), hslider("vital_rev:chorus_amt", 0.3, 0, 1, 0.01), hslider("vital_rev:chorus_freq", 0.2, 0, 1, 0.01), hslider("vital_rev:predelay", 0.1, 0, 1, 0.01), hslider("vital_rev:time", 0.7, 0, 1, 0.01), hslider("vital_rev:size", 0.5, 0, 1, 0.01), hslider("vital_rev:mix", 0.4, 0, 1, 0.01));
jpverb_size_modulated_test = (no.noises(2, 0), no.noises(2, 1)) : re.jpverb(3.0, 0.2, 0.5 + 2.5*tri, 0.8, 0, 0.4, 0.9, 0.8, 0.7, 500, 4000) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
greyhole_size_modulated_test = (no.noises(2, 0), no.noises(2, 1)) : re.greyhole(2.0, 0.3, 0.5 + 2.5*tri, 0.6, 0.5, 0, 0.2) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
greyhole_dt_jump_test = (no.noises(2, 0), no.noises(2, 1)) : re.greyhole(0.25 + 0.25*sq, 0.3, 1.0, 0.6, 0.5, 0, 0.2) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
```

`autowah_test` and `crybaby_test` still take their parameters from sliders:
their split into a constant `_test` and a `_slider_test`, as for the other
functions of `vaeffects.lib`, waits for the same fix, since both versions
carry the debt of the function and a new baseline entry is not allowed.
`bandpass2Matched_test` was split with #271.

The PR numbers are open PRs that rewrite these structures. Whether a
given PR makes its test pass is to be checked when it lands, by running
the test.
