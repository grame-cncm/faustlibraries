#  noises.lib 

Noises library. Its official prefix is `no`.

This library provides various noise generators and stochastic signal sources
for audio synthesis and testing. It includes white, pink, brown, and blue noise,
as well as pseudo-random number generators and utilities for decorrelated signals
and random modulation in Faust DSP programs.

The Noises library is organized into 1 section:

* [Functions Reference](#functions-reference)

#### References

* [https://github.com/grame-cncm/faustlibraries/blob/master/noises.lib](https://github.com/grame-cncm/faustlibraries/blob/master/noises.lib)

## Functions Reference


----

### `(no.)noise`

White noise generator (outputs random number between -1 and 1).
`noise` is a standard Faust function.

#### Usage

```
noise : _
```

Where:

* output: white noise signal in [-1, 1].

#### Test
```
no = library("noises.lib");
noise_test = no.noise;
```

----

### `(no.)multirandom`

Generates multiple decorrelated random numbers in parallel.

#### Usage
```
multirandom(N) : si.bus(N)
```

Where:

* `N`: the number of decorrelated random numbers in parallel, a constant numerical expression

#### Test
```
no = library("noises.lib");
multirandom_test = no.multirandom(4);
```

----

### `(no.)multinoise`

Generates multiple decorrelated noises in parallel.

#### Usage

```
multinoise(N) : si.bus(N)
```

Where:

* `N`: the number of decorrelated random numbers in parallel, a constant numerical expression

#### Test
```
no = library("noises.lib");
multinoise_test = no.multinoise(3);
```

----

### `(no.)noises`

A convenient wrapper around multinoise.

#### Usage

```
noises(N,i) : _
```

Where:

* `N`: the number of decorrelated random numbers in parallel, a constant numerical expression
* `i`: the selected random number (i in [0..N[)

#### Test
```
no = library("noises.lib");
noises_test = no.noises(4, 2);
```

----

### `(no.)dnoise`

A deterministic noise burst with a dynamically adjustable seed, enabling consistent recall.
Useful for noise variation sensitive applications like replicable/recallable percussion sounds and waveguide excitation.

#### Usage

```
dnoise(t,sx) : _
```

Where:

* `t`: is a noise burst trigger
* `sx`: defines the range of integer seed multipliers. 

#### Test
```
no = library("noises.lib");
ba = library("basics.lib");
dnoise_test = (1 : ba.impulsify, 10.0) : no.dnoise;
```

#### Example 
This expression `sx = hslider("seed multiplier",1,1,1000,1)` allows 1000 distinct seed variations.
To generate a burst with a fixed length, use `ba.spulse(bLength, t)` (as trigger for the `t` parameter), where `bLength` is the burst duration in samples and `t` is a trigger.

----

### `(no.)randomseed`

A random seed based on the foreign function `arc4random`
(see man arc4random). Used in `rnoise`, `rmultirandom`, etc. to 
avoid having the same pseudo random sequence at each run.

WARNING: using the foreign function `arc4random`, so only available in C/C++ and LLVM backends.

#### Usage

```
randomseed : _
```

Where:

* output: platform-specific random seed value.

#### Test
```
no = library("noises.lib");
randomseed_test = no.randomseed;
```

----

### `(no.)rnoise`

A randomized white noise generator (outputs random number between -1 and 1).

WARNING: using the foreign function `arc4random`, so only available in C/C++ and LLVM backends.

#### Usage

```
rnoise : _
```

#### Test
```
no = library("noises.lib");
rnoise_test = no.rnoise;
```

----

### `(no.)rmultirandom`

Generates multiple decorrelated random numbers in parallel.

WARNING: using the foreign function `arc4random`, so only available in C/C++ and LLVM backends.

#### Usage
```
rmultirandom(N) : _
```

Where:

* `N`: the number of decorrelated random numbers in parallel, a constant numerical expression

#### Test
```
no = library("noises.lib");
rmultirandom_test = no.rmultirandom(4);
```

----

### `(no.)rmultinoise`

Generates multiple decorrelated noises in parallel.

WARNING: using the foreign function `arc4random`, so only available in C/C++ and LLVM backends.

#### Usage

```
rmultinoise(N) : _
```

Where:

* `N`: the number of decorrelated random numbers in parallel, a constant numerical expression

#### Test
```
no = library("noises.lib");
rmultinoise_test = no.rmultinoise(3);
```

----

### `(no.)rnoises`

A convenient wrapper around rmultinoise.

WARNING: using the foreign function `arc4random`, so only available in C/C++ and LLVM backends.

#### Usage

```
rnoises(N,i) : _
```

Where:

* `N`: the number of decorrelated random numbers in parallel
* `i`: the selected random number (i in [0..N[)

#### Test
```
no = library("noises.lib");
rnoises_test = no.rnoises(4, 2);
```

----

### `(no.)pink_noise`

Pink noise (1/f noise) generator (third-order approximation covering the audio band well).
`pink_noise` is a standard Faust function.

#### Usage
```
pink_noise : _
```

Where:

* output: pink (1/f) noise signal.

#### Test
```
no = library("noises.lib");
pink_noise_test = no.pink_noise;
```

#### Alternatives
Higher-order approximations covering any frequency band can be obtained using
```
no.noise : fi.spectral_tilt(order,lowerBandLimit,Bandwidth,p)
```
where `p=-0.5` means filter rolloff `f^(-1/2)` which gives 1/f rolloff in the
power spectral density, and can be changed to other real values.

#### Example
pink_noise_compare.dsp - compare three pinking filters
```
process = pink_noises with {
    f0 = 35; // Lower bandlimit in Hz
    bw3 = 0.7 * ma.SR/2.0 - f0; // Bandwidth in Hz, 3rd order case
    bw9 = 0.8 * ma.SR/2.0 - f0; // Bandwidth in Hz, 9th order case
    pink_tilt_3 = fi.spectral_tilt(3,f0,bw3,-0.5);
    pink_tilt_9 = fi.spectral_tilt(9,f0,bw9,-0.5);
    pink_noises = 1-1' <:
      no.pink_filter, // original designed by invfreqz in Octave
      pink_tilt_3,    // newer method using the same filter order
      pink_tilt_9;    // newer method using a higher filter order
};
```

#### Output of Example
```
faust2octave pink_noise_compare.dsp
Octave:1> semilogx(20*log10(abs(fft(faustout,8192))(1:4096,:)));
...
```
<img alt="pink_noise_demo figure" src="https://ccrma.stanford.edu/wiki/Images/8/86/Tpinkd.jpg" width="600" />

#### References

* [https://ccrma.stanford.edu/~jos/sasp/Example_Synthesis_1_F_Noise.html](https://ccrma.stanford.edu/~jos/sasp/Example_Synthesis_1_F_Noise.html)

----

### `(no.)pink_noise_vm`

Multi pink noise generator.

#### Usage

```
pink_noise_vm(N) : _
```

Where:

* `N`: number of latched white-noise processes to sum,
not to exceed sizeof(int) in C++ (typically 32).

#### Test
```
no = library("noises.lib");
pink_noise_vm_test = no.pink_noise_vm(4);
```

#### References

* [http://www.dsprelated.com/showarticle/908.php](http://www.dsprelated.com/showarticle/908.php)
* [http://www.firstpr.com.au/dsp/pink-noise/#Voss-McCartney](http://www.firstpr.com.au/dsp/pink-noise/#Voss-McCartney)

----

### `(no.)lfnoise`, `(no.)lfnoise0` and `(no.)lfnoiseN`

Low-frequency noise generators (Butterworth-filtered downsampled white noise).

#### Usage

```
lfnoise0(rate) : _   // new random number every int(ma.SR/rate) samples or so
lfnoiseN(N,rate) : _ // same as "lfnoise0(rate) : fi.lowpass(N,rate)" [see filters.lib]
lfnoise(rate) : _    // same as "lfnoise0(rate) : seq(i,5,fi.lowpass(N,rate))" (no overshoot)
```

#### Example

(view waveforms in faust2octave):

```
rate = ma.SR/100.0; // new random value every 100 samples (ma.SR from maths.lib)
process = lfnoise0(rate),   // sampled/held noise (piecewise constant)
          lfnoiseN(3,rate), // lfnoise0 smoothed by 3rd order Butterworth LPF
          lfnoise(rate);    // lfnoise0 smoothed with no overshoot
```

#### Test
```
no = library("noises.lib");
lfnoise0_test = no.lfnoise0(10.0);
lfnoiseN_test = no.lfnoiseN(3, 10.0);
lfnoise_test = no.lfnoise(10.0);
```

----

### `(no.)sparse_noise`

Sparse noise generator.

#### Usage

```
sparse_noise(f0) : _
```

Where:

* `f0`: average frequency of noise impulses per second

Random impulses in the amplitude range -1 to 1 are generated
at an average rate of f0 impulses per second.

#### Test
```
no = library("noises.lib");
sparse_noise_test = no.sparse_noise(5.0);
```

#### References

* See velvet_noise

----

### `(no.)velvet_noise_vm`

Velvet noise generator.

#### Usage

```
velvet_noise(amp, f0) : _
```

Where:

* `amp`: amplitude of noise impulses (positive and negative)
* `f0`: average frequency of noise impulses per second

#### Test
```
no = library("noises.lib");
velvet_noise_test = no.velvet_noise(0.5, 5.0);
```

#### References

* Matti Karjalainen and Hanna Jarvelainen,
  "Reverberation Modeling Using Velvet Noise",
  in Proc. 30th Int. Conf. Intelligent Audio Environments (AES07),
  March 2007.

----

### `(no.)gnoise`

Approximate zero-mean, unit-variance Gaussian white noise generator.

#### Usage

```
gnoise(N) : _
```

Where:

* `N`: number of uniform random numbers added to approximate Gaussian white noise

#### Test
```
no = library("noises.lib");
gnoise_test = no.gnoise(8);
```

#### References

* See Central Limit Theorem

----

### `(no.)colored_noise`

Generates a colored noise signal with an arbitrary spectral
roll-off factor (alpha) over the entire audible frequency range
(20-20000 Hz). The output is normalized so that an equal RMS
level is maintained for different values of alpha.

#### Usage

```
colored_noise(N,alpha) : _
```

Where:

* `N`: desired integer filter order (constant numerical expression)
* `alpha`: slope of roll-off, between -1 and 1. -1 corresponds to 
brown/red noise, -1/2 pink noise, 0 white noise, 1/2 blue noise,
and 1 violet/azure noise.


#### Test
```
no = library("noises.lib");
colored_noise_test = no.colored_noise(4, 0.0);
```

#### Examples
See `dm.colored_noise_demo`.

