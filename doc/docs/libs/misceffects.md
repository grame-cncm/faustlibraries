#  misceffects.lib 

Miscellaneous Effects library. Its official prefix is `ef`.

This library contains a collection of diverse audio effects and utilities
not included in other specialized Faust libraries. It includes filtering, mixing, time based, pitch shifters, 
and other creative or experimental signal processing components for sound design and musical applications.

The library is organized into 7 sections:

* [Dynamic](#dynamic)
* [Fibonacci](#fibonacci)
* [Filtering](#filtering)
* [Meshes](#meshes)
* [Mixing](#mixing)
* [Time Based](#time-based)
* [Pitch Shifting](#pitch-shifting)
* [Saturators](#saturators)

#### References

* [https://github.com/grame-cncm/faustlibraries/blob/master/misceffects.lib](https://github.com/grame-cncm/faustlibraries/blob/master/misceffects.lib)

## Dynamic


----

### `(ef.)cubicnl`

Cubic nonlinearity distortion.
`cubicnl` is a standard Faust function.

#### Usage:

```
_ : cubicnl(drive,offset) : _
_ : cubicnl_nodc(drive,offset) : _
```

Where:

* `drive`: distortion amount, between 0 and 1
* `offset`: constant added before nonlinearity to give even harmonics. Note: offset
   can introduce a nonzero mean - feed cubicnl output to dcblocker to remove this.

#### Test
```
ef = library("misceffects.lib");
os = library("oscillators.lib");
cubicnl_test = os.osc(440) : ef.cubicnl(0.5, 0.0);
cubicnl_nodc_test = os.osc(440) : ef.cubicnl_nodc(0.5, 0.0);
```

#### References

* [https://ccrma.stanford.edu/~jos/pasp/Cubic_Soft_Clipper.html](https://ccrma.stanford.edu/~jos/pasp/Cubic_Soft_Clipper.html)
* [https://ccrma.stanford.edu/~jos/pasp/Nonlinear_Distortion.html](https://ccrma.stanford.edu/~jos/pasp/Nonlinear_Distortion.html)

----

### `(ef.)gate_mono`

Mono signal gate.
`gate_mono` is a standard Faust function.

#### Usage

```
_ : gate_mono(thresh,att,hold,rel) : _
```

Where:

* `thresh`: dB level threshold above which gate opens (e.g., -60 dB)
* `att`: attack time = time constant (sec) for gate to open (e.g., 0.0001 s = 0.1 ms)
* `hold`: hold time = time (sec) gate stays open after signal level < thresh (e.g., 0.1 s)
* `rel`: release time = time constant (sec) for gate to close (e.g., 0.020 s = 20 ms)

#### Test
```
ef = library("misceffects.lib");
os = library("oscillators.lib");
gate_mono_test = os.osc(440) : ef.gate_mono(-60, 0.0001, 0.1, 0.02);
```

#### References

* [http://en.wikipedia.org/wiki/Noise_gate](http://en.wikipedia.org/wiki/Noise_gate)
* [http://www.soundonsound.com/sos/apr01/articles/advanced.asp](http://www.soundonsound.com/sos/apr01/articles/advanced.asp)
* [http://en.wikipedia.org/wiki/Gating_(sound_engineering)](http://en.wikipedia.org/wiki/Gating_(sound_engineering))

----

### `(ef.)gate_stereo`

Stereo signal gates.
`gate_stereo` is a standard Faust function.

#### Usage

```
 _,_ : gate_stereo(thresh,att,hold,rel) : _,_
```

Where:

* `thresh`: dB level threshold above which gate opens (e.g., -60 dB)
* `att`: attack time = time constant (sec) for gate to open (e.g., 0.0001 s = 0.1 ms)
* `hold`: hold time = time (sec) gate stays open after signal level < thresh (e.g., 0.1 s)
* `rel`: release time = time constant (sec) for gate to close (e.g., 0.020 s = 20 ms)

#### Test
```
ef = library("misceffects.lib");
os = library("oscillators.lib");
gate_stereo_test = os.osc(440), os.osc(441) : ef.gate_stereo(-60, 0.0001, 0.1, 0.02);
```

#### References

* [http://en.wikipedia.org/wiki/Noise_gate](http://en.wikipedia.org/wiki/Noise_gate)
* [http://www.soundonsound.com/sos/apr01/articles/advanced.asp](http://www.soundonsound.com/sos/apr01/articles/advanced.asp)
* [http://en.wikipedia.org/wiki/Gating_(sound_engineering)](http://en.wikipedia.org/wiki/Gating_(sound_engineering))

## Fibonacci


----

### `(ef.)fibonacci`

Fibonacci system where the current output is the current
input plus the sum of the previous N outputs.

#### Usage

```
_ : fibonacci(N) : _
```

Where:

* `N`: the Fibonacci system's order, where 2 is standard

#### Test
```
ef = library("misceffects.lib");
fibonacci_test = 0 : ef.fibonacci(2);
```

#### Example
Generate the famous series: [1, 1, 2, 3, 5, 8, 13, ...]

```
1. : ba.impulsify : fibonacci(2)
```

----

### `(ef.)fibonacciGeneral`

Fibonacci system with customizable coefficients.
The order of the system is inferred from the number of coefficients.

#### Usage

```
_ : fibonacciGeneral(wave) : _
```

Where:

* `wave`: a waveform such as `waveform{1, 1}`

#### Test
```
ef = library("misceffects.lib");
fibonacciGeneral_test = 0 : ef.fibonacciGeneral(waveform{2, 3});
```

#### Example:
Use the update equation `y = 2*y' + 3*y'' + 4*y'''`

```
1. : ba.impulsify : fibonacciGeneral(waveform{2, 3, 4})
```

----

### `(ef.)fibonacciSeq`

First N numbers of the Fibonacci sequence [1, 1, 2, 3, 5, 8, ...]
as parallel channels.

#### Usage

```
fibonacciSeq(N) : si.bus(N)
```

Where:

* `N`: The number of Fibonacci numbers to generate as channels.

#### Test
```
ef = library("misceffects.lib");
fibonacciSeq_test = ef.fibonacciSeq(5);
```


## Filtering


----

### `(ef.)speakerbp`

Dirt-simple speaker simulator (overall bandpass eq with observed
roll-offs above and below the passband). `speakerbp` is a standard Faust function.

Low-frequency speaker model = +12 dB/octave slope breaking to
flat near f1. Implemented using two dc blockers in series.

High-frequency model = -24 dB/octave slope implemented using a
fourth-order Butterworth lowpass.


#### Usage
```
_ : speakerbp(f1,f2) : _
```

#### Test
```
ef = library("misceffects.lib");
os = library("oscillators.lib");
speakerbp_test = os.osc(440) : ef.speakerbp(100.0, 5000.0);
```

#### Example

Based on measured Celestion G12 (12" speaker):
```
speakerbp(130,5000)
```

----

### `(ef.)piano_dispersion_filter`

Piano dispersion allpass filter in closed form.

#### Usage

```
piano_dispersion_filter(M,B,f0)
_ : piano_dispersion_filter(1,B,f0) : +(totalDelay),_ : fdelay(maxDelay) : _
```

Where:

* `M`: number of first-order allpass sections (compile-time only)
   Keep below 20. 8 is typical for medium-sized piano strings.
* `B`: string inharmonicity coefficient (0.0001 is typical)
* `f0`: fundamental frequency in Hz

#### Test
```
ef = library("misceffects.lib");
os = library("oscillators.lib");
piano_dispersion_filter_test = os.osc(110) : ef.piano_dispersion_filter(4, 0.0001, 110);
```

#### Outputs

* MINUS the estimated delay at `f0` of allpass chain in samples,
    provided in negative form to facilitate subtraction
    from delay-line length.
* Output signal from allpass chain

#### References

* "Dispersion Modeling in Waveguide Piano Synthesis Using Tunable
Allpass Filters", by Jukka Rauhala and Vesa Valimaki, DAFX-2006, pp. 71-76
* [http://lib.tkk.fi/Diss/2007/isbn9789512290666/article2.pdf](http://lib.tkk.fi/Diss/2007/isbn9789512290666/article2.pdf)
  An erratum in Eq. (7) is corrected in Dr. Rauhala's encompassing
  dissertation (and below).
* [http://www.acoustics.hut.fi/research/asp/piano/](http://www.acoustics.hut.fi/research/asp/piano/)

----

### `(ef.)stereo_width`

Stereo Width effect using the Blumlein Shuffler technique.
`stereo_width` is a standard Faust function.

#### Usage

```
_,_ : stereo_width(w) : _,_
```

Where:

* `w`: stereo width between 0 and 1

#### Test
```
ef = library("misceffects.lib");
os = library("oscillators.lib");
stereo_width_test = os.osc(440), os.osc(550) : ef.stereo_width(0.5);
```

At `w=0`, the output signal is mono ((left+right)/2 in both channels).
At `w=1`, there is no effect (original stereo image).
Thus, w between 0 and 1 varies stereo width from 0 to "original".

#### References

* "Applications of Blumlein Shuffling to Stereo Microphone Techniques"
Michael A. Gerzon, JAES vol. 42, no. 6, June 1994

## Meshes


----

### `(ef.)mesh_square`

Square Rectangular Digital Waveguide Mesh.

#### Usage

```
bus(4*N) : mesh_square(N) : bus(4*N)
```

Where:

* `N`: number of nodes along each edge - a power of two (1,2,4,8,...)

#### Test
```
ef = library("misceffects.lib");
mesh_square_test = (0,0,0,0) : ef.mesh_square(1);
```

#### Signal Order In and Out

The mesh is constructed recursively using 2x2 embeddings. Thus,
the top level of `mesh_square(M)` is a block 2x2 mesh, where each
block is a `mesh(M/2)`. Let these blocks be numbered 1,2,3,4 in the
geometry NW,NE,SW,SE, i.e., as:

        1 2
        3 4

Each block has four vector inputs and four vector outputs, where the
length of each vector is `M/2`. Label the input vectors as Ni,Ei,Wi,Si,
i.e., as the inputs from the North, East South, and West,
and similarly for the outputs. Then, for example, the upper
left input block of M/2 signals is labeled 1Ni. Most of the
connections are internal, such as 1Eo -> 2Wi. The `8*(M/2)` input
signals are grouped in the order:

       1Ni 2Ni
       3Si 4Si
       1Wi 3Wi
       2Ei 4Ei

and the output signals are:

       1No 1Wo
       2No 2Eo
       3So 3Wo
       4So 4Eo
or:

       In: 1No 1Wo 2No 2Eo 3So 3Wo 4So 4Eo
       Out: 1Ni 2Ni 3Si 4Si 1Wi 3Wi 2Ei 4Ei

Thus, the inputs are grouped by direction N,S,W,E, while the
outputs are grouped by block number 1,2,3,4, which can also be
interpreted as directions NW, NE, SW, SE.  A simple program
illustrating these orderings is `process = mesh_square(2);`.

#### Example

Reflectively terminated mesh impulsed at one corner:

```
mesh_square_test(N,x) = mesh_square(N)~(busi(4*N,x)) // input to corner
with { 
    busi(N,x) = bus(N) : par(i,N,*(-1)) : par(i,N-1,_), +(x); 
};
process = 1-1' : mesh_square_test(4); // all modes excited forever
```

In this simple example, the mesh edges are connected as follows:

       1No -> 1Ni, 1Wo -> 2Ni, 2No -> 3Si, 2Eo -> 4Si,
       3So -> 1Wi, 3Wo -> 3Wi, 4So -> 2Ei, 4Eo -> 4Ei

A routing matrix can be used to obtain other connection geometries.

#### References

* [https://ccrma.stanford.edu/~jos/pasp/Digital_Waveguide_Mesh.html](https://ccrma.stanford.edu/~jos/pasp/Digital_Waveguide_Mesh.html)


## Mixing


----

### `(ef.)dryWetMixer`

Linear dry-wet mixer for a N inputs and N outputs effect.

#### Usage

```
si.bus(inputs(FX)) : dryWetMixer(wetAmount, FX) : si.bus(inputs(FX))
```

Where:

* `wetAmount`: the wet amount (0-1). 0 produces only the dry signal and 1 produces only the wet signal
* `FX`: an arbitrary effect (N inputs and N outputs) to apply to the input bus

#### Test
```
ef = library("misceffects.lib");
os = library("oscillators.lib");
dryWetMixer_test = os.osc(440) : ef.dryWetMixer(0.5, fi.dcblocker);
```

----

### `(ef.)dryWetMixerConstantPower`

Constant-power dry-wet mixer for a N inputs and N outputs effect.

#### Usage

```
si.bus(inputs(FX)) : dryWetMixerConstantPower(wetAmount, FX) :si.bus(inputs(FX))
```

Where:

* `wetAmount`: the wet amount (0-1). 0 produces only the dry signal and 1 produces only the wet signal
* `FX`: an arbitrary effect (N inputs and N outputs) to apply to the input bus

#### Test
```
ef = library("misceffects.lib");
os = library("oscillators.lib");
dryWetMixerConstantPower_test = os.osc(440) : ef.dryWetMixerConstantPower(0.5, fi.dcblocker);
```

----

### `(ef.)mixLinearClamp`

Linear mixer for `N` buses, each with `C` channels. The output will be a sum of 2 buses
determined by the mixing index `mix`. 0 produces the first bus, 1 produces the
second, and so on. `mix` is clamped automatically. For example, `mixLinearClamp(4, 1, 1)`
will weight its 4 inputs by `(0, 1, 0, 0)`. Similarly, `mixLinearClamp(4, 1, 1.1)`
will weight its 4 inputs by `(0,.9,.1,0)`.

#### Usage

```
si.bus(N*C) : mixLinearClamp(N, C, mix) : si.bus(C)
```

Where:

* `N`: the number of input buses
* `C`: the number of channels in each bus
* `mix`: the mixing index, continuous in [0;N-1].

#### Test
```
ef = library("misceffects.lib");
mixLinearClamp_test = (1,0,0,0) : ef.mixLinearClamp(4, 1, 1.2);
```

----

### `(ef.)mixLinearLoop`

Linear mixer for `N` buses, each with `C` channels. Refer to `mixLinearClamp`. `mix`
will loop for multiples of `N`. For example, `mixLinearLoop(4, 1, 0)` has the same
effect as `mixLinearLoop(4, 1, -4)` and `mixLinearLoop(4, 1, 4)`.

#### Usage

```
si.bus(N*C) : mixLinearLoop(N, C, mix) : si.bus(C)
```

Where:

* `N`: the number of input buses
* `C`: the number of channels in each bus
* `mix`: the mixing index (N-1) selects the last bus, and 0 or N selects the 0th bus.

#### Test
```
ef = library("misceffects.lib");
mixLinearLoop_test = (1,0,0,0) : ef.mixLinearLoop(4, 1, -0.3);
```

----

### `(ef.)mixPowerClamp`

Constant-power mixer for `N` buses, each with `C` channels. The output will be a sum of 2 buses
determined by the mixing index `mix`. 0 produces the first bus, 1 produces the
second, and so on. `mix` is clamped automatically. `mixPowerClamp(4, 1, 1)`
will weight its 4 inputs by `(0, 1./sqrt(2), 0, 0)`. Similarly, `mixPowerClamp(4, 1, 1.5)`
will weight its 4 inputs by `(0,.5,.5,0)`.

#### Usage

```
si.bus(N*C) : mixPowerClamp(N, C, mix) : si.bus(C)
```

Where:

* `N`: the number of input buses
* `C`: the number of channels in each bus
* `mix`: the mixing index, continuous in [0;N-1].

#### Test
```
ef = library("misceffects.lib");
mixPowerClamp_test = (1,0,0,0) : ef.mixPowerClamp(4, 1, 1.5);
```

----

### `(ef.)mixPowerLoop`

Constant-power mixer for `N` buses, each with `C` channels. Refer to `mixPowerClamp`. `mix`
will loop for multiples of `N`. For example, `mixPowerLoop(4, 1, 0)` has the same effect
as `mixPowerLoop(4, 1, -4)` and `mixPowerLoop(4, 1, 4)`.

#### Usage

```
si.bus(N*C) : mixPowerLoop(N, C, mix) : si.bus(C)
```

Where:

* `N`: the number of input buses
* `C`: the number of channels in each bus
* `mix`: the mixing index (N-1) selects the last bus, and 0 or N selects the 0th bus.

#### Test
```
ef = library("misceffects.lib");
mixPowerLoop_test = (1,0,0,0) : ef.mixPowerLoop(4, 1, -0.5);
```

## Time Based


----

### `(ef.)echo`

A simple echo effect.
`echo` is a standard Faust function.

#### Usage

```
_ : echo(maxDuration,duration,feedback) : _
```

Where:

* `maxDuration`: the max echo duration in seconds
* `duration`: the echo duration in seconds
* `feedback`: the feedback coefficient
#### Test
```
ef = library("misceffects.lib");
os = library("oscillators.lib");
echo_test = os.osc(440) : ef.echo(0.5, 0.25, 0.4);
```

----

### `(ef.)reverseEchoN`

Reverse echo effect.

#### Usage

```
_ : ef.reverseEchoN(N,delay) : si.bus(N)
```

Where:

* `N`: Number of output channels desired (1 or more), a constant numerical expression
* `delay`: echo delay (integer power of 2)

#### Test
```
ef = library("misceffects.lib");
os = library("oscillators.lib");
reverseEchoN_test = os.osc(440) : ef.reverseEchoN(2, 32);
```

#### Demo

```
_ : dm.reverseEchoN(N) : _,_
```

#### Description

The effect uses N instances of `reverseDelayRamped` at different phases.


----

### `(ef.)reverseDelayRamped`

Reverse delay with amplitude ramp.

#### Usage

```
_ : ef.reverseDelayRamped(delay,phase) : _
```

Where:

* `delay`: echo delay (integer power of 2)
* `phase`: float between 0 and 1 giving ramp delay phase*delay

#### Test
```
ef = library("misceffects.lib");
os = library("oscillators.lib");
reverseDelayRamped_test = os.osc(440) : ef.reverseDelayRamped(32, 0.6);
```

#### Demo

```
_ : ef.reverseDelayRamped(32,0.6) : _,_
```


----

### `(ef.)uniformPanToStereo`

Pan nChans channels to the stereo field, spread uniformly left to right.

#### Usage

```
si.bus(N) : ef.uniformPanToStereo(N) : _,_
```

Where:

* `N`: Number of input channels to pan down to stereo, a constant numerical expression

#### Test
```
ef = library("misceffects.lib");
os = library("oscillators.lib");
uniformPanToStereo_test = os.osc(440), os.osc(550), os.osc(660) : ef.uniformPanToStereo(3);
```

#### Demo

```
_,_,_ : ef.uniformPanToStereo(3) : _,_
```


----

### `(ef.)tapeStop`

A tape-stop effect, like putting a finger on a vinyl record player.

#### Usage:

```
_,_ : tapeStop(2, LAGRANGE_ORDER, MAX_TIME_SAMP, 
              crossfade, gainAlpha, stopAlpha, stopTime, stop) : _,_
```

```
_ : tapeStop(1, LAGRANGE_ORDER, MAX_TIME_SAMP, 
             crossfade, gainAlpha, stopAlpha, stopTime, stop) : _
```

Where:

* `C`: The number of input and output channels.
* `LAGRANGE_ORDER`: The order of the Lagrange interpolation on the delay line. [2-3] recommended.
* `MAX_TIME_SAMP`: Maximum stop time in samples
* `crossfade`: A crossfade in samples to apply when resuming normal playback. Crossfade is not applied during the enabling of the tape-stop.
* `gainAlpha`: During the tape-stop, lower alpha stays louder longer. Safe values are in the range [.01,2].
* `stopAlpha`: `stopAlpha==1` represents a linear deceleration (constant force). `stopAlpha<1` represents an initially weaker, then stronger force. `stopAlpha>1` represents an initially stronger, then weaker force. Safe values are in the range [.01,2].
* `stopTime`: Desired duration of the stop time, in samples.
* `stop`: When `stop` becomes positive, the tape-stop effect will start. When `stop` becomes zero, normal audio will resume via crossfade.
#### Test
```
ef = library("misceffects.lib");
os = library("oscillators.lib");
tapeStop_test = os.osc(440), os.osc(441) : ef.tapeStop(2, 3, 44100, 128, 1.0, 1.0, 22050, button("stop"));
```

## Pitch Shifting


----

### `(ef.)transpose`

A simple pitch shifter based on 2 delay lines.
`transpose` is a standard Faust function.

#### Usage

```
_ : transpose(w, x, s) : _
```

Where:

* `w`: the window length (samples)
* `x`: crossfade duration duration (samples)
* `s`: shift (semitones)
#### Test
```
ef = library("misceffects.lib");
os = library("oscillators.lib");
transpose_test = os.osc(440) : ef.transpose(1024, 512, 7);
```

----

### `(ef.)doppler_shift`

Pitch shifter for signals with known fundamental frequency.
Uses Doppler effect from a continuously ramping delay line,
with phase-coherent phasor reset synced to the signal period.
Best suited for harmonic/periodic signals like oscillator outputs.

#### Usage

```
_ : doppler_shift(freq, ratio) : _
```

Where:

* `freq`: fundamental frequency of the input signal (Hz)
* `ratio`: pitch ratio (1.0 = no shift, 2.0 = octave up, 0.5 = octave down)

#### Test
```
ef = library("misceffects.lib");
os = library("oscillators.lib");
doppler_shift_test = os.sawtooth(220) : ef.doppler_shift(220, 1.5);
```

#### References

* [https://www.researchgate.net/publication/325654284](https://www.researchgate.net/publication/325654284)

## Saturators


----

### `(ef.)softclipQuadratic`

Quadratic softclip nonlinearity.

#### Usage

```
_ : softclipQuadratic : _
```

#### Test
```
ef = library("misceffects.lib");
os = library("oscillators.lib");
softclipQuadratic_test = os.osc(440) : ef.softclipQuadratic;
```

#### References

* U. Zölzer: Digital Audio Signal Processing. John Wiley & Sons Ltd, 2022.

----

### `(ef.)wavefold`

Wavefolding nonlinearity.

#### Usage

```
_ : wavefold(width) : _
```

Where:

* `width`: The width of the folded section [0..1] (float).

#### Test
```
ef = library("misceffects.lib");
os = library("oscillators.lib");
wavefold_test = os.osc(440) : ef.wavefold(0.5);
```
