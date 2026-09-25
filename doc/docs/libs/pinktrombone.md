#  pinktrombone.lib 

A Faust port of Neil Thapen's **Pink Trombone** (2017), the bare-handed procedural
speech synthesiser [https://dood.al/pinktrombone/](https://dood.al/pinktrombone/).

The original is a ~1000-line JavaScript program running in a ScriptProcessorNode.
This library reproduces its DSP core:

* **Glottis** — a per-period-resampled Liljencrants–Fant (LF) glottal-flow
  waveform driven by a single "tenseness" parameter (Rd = 3(1-tenseness)),
  plus aspiration noise modulated by the glottal cycle, vibrato / pitch wobble
  and slow tenseness drift.
* **Tract** — a 44-section Kelly–Lochbaum digital waveguide of the vocal
  tract, run at *twice* the audio rate (two waveguide ticks per sample),
  with a 28-section nasal branch coupled at section 17 by a three-port
  scattering junction, glottal reflection 0.75, lip/nostril reflection -0.85,
  fricative turbulence injected at a movable constriction, and a decaying
  "transient" pulse released when a full closure opens (plosives).
* **Tract shape** — the "tongue" (index / diameter) that bends the rest
  diameters between the blade and the lips, one or two constrictions
  (index / diameter, e.g. for fricatives and stops), and the velum.

Everything that was block-rate (512 samples) in the JavaScript is computed
at sample rate here, with the block-rate constants converted to rates using
the original's block length.

**Sample rate.** Each waveguide section is one tick long, so the tract's
acoustic length, and with it every formant, scales with the tick rate; the
original has the same property. With the default `ticksPerSample = 2` the
model is tuned for 44.1 and 48 kHz (at 48 kHz the formants of a given shape
are about 9 % higher than at 44.1 kHz). At 88.2 or 96 kHz, override it to 1,
e.g. `pt[ticksPerSample=1;].pinkTrombone(...)`: the whole model then behaves
as it does at 44.1 or 48 kHz. Other rates shift the formants in proportion.
The 1-D simplex drift noises are the real thing (`no.simplex1_lf`, a port of
the same noisejs code, with a fixed seed instead of `Date.now()`); the browser's
uniform `Math.random()` white noise is replaced by scaled `no.noise`.

Its official prefix is `pt`.

#### Deviations from the original

* The block-rate updates (512-sample blocks) run at sample rate, and the reflection
  coefficients follow the section diameters every sample instead of being
  interpolated across each block (which also removes the original's swapped
  old/new interpolation at the nose junction). The release of a closure is still
  detected one block late, as in the original.
* `voiced` behaves like a finger on the original's pitch keyboard: voicing ramps
  in and out, without the pressed onset of the original's untouched "always
  voice" start-up.
* UI-only behaviour is not modelled: the keyboard is replaced by `freq` in Hz;
  the tongue control's reachable-range kludge, and its side effect of acting as a
  wide constriction while held, are left out; at most two constrictions
  (`tract2`, `pinkTrombone2`); the velum is the separate `nasal` gate instead of a
  touch below the tract.
* Up to two release transients sound at once (the original keeps a list).
* The simplex drift uses the fixed seed `noiseSeed` instead of `Date.now()`, and
  the uniform white noise is scaled `no.noise`.
* Waveguide state below 1e-20 is flushed to zero, so the (lossless) nose does not
  decay into denormals.

Against a line-by-line reference port of the JavaScript, settled tract output
matches to about 1e-6 (relative) and the LF waveform to 2e-3 (absolute, float32).

#### Usage

```
pt = library("pinktrombone.lib");
process = pt.pinkTrombone(freq, tenseness, voiced, wobble, tongueIndex, tongueDiameter,
                          constrictionIndex, constrictionDiameter, constrictionOn, nasal);
```

Use `process = dm.pink_trombone_demo;` with `import("stdfaust.lib");` for the demo.

Note: pass *signals* (or use partial application / sequential composition) for the
audio-rate arguments `glottalOutput`, `noiseModulator`, `fricNoise` — an explicit
`_` argument gets duplicated wherever the parameter is used inside the function.

#### References

* Neil Thapen, *Pink Trombone — bare-handed procedural speech synthesis*,
  version 1.1 (March 2017), MIT licence. [https://dood.al/pinktrombone/](https://dood.al/pinktrombone/)
* The original's bibliography: J. O. Smith III, *Physical Audio Signal Processing*
  [https://ccrma.stanford.edu/~jos/pasp/](https://ccrma.stanford.edu/~jos/pasp/); B. H. Story, "A parametric model of the
  vocal tract area function for vowel and consonant simulation", JASA 117(5), 2005;
  H.-L. Lu & J. O. Smith, "Glottal source modeling for singing voice synthesis",
  ICMC 2000; J. Mullen, *Physical modelling of the vocal tract with the 2D digital
  waveguide mesh*, PhD thesis, York, 2006.
* G. Fant, "The LF-model revisited. Transformations and frequency domain analysis",
  STL-QPSR 36(2-3), 1995 (the Rd parametrisation used by `setupWaveform`).

#### License

The Faust port is MIT-licensed, Copyright 2026 David Braun. It is a derivative
work of *Pink Trombone* version 1.1 (March 2017) by Neil Thapen
[https://venuspatrol.nfshost.com](https://venuspatrol.nfshost.com); the original copyright and permission notice
follows, reproduced verbatim as it requires:

Copyright 2017 Neil Thapen

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
IN THE SOFTWARE.

##  Constants 


----

### `(pt.)ticksPerSample`

Waveguide ticks per sample (2). The tract's length, and so its formants, follow
the tick rate: keep 2 at 44.1/48 kHz, override it to 1 at 88.2/96 kHz with
explicit substitution (`pt[ticksPerSample=1;]`).

#### Usage

```
ticksPerSample : _
```

#### Test
```
import("stdfaust.lib");
pt_ticksPerSample_test = pt[ticksPerSample=1;].pinkTrombone(140, 0.6, 1, 0, 12.9, 2.43, 30, 3, 0, 0);
```

##  Utilities 


----

### `(pt.)noiseSeed`

Constant integer seed (12345) shared by the simplex drift streams. Override with explicit library substitution to choose another seed.

#### Usage

```
noiseSeed : _
```

#### Test
```
import("stdfaust.lib");
pt_noiseSeed_test = pt[noiseSeed=7;].glottis(140, 0.6, 1, 1) : _, !, !, !;
```

##  Glottis 


----

### `(pt.)lfWaveform`

The original's `setupWaveform` + `normalizedLFWaveform`: a Liljencrants–Fant
glottal flow derivative pulse parametrised by Rd (0.5..2.7), normalised to a
period of 1 and Ee = 1, evaluated at phase `t` in [0,1).

#### Usage

```
lfWaveform(Rd0, t) : _
```

Where:

* `Rd0`: LF shape parameter, clamped to 0.5..2.7.
* `t`: Phase in the half-open interval [0, 1).

#### Test
```
import("stdfaust.lib");
lfWaveform_test = par(i, 3, pt.lfWaveform(0.5 + i, os.lf_sawpos(100)));
lfWaveform_modulated_test = pt.lfWaveform(0.5 + 1.1*(1 + os.osc(2)), os.lf_sawpos(200));
```

----

### `(pt.)glottis`

The Pink Trombone glottal source. Returns the glottal flow (LF pulse plus
aspiration noise) that feeds the tract, together with the signals the tract
needs from the glottis (noise modulator, and glottal-phase & intensity for
convenience).
Outputs are glottal excitation, noise modulator, intensity and phase, in that order.

#### Usage

```
glottis(freq, tenseness, voiced, wobble) : _, _, _, _
```

Where:

* `freq`: Positive fundamental frequency in Hz; the demo spans about 87..277 Hz.
* `tenseness`: Voice tenseness in 0..1; the default is 0.6.
* `voiced`: Voice gate: positive is on, zero is off. It acts like a finger on the
  original's pitch keyboard: voicing ramps in and out, with no pressed onset.
* `wobble`: Pitch wobble amount in 0..1.

#### Test
```
import("stdfaust.lib");
glottis_test = pt.glottis(140, 0.6, (ba.time < 24000), 0);
glottis_modulated_test = pt.glottis(150 + 50*os.osc(0.8), 0.5 + 0.45*os.osc(4), (ba.time % 48000) > 12000, 1);
```

##  Tract shape 


----

### `(pt.)tractDiameters`

The 44 time-varying section diameters (after the original's movement
smoothing), as parallel signals.

#### Usage

```
tractDiameters(tongueIndex, tongueDiameter, cIndex, cDiameter, cActive) : si.bus(44)
```

Where:

* `tongueIndex`: Tongue position in sections, 12..29 (default 12.9).
* `tongueDiameter`: Tongue diameter in model units, 2.05..3.5 (default 2.43).
* `cIndex`: Constriction position in sections, 2..44; position 44 lies beyond the mouth cells.
* `cDiameter`: Touch diameter in model units, 0..3; at most 0.3 closes the tract, 3 leaves it open.
* `cActive`: Constriction gate, 0 or 1.

#### Test
```
import("stdfaust.lib");
tractDiameters_test = pt.tractDiameters(12.9, 2.43, 30, 3, 0);
tractDiameters_constricted_test = pt.tractDiameters(20, 3.0, 30.4, 0.55, 1);
```

----

### `(pt.)tractDiameters2`

Same with two independent constrictions, applied in order like the original's
touch loop (each can only narrow what the previous ones left).

#### Usage

```
tractDiameters2(tongueIndex, tongueDiameter, c1i, c1d, c1a, c2i, c2d, c2a) : si.bus(44)
```

Where:

* `tongueIndex`: Tongue position in sections, 12..29 (default 12.9).
* `tongueDiameter`: Tongue diameter in model units, 2.05..3.5 (default 2.43).
* `c1i`: First constriction position in sections, 2..44.
* `c1d`: First touch diameter in model units, 0..3; at most 0.3 closes the tract.
* `c1a`: First constriction gate, 0 or 1.
* `c2i`: Second constriction position in sections, 2..44.
* `c2d`: Second touch diameter in model units, 0..3; at most 0.3 closes the tract.
* `c2a`: Second constriction gate, 0 or 1.

#### Test
```
import("stdfaust.lib");
tractDiameters2_test = pt.tractDiameters2(20, 3.0, 36.3, 0.5, 1, 20.6, 0.8, 1);
```

##  Tract waveguide 


----

### `(pt.)tract`

The Pink Trombone vocal tract: 44-section Kelly–Lochbaum waveguide with a
28-section nasal branch, ticked twice per sample. Diameters, constriction and
velum drive the reflection coefficients; fricative noise and closure-release
transients are injected into the waveguide.

#### Usage

```
tract(tongueIndex, tongueDiameter, cIndex, cDiameter, cActive, nasal, glottalOutput, noiseModulator) : _
```

Where:

* `tongueIndex`: Tongue position in sections, 12..29 (default 12.9).
* `tongueDiameter`: Tongue diameter in model units, 2.05..3.5 (default 2.43).
* `cIndex`: Constriction position in sections, 2..44; position 44 lies beyond the mouth cells.
* `cDiameter`: Touch diameter in model units, 0..3; at most 0.3 closes the tract, 3 leaves it open.
* `cActive`: Constriction gate, 0 or 1.
* `nasal`: Velum gate: positive selects diameter 0.4; zero selects 0.01.
* `glottalOutput`: Audio excitation from glottis or an external source.
* `noiseModulator`: Turbulence amplitude modulator, normally the second output of glottis.

#### Test
```
import("stdfaust.lib");
tract_test = (os.lf_imptrain(140), 0.3) : pt.tract(12.9, 2.43, 30, 3, 0, 0);
tract_nasal_test = (os.lf_imptrain(140), 0.3) : pt.tract(27, 2.2, 30, 3, 0, 1);
tract_closure_test = (os.lf_imptrain(140), 0.3) : pt.tract(12.9, 2.43, 40, 0, 1, 0);
tract_release_test = (os.lf_imptrain(140), 0.3) : pt.tract(12.9, 2.43, 30, 0, ba.time < 12000, 0);
```

----

### `(pt.)tract2`

`tract` with two independent constrictions (the original is multi-touch: each
touch narrows the tract and injects its own turbulence). Useful for consonant
clusters and double articulations.

#### Usage

```
tract2(tongueIndex, tongueDiameter, c1i, c1d, c1a, c2i, c2d, c2a, nasal, glottalOutput, noiseModulator) : _
```

Where:

* `tongueIndex`: Tongue position in sections, 12..29 (default 12.9).
* `tongueDiameter`: Tongue diameter in model units, 2.05..3.5 (default 2.43).
* `c1i`: First constriction position in sections, 2..44.
* `c1d`: First touch diameter in model units, 0..3; at most 0.3 closes the tract.
* `c1a`: First constriction gate, 0 or 1.
* `c2i`: Second constriction position in sections, 2..44.
* `c2d`: Second touch diameter in model units, 0..3; at most 0.3 closes the tract.
* `c2a`: Second constriction gate, 0 or 1.
* `nasal`: Velum gate: positive selects diameter 0.4; zero selects 0.01.
* `glottalOutput`: Audio excitation from glottis or an external source.
* `noiseModulator`: Turbulence amplitude modulator, normally the second output of glottis.

#### Test
```
import("stdfaust.lib");
tract2_test = (os.lf_imptrain(140), 0.3) : pt.tract2(12.9, 2.43, 36.3, 0.5, 1, 20.6, 0.8, 1, 0);
```

----

### `(pt.)tractExt`

Same as `tract` / `tract2` but with an explicit turbulence noise source (the
original's 1 kHz, Q 0.5 bandpassed white noise) as first argument, for testing.

With `fricNoise = 0` and *constant* articulation arguments, `tractExt`/`tract2Ext`
reduce to the bare linear waveguide, which is exactly LTI from `glottalOutput`
to the output: `_moveTowards` starts on its target, so constant articulation
never ramps, the reflection coefficients are constants, and no release
transient can fire. Its impulse response then characterises it completely
(useful for FIR/formant analysis of a fixed vocal-tract shape).

#### Usage

```
tractExt(fricNoise, tongueIndex, tongueDiameter, cIndex, cDiameter, cActive, nasal, glottalOutput, noiseModulator) : _
```

Where:

* `fricNoise`: External turbulence signal, typically white noise bandpassed at 1 kHz with Q 0.5; zero disables turbulence.
* `tongueIndex`: Tongue position in sections, 12..29 (default 12.9).
* `tongueDiameter`: Tongue diameter in model units, 2.05..3.5 (default 2.43).
* `cIndex`: Constriction position in sections, 2..44; position 44 lies beyond the mouth cells.
* `cDiameter`: Touch diameter in model units, 0..3; at most 0.3 closes the tract, 3 leaves it open.
* `cActive`: Constriction gate, 0 or 1.
* `nasal`: Velum gate: positive selects diameter 0.4; zero selects 0.01.
* `glottalOutput`: Audio excitation from glottis or an external source.
* `noiseModulator`: Turbulence amplitude modulator, normally the second output of glottis.

#### Test
```
import("stdfaust.lib");
tractExt_test = pt.tractExt(no.noise, 12.9, 2.43, 30.4, 0.55, 1, 0, os.lf_imptrain(140), 0.3);
```

----

### `(pt.)tract2Ext`

Vocal tract with two independent constrictions and an explicit turbulence source.
With zero turbulence and constant articulation, this is a linear time-invariant
filter of the glottal excitation. Constant articulation starts on its target.

#### Usage

```
tract2Ext(fricNoise, tongueIndex, tongueDiameter, c1i, c1d, c1a, c2i, c2d, c2a, nasal, glottalOutput, noiseModulator) : _
```

Where:

* `fricNoise`: External turbulence signal, typically white noise bandpassed at 1 kHz with Q 0.5; zero disables turbulence.
* `tongueIndex`: Tongue position in sections, 12..29 (default 12.9).
* `tongueDiameter`: Tongue diameter in model units, 2.05..3.5 (default 2.43).
* `c1i`: First constriction position in sections, 2..44.
* `c1d`: First touch diameter in model units, 0..3; at most 0.3 closes the tract.
* `c1a`: First constriction gate, 0 or 1.
* `c2i`: Second constriction position in sections, 2..44.
* `c2d`: Second touch diameter in model units, 0..3; at most 0.3 closes the tract.
* `c2a`: Second constriction gate, 0 or 1.
* `nasal`: Velum gate: positive selects diameter 0.4; zero selects 0.01.
* `glottalOutput`: Audio excitation from glottis or an external source.
* `noiseModulator`: Turbulence amplitude modulator, normally the second output of glottis.

#### Test
```
import("stdfaust.lib");
tract2Ext_test = pt.tract2Ext(no.noise, 12.9, 2.43, 36.3, 0.5, 1, 20.6, 0.8, 1, 0, os.lf_imptrain(140), 0.3);
```

##  Full instrument 


----

### `(pt.)pinkTrombone`

Glottis + tract. Mono output.

#### Usage

```
pinkTrombone(freq, tenseness, voiced, wobble, tongueIndex, tongueDiameter, cIndex, cDiameter, cActive, nasal) : _
```

Where:

* `freq`: Positive fundamental frequency in Hz; the demo spans about 87..277 Hz.
* `tenseness`: Voice tenseness in 0..1; the default is 0.6.
* `voiced`: Voice gate: positive is on, zero is off. It acts like a finger on the
  original's pitch keyboard: voicing ramps in and out, with no pressed onset.
* `wobble`: Pitch wobble amount in 0..1.
* `tongueIndex`: Tongue position in sections, 12..29 (default 12.9).
* `tongueDiameter`: Tongue diameter in model units, 2.05..3.5 (default 2.43).
* `cIndex`: Constriction position in sections, 2..44; position 44 lies beyond the mouth cells.
* `cDiameter`: Touch diameter in model units, 0..3; at most 0.3 closes the tract, 3 leaves it open.
* `cActive`: Constriction gate, 0 or 1.
* `nasal`: Velum gate: positive selects diameter 0.4; zero selects 0.01.

#### Test
```
import("stdfaust.lib");
pinkTrombone_test = pt.pinkTrombone(140, 0.6, 1, 0, 12.9, 2.43, 30, 3, 0, 0);
```

----

### `(pt.)pinkTrombone2`

Glottis + tract with two constrictions. Mono output.

#### Usage

```
pinkTrombone2(freq, tenseness, voiced, wobble, tongueIndex, tongueDiameter, c1i, c1d, c1a, c2i, c2d, c2a, nasal) : _
```

Where:

* `freq`: Positive fundamental frequency in Hz; the demo spans about 87..277 Hz.
* `tenseness`: Voice tenseness in 0..1; the default is 0.6.
* `voiced`: Voice gate: positive is on, zero is off. It acts like a finger on the
  original's pitch keyboard: voicing ramps in and out, with no pressed onset.
* `wobble`: Pitch wobble amount in 0..1.
* `tongueIndex`: Tongue position in sections, 12..29 (default 12.9).
* `tongueDiameter`: Tongue diameter in model units, 2.05..3.5 (default 2.43).
* `c1i`: First constriction position in sections, 2..44.
* `c1d`: First touch diameter in model units, 0..3; at most 0.3 closes the tract.
* `c1a`: First constriction gate, 0 or 1.
* `c2i`: Second constriction position in sections, 2..44.
* `c2d`: Second touch diameter in model units, 0..3; at most 0.3 closes the tract.
* `c2a`: Second constriction gate, 0 or 1.
* `nasal`: Velum gate: positive selects diameter 0.4; zero selects 0.01.

#### Test
```
import("stdfaust.lib");
pinkTrombone2_test = pt.pinkTrombone2(140, 0.6, 1, 0, 12.9, 2.43, 40, 0.2, 1, 20, 1.0, 1, 1);
```
