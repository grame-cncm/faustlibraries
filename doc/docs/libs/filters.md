#  filters.lib 

Filters library. Its official prefix is `fi`.

This library provides a comprehensive collection of linear and nonlinear
filters used in audio and signal processing. It includes low-pass, high-pass,
band-pass, allpass, shelving, equalizer, and crossover filters, as well as advanced
analog and digital filter design sections for both educational and production use.

The Filters library is organized into 23 sections:

* [Basic Filters](#basic-filters)
* [Comb Filters](#comb-filters)
* [Direct-Form Digital Filter Sections](#direct-form-digital-filter-sections)
* [Direct-Form Second-Order Biquad Sections](#direct-form-second-order-biquad-sections)
* [Ladder/Lattice Digital Filters](#ladderlattice-digital-filters)
* [Useful Special Cases](#useful-special-cases)
* [Ladder/Lattice Allpass Filters](#ladderlattice-allpass-filters)
* [Digital Filter Sections Specified as Analog Filter Sections](#digital-filter-sections-specified-as-analog-filter-sections)
* [Simple Resonator Filters](#simple-resonator-filters)
* [Butterworth Lowpass/Highpass Filters](#butterworth-lowpasshighpass-filters)
* [Special Filter-Bank Delay-Equalizing Allpass Filters](#special-filter-bank-delay-equalizing-allpass-filters)
* [Elliptic (Cauer) Lowpass Filters](#elliptic-cauer-lowpass-filters)
* [Elliptic Highpass Filters](#elliptic-highpass-filters)
* [Butterworth Bandpass/Bandstop Filters](#butterworth-bandpassbandstop-filters)
* [Elliptic Bandpass Filters](#elliptic-bandpass-filters)
* [Parametric Equalizers (Shelf, Peaking)](#parametric-equalizers-shelf-peaking)
* [Mth-Octave Filter-Banks](#mth-octave-filter-banks)
* [Arbitrary-Crossover Filter-Banks and Spectrum Analyzers](#arbitrary-crossover-filter-banks-and-spectrum-analyzers)
* [State Variable Filters (SVF)](#state-variable-filters)
* [Linkwitz-Riley 4th-order 2-way, 3-way, and 4-way crossovers](#linkwitz-riley-4th-order-2-way-3-way-and-4-way-crossovers)
* [Standardized Filters](#standardized-filters)
* [Averaging Functions](#averaging-functions)
* [Kalman Filters](#kalman-filters)

#### References

* [https://github.com/grame-cncm/faustlibraries/blob/master/filters.lib](https://github.com/grame-cncm/faustlibraries/blob/master/filters.lib)

## Basic Filters


----

### `(fi.)zero`

One zero filter. Difference equation: \(y(n) = x(n) - zx(n-1)\).

#### Usage

```
_ : zero(z) : _
```

Where:

* `z`: location of zero along real axis in z-plane

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
zero_test = os.osc(440) : fi.zero(0.5);
```

#### References
* [https://ccrma.stanford.edu/~jos/filters/One_Zero.html](https://ccrma.stanford.edu/~jos/filters/One_Zero.html)

----

### `(fi.)pole`

One pole filter. Could also be called a "leaky integrator".
Difference equation: \(y(n) = x(n) + py(n-1)\).

#### Usage

```
_ : pole(p) : _
```

Where:

* `p`: pole location = feedback coefficient

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
pole_test = os.osc(440) : fi.pole(0.9);
```

#### References
* [https://ccrma.stanford.edu/~jos/filters/One_Pole.html](https://ccrma.stanford.edu/~jos/filters/One_Pole.html)

----

### `(fi.)integrator`

Same as `pole(1)` [implemented separately for block-diagram clarity].

#### Usage

```
_ : integrator : _
```

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
integrator_test = os.osc(440) : fi.integrator;
```

----

### `(fi.)dcblockerat`

DC blocker with configurable "break frequency".
The amplitude response is substantially flat above `fb`,
and sloped at about +6 dB/octave below `fb`.
Derived from the analog transfer function:
$$H(s) = \frac{s}{(s + 2 \pi f_b)}$$
(which can be seen as a 1st-order Butterworth highpass filter)
by the low-frequency-matching bilinear transform method
(i.e., using the typical frequency-scaling constant `2*SR`).

#### Usage

```
_ : dcblockerat(fb) : _
```

Where:

* `fb`: "break frequency" in Hz, i.e., -3 dB gain frequency (see 2nd reference below)

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
dcblockerat_test = os.osc(440) : fi.dcblockerat(30);
```

#### References

* [https://ccrma.stanford.edu/~jos/pasp/Bilinear_Transformation.html](https://ccrma.stanford.edu/~jos/pasp/Bilinear_Transformation.html)
* [https://ccrma.stanford.edu/~jos/spectilt/Bode_Plots.html](https://ccrma.stanford.edu/~jos/spectilt/Bode_Plots.html)

----

### `(fi.)dcblocker`

DC blocker. Default dc blocker has -3dB point near 35 Hz (at 44.1 kHz)
and high-frequency gain near 1.0025 (due to no scaling).
`dcblocker` is as standard Faust function.

#### Usage

```
_ : dcblocker : _
```

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
dcblocker_test = os.osc(440) : fi.dcblocker;
```

----

### `(fi.)lptN`

One-pole lowpass filter with arbitrary dis/charging factors set in dB and
times set in seconds.

#### Usage

```
_ : lptN(N, tN) : _
```

Where:

* `N`: is the attenuation factor in dB
* `tN`: is the filter period in seconds, that is, the time for the
impulse response to decay by `N` dB

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
lptN_test = os.osc(440) : fi.lptN(60, 0.1);
```

#### References

* [https://ccrma.stanford.edu/~jos/mdft/Exponentials.html](https://ccrma.stanford.edu/~jos/mdft/Exponentials.html)

----

### `(fi.)lptau`

One-pole lowpass with a tau time constant (1/e attenuation after `tN` seconds).

#### Usage

```
_ : lptau(tN) : _
```

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
lptau_test = os.osc(440) : fi.lptau(0.1);
```

----

### `(fi.)lpt60`

One-pole lowpass with a T60 time constant (60 dB attenuation after `tN` seconds).

#### Usage

```
_ : lpt60(tN) : _
```

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
lpt60_test = os.osc(440) : fi.lpt60(0.3);
```

----

### `(fi.)lpt19`

One-pole lowpass with a T19 time constant (approx. 19 dB attenuation after `tN` seconds).

#### Usage

```
_ : lpt19(tN) : _
```

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
lpt19_test = os.osc(440) : fi.lpt19(0.2);
```

## Comb Filters


----

### `(fi.)ff_comb`

Feed-Forward Comb Filter. Note that `ff_comb` requires integer delays
(uses `delay`  internally).
`ff_comb` is a standard Faust function.

#### Usage

```
_ : ff_comb(maxdel,intdel,b0,bM) : _
```

Where:

* `maxdel`: maximum delay (a power of 2)
* `intdel`: current (integer) comb-filter delay between 0 and maxdel
* `del`: current (float) comb-filter delay between 0 and maxdel
* `b0`: gain applied to delay-line input
* `bM`: gain applied to delay-line output and then summed with input

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
ff_comb_test = os.osc(440) : fi.ff_comb(2048, 64, 1, 0.7);
```

#### References

* [https://ccrma.stanford.edu/~jos/pasp/Feedforward_Comb_Filters.html](https://ccrma.stanford.edu/~jos/pasp/Feedforward_Comb_Filters.html)

----

### `(fi.)ff_fcomb`

Feed-Forward Comb Filter. Note that `ff_fcomb` takes floating-point delays
(uses `fdelay` internally).
`ff_fcomb` is a standard Faust function.

#### Usage

```
_ : ff_fcomb(maxdel,del,b0,bM) : _
```

Where:

* `maxdel`: maximum delay (a power of 2)
* `del`: current (float) comb-filter delay between 0 and maxdel
* `b0`: gain applied to delay-line input
* `bM`: gain applied to delay-line output and then summed with input

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
ff_fcomb_test = os.osc(440) : fi.ff_fcomb(2048, 64.5, 1, 0.7);
```

#### References

* [https://ccrma.stanford.edu/~jos/pasp/Feedforward_Comb_Filters.html](https://ccrma.stanford.edu/~jos/pasp/Feedforward_Comb_Filters.html)

----

### `(fi.)ffcombfilter`

Typical special case of `ff_comb()` where: `b0 = 1`.

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
ffcombfilter_test = os.osc(440) : fi.ffcombfilter(2048, 64, 0.7);
```

----

### `(fi.)fb_comb_common`

A generic feedback comb filter.

#### Usage

```
_ : fb_comb_common(dop,N,b0,aN) : _
```

Where

* `dop`: delay operator, e.g. `@` or `de.fdelay4a(2048)`
* `N`: current delay
* `b0`: gain applied to input
* `aN`: gain applied to delay-line output

#### Example test program

```
process = fb_comb_common(@,N,b0,aN);
```
implements the following difference equation:
```
y[n] = b0 x[n] + aN y[n - N]
```

See more examples in `filters.lib` below.

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
fb_comb_common_test = os.osc(440) : fi.fb_comb_common(@, 64, 0.8, 0.6);
```
--------------------------------------------------------

----

### `(fi.)fb_comb`

Feed-Back Comb Filter (integer delay).

#### Usage

```
_ : fb_comb(maxdel,del,b0,aN) : _
```

Where:

* `maxdel`: maximum delay (a power of 2)
* `del`: current (float) comb-filter delay between 0 and maxdel
* `b0`: gain applied to delay-line input and forwarded to output
* `aN`: minus the gain applied to delay-line output before summing with the input
    and feeding to the delay line

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
fb_comb_test = os.osc(440) : fi.fb_comb(2048, 64, 0.7, 0.6);
```

#### References

* [https://ccrma.stanford.edu/~jos/pasp/Feedback_Comb_Filters.html](https://ccrma.stanford.edu/~jos/pasp/Feedback_Comb_Filters.html)

----

### `(fi.)fb_fcomb`

Feed-Back Comb Filter (floating point delay).

#### Usage

```
_ : fb_fcomb(maxdel,del,b0,aN) : _
```

Where:

* `maxdel`: maximum delay (a power of 2)
* `del`: current (float) comb-filter delay between 0 and maxdel
* `b0`: gain applied to delay-line input and forwarded to output
* `aN`: minus the gain applied to delay-line output before summing with the input
    and feeding to the delay line

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
fb_fcomb_test = os.osc(440) : fi.fb_fcomb(2048, 64.5, 0.7, 0.6);
```

#### References

* [https://ccrma.stanford.edu/~jos/pasp/Feedback_Comb_Filters.html](https://ccrma.stanford.edu/~jos/pasp/Feedback_Comb_Filters.html)

----

### `(fi.)rev1`

Special case of `fb_comb` (`rev1(maxdel,N,g)`).
The "rev1 section" dates back to the 1960s in computer-music reverberation.
See the `jcrev` and `brassrev` in `reverbs.lib` for usage examples.

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
rev1_test = os.osc(440) : fi.rev1(2048, 64, 0.6);
```

----

### `(fi.)fbcombfilter` and `(fi.)ffbcombfilter`

Other special cases of Feed-Back Comb Filter.

#### Usage

```
_ : fbcombfilter(maxdel,intdel,g) : _
_ : ffbcombfilter(maxdel,del,g) : _
```

Where:

* `maxdel`: maximum delay (a power of 2)
* `intdel`: current (integer) comb-filter delay between 0 and maxdel
* `del`: current (float) comb-filter delay between 0 and maxdel
* `g`: feedback gain

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
fbcombfilter_test = os.osc(440) : fi.fbcombfilter(2048, 64, 0.6);
ffbcombfilter_test = os.osc(440) : fi.ffbcombfilter(2048, 64.5, 0.6);
```

#### References

* [https://ccrma.stanford.edu/~jos/pasp/Feedback_Comb_Filters.html](https://ccrma.stanford.edu/~jos/pasp/Feedback_Comb_Filters.html)

----

### `(fi.)allpass_comb`

Schroeder Allpass Comb Filter. Note that:

```
allpass_comb(maxlen,len,aN) = ff_comb(maxlen,len,aN,1) : fb_comb(maxlen,len-1,1,aN);
```

which is a direct-form-1 implementation, requiring two delay lines.
The implementation here is direct-form-2 requiring only one delay line.

#### Usage

```
_ : allpass_comb(maxdel,intdel,aN) : _
```

Where:

* `maxdel`: maximum delay (a power of 2)
* `intdel`: current (integer) comb-filter delay between 0 and maxdel
* `del`: current (float) comb-filter delay between 0 and maxdel
* `aN`: minus the feedback gain

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
allpass_comb_test = os.osc(440) : fi.allpass_comb(2048, 64, 0.6);
```

#### References

* [https://ccrma.stanford.edu/~jos/pasp/Allpass_Two_Combs.html](https://ccrma.stanford.edu/~jos/pasp/Allpass_Two_Combs.html)
* [https://ccrma.stanford.edu/~jos/pasp/Schroeder_Allpass_Sections.html](https://ccrma.stanford.edu/~jos/pasp/Schroeder_Allpass_Sections.html)
* [https://ccrma.stanford.edu/~jos/filters/Four_Direct_Forms.html](https://ccrma.stanford.edu/~jos/filters/Four_Direct_Forms.html)

----

### `(fi.)allpass_fcomb`

Schroeder Allpass Comb Filter. Note that:

```
allpass_comb(maxlen,len,aN) = ff_comb(maxlen,len,aN,1) : fb_comb(maxlen,len-1,1,aN);
```

which is a direct-form-1 implementation, requiring two delay lines.
The implementation here is direct-form-2 requiring only one delay line.

`allpass_fcomb` is a standard Faust library.

#### Usage

```
_ : allpass_comb(maxdel,intdel,aN) : _
_ : allpass_fcomb(maxdel,del,aN) : _
```

Where:

* `maxdel`: maximum delay (a power of 2)
* `intdel`: current (float) comb-filter delay between 0 and maxdel
* `del`: current (float) comb-filter delay between 0 and maxdel
* `aN`: minus the feedback gain

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
allpass_fcomb_test = os.osc(440) : fi.allpass_fcomb(2048, 64.5, 0.6);
```

#### References

* [https://ccrma.stanford.edu/~jos/pasp/Allpass_Two_Combs.html](https://ccrma.stanford.edu/~jos/pasp/Allpass_Two_Combs.html)
* [https://ccrma.stanford.edu/~jos/pasp/Schroeder_Allpass_Sections.html](https://ccrma.stanford.edu/~jos/pasp/Schroeder_Allpass_Sections.html)
* [https://ccrma.stanford.edu/~jos/filters/Four_Direct_Forms.html](https://ccrma.stanford.edu/~jos/filters/Four_Direct_Forms.html)

----

### `(fi.)rev2`

Special case of `allpass_comb` (`rev2(maxlen,len,g)`).
The "rev2 section" dates back to the 1960s in computer-music reverberation.
See the `jcrev` and `brassrev` in `reverbs.lib` for usage examples.

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
rev2_test = os.osc(440) : fi.rev2(2048, 64, 0.6);
```

----

### `(fi.)allpass_fcomb5` and `(fi.)allpass_fcomb1a`

Same as `allpass_fcomb` but use `fdelay5` and `fdelay1a` internally
(Interpolation helps - look at an fft of faust2octave on:
`1-1' <: allpass_fcomb(1024,10.5,0.95), allpass_fcomb5(1024,10.5,0.95);`)

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
allpass_fcomb5_test = os.osc(440) : fi.allpass_fcomb5(2048, 64.5, 0.6);
allpass_fcomb1a_test = os.osc(440) : fi.allpass_fcomb1a(2048, 64.5, 0.6);
```

## Direct-Form Digital Filter Sections


----

### `(fi.)iir`

Nth-order Infinite-Impulse-Response (IIR) digital filter,
implemented in terms of the Transfer-Function (TF) coefficients.
Such filter structures are termed "direct form".

`iir` is a standard Faust function.

#### Usage

```
_ : iir(bcoeffs,acoeffs) : _
```

Where:

* `bcoeffs`: (b0,b1,...,b_order) = TF numerator coefficients
* `acoeffs`: (a1,...,a_order) = TF denominator coeffs (a0=1)

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
iir_test = os.osc(440) : fi.iir((0.5, 0.5), (0.3));
```

#### References

* [https://ccrma.stanford.edu/~jos/filters/Four_Direct_Forms.html](https://ccrma.stanford.edu/~jos/filters/Four_Direct_Forms.html)

----

### `(fi.)fir`

FIR filter (convolution of FIR filter coefficients with a signal). `fir` is standard Faust function.

#### Usage

```
_ : fir(bv) : _
```

Where:

* `bv` = b0,b1,...,bn is a parallel bank of coefficient signals.

#### Note

`bv` is processed using pattern-matching at compile time,
      so it must have this normal form (parallel signals).

#### Example test program

Smoothing white noise with a five-point moving average:

```
bv = .2,.2,.2,.2,.2;
process = noise : fir(bv);
```

Equivalent (note double parens):

```
process = noise : fir((.2,.2,.2,.2,.2));
```

----

### `(fi.)conv` and `(fi.)convN`

Convolution of input signal with given coefficients.

#### Usage

```
_ : conv((k1,k2,k3,...,kN)) : _ // Argument = one signal bank
_ : convN(N,(k1,k2,k3,...)) : _ // Useful when N < count((k1,...))
```

----

### `(fi.)tf1`, `(fi.)tf2` and `(fi.)tf3`

tfN = N'th-order direct-form digital filter.

#### Usage

```
_ : tf1(b0,b1,a1) : _
_ : tf2(b0,b1,b2,a1,a2) : _
_ : tf3(b0,b1,b2,b3,a1,a2,a3) : _
```

Where:

* `b`: transfer-function numerator
* `a`: transfer-function denominator (monic)

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
tf1_test = os.osc(440) : fi.tf1(0.5, 0.25, -0.4);
tf2_test = os.osc(440) : fi.tf2(0.1, 0.2, 0.1, -0.5, 0.06);
tf3_test = os.osc(440) : fi.tf3(0.1, 0.3, 0.3, 0.1, -0.9, 0.26, -0.024);
```

#### References

* [https://ccrma.stanford.edu/~jos/fp/Direct_Form_I.html](https://ccrma.stanford.edu/~jos/fp/Direct_Form_I.html)

----

### `(fi.)notchw`

Simple notch filter based on a biquad (`tf2`).
`notchw` is a standard Faust function.

#### Usage:

```
_ : notchw(width,freq) : _
```

Where:

* `width`: "notch width" in Hz (approximate)
* `freq`: "notch frequency" in Hz

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
notchw_test = os.osc(440) : fi.notchw(200, 1000);
```

#### References

* [https://ccrma.stanford.edu/~jos/pasp/Phasing_2nd_Order_Allpass_Filters.html](https://ccrma.stanford.edu/~jos/pasp/Phasing_2nd_Order_Allpass_Filters.html)

## Direct-Form Second-Order Biquad Sections

Direct-Form Second-Order Biquad Sections

#### References

* [https://ccrma.stanford.edu/~jos/filters/Four_Direct_Forms.html](https://ccrma.stanford.edu/~jos/filters/Four_Direct_Forms.html)

----

### `(fi.)tf21`, `(fi.)tf22`, `(fi.)tf22t` and `(fi.)tf21t`

tfN = N'th-order direct-form digital filter where:

* `tf21` is tf2, direct-form 1
* `tf22` is tf2, direct-form 2
* `tf22t` is tf2, direct-form 2 transposed
* `tf21t` is tf2, direct-form 1 transposed

#### Usage

```
_ : tf21(b0,b1,b2,a1,a2) : _
_ : tf22(b0,b1,b2,a1,a2) : _
_ : tf22t(b0,b1,b2,a1,a2) : _
_ : tf21t(b0,b1,b2,a1,a2) : _
```

Where:

* `b`: transfer-function numerator
* `a`: transfer-function denominator (monic)

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
tf21_test = os.osc(440) : fi.tf21(0.1, 0.2, 0.1, -0.5, 0.06);
tf22_test = os.osc(440) : fi.tf22(0.1, 0.2, 0.1, -0.5, 0.06);
tf22t_test = os.osc(440) : fi.tf22t(0.1, 0.2, 0.1, -0.5, 0.06);
tf21t_test = os.osc(440) : fi.tf21t(0.1, 0.2, 0.1, -0.5, 0.06);
```

#### References

* [https://ccrma.stanford.edu/~jos/fp/Direct_Form_I.html](https://ccrma.stanford.edu/~jos/fp/Direct_Form_I.html)

##  Ladder/Lattice Digital Filters 

Ladder and lattice digital filters generally have superior numerical
properties relative to direct-form digital filters.  They can be derived
from digital waveguide filters, which gives them a physical interpretation.
#### References

* F. Itakura and S. Saito: "Digital Filtering Techniques for Speech Analysis and Synthesis",
    7th Int. Cong. Acoustics, Budapest, 25 C 1, 1971.
* J. D. Markel and A. H. Gray: Linear Prediction of Speech, New York: Springer Verlag, 1976.
* [https://ccrma.stanford.edu/~jos/pasp/Conventional_Ladder_Filters.html](https://ccrma.stanford.edu/~jos/pasp/Conventional_Ladder_Filters.html)

----

### `(fi.)av2sv`

Compute reflection coefficients sv from transfer-function denominator av.

#### Usage

```
sv = av2sv(av)
```

Where:

* `av`: parallel signal bank `a1,...,aN`
* `sv`: parallel signal bank `s1,...,sN`

where `ro = ith` reflection coefficient, and
      `ai` = coefficient of `z^(-i)` in the filter
         transfer-function denominator `A(z)`.

#### Test
```
fi = library("filters.lib");
si = library("signals.lib");
av2sv_test = fi.av2sv((-0.4, 0.1)) : si.bus(2);
```

#### References

*   [https://ccrma.stanford.edu/~jos/filters/Step_Down_Procedure.html](https://ccrma.stanford.edu/~jos/filters/Step_Down_Procedure.html)
  (where reflection coefficients are denoted by k rather than s).

----

### `(fi.)bvav2nuv`

Compute lattice tap coefficients from transfer-function coefficients.

#### Usage

```
nuv = bvav2nuv(bv,av)
```

Where:

* `av`: parallel signal bank `a1,...,aN`
* `bv`: parallel signal bank `b0,b1,...,aN`
* `nuv`: parallel signal bank  `nu1,...,nuN`

where `nui` is the i'th tap coefficient,
      `bi` is the coefficient of `z^(-i)` in the filter numerator,
      `ai` is the coefficient of `z^(-i)` in the filter denominator

#### Test
```
fi = library("filters.lib");
si = library("signals.lib");
bvav2nuv_test = fi.bvav2nuv((0.1, 0.2, 0.3), (-0.4, 0.1)) : si.bus(3);
```

----

### `(fi.)iir_lat2`

Two-multiply lattice IIR filter of arbitrary order.

#### Usage

```
_ : iir_lat2(bv,av) : _
```

Where:

* `bv`: transfer-function numerator
* `av`: transfer-function denominator (monic)

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
iir_lat2_test = os.osc(440) : fi.iir_lat2((0.1, 0.2, 0.3), (-0.4, 0.1));
```

----

### `(fi.)allpassnt`

Two-multiply lattice allpass (nested order-1 direct-form-ii allpasses), with taps.

#### Usage

```
_ : allpassnt(n,sv) : si.bus(n+1)
```

Where:

* `n`: the order of the filter
* `sv`: the reflection coefficients (-1 1)

The first output is the n-th order allpass output,
while the remaining outputs are taps taken from the
input of each delay element from the input to the output.
See (fi.)allpassn for the single-output case.

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
si = library("signals.lib");
allpassnt_test = os.osc(440) : fi.allpassnt(2, (0.3, -0.2)) : si.bus(3);
```

----

### `(fi.)iir_kl`

Kelly-Lochbaum ladder IIR filter of arbitrary order.

#### Usage

```
_ : iir_kl(bv,av) : _
```

Where:

* `bv`: transfer-function numerator
* `av`: transfer-function denominator (monic)

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
iir_kl_test = os.osc(440) : fi.iir_kl((0.1, 0.2, 0.3), (-0.4, 0.1));
```

----

### `(fi.)allpassnklt`

Kelly-Lochbaum ladder allpass.

#### Usage:

```
_ : allpassnklt(n,sv) : _
```

Where:

* `n`: the order of the filter
* `sv`: the reflection coefficients (-1 1)

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
si = library("signals.lib");
allpassnklt_test = os.osc(440) : fi.allpassnklt(2, (0.3, -0.2)) : si.bus(3);
```

----

### `(fi.)iir_lat1`

One-multiply lattice IIR filter of arbitrary order.

#### Usage

```
_ : iir_lat1(bv,av) : _
```

Where:

* bv: transfer-function numerator as a bank of parallel signals
* av: transfer-function denominator as a bank of parallel signals

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
iir_lat1_test = os.osc(440) : fi.iir_lat1((0.1, 0.2, 0.3), (-0.4, 0.1));
```

----

### `(fi.)allpassn1mt`

One-multiply lattice allpass with tap lines.

#### Usage

```
_ : allpassn1mt(N,sv) : _
```

Where:

* `N`: the order of the filter (fixed at compile time)
* `sv`: the reflection coefficients (-1 1)

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
si = library("signals.lib");
allpassn1mt_test = os.osc(440) : fi.allpassn1mt(2, (0.3, -0.2)) : si.bus(3);
```

----

### `(fi.)iir_nl`

Normalized ladder filter of arbitrary order.

#### Usage

```
_ : iir_nl(bv,av) : _
```

Where:

* `bv`: transfer-function numerator
* `av`: transfer-function denominator (monic)

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
iir_nl_test = os.osc(440) : fi.iir_nl((0.1, 0.2, 0.3), (-0.4, 0.1));
```

#### References

* J. D. Markel and A. H. Gray, Linear Prediction of Speech, New York: Springer Verlag, 1976.
* [https://ccrma.stanford.edu/~jos/pasp/Normalized_Scattering_Junctions.html](https://ccrma.stanford.edu/~jos/pasp/Normalized_Scattering_Junctions.html)

----

### `(fi.)allpassnnlt`

Normalized ladder allpass filter of arbitrary order.

#### Usage:

```
_ : allpassnnlt(N,sv) : _
```

Where:

* `N`: the order of the filter (fixed at compile time)
* `sv`: the reflection coefficients (-1 1)

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
si = library("signals.lib");
allpassnnlt_test = os.osc(440) : fi.allpassnnlt(2, (0.3, -0.2)) : si.bus(3);
```

#### References

* J. D. Markel and A. H. Gray, Linear Prediction of Speech, New York: Springer Verlag, 1976.
* [https://ccrma.stanford.edu/~jos/pasp/Normalized_Scattering_Junctions.html](https://ccrma.stanford.edu/~jos/pasp/Normalized_Scattering_Junctions.html)

## Useful Special Cases


----

### `(fi.)tf2np`

Biquad based on a stable second-order Normalized Ladder Filter
(more robust to modulation than `tf2` and protected against instability).

#### Usage

```
_ : tf2np(b0,b1,b2,a1,a2) : _
```

Where:

* `b`: transfer-function numerator
* `a`: transfer-function denominator (monic)

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
tf2np_test = os.osc(440) : fi.tf2np(0.6, 0.3, 0.2, -0.5, 0.2);
```

----

### `(fi.)wgr`

Second-order transformer-normalized digital waveguide resonator.

#### Usage

```
_ : wgr(f,r) : _
```

Where:

* `f`: resonance frequency (Hz)
* `r`: loss factor for exponential decay (set to 1 to make a numerically stable oscillator)

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
wgr_test = fi.wgr(440, 0.995, os.osc(440));
```

#### References

* [https://ccrma.stanford.edu/~jos/pasp/Power_Normalized_Waveguide_Filters.html](https://ccrma.stanford.edu/~jos/pasp/Power_Normalized_Waveguide_Filters.html)
* [https://ccrma.stanford.edu/~jos/pasp/Digital_Waveguide_Oscillator.html](https://ccrma.stanford.edu/~jos/pasp/Digital_Waveguide_Oscillator.html)

----

### `(fi.)nlf2`

Second order normalized digital waveguide resonator.

#### Usage

```
_ : nlf2(f,r) : _
```

Where:

* `f`: resonance frequency (Hz)
* `r`: loss factor for exponential decay (set to 1 to make a sinusoidal oscillator)

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
nlf2_test = fi.nlf2(440, 0.995, os.osc(440));
```

#### References

* [https://ccrma.stanford.edu/~jos/pasp/Power_Normalized_Waveguide_Filters.html](https://ccrma.stanford.edu/~jos/pasp/Power_Normalized_Waveguide_Filters.html)

----

### `(fi.)apnl`

Passive Nonlinear Allpass based on Pierce switching springs idea.
Switch between allpass coefficient `a1` and `a2` at signal zero crossings.

#### Usage

```
_ : apnl(a1,a2) : _
```

Where:

* `a1` and `a2`: allpass coefficients

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
apnl_test = fi.apnl(0.5, -0.5, os.osc(440));
```

#### References

* "A Passive Nonlinear Digital Filter Design ..." by John R. Pierce and Scott
A. Van Duyne, JASA, vol. 101, no. 2, pp. 1120-1126, 1997

## Ladder/Lattice Allpass Filters

An allpass filter has gain 1 at every frequency, but variable phase.
Ladder/lattice allpass filters are specified by reflection coefficients.
They are defined here as nested allpass filters, hence the names `allpassn*`.

#### References

* [https://ccrma.stanford.edu/~jos/pasp/Conventional_Ladder_Filters.html](https://ccrma.stanford.edu/~jos/pasp/Conventional_Ladder_Filters.html)
* [https://ccrma.stanford.edu/~jos/pasp/Nested_Allpass_Filters.html](https://ccrma.stanford.edu/~jos/pasp/Nested_Allpass_Filters.html)
* Linear Prediction of Speech, Markel and Gray, Springer Verlag, 1976

----

### `(fi.)scatN`

N-port scattering junction.

#### Usage

```
si.bus(N) : scatN(N,av,filter) : si.bus(N)
```

Where:

* `N`: number of incoming/outgoing waves
* `av`: vector (list) of `N` alpha parameters (each between 0 and 2, and normally summing to 2): [https://ccrma.stanford.edu/~jos/pasp/Alpha_Parameters.html](https://ccrma.stanford.edu/~jos/pasp/Alpha_Parameters.html)
* `filter` : optional junction filter to apply (`_` for none, see below)

With no filter:

- The junction is _lossless_ when the alpha parameters sum to 2 ("allpass").
- The junction is _passive_ but lossy when the alpha parameters sum to less than 2 ("resistive loss").
- Dynamic and reactive junctions are obtained using the `filter` argument.
  For guaranteed stability, the filter should be _positive real_. (See 2nd ref. below).

For \(N=2\) (two-port scattering), the reflection coefficient \(\rho\) corresponds
to alpha parameters \(1\pm\rho\).

#### Example: Whacky echo chamber made of 16 lossless "acoustic tubes":

```
process = _ : *(1.0/sqrt(N)) <: daisyRev(16,2,0.9999) :> _,_ with { 
  daisyRev(N,Dp2,G) = si.bus(N) : (si.bus(2*N) :> si.bus(N)
    : fi.scatN(N, par(i,N,2*G/float(N)), fi.lowpass(1,5000.0))
    : par(i,N,de.delay(DS(i),DS(i)-1))) ~ si.bus(N) with { DS(i) = 2^(Dp2+i); };
};
```

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
scatN_test = (os.osc(440), os.osc(660)) : fi.scatN(2, (1, 1), _);
```

#### References

* [https://ccrma.stanford.edu/~jos/pasp/Loaded_Waveguide_Junctions.html](https://ccrma.stanford.edu/~jos/pasp/Loaded_Waveguide_Junctions.html)
* [https://ccrma.stanford.edu/~jos/pasp/Passive_String_Terminations.html](https://ccrma.stanford.edu/~jos/pasp/Passive_String_Terminations.html)
* [https://ccrma.stanford.edu/~jos/pasp/Unloaded_Junctions_Alpha_Parameters.html](https://ccrma.stanford.edu/~jos/pasp/Unloaded_Junctions_Alpha_Parameters.html)

----

### `(fi.)scat`

Scatter off of reflectance r with reflection coefficient s.

#### Usage:

```
_ : scat(s,r) : _
```
#### Where:

* `s`: reflection coefficient between -1 and 1 for stability
* `r`: single-input, single-output block diagram,
       having gain less than 1 at all frequencies for stability.

#### Example: the following program should produce all zeros:

```
process = fi.allpassn(3,(.3,.2,.1)), fi.scat(.1, fi.scat(.2, fi.scat(.3, _)))
          :> - : ^(2) : +~_;
```

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
scat_test = os.osc(440) : fi.scat(0.5, _);
```

#### References

* [https://ccrma.stanford.edu/~jos/pasp/Scattering_Impedance_Changes.html](https://ccrma.stanford.edu/~jos/pasp/Scattering_Impedance_Changes.html)

----

### `(fi.)allpassn`

Two-multiply lattice filter.

#### Usage:

```
_ : allpassn(n,sv) : _
```
#### Where:

* `n`: the order of the filter
* `sv`: the reflection coefficients (-1 1)
* `sv`: the reflection coefficients  (s1,s2,...,sN), each between -1 and 1.

Equivalent to `fi.allpassnt(n,sv) : _, par(i,n,!);`

Equivalent to `fi.scat( s(n), fi.scat( s(n-1), ..., fi.scat( s(1), _ )))
              with { s(k) = ba.take(k,sv); } ;`

Identical to `allpassn` in `old/filter.lib`.

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
allpassn_test = os.osc(440) : fi.allpassn(3, (0.3, 0.2, 0.1));
```

#### References

* J. D. Markel and A. H. Gray: Linear Prediction of Speech, New York: Springer Verlag, 1976.
* [https://ccrma.stanford.edu/~jos/pasp/Conventional_Ladder_Filters.html](https://ccrma.stanford.edu/~jos/pasp/Conventional_Ladder_Filters.html)

----

### `(fi.)allpassnn`

Normalized form - four multiplies and two adds per section,
but coefficients can be time varying and nonlinear without
"parametric amplification" (modulation of signal energy).

#### Usage:

```
_ : allpassnn(n,tv) : _
```

Where:

* `n`: the order of the filter
* `tv`: the reflection coefficients (-PI PI)

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
allpassnn_test = os.osc(440) : fi.allpassnn(3, (0.3, 0.2, 0.1));
```

----

### `(fi.)allpassnkl`

Kelly-Lochbaum form - four multiplies and two adds per
section, but all signals have an immediate physical
interpretation as traveling pressure waves, etc.

#### Usage:

```
_ : allpassnkl(n,sv) : _
```

Where:

* `n`: the order of the filter
* `sv`: the reflection coefficients (-1 1)

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
allpassnkl_test = os.osc(440) : fi.allpassnkl(3, (0.3, 0.2, 0.1));
```

----

### `(fi.)allpass1m`

One-multiply form - one multiply and three adds per section.
Normally the most efficient in special-purpose hardware.

#### Usage:

```
_ : allpassn1m(n,sv) : _
```

Where:

* `n`: the order of the filter
* `sv`: the reflection coefficients (-1 1)

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
allpassn1m_test = os.osc(440) : fi.allpassn1m(3, (0.3, 0.2, 0.1));
```

## Digital Filter Sections Specified as Analog Filter Sections


----

### `(fi.)tf2s` and `(fi.)tf2snp`

Second-order direct-form digital filter,
specified by ANALOG transfer-function polynomials B(s)/A(s),
and a frequency-scaling parameter. Digitization via the
bilinear transform is built in.

#### Usage

```
_ : tf2s(b2,b1,b0,a1,a0,w1) : _
```
Where:

```
        b2 s^2 + b1 s + b0
H(s) = --------------------
           s^2 + a1 s + a0
```

and `w1` is the desired digital frequency (in radians/second)
corresponding to analog frequency 1 rad/sec (i.e., `s = j`).

#### Example test program

A second-order ANALOG Butterworth lowpass filter,
normalized to have cutoff frequency at 1 rad/sec,
has transfer function:

```
             1
H(s) = -----------------
        s^2 + a1 s + 1
```

where `a1 = sqrt(2)`. Therefore, a DIGITAL Butterworth lowpass
cutting off at `SR/4` is specified as `tf2s(0,0,1,sqrt(2),1,PI*SR/2);`

#### Method

Bilinear transform scaled for exact mapping of w1.

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
ma = library("maths.lib");
tf2s_test = os.osc(440) : fi.tf2s(0, 0, 1, sqrt(2), 1, ma.PI*ma.SR/2);
```

#### References

* [https://ccrma.stanford.edu/~jos/pasp/Bilinear_Transformation.html](https://ccrma.stanford.edu/~jos/pasp/Bilinear_Transformation.html)

----

### `(fi.)tf1snp`

First-order special case of tf2snp above.

#### Usage

```
_ : tf1snp(b1,b0,a0) : _
```

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
ma = library("maths.lib");
tf1snp_test = os.osc(440) : fi.tf1snp(0, 1, 1, ma.PI*ma.SR/2);
```

----

### `(fi.)tf3slf`

Analogous to `tf2s` above, but third order, and using the typical
low-frequency-matching bilinear-transform constant 2/T ("lf" series)
instead of the specific-frequency-matching value used in `tf2s` and `tf1s`.
Note the lack of a "w1" argument.

#### Usage

```
_ : tf3slf(b3,b2,b1,b0,a3,a2,a1,a0) : _
```

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
tf3slf_test = os.osc(440) : fi.tf3slf(0, 0, 0, 1, 1, 2, 2, 1);
```

----

### `(fi.)tf1s`

First-order direct-form digital filter,
specified by ANALOG transfer-function polynomials B(s)/A(s),
and a frequency-scaling parameter.

#### Usage

```
_ : tf1s(b1,b0,a0,w1) : _
```
Where:

       b1 s + b0
H(s) = ----------
          s + a0

and `w1` is the desired digital frequency (in radians/second)
corresponding to analog frequency 1 rad/sec (i.e., `s = j`).

#### Example test program

A first-order ANALOG Butterworth lowpass filter,
normalized to have cutoff frequency at 1 rad/sec,
has transfer function:

          1
H(s) = -------
        s + 1

so `b0 = a0 = 1` and `b1 = 0`.  Therefore, a DIGITAL first-order
Butterworth lowpass with gain -3dB at `SR/4` is specified as

```
tf1s(0,1,1,PI*SR/2); // digital half-band order 1 Butterworth
```

#### Method

Bilinear transform scaled for exact mapping of w1.

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
ma = library("maths.lib");
tf1s_test = os.osc(440) : fi.tf1s(0, 1, 1, ma.PI*ma.SR/2);
```

#### References

* [https://ccrma.stanford.edu/~jos/pasp/Bilinear_Transformation.html](https://ccrma.stanford.edu/~jos/pasp/Bilinear_Transformation.html)

----

### `(fi.)tf2sb`

Bandpass mapping of `tf2s`: In addition to a frequency-scaling parameter
`w1` (set to HALF the desired passband width in rad/sec),
there is a desired center-frequency parameter wc (also in rad/s).
Thus, `tf2sb` implements a fourth-order digital bandpass filter section
specified by the coefficients of a second-order analog lowpass prototype
section.  Such sections can be combined in series for higher orders.
The order of mappings is (1) frequency scaling (to set lowpass cutoff w1),
(2) bandpass mapping to wc, then (3) the bilinear transform, with the
usual scale parameter `2*SR`.  Algebra carried out in maxima and pasted here.

#### Usage

```
_ : tf2sb(b2,b1,b0,a1,a0,w1,wc) : _
```

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
ma = library("maths.lib");
tf2sb_test = os.osc(440) : fi.tf2sb(0, 0, 1, sqrt(2), 1, 2*ma.PI*200, 2*ma.PI*1000);
```

----

### `(fi.)tf1sb`

First-to-second-order lowpass-to-bandpass section mapping,
analogous to tf2sb above.

#### Usage

```
_ : tf1sb(b1,b0,a0,w1,wc) : _
```

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
ma = library("maths.lib");
tf1sb_test = os.osc(440) : fi.tf1sb(0, 1, 1, 2*ma.PI*200, 2*ma.PI*1000);
```

## Simple Resonator Filters


----

### `(fi.)resonlp`

Simple resonant lowpass filter based on `tf2s` (virtual analog).
`resonlp` is a standard Faust function.

#### Usage

```
_ : resonlp(fc,Q,gain) : _
_ : resonhp(fc,Q,gain) : _
_ : resonbp(fc,Q,gain) : _

```

Where:

* `fc`: center frequency (Hz)
* `Q`: q
* `gain`: gain (0-1)

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
resonlp_test = os.osc(440) : fi.resonlp(1000, 2, 0.8);
```

----

### `(fi.)resonhp`

Simple resonant highpass filters based on `tf2s` (virtual analog).
`resonhp` is a standard Faust function.

#### Usage

```
_ : resonlp(fc,Q,gain) : _
_ : resonhp(fc,Q,gain) : _
_ : resonbp(fc,Q,gain) : _

```

Where:

* `fc`: center frequency (Hz)
* `Q`: q
* `gain`: gain (0-1)

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
resonhp_test = fi.resonhp(1000, 2, 0.8, os.osc(440));
```

----

### `(fi.)resonbp`

Simple resonant bandpass filters based on `tf2s` (virtual analog).
`resonbp` is a standard Faust function.

#### Usage

```
_ : resonlp(fc,Q,gain) : _
_ : resonhp(fc,Q,gain) : _
_ : resonbp(fc,Q,gain) : _

```

Where:

* `fc`: center frequency (Hz)
* `Q`: q
* `gain`: gain (0-1)

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
resonbp_test = os.osc(440) : fi.resonbp(1000, 2, 0.8);
```

## Butterworth Lowpass/Highpass Filters


----

### `(fi.)lowpass`

Nth-order Butterworth lowpass filter.
`lowpass` is a standard Faust function.

#### Usage

```
_ : lowpass(N,fc) : _
```

Where:

* `N`: filter order (number of poles), nonnegative constant numerical expression
* `fc`: desired cut-off frequency (-3dB frequency) in Hz

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
lowpass_test = os.osc(440) : fi.lowpass(4, 2000);
```

#### References

* [https://ccrma.stanford.edu/~jos/filters/Butterworth_Lowpass_Design.html](https://ccrma.stanford.edu/~jos/filters/Butterworth_Lowpass_Design.html)
* `butter` function in Octave `("[z,p,g] = butter(N,1,'s');")`

----

### `(fi.)highpass`

Nth-order Butterworth highpass filter.
`highpass` is a standard Faust function.

#### Usage

```
_ : highpass(N,fc) : _
```

Where:

* `N`: filter order (number of poles), nonnegative constant numerical expression
* `fc`: desired cut-off frequency (-3dB frequency) in Hz

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
highpass_test = os.osc(440) : fi.highpass(4, 500);
```

#### References

* [https://ccrma.stanford.edu/~jos/filters/Butterworth_Lowpass_Design.html](https://ccrma.stanford.edu/~jos/filters/Butterworth_Lowpass_Design.html)
* `butter` function in Octave `("[z,p,g] = butter(N,1,'s');")`

----

### `(fi.)lowpass0_highpass1`


#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
lowpass0_highpass1_test = os.osc(440) : fi.lowpass0_highpass1(0, 2, 1000);
```

## Special Filter-Bank Delay-Equalizing Allpass Filters

These special allpass filters are needed by filterbank et al. below.
They are equivalent to (`lowpass(N,fc)` +|- `highpass(N,fc))/2`, but with
canceling pole-zero pairs removed (which occurs for odd N).

----

### `(fi.)highpass_plus_lowpass`


#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
highpass_plus_lowpass_test = os.osc(440) : fi.highpass_plus_lowpass(3, 1000);
```

----

### `(fi.)highpass_minus_lowpass`


#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
highpass_minus_lowpass_test = os.osc(440) : fi.highpass_minus_lowpass(3, 1000);
```

----

### `(fi.)highpass_plus_lowpass_even`


#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
highpass_plus_lowpass_even_test = os.osc(440) : fi.highpass_plus_lowpass_even(4, 1000);
```

----

### `(fi.)highpass_plus_lowpass_even`


#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
highpass_minus_lowpass_even_test = os.osc(440) : fi.highpass_minus_lowpass_even(4, 1000);
```

----

### `(fi.)highpass_minus_lowpass_odd`


#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
highpass_plus_lowpass_odd_test = os.osc(440) : fi.highpass_plus_lowpass_odd(3, 1000);
```
FIXME: Rewrite the following, as for orders 3 and 5 above,
       to eliminate pole-zero cancellations:

----

### `(fi.)highpass_minus_lowpass_odd`


#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
highpass_minus_lowpass_odd_test = os.osc(440) : fi.highpass_minus_lowpass_odd(3, 1000);
```
FIXME: Rewrite the following, as for orders 3 and 5 above,
       to eliminate pole-zero cancellations/

## Elliptic (Cauer) Lowpass Filters

Elliptic (Cauer) Lowpass Filters

#### References

* [http://en.wikipedia.org/wiki/Elliptic_filter](http://en.wikipedia.org/wiki/Elliptic_filter)
* functions `ncauer` and `ellip` in Octave.

----

### `(fi.)lowpass3e`

Third-order Elliptic (Cauer) lowpass filter.

#### Usage

```
_ : lowpass3e(fc) : _
```

Where:

* `fc`: -3dB frequency in Hz

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
lowpass3e_test = os.osc(440) : fi.lowpass3e(1000);
```

#### Design

For spectral band-slice level display (see `octave_analyzer3e`):

```
[z,p,g] = ncauer(Rp,Rs,3);  % analog zeros, poles, and gain, where
Rp = 60  % dB ripple in stopband
Rs = 0.2 % dB ripple in passband
```

----

### `(fi.)lowpass6e`

Sixth-order Elliptic/Cauer lowpass filter.

#### Usage

```
_ : lowpass6e(fc) : _
```

Where:

* `fc`: -3dB frequency in Hz

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
lowpass6e_test = os.osc(440) : fi.lowpass6e(1000);
```

#### Design

For spectral band-slice level display (see octave_analyzer6e):

```
[z,p,g] = ncauer(Rp,Rs,6);  % analog zeros, poles, and gain, where
 Rp = 80  % dB ripple in stopband
 Rs = 0.2 % dB ripple in passband
```

## Elliptic Highpass Filters


----

### `(fi.)highpass3e`

Third-order Elliptic (Cauer) highpass filter. Inversion of `lowpass3e` wrt unit
circle in s plane (s <- 1/s).

#### Usage

```
_ : highpass3e(fc) : _
```

Where:

* `fc`: -3dB frequency in Hz

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
highpass3e_test = os.osc(440) : fi.highpass3e(1000);
```

----

### `(fi.)highpass6e`

Sixth-order Elliptic/Cauer highpass filter. Inversion of `lowpass3e` wrt unit
circle in s plane (s <- 1/s).

#### Usage

```
_ : highpass6e(fc) : _
```

Where:

* `fc`: -3dB frequency in Hz

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
highpass6e_test = os.osc(440) : fi.highpass6e(1000);
```

## Butterworth Bandpass/Bandstop Filters


----

### `(fi.)bandpass`

Order 2*Nh Butterworth bandpass filter made using the transformation
`s <- s + wc^2/s` on `lowpass(Nh)`, where `wc` is the desired bandpass center
frequency.  The `lowpass(Nh)` cutoff `w1` is half the desired bandpass width.
`bandpass` is a standard Faust function.

#### Usage

```
_ : bandpass(Nh,fl,fu) : _
```

Where:

* `Nh`: HALF the desired bandpass order (which is therefore even)
* `fl`: lower -3dB frequency in Hz
* `fu`: upper -3dB frequency in Hz
Thus, the passband width is `fu-fl`,
      and its center frequency is `(fl+fu)/2`.

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
bandpass_test = os.osc(440) : fi.bandpass(2, 500, 1500);
```

----

### `(fi.)bandstop`

Order 2*Nh Butterworth bandstop filter made using the transformation
`s <- s + wc^2/s` on `highpass(Nh)`, where `wc` is the desired bandpass center
frequency.  The `highpass(Nh)` cutoff `w1` is half the desired bandpass width.
`bandstop` is a standard Faust function.

#### Usage

```
_ : bandstop(Nh,fl,fu) : _
```
Where:

* `Nh`: HALF the desired bandstop order (which is therefore even)
* `fl`: lower -3dB frequency in Hz
* `fu`: upper -3dB frequency in Hz
Thus, the passband (stopband) width is `fu-fl`,
      and its center frequency is `(fl+fu)/2`.

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
bandstop_test = os.osc(440) : fi.bandstop(2, 500, 1500);
```

----

### `(fi.)bandstop`


#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
bandpass0_bandstop1_test = os.osc(440) : fi.bandpass0_bandstop1(0, 2, 500, 1500);
```

## Elliptic Bandpass Filters


----

### `(fi.)bandpass6e`

Order 12 elliptic bandpass filter analogous to `bandpass(6)`.

----

### `(fi.)bandpass12e`

Order 24 elliptic bandpass filter analogous to `bandpass(6)`.

----

### `(fi.)pospass`

Positive-Pass Filter (single-side-band filter).

#### Usage

```
_ : pospass(N,fc) : _,_
```

where

* `N`: filter order (Butterworth bandpass for positive frequencies).
* `fc`: lower bandpass cutoff frequency in Hz.
  - Highpass cutoff frequency at ma.SR/2 - fc Hz.

#### Example test program

* See `dm.pospass_demo`
* Look at frequency response

#### Method

A filter passing only positive frequencies can be made from a
half-band lowpass by modulating it up to the positive-frequency range.
Equivalently, down-modulate the input signal using a complex sinusoid at -SR/4 Hz,
lowpass it with a half-band filter, and modulate back up by SR/4 Hz.
In Faust/math notation:
$$pospass(N) = \ast(e^{-j\frac{\pi}{2}n}) : \mbox{lowpass(N,SR/4)} : \ast(e^{j\frac{\pi}{2}n})$$

An approximation to the Hilbert transform is given by the
imaginary output signal:

```
hilbert(N) = pospass(N) : !,*(2);
```

#### References

* [https://ccrma.stanford.edu/~jos/mdft/Analytic_Signals_Hilbert_Transform.html](https://ccrma.stanford.edu/~jos/mdft/Analytic_Signals_Hilbert_Transform.html)
* [https://ccrma.stanford.edu/~jos/sasp/Comparison_Optimal_Chebyshev_FIR_I.html](https://ccrma.stanford.edu/~jos/sasp/Comparison_Optimal_Chebyshev_FIR_I.html)
* [https://ccrma.stanford.edu/~jos/sasp/Hilbert_Transform.html](https://ccrma.stanford.edu/~jos/sasp/Hilbert_Transform.html)

## Parametric Equalizers (Shelf, Peaking)

Parametric Equalizers (Shelf, Peaking).

#### References

* [http://en.wikipedia.org/wiki/Equalization](http://en.wikipedia.org/wiki/Equalization)
* [https://webaudio.github.io/Audio-EQ-Cookbook/Audio-EQ-Cookbook.txt](https://webaudio.github.io/Audio-EQ-Cookbook/Audio-EQ-Cookbook.txt)
* Digital Audio Signal Processing, Udo Zolzer, Wiley, 1999, p. 124
* [https://ccrma.stanford.edu/~jos/filters/Low_High_Shelving_Filters.html](https://ccrma.stanford.edu/~jos/filters/Low_High_Shelving_Filters.html)
* [https://ccrma.stanford.edu/~jos/filters/Peaking_Equalizers.html](https://ccrma.stanford.edu/~jos/filters/Peaking_Equalizers.html)
* maxmsp.lib in the Faust distribution
* bandfilter.dsp in the faust2pd distribution

----

### `(fi.)lowshelf`

First-order "low shelf" filter (gain boost|cut between dc and some frequency)
`low_shelf` is a standard Faust function.

#### Usage

```
_ : lowshelf(N,L0,fx) : _
_ : low_shelf(L0,fx) : _ // default case (order 3)
_ : lowshelf_other_freq(N,L0,fx) : _
```

Where:

* `N`: filter order 1, 3, 5, ... (odd only, default should be 3, a constant numerical expression)
* `L0`: desired level (dB) between dc and fx (boost `L0>0` or cut `L0<0`)
* `fx`: -3dB frequency of lowpass band (`L0>0`) or upper band (`L0<0`)
      (see "SHELF SHAPE" below).

The gain at SR/2 is constrained to be 1.
The generalization to arbitrary odd orders is based on the well known
fact that odd-order Butterworth band-splits are allpass-complementary
(see filterbank documentation below for references).

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
lowshelf_test = os.osc(440) : fi.lowshelf(3, 6, 500);
```

#### Shelf Shape
The magnitude frequency response is approximately piecewise-linear
on a log-log plot ("BODE PLOT").  The Bode "stick diagram" approximation
L(lf) is easy to state in dB versus dB-frequency lf = dB(f):

* L0 > 0:
* L(lf) = L0, f between 0 and fx = 1st corner frequency;
* L(lf) = L0 - N * (lf - lfx), f between fx and f2 = 2nd corner frequency;
* L(lf) = 0, lf > lf2.
* lf2 = lfx + L0/N = dB-frequency at which level gets back to 0 dB.
* L0 < 0:
* L(lf) = L0, f between 0 and f1 = 1st corner frequency;
* L(lf) = - N * (lfx - lf), f between f1 and lfx = 2nd corner frequency;
* L(lf) = 0, lf > lfx.
* lf1 = lfx + L0/N = dB-frequency at which level goes up from L0.

 See `lowshelf_other_freq`.

#### References

* See "Parametric Equalizers" above for references regarding `low_shelf`, `high_shelf`, and `peak_eq`.

----

### `(fi.)low_shelf`

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
low_shelf_test = os.osc(440) : fi.low_shelf(6, 500);
```

----

### `(fi.)low_shelf1_l`

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
low_shelf1_l_test = fi.low_shelf1_l(2, 500, os.osc(440));
```

----

### `(fi.)low_shelf1_l`

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
low_shelf1_l_test = fi.low_shelf1_l(2, 500, os.osc(440));
```

----

### `(fi.)lowshelf_other_freq`

#### Test
```
fi = library("filters.lib");
lowshelf_other_freq_test = fi.lowshelf_other_freq(3, 6, 500);
```

----

### `(fi.)high_shelf`

First-order "high shelf" filter (gain boost|cut above some frequency).
`high_shelf` is a standard Faust function.

#### Usage

```
_ : highshelf(N,Lpi,fx) : _
_ : high_shelf(L0,fx) : _ // default case (order 3)
_ : highshelf_other_freq(N,Lpi,fx) : _
```

Where:

* `N`: filter order 1, 3, 5, ... (odd only, a constant numerical expression).
* `Lpi`: desired level (dB) between fx and SR/2 (boost Lpi>0 or cut Lpi<0)
* `fx`: -3dB frequency of highpass band (L0>0) or lower band (L0<0)
       (Use highshelf_other_freq() below to find the other one.)

The gain at dc is constrained to be 1.
See `lowshelf` documentation above for more details on shelf shape.

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
highshelf_test = os.osc(440) : fi.highshelf(3, 6, 2000);
```

#### References

* See "Parametric Equalizers" above for references regarding `low_shelf`, `high_shelf`, and `peak_eq`.

----

### `(fi.)high_shelf`

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
high_shelf_test = os.osc(440) : fi.high_shelf(6, 2000);
```

----

### `(fi.)high_shelf1`

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
high_shelf1_test = fi.high_shelf1(6, 2000, os.osc(440));
```

----

### `(fi.)high_shelf1_l`

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
high_shelf1_l_test = fi.high_shelf1_l(2, 2000, os.osc(440));
```

----

### `(fi.)highshelf_other_freq`

#### Test
```
fi = library("filters.lib");
highshelf_other_freq_test = fi.highshelf_other_freq(3, 6, 2000);
```

----

### `(fi.)peak_eq`

Second order "peaking equalizer" section (gain boost or cut near some frequency)
Also called a "parametric equalizer" section.
`peak_eq` is a standard Faust function.

#### Usage

```
_ : peak_eq(Lfx,fx,B) : _
```

Where:

* `Lfx`: level (dB) at fx (boost Lfx>0 or cut Lfx<0)
* `fx`: peak frequency (Hz)
* `B`: bandwidth (B) of peak in Hz

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
peak_eq_test = os.osc(440) : fi.peak_eq(6, 1000, 200);
```

#### References

* See "Parametric Equalizers" above for references regarding `low_shelf`, `high_shelf`, and `peak_eq`.

----

### `(fi.)peak_eq_cq`

Constant-Q second order peaking equalizer section.

#### Usage

```
_ : peak_eq_cq(Lfx,fx,Q) : _
```

Where:

* `Lfx`: level (dB) at fx
* `fx`: boost or cut frequency (Hz)
* `Q`: "Quality factor" = fx/B where B = bandwidth of peak in Hz

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
peak_eq_cq_test = os.osc(440) : fi.peak_eq_cq(6, 1000, 4);
```

#### References

* See "Parametric Equalizers" above for references regarding `low_shelf`, `high_shelf`, and `peak_eq`.

----

### `(fi.)peak_eq_rm`

Regalia-Mitra second order peaking equalizer section.

#### Usage

```
_ : peak_eq_rm(Lfx,fx,tanPiBT) : _
```

Where:

* `Lfx`: level (dB) at fx
* `fx`: boost or cut frequency (Hz)
* `tanPiBT`: `tan(PI*B/SR)`, where B = -3dB bandwidth (Hz) when 10^(Lfx/20) = 0
        ~ PI*B/SR for narrow bandwidths B

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
ma = library("maths.lib");
peak_eq_rm_test = os.osc(440) : fi.peak_eq_rm(6, 1000, ma.tan(ma.PI*200/ma.SR));
```

#### References

P.A. Regalia, S.K. Mitra, and P.P. Vaidyanathan,
"The Digital All-Pass Filter: A Versatile Signal Processing Building Block"
Proceedings of the IEEE, 76(1):19-37, Jan. 1988.  (See pp. 29-30.)
See also "Parametric Equalizers" above for references on shelf
and peaking equalizers in general.

----

### `(fi.)spectral_tilt`

Spectral tilt filter, providing an arbitrary spectral rolloff factor
alpha in (-1,1), where
 -1 corresponds to one pole (-6 dB per octave), and
 +1 corresponds to one zero (+6 dB per octave).
In other words, alpha is the slope of the ln magnitude versus ln frequency.
For a "pinking filter" (e.g., to generate 1/f noise from white noise),
set alpha to -1/2.

#### Usage

```
_ : spectral_tilt(N,f0,bw,alpha) : _
```
Where:

* `N`: desired integer filter order (fixed at compile time)
* `f0`: lower frequency limit for desired roll-off band > 0
* `bw`: bandwidth of desired roll-off band
* `alpha`: slope of roll-off desired in nepers per neper,
        between -1 and 1 (ln mag / ln radian freq)

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
spectral_tilt_test = os.osc(440) : fi.spectral_tilt(4, 200, 2000, -0.5);
```

#### Example test program

See `dm.spectral_tilt_demo` and the documentation for `no.pink_noise`.

#### References

J.O. Smith and H.F. Smith,
"Closed Form Fractional Integration and Differentiation via Real Exponentially Spaced Pole-Zero Pairs",
* arXiv.org publication arXiv:1606.06154 [cs.CE], June 7, 2016, [http://arxiv.org/abs/1606.06154](http://arxiv.org/abs/1606.06154)

----

### `(fi.)levelfilter`

Dynamic level lowpass filter.
`levelfilter` is a standard Faust function.

#### Usage

```
_ : levelfilter(L,freq) : _
```

Where:

* `L`: desired level (in dB) at Nyquist limit (SR/2), e.g., -60
* `freq`: corner frequency (-3dB point) usually set to fundamental freq
* `N`: Number of filters in series where L = L/N

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
levelfilter_test = fi.levelfilter(0.1, 200, os.osc(440));
```

#### References

* [https://ccrma.stanford.edu/realsimple/faust_strings/Dynamic_Level_Lowpass_Filter.html](https://ccrma.stanford.edu/realsimple/faust_strings/Dynamic_Level_Lowpass_Filter.html)

----

### `(fi.)levelfilterN`

Dynamic level lowpass filter.

#### Usage

```
_ : levelfilterN(N,freq,L) : _
```

Where:

* `N`: Number of filters in series where L = L/N, a constant numerical expression
* `freq`: corner frequency (-3dB point) usually set to fundamental freq
* `L`: desired level (in dB) at Nyquist limit (SR/2), e.g., -60

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
levelfilterN_test = os.osc(440) : fi.levelfilterN(3, 200, 0.1);
```

#### References

* [https://ccrma.stanford.edu/realsimple/faust_strings/Dynamic_Level_Lowpass_Filter.html](https://ccrma.stanford.edu/realsimple/faust_strings/Dynamic_Level_Lowpass_Filter.html)

## Mth-Octave Filter-Banks

Mth-octave filter-banks split the input signal into a bank of parallel signals, one
for each spectral band. They are related to the Mth-Octave Spectrum-Analyzers in
`analysis.lib`.
The documentation of this library contains more details about the implementation.
The parameters are:

* `M`: number of band-slices per octave (>1), a constant numerical expression
* `N`: total number of bands (>2), a constant numerical expression
* `ftop`: upper bandlimit of the Mth-octave bands (<SR/2)

In addition to the Mth-octave output signals, there is a highpass signal
containing frequencies from ftop to SR/2, and a "dc band" lowpass signal
containing frequencies from 0 (dc) up to the start of the Mth-octave bands.
Thus, the N output signals are

```
highpass(ftop), MthOctaveBands(M,N-2,ftop), dcBand(ftop*2^(-M*(N-1)))
```

A Filter-Bank is defined here as a signal bandsplitter having the
property that summing its output signals gives an allpass-filtered
version of the filter-bank input signal.  A more conventional term for
this is an "allpass-complementary filter bank".  If the allpass filter
is a pure delay (and possible scaling), the filter bank is said to be
a "perfect-reconstruction filter bank" (see Vaidyanathan-1993 cited
below for details).  A "graphic equalizer", in which band signals
are scaled by gains and summed, should be based on a filter bank.

The filter-banks below are implemented as Butterworth or Elliptic
spectrum-analyzers followed by delay equalizers that make them
allpass-complementary.

#### Increasing Channel Isolation

Go to higher filter orders - see Regalia et al. or Vaidyanathan (cited
below) regarding the construction of more aggressive recursive
filter-banks using elliptic or Chebyshev prototype filters.

#### References

* "Tree-structured complementary filter banks using all-pass sections", Regalia et al., IEEE Trans. Circuits & Systems, CAS-34:1470-1484, Dec. 1987
* "Multirate Systems and Filter Banks", P. Vaidyanathan, Prentice-Hall, 1993
* Elementary filter theory: [https://ccrma.stanford.edu/~jos/filters/](https://ccrma.stanford.edu/~jos/filters/)

----

### `(fi.)mth_octave_filterbank[n]`

Allpass-complementary filter banks based on Butterworth band-splitting.
For Butterworth band-splits, the needed delay equalizer is easily found.

#### Usage

```
_ : mth_octave_filterbank(O,M,ftop,N) : par(i,N,_)     // Oth-order
_ : mth_octave_filterbank_alt(O,M,ftop,N) : par(i,N,_) // dc-inverted version
```

Also for convenience:

```
_ : mth_octave_filterbank3(M,ftop,N) : par(i,N,_) // 3rd-order Butterworth
_ : mth_octave_filterbank5(M,ftop,N) : par(i,N,_) // 5th-order Butterworth
mth_octave_filterbank_default = mth_octave_filterbank5;
```

Where:

* `O`: order of filter used to split each frequency band into two, a constant numerical expression
* `M`: number of band-slices per octave, a constant numerical expression
* `ftop`: highest band-split crossover frequency (e.g., 20 kHz)
* `N`: total number of bands (including dc and Nyquist), a constant numerical expression

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
mth_octave_filterbank_test = os.osc(440) : fi.mth_octave_filterbank(3, 2, 8000, 2);
```

----

### `(fi.)mth_octave_filterbank_alt`


#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
mth_octave_filterbank_alt_test = os.osc(440) : fi.mth_octave_filterbank_alt(3, 2, 8000, 2);
```

----

### `(fi.)mth_octave_filterbank3`


#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
mth_octave_filterbank3_test = os.osc(440) : fi.mth_octave_filterbank3(2, 8000, 2);
```

----

### `(fi.)mth_octave_filterbank5`


#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
mth_octave_filterbank5_test = os.osc(440) : fi.mth_octave_filterbank5(2, 8000, 2);
```

----

### `(fi.)mth_octave_filterbank_default`


#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
mth_octave_filterbank_default_test = os.osc(440) : fi.mth_octave_filterbank_default(2, 8000, 2);
```

## Arbitrary-Crossover Filter-Banks and Spectrum Analyzers

These are similar to the Mth-octave analyzers above, except that the
band-split frequencies are passed explicitly as arguments.

----

### `(fi.)filterbank`

Filter bank.
`filterbank` is a standard Faust function.

#### Usage

```
_ : filterbank (O,freqs) : par(i,N,_) // Butterworth band-splits
```
Where:

* `O`: band-split filter order (odd integer required for filterbank[i], a constant numerical expression)
* `freqs`: (fc1,fc2,...,fcNs) [in numerically ascending order], where
          Ns=N-1 is the number of octave band-splits
          (total number of bands N=Ns+1).

If frequencies are listed explicitly as arguments, enclose them in parens:

```
_ : filterbank(3,(fc1,fc2)) : _,_,_
```

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
filterbank_test = os.osc(440) : fi.filterbank(3, (500, 2000));
```

----

### `(fi.)filterbanki`

Inverted-dc filter bank.

#### Usage

```
_ : filterbanki(O,freqs) : par(i,N,_) // Inverted-dc version
```

Where:

* `O`: band-split filter order (odd integer required for `filterbank[i]`, a constant numerical expression)
* `freqs`: (fc1,fc2,...,fcNs) [in numerically ascending order], where
          Ns=N-1 is the number of octave band-splits
          (total number of bands N=Ns+1).

If frequencies are listed explicitly as arguments, enclose them in parens:

```
_ : filterbanki(3,(fc1,fc2)) : _,_,_
```

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
filterbanki_test = os.osc(440) : fi.filterbanki(3, (500, 2000));
```

## State Variable Filters

#### References

* Solving the continuous SVF equations using trapezoidal integration
* [https://cytomic.com/files/dsp/SvfLinearTrapOptimised2.pdf](https://cytomic.com/files/dsp/SvfLinearTrapOptimised2.pdf)

----

### `(fi.)svf`

An environment with `lp`, `bp`, `hp`, `notch`, `peak`, `ap`, `bell`, `ls`, `hs` SVF based filters.
All filters have `freq` and `Q` parameters, the `bell`, `ls`, `hs` ones also have a `gain` third parameter.

#### Usage

```
_ : svf.xx(freq, Q, [gain]) : _
```

Where:

* `freq`: cut frequency
* `Q`: quality factor
* `[gain]`: gain in dB

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
svf_lp_test = fi.svf.lp(1000, 0.707, os.osc(440));
svf_bp_test = fi.svf.bp(1000, 0.707, os.osc(440));
svf_hp_test = fi.svf.hp(1000, 0.707, os.osc(440));
svf_notch_test = fi.svf.notch(1000, 0.707, os.osc(440));
svf_peak_test = fi.svf.peak(1000, 0.707, os.osc(440));
svf_ap_test = fi.svf.ap(1000, 0.707, os.osc(440));
svf_bell_test = fi.svf.bell(1000, 0.707, 6, os.osc(440));
svf_ls_test = fi.svf.ls(500, 0.707, 6, os.osc(440));
svf_hs_test = fi.svf.hs(3000, 0.707, 6, os.osc(440));
```

----

### `(fi.)svf_morph`

An SVF-based filter that can smoothly morph between
being lowpass, bandpass, and highpass.

#### Usage

```
_ : svf_morph(freq, Q, blend) : _
```

Where:

* `freq`: cutoff frequency
* `Q`: quality factor
* `blend`: [0..2] continuous, where 0 is `lowpass`, 1 is `bandpass`, and 2 is `highpass`. For performance, the value is not clamped to [0..2].

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
svf_morph_test = fi.svf_morph(1000, 0.707, 1, os.osc(440));
```

#### Example test program

```
process = no.noise : svf_morph(freq, q, blend)
with {
  blend = hslider("Blend", 0, 0, 2, .01) : si.smoo;
  q = hslider("Q", 1, 0.1, 10, .01) : si.smoo;
  freq = hslider("freq", 5000, 100, 18000, 1) : si.smoo;
};
```

#### References

* [https://github.com/mtytel/vital/blob/636ca0ef517a4db087a6a08a6a8a5e704e21f836/src/synthesis/filters/digital_svf.cpp#L292-L295](https://github.com/mtytel/vital/blob/636ca0ef517a4db087a6a08a6a8a5e704e21f836/src/synthesis/filters/digital_svf.cpp#L292-L295)

----

### `(fi.)svf_notch_morph`

An SVF-based notch-filter that can smoothly morph between
being lowpass, notch, and highpass.

#### Usage

```
_ : svf_notch_morph(freq, Q, blend) : _
```

Where:

* `freq`: cutoff frequency
* `Q`: quality factor
* `blend`: [0..2] continuous, where 0 is `lowpass`, 1 is `notch`, and 2 is `highpass`. For performance, the value is not clamped to [0..2].

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
svf_notch_morph_test = fi.svf_notch_morph(1000, 0.707, 1, os.osc(440));
```

#### Example test program

```
process = no.noise : svf_notch_morph(freq, q, blend)
with {
  blend = hslider("Blend", 0, 0, 2, .01) : si.smoo;
  q = hslider("Q", 1, 0.1, 10, .01) : si.smoo;
  freq = hslider("freq", 5000, 100, 18000, 1) : si.smoo;
};
```

#### References

* [https://github.com/mtytel/vital/blob/636ca0ef517a4db087a6a08a6a8a5e704e21f836/src/synthesis/filters/digital_svf.cpp#L256C36-L263](https://github.com/mtytel/vital/blob/636ca0ef517a4db087a6a08a6a8a5e704e21f836/src/synthesis/filters/digital_svf.cpp#L256C36-L263)

----

### `(fi.)SVFTPT`


Topology-preserving transform implementation following Zavalishin's method.

Outputs: lowpass, highpass, bandpass, normalised bandpass, notch, allpass, 
peaking.

Each individual output can be recalled with its name in the environment as in:
     `SVFTPT.LP2(1000.0, .707)`.

The 7 outputs can be recalled by using `SVF` name as in:
     `SVFTPT.SVF(1000.0, .707)`.

Even though the implementation is different, the characteristics of this
filter are comparable to those of the `svf` environment in this library.

#### Usage:

```
_ : SVFTPT.xxx(CF, Q) : _
```

Where:

* `xxx` can be one of the following: `LP2`, `HP2`, `BP2`, `BP2Norm`, `Notch2`, `AP2`, `Peaking2`
* `CF`: cutoff in Hz
* `Q`: resonance

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
SVFTPT_SVF_test = fi.SVFTPT.SVF(1000, 0.707, os.osc(440));
SVFTPT_LP2_test = fi.SVFTPT.LP2(1000, 0.707, os.osc(440));
SVFTPT_HP2_test = fi.SVFTPT.HP2(1000, 0.707, os.osc(440));
SVFTPT_BP2_test = fi.SVFTPT.BP2(1000, 0.707, os.osc(440));
SVFTPT_BP2Norm_test = fi.SVFTPT.BP2Norm(1000, 0.707, os.osc(440));
SVFTPT_Notch2_test = fi.SVFTPT.Notch2(1000, 0.707, os.osc(440));
SVFTPT_AP2_test = fi.SVFTPT.AP2(1000, 0.707, os.osc(440));
SVFTPT_Peaking2_test = fi.SVFTPT.Peaking2(1000, 0.707, os.osc(440));
```

----

### `(fi.)dynamicSmoothing`


Adaptive smoother based on Andy Simper's paper.

This filter uses both the lowpass and bandpass outputs of a 
state-variable filter. The lowpass is used to smooth out the input signal,
the bandpass, which is a smoothed out version of the highpass, provides
information on the rate of change of the input. Hence, the bandpass signal
can be used to adjust the cutoff of the filter to quickly follow the input's
fast and large variations while effectively filtering out local 
perturbations.

This implementation does not use an approximation for the CF computation,
and it deploys guards to prevent overshooting with extreme sensitivity 
values.

#### Usage:

```
_ : dynamicSmoothing(sensitivity, baseCF) : _
```

Where:

* `sensitivity`: sensitivity to changes in the input signal.
     The range is, theoretically, from 0 to INF, though anything between
     0.0 and 1.0 should be reasonable
* `baseCF`: cutoff frequency, in Hz, when there is no variation in the 
     input signal

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
dynamicSmoothing_test = fi.dynamicSmoothing(0.5, 500, os.osc(440));
```

#### References

* [https://cytomic.com/files/dsp/DynamicSmoothing.pdf](https://cytomic.com/files/dsp/DynamicSmoothing.pdf)

----

### `(fi.)oneEuro`

The One Euro Filter (1€ Filter) is an adaptive lowpass filter.
This kind of filter is commonly used in object-tracking,
not necessarily audio processing.

#### Usage

```
_ : oneEuro(derivativeCutoff, beta, minCutoff) : _
```

Where:

* `derivativeCutoff`: Used to filter the first derivative of the input. 1 Hz is a good default.
* `beta`: "Speed" parameter where higher values reduce latency.
* `minCutoff`: Minimum cutoff frequency in Hz. Lower values remove more jitter.

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
oneEuro_test = os.osc(440) : fi.oneEuro(1, 0.5, 5);
```

#### References

* [https://gery.casiez.net/1euro/](https://gery.casiez.net/1euro/)

## Linkwitz-Riley 4th-order 2-way, 3-way, and 4-way crossovers


The Linkwitz-Riley (LR) crossovers are designed to produce a fully-flat
magnitude response when their outputs are combined. The 4th-order
LR filters (LR4) have a 24dB/octave slope and they are rather popular audio
crossovers used in multi-band processing.

The LR4 can be constructed by cascading two second-order Butterworth
filters. For the second-order Butterworth filters, we will use the SVF
filter implemented above by setting the Q-factor to 1.0 / sqrt(2.0).
These will be cascaded in pairs to build the LR4 highpass and lowpass.
For the phase correction, we will use the 2nd-order Butterworth allpass.

#### References

Zavalishin, Vadim. "The art of VA filter design." Native Instruments, Berlin, Germany (2012).

----

### `(fi.)lowpassLR4`

4th-order Linkwitz-Riley lowpass.

#### Usage

```
_ : lowpassLR4(cf) : _
```

Where:

* `cf` is the lowpass cutoff in Hz

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
lowpassLR4_test = os.osc(440) : fi.lowpassLR4(1000);
```

----

### `(fi.)highpassLR4`

4th-order Linkwitz-Riley highpass.

#### Usage

```
_ : highpassLR4(cf) : _
```

Where:

* `cf` is the highpass cutoff in Hz

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
highpassLR4_test = os.osc(440) : fi.highpassLR4(1000);
```

----

### `(fi.)crossover2LR4`

Two-way 4th-order Linkwitz-Riley crossover.

#### Usage

```
_ : crossover2LR4(cf) : si.bus(2)
```

Where:

* `cf` is the crossover split cutoff in Hz

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
crossover2LR4_test = os.osc(440) : fi.crossover2LR4(1000);
```

----

### `(fi.)crossover3LR4`

Three-way 4th-order Linkwitz-Riley crossover.

#### Usage

```
_ : crossover3LR4(cf1, cf2) : si.bus(3)
```

Where:

* `cf1` is the crossover lower split cutoff in Hz
* `cf2` is the crossover upper split cutoff in Hz

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
crossover3LR4_test = os.osc(440) : fi.crossover3LR4(500, 2000);
```

----

### `(fi.)crossover4LR4`

Four-way 4th-order Linkwitz-Riley crossover.

#### Usage

```
_ : crossover4LR4(cf1, cf2, cf3) : si.bus(4)
```

Where:

* `cf1` is the crossover lower split cutoff in Hz
* `cf2` is the crossover mid split cutoff in Hz
* `cf3` is the crossover upper split cutoff in Hz

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
crossover4LR4_test = os.osc(440) : fi.crossover4LR4(300, 1000, 3000);
```

----

### `(fi.)crossover8LR4`

Eight-way 4th-order Linkwitz-Riley crossover.

#### Usage

```
_ : crossover8LR4(cf1, cf2, cf3, cf4, cf5, cf6, cf7) : si.bus(8)
```

Where:

* `cf1-cf7` are the crossover cutoff frequencies in Hz

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
crossover8LR4_test = os.osc(440) : fi.crossover8LR4(100, 200, 400, 800, 1600, 3200, 6400);
```

##  Standardized Filters 


----

### `(fi.)itu_r_bs_1770_4_kfilter`

The prefilter from Recommendation ITU-R BS.1770-4 for loudness
measurement. Also known as "K-filter". The recommendation defines
biquad filter coefficients for a fixed sample rate of 48kHz (page
4-5). Here, we construct biquads for arbitrary samplerates.  The
resulting filter is normalized, such that the magnitude at 997Hz is
unity gain 1.0.

Please note, the ITU-recommendation handles the normalization in
equation (2) by subtracting 0.691dB, which is not needed with
`itu_r_bs_1770_4_kfilter`.

One option for future improvement might be, to round those filter
coefficients, that are almost equal to one. Second, the maximum
magnitude difference at 48kHz between the ITU-defined filter and
`itu_r_bs_1770_4_kfilter` is 0.001dB, which obviously could be
less.

#### Usage

```
_ : itu_r_bs_1770_4_kfilter : _
```

#### Test
```
fi = library("filters.lib");
os = library("oscillators.lib");
itu_r_bs_1770_4_kfilter_test = os.osc(440) : fi.itu_r_bs_1770_4_kfilter;
```

#### References

* [https://www.itu.int/rec/R-REC-BS.1770](https://www.itu.int/rec/R-REC-BS.1770)
* [https://gist.github.com/jkbd/07521a98f7873a2dc3dbe16417930791](https://gist.github.com/jkbd/07521a98f7873a2dc3dbe16417930791)

## Averaging Functions


----

### `(fi.)avg_rect`

Moving average.

#### Usage

```
_ : avg_rect(period) : _
```

Where:

* `period` is the averaging frame in seconds

----

### `(fi.)avg_tau`

Averaging function based on a one-pole filter and the tau response time.
Tau represents the effective length of the one-pole impulse response,
that is, tau is the integral of the filter's impulse response. This
response is slower to reach the final value but has less ripples in
non-steady signals.

#### Usage

```
_ : avg_tau(period) : _
```

Where:

* `period` is the time, in seconds, for the system to decay by 1/e,
or to reach 1-1/e of its final value.

#### References

* [https://ccrma.stanford.edu/~jos/mdft/Exponentials.html](https://ccrma.stanford.edu/~jos/mdft/Exponentials.html)

----

### `(fi.)avg_t60`

Averaging function based on a one-pole filter and the t60 response time.
This response is particularly useful when the system is required to
reach the final value after about `period` seconds.

#### Usage

```
_ : avg_t60(period) : _
```

Where:

* `period` is the time, in seconds, for the system to decay by 1/1000,
or to reach 1-1/1000 of its final value.

#### References

* [https://ccrma.stanford.edu/~jos/mdft/Audio_Decay_Time_T60.html](https://ccrma.stanford.edu/~jos/mdft/Audio_Decay_Time_T60.html)

----

### `(fi.)avg_t19`

Averaging function based on a one-pole filter and the t19 response time.
This response is close to the moving-average algorithm as it roughly reaches
the final value after `period` seconds and shows about the same
oscillations for non-steady signals.

#### Usage

```
_ : avg_t19(period) : _
```

Where:

* `period` is the time, in seconds, for the system to decay by 1/e^2.2,
or to reach 1-1/e^2.2 of its final value.

#### References

Zölzer, U. (2008). Digital audio signal processing (Vol. 9). New York: Wiley.

## Kalman Filters


----

### `(fi.)kalman`

The Kalman filter. It returns the state (a bus of size `N`).
Note that the only compile-time constant arguments are `N` and `M`.
Other arguments are capitalized because they're matrices, and it makes
reading them much easier.

#### Usage
```
kalman(N, M, B, R, H, Q, F, reset, u, z) : si.bus(N)
```

Where:

* `N`: State size (constant int)
* `M`: Measurement size (constant int)
* `B`: Control input matrix (NxM)
* `R`: Measurement noise covariance matrix (MxM)
* `H`: Observation matrix (MxN)
* `Q`: Process noise covariance matrix (NxN)
* `F`: State transition matrix (NxN)
* `reset`: Reset trigger. Whenever `reset>0`, the internal state `x` and covariance matrix `P` are reset.
* `u`: Control input (Mx1)
* `z`: Measurement signal (Mx1)

#### Example test programs
Demo 1 `(N=1, M=1)` (don't listen, just use oscilloscope):

```
process = fi.kalman(N, M, B, R, H, Q, F, reset, u, z) : it.interpolate_linear(filteredAmt, z)
with {
   B = 1.;
   R = 0.1;
   H = 1;
   Q = .01; 
   F = la.identity(N);
   reset = button("reset");

   // Dimensions
   N = 1; // State size
   M = 1; // Measurement size

   freq = hslider("Freq", 1, 0.01, 10, .01);
   u = 0.; // constant input
   trueState = os.osc(freq)*.5 + u;
   noiseGain = hslider("Noise Gain", .1, 0, 1, .01);

   filteredAmt = hslider("Filter Amount", 1, 0, 1, .01) : si.smoo;

   measurementNoise = no.noise*noiseGain;
   z = trueState + measurementNoise; // Observed state
};
```

Demo 2 `(N=2, M=1)` (don't listen, just use oscilloscope)

```
process = fi.kalman(N, M, B, R, H, Q, F, reset, u, z)
with {
    B = par(i, N, 0);
    R = (0.1);
    H = (1, 0);
    Q = la.diag(2, par(i, N, .1));
    F = la.identity(N);
    reset = 0;
    u = si.bus(M);
    z = si.bus(M);

    // Dimensions
    N = 2; // State size
    M = 1; // Measurement size
};
```
#### References

* [https://en.wikipedia.org/wiki/Kalman_filter](https://en.wikipedia.org/wiki/Kalman_filter)
* [https://www.cs.unc.edu/~welch/kalman/index.html](https://www.cs.unc.edu/~welch/kalman/index.html)
