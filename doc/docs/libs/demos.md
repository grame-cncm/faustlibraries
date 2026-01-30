#  demos.lib 

Demos library. Its official prefix is `dm`.

This library provides a collection of example DSP algorithms and demonstrations
used to illustrate Faust features, syntax, and best practices. It includes simple
oscillators, filters, effects, and synthesis examples useful for learning and testing.

The Demos library is organized into 7 sections:

* [Analyzers](#analyzers)
* [Filters](#filters)
* [Effects](#effects)
* [Reverbs](#reverbs)
* [Generators](#generators)
* [Motion](#motion)
* [Hysteresis](#hysteresis)

#### References

* [https://github.com/grame-cncm/faustlibraries/blob/master/demos.lib](https://github.com/grame-cncm/faustlibraries/blob/master/demos.lib)

## Analyzers


----

### `(dm.)mth_octave_spectral_level_demo`

Demonstrate mth_octave_spectral_level in a standalone GUI.

#### Usage
```
_ : mth_octave_spectral_level_demo(BandsPerOctave) : _
_ : spectral_level_demo : _ // 2/3 octave

```
#### Test
```
dm = library("demos.lib");
no = library("noises.lib");
mth_octave_spectral_level_demo_test = no.noise : dm.mth_octave_spectral_level_demo(1.5);
spectral_level_demo_test = no.noise : dm.spectral_level_demo;
```

## Filters


----

### `(dm.)parametric_eq_demo`

A parametric equalizer application.

#### Usage:

```
_ : parametric_eq_demo : _

```
#### Test
```
dm = library("demos.lib");
no = library("noises.lib");
parametric_eq_demo_test = no.noise : dm.parametric_eq_demo;
```

----

### `(dm.)spectral_tilt_demo`

A spectral tilt application.

#### Usage

```
_ : spectral_tilt_demo(N) : _ 
```

Where:

* `N`: filter order (integer)

#### Test
```
dm = library("demos.lib");
no = library("noises.lib");
spectral_tilt_demo_test = no.noise : dm.spectral_tilt_demo(4);
```

All other parameters interactive

----

### `(dm.)mth_octave_filterbank_demo` and `(dm.)filterbank_demo`

Graphic Equalizer: each filter-bank output signal routes through a fader.

#### Usage

```
_ : mth_octave_filterbank_demo(M) : _
_ : filterbank_demo : _
```

Where:

* `M`: number of bands per octave

#### Test
```
dm = library("demos.lib");
no = library("noises.lib");
mth_octave_filterbank_demo_test = no.noise : dm.mth_octave_filterbank_demo(1);
filterbank_demo_test = no.noise : dm.filterbank_demo;
```

## Effects


----

### `(dm.)cubicnl_demo`

Distortion demo application.

#### Usage:

```
_ : cubicnl_demo : _

```
#### Test
```
dm = library("demos.lib");
no = library("noises.lib");
cubicnl_demo_test = no.noise : dm.cubicnl_demo;
```

----

### `(dm.)gate_demo`

Gate demo application.

#### Usage

```
_,_ : gate_demo : _,_

```
#### Test
```
dm = library("demos.lib");
no = library("noises.lib");
gate_demo_test = no.noise, no.noise : dm.gate_demo;
```

----

### `(dm.)compressor_demo`

Compressor demo application.

#### Usage

```
_,_ : compressor_demo : _,_

```
#### Test
```
dm = library("demos.lib");
no = library("noises.lib");
compressor_demo_test = no.noise, no.noise : dm.compressor_demo;
```

----

### `(dm.)moog_vcf_demo`

Illustrate and compare all three Moog VCF implementations above.

#### Usage

```
_ : moog_vcf_demo : _
```

#### Test
```
dm = library("demos.lib");
os = library("oscillators.lib");
moog_vcf_demo_test = os.osc(440) : dm.moog_vcf_demo;
```

----

### `(dm.)wah4_demo`

Wah pedal application.

#### Usage

```
_ : wah4_demo : _
```

#### Test
```
dm = library("demos.lib");
os = library("oscillators.lib");
wah4_demo_test = os.osc(440) : dm.wah4_demo;
```

----

### `(dm.)crybaby_demo`

Crybaby effect application.

#### Usage

```
_ : crybaby_demo : _
```

#### Test
```
dm = library("demos.lib");
os = library("oscillators.lib");
crybaby_demo_test = os.osc(440) : dm.crybaby_demo;
```

----

### `(dm.)flanger_demo`

Flanger effect application.

#### Usage

```
_,_ : flanger_demo : _,_
```

#### Test
```
dm = library("demos.lib");
os = library("oscillators.lib");
flanger_demo_test = os.osc(440), os.osc(442) : dm.flanger_demo;
```

----

### `(dm.)phaser2_demo`

Phaser effect demo application.

#### Usage

```
_,_ : phaser2_demo : _,_
```

#### Test
```
dm = library("demos.lib");
os = library("oscillators.lib");
phaser2_demo_test = os.osc(440), os.osc(442) : dm.phaser2_demo;
```

----

### `(dm.)tapeStop_demo`

Stereo tape-stop effect.

#### Usage

```
_,_ : tapeStop_demo : _,_
```

#### Test
```
dm = library("demos.lib");
os = library("oscillators.lib");
tapeStop_demo_test = os.osc(440), os.osc(442) : dm.tapeStop_demo;
```

## Reverbs


----

### `(dm.)freeverb_demo`

Freeverb demo application.

#### Usage

```
_,_ : freeverb_demo : _,_
```

#### Test
```
dm = library("demos.lib");
os = library("oscillators.lib");
freeverb_demo_test = os.osc(440), os.osc(442) : dm.freeverb_demo;
```

----

### `(dm.)springreverb_demo`

Mono spring-inspired reverb demo using `re.springreverb`.

#### Usage

```
_ : springreverb_demo : _
```

#### Test
```
dm = library("demos.lib");
os = library("oscillators.lib");
springreverb_demo_test = os.osc(220) : dm.springreverb_demo;
```

----

### `(dm.)stereo_reverb_tester`

Handy test inputs for reverberator demos below.

#### Usage

```
_,_ : stereo_reverb_tester(gui_group) : _,_
```
For suppressing the `gui_group` input, pass it as `!`.
(See `(dm.)fdnrev0_demo` for an example of its use).

#### Test
```
dm = library("demos.lib");
no = library("noises.lib");
stereo_reverb_tester_test = no.noise, no.noise : dm.stereo_reverb_tester(!);
```

----

### `(dm.)fdnrev0_demo`

A reverb application using `fdnrev0`.

#### Usage

```
_,_,_,_ : fdnrev0_demo(N,NB,BBSO) : _,_
```

Where:

* `N`: feedback Delay Network (FDN) order / number of delay lines used =
   order of feedback matrix / 2, 4, 8, or 16 [extend primes array below for
   32, 64, ...]
* `NB`: number of frequency bands / Number of (nearly) independent T60 controls
   / Integer 3 or greater
* `BBSO` : butterworth band-split order / order of lowpass/highpass bandsplit
   used at each crossover freq / odd positive integer

#### Test
```
dm = library("demos.lib");
no = library("noises.lib");
fdnrev0_demo_test = no.noise, no.noise : dm.fdnrev0_demo(16, 5, 3);
```

----

### `(dm.)zita_rev_fdn_demo`

Reverb demo application based on `zita_rev_fdn`.

#### Usage

```
si.bus(8) : zita_rev_fdn_demo : si.bus(8)
```

#### Test
```
dm = library("demos.lib");
os = library("oscillators.lib");
zita_rev_fdn_demo_test = par(i, 8, os.osc(440 + i)) : dm.zita_rev_fdn_demo;
```

----

### `(dm.)zita_light`

Light version of `dm.zita_rev1` with only 2 UI elements.

#### Usage

```
_,_ : zita_light : _,_
```

#### Test
```
dm = library("demos.lib");
os = library("oscillators.lib");
zita_light_test = os.osc(440), os.osc(442) : dm.zita_light;
```

----

### `(dm.)zita_rev1`

Example GUI for `zita_rev1_stereo` (mostly following the Linux `zita-rev1` GUI).

Only the dry/wet and output level parameters are "dezippered" here. If
parameters are to be varied in real time, use `smooth(0.999)` or the like
in the same way.

#### Usage

```
_,_ : zita_rev1 : _,_
```

#### Test
```
dm = library("demos.lib");
os = library("oscillators.lib");
zita_rev1_test = os.osc(440), os.osc(442) : dm.zita_rev1;
```

#### References

* [http://www.kokkinizita.net/linuxaudio/zita-rev1-doc/quickguide.html](http://www.kokkinizita.net/linuxaudio/zita-rev1-doc/quickguide.html)

----

### `(dm.)vital_rev_demo`

Example GUI for `vital_rev` with all parameters exposed.

#### Usage

```
_,_ : vital_rev_demo : _,_

```
#### Test
```
dm = library("demos.lib");
os = library("oscillators.lib");
vital_rev_demo_test = os.osc(440), os.osc(442) : dm.vital_rev_demo;
```

----

### `(dm.)reverbTank_demo`


This is a stereo reverb following the "ReverbTank" example in [1],
although some parameter ranges and scaling have been adjusted.
It is an unofficial version of the Spin Semiconductor® Reverb.
Other relevant instructional material can be found in [2-4].

#### Usage
```
_,_ : reverbTank_demo : _,_
```

#### Test
```
dm = library("demos.lib");
os = library("oscillators.lib");
reverbTank_demo_test = os.osc(440), os.osc(442) : dm.reverbTank_demo;
```

#### References

* [1] Pirkle, W. C. (2019). Designing audio effect plugins in C++ (2nd ed.). Chapter 17.14.

* [2] Spin Semiconductor. (n.d.). Reverberation. Retrieved 2024-04-16, from [http://www.spinsemi.com/knowledge_base/effects.html#Reverberation](http://www.spinsemi.com/knowledge_base/effects.html#Reverberation)

* [3] Zölzer, U. (2022). Digital audio signal processing (3rd ed.). Chapter 7, Figure 7.39.

* [4] Valhalla DSP. (2010, August 25). RIP Keith Barr. Retrieved 2024-04-16, from [https://valhalladsp.com/2010/08/25/rip-keith-barr/](https://valhalladsp.com/2010/08/25/rip-keith-barr/)

----

### `(dm.)kb_rom_rev1_demo`

Keith Barr reverb effect rom_rev1 demo application.

#### Usage

```
_,_ : kb_rom_rev1_demo : _,_
```

#### Test
```
dm = library("demos.lib");
os = library("oscillators.lib");
kb_rom_rev1_demo_test = os.osc(440), os.osc(442) : dm.kb_rom_rev1_demo;
```

----

### `(dm.)dattorro_rev_demo`

Example GUI for `dattorro_rev` with all parameters exposed and additional
dry/wet and output gain control.

#### Usage

```
_,_ : dattorro_rev_demo : _,_
```

#### Test
```
dm = library("demos.lib");
os = library("oscillators.lib");
dattorro_rev_demo_test = os.osc(440), os.osc(442) : dm.dattorro_rev_demo;
```

----

### `(dm.)jprev_demo`

Example GUI for `jprev` with all parameters exposed. 

#### Usage

```
_,_ : jprev_demo : _,_
```

#### Test
```
dm = library("demos.lib");
os = library("oscillators.lib");
jprev_demo_test = os.osc(440), os.osc(442) : dm.jprev_demo;
```

----

### `(dm.)greyhole_demo`

Example GUI for `greyhole` with all parameters exposed. 

#### Usage

```
_,_ : greyhole_demo : _,_

```
#### Test
```
dm = library("demos.lib");
os = library("oscillators.lib");
greyhole_demo_test = os.osc(440), os.osc(442) : dm.greyhole_demo;
```

## Generators


----

### `(dm.)sawtooth_demo`

An application demonstrating the different sawtooth oscillators of Faust.

#### Usage

```
sawtooth_demo : _
```

#### Test
```
dm = library("demos.lib");
sawtooth_demo_test = dm.sawtooth_demo;
```

----

### `(dm.)virtual_analog_oscillator_demo`

Virtual analog oscillator demo application.

#### Usage

```
virtual_analog_oscillator_demo : _
```

#### Test
```
dm = library("demos.lib");
virtual_analog_oscillator_demo_test = dm.virtual_analog_oscillator_demo;
```

----

### `(dm.)twin_osc_demo`

TwinOsc - virtual analog synthesis with a time-varying comb filter.

Based on: "Virtual Analog Synthesis with a Time-Varying Comb Filter"
D. Lowenfels, AES Convention 115, October 2003.

#### Usage

```
twin_osc_demo : _,_
```

#### Test
```
dm = library("demos.lib");
twin_osc_demo_test = dm.twin_osc_demo;
```

#### References

* [https://www.researchgate.net/publication/325654284](https://www.researchgate.net/publication/325654284)

----

### `(dm.)oscrs_demo` 

Simple application demoing filter based oscillators.

#### Usage

```
oscrs_demo : _
```

#### Test
```
dm = library("demos.lib");
oscrs_demo_test = dm.oscrs_demo;
```

----

### `(dm.)velvet_noise_demo`

Listen to velvet_noise!

#### Usage

```
velvet_noise_demo : _
```

#### Test
```
dm = library("demos.lib");
velvet_noise_demo_test = dm.velvet_noise_demo;
```

----

### `(dm.)latch_demo`

Illustrate latch operation.

#### Usage

```
echo 'import("stdfaust.lib");' > latch_demo.dsp
echo 'process = dm.latch_demo;' >> latch_demo.dsp
faust2octave latch_demo.dsp
Octave:1> plot(faustout);
```

#### Test
```
dm = library("demos.lib");
latch_demo_test = dm.latch_demo;
```

----

### `(dm.)envelopes_demo`

Illustrate various envelopes overlaid, including their gate * 1.1.

#### Usage

```
echo 'import("stdfaust.lib");' > envelopes_demo.dsp
echo 'process = dm.envelopes_demo;' >> envelopes_demo.dsp
faust2octave envelopes_demo.dsp
Octave:1> plot(faustout);
```

#### Test
```
dm = library("demos.lib");
envelopes_demo_test = dm.envelopes_demo;
```

----

### `(dm.)fft_spectral_level_demo`

Make a real-time spectrum analyzer using FFT from analyzers.lib.

#### Usage

```
echo 'import("stdfaust.lib");' > fft_spectral_level_demo.dsp
echo 'process = dm.fft_spectral_level_demo;' >> fft_spectral_level_demo.dsp
Mac:
  faust2caqt fft_spectral_level_demo.dsp
  open fft_spectral_level_demo.app
Linux GTK:
  faust2jack fft_spectral_level_demo.dsp
  ./fft_spectral_level_demo
Linux QT:
  faust2jaqt fft_spectral_level_demo.dsp
  ./fft_spectral_level_demo
```

#### Test
```
dm = library("demos.lib");
fft_spectral_level_demo_test = dm.fft_spectral_level_demo(256);
```

----

### `(dm.)reverse_echo_demo(nChans)`

Multichannel echo effect with reverse delays.

#### Usage

```
echo 'import("stdfaust.lib");' > reverse_echo_demo.dsp
echo 'nChans = 3; // Any integer > 1 should work here' >> reverse_echo_demo.dsp
echo 'process = dm.reverse_echo_demo(nChans);' >> reverse_echo_demo.dsp
Mac:
  faust2caqt reverse_echo_demo.dsp
  open reverse_echo_demo.app
Linux GTK:
  faust2jack reverse_echo_demo.dsp
  ./reverse_echo_demo
Linux QT:
  faust2jaqt reverse_echo_demo.dsp
  ./reverse_echo_demo
Etc.
```

#### Test
```
dm = library("demos.lib");
no = library("noises.lib");
reverse_echo_demo_test = no.noise : dm.reverse_echo_demo(3);
```

----

### `(dm.)pospass_demo`

Use Positive-Pass Filter pospass() to frequency-shift a sine tone.
First, a real sinusoid is converted to its analytic-signal form
using pospass() to filter out its negative frequency component.
Next, it is multiplied by a modulating complex sinusoid at the
shifting frequency to create the frequency-shifted result.
The real and imaginary parts are output to channels 1 & 2.
For a more interesting frequency-shifting example, check the
"Use Mic" checkbox to replace the input sinusoid by mic input.
Note that frequency shifting is not the same as frequency scaling.
A frequency-shifted harmonic signal is usually not harmonic.
Very small frequency shifts give interesting chirp effects when
there is feedback around the frequency shifter.

#### Usage

```
echo 'import("stdfaust.lib");' > pospass_demo.dsp
echo 'process = dm.pospass_demo;' >> pospass_demo.dsp
Mac:
  faust2caqt pospass_demo.dsp
  open pospass_demo.app
Linux GTK:
  faust2jack pospass_demo.dsp
  ./pospass_demo
Linux QT:
  faust2jaqt pospass_demo.dsp
  ./pospass_demo
Etc.
```

#### Test
```
dm = library("demos.lib");
os = library("oscillators.lib");
pospass_demo_test = os.osc(440) : dm.pospass_demo;
```

----

### `(dm.)exciter`

Psychoacoustic harmonic exciter, with GUI.

#### Usage

```
_ : exciter : _

```
#### Test
```
dm = library("demos.lib");
no = library("noises.lib");
exciter_test = no.noise : dm.exciter;
```

#### References

* [https://secure.aes.org/forum/pubs/ebriefs/?elib=16939](https://secure.aes.org/forum/pubs/ebriefs/?elib=16939)
* [https://www.researchgate.net/publication/258333577_Modeling_the_Harmonic_Exciter](https://www.researchgate.net/publication/258333577_Modeling_the_Harmonic_Exciter)

----

### `(dm.)vocoder_demo`

Use example of the vocoder function where an impulse train is used
as excitation.

#### Usage

```
_ : vocoder_demo : _

```
#### Test
```
dm = library("demos.lib");
os = library("oscillators.lib");
no = library("noises.lib");
vocoder_demo_test = no.noise : dm.vocoder_demo;
```

----

### `(dm.)colored_noise_demo`

A coloured noise signal generator.

#### Usage

```
colored_noise_demo : _
```

#### Test
```
dm = library("demos.lib");
colored_noise_demo_test = dm.colored_noise_demo;
```

## Motion

Motion, gravity, and orientation demos based on motion helpers.

----

### `(dm.)shock_trigger_demo`

Debounced shock trigger driving a tone. UI:

- [Auto Pulse] synths periodic impacts.
- [Pulse Rate] sets the tempo.
- [Axis Offset] trims the accelerometer input before HP/threshold.
- [High-pass], [Threshold], [Debounce] shape the trigger window.
- [Tone Frequency] sets the audible indicator driven by the shock gate.

#### Usage

```
shock_trigger_demo : _
```

#### Test
```
dm = library("demos.lib");
shock_trigger_demo_test = dm.shock_trigger_demo;
```

----

### `(dm.)projected_gravity_demo`

Gravity projection mapped to a low-pass filter sweep. UI:

- [Auto Tilt] + [Tilt Rate]/[Tilt Depth] synthesize rocking.
- [Axis Offset] biases the axis.
- [Low-pass] controls smoothing before projection
- [Offset] sets the dead-zone.
- [Noise Level] sets bed loudness; projection modulates filter cutoff.

#### Usage

```
projected_gravity_demo : _
```

#### Test
```
dm = library("demos.lib");
projected_gravity_demo_test = dm.projected_gravity_demo;
```

----

### `(dm.)total_accel_demo`

Total acceleration envelope mapped to noise amplitude. UI:

- [Auto Motion] + per-axis rates/depth synthesize movement; per-axis offsets bias inputs.
- [Threshold]/[Gain] set envelope detection.
- [Attack]/[Release] smooth it.
- Envelope scales the saw tone amplitude.

#### Usage

```
total_accel_demo : _
```

#### Test
```
dm = library("demos.lib");
total_accel_demo_test = dm.total_accel_demo;
```

----

### `(dm.)orientation6_demo`

Six-axis orientation weights mapped to six tonal channels. UI:

- [Auto Orbit] + [Orbit Rate]/[Depth] synthesize a 3D path; X/Y/Z knobs add offsets.
- Six [Shape ...] knobs tighten/loosen each face’s lobe.
- [Smooth] sets response time.
- Each weight drives a distinct tone channel.

#### Usage

```
orientation6_demo : _,_,_,_,_,_
```

#### Test
```
dm = library("demos.lib");
orientation6_demo_test = dm.orientation6_demo;
```

----

### `(dm.)motion_wrapper_demo`

End-to-end motion feature monitor built on motion.lib:

- Ingests six 3-axis IMUs (left arm, feet, back, right arm, head, stomach).
- Derives shock triggers, inclinometers, projected gravity, accel/gyro envelopes,
  six-face orientation weights per sensor, and raw/scaled axis taps.
- Exposes 92 UI-gated outputs matching the motion.lib signal names.

#### Usage

```
motion_wrapper_demo :
  (leftArm_x,  leftArm_y,  leftArm_z,
   feet_x,     feet_y,     feet_z,
   back_x,     back_y,     back_z,
   rightArm_x, rightArm_y, rightArm_z,
   head_x,     head_y,     head_z,
   stomach_x,  stomach_y,  stomach_z) -> 92 outputs
```

#### Test
```
dm = library("demos.lib");
motion_wrapper_demo_test = dm.motion_wrapper_demo;
```

## Hysteresis


----

### `(dm.)ja_transformer_demo`

Magnetic transformer saturation demo using Jiles-Atherton hysteresis.
Stereo processor with Pre-EQ, J-A hysteresis core, and inverse Post-EQ.

#### Usage

```
_,_ : ja_transformer_demo : _,_
```

#### Test
```
dm = library("demos.lib");
no = library("noises.lib");
ja_transformer_demo_test = no.noise, no.noise : dm.ja_transformer_demo;
```
