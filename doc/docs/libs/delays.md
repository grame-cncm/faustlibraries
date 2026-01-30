#  delays.lib 

Delays library. Its official prefix is `de`.

This library provides reusable building blocks for delay-based processing:
single and multi-tap delays, fractional delays and utilities for echo and spatial effects.

The Delays library is organized into 4 sections:

* [Basic Delay Functions](#basic-delay-functions)
* [Lagrange Interpolation](#lagrange-interpolation)
* [Thiran Allpass Interpolation](#thiran-allpass-interpolation)
* [Others](#others)

#### References

* [https://github.com/grame-cncm/faustlibraries/blob/master/delays.lib](https://github.com/grame-cncm/faustlibraries/blob/master/delays.lib)

## Basic Delay Functions


----

### `(de.)delay`

Simple `d` samples delay where `n` is the maximum delay length as a number of
samples. Unlike the `@` delay operator, here the delay signal `d` is explicitly
bounded to the interval [0..n]. The consequence is that delay will compile even
if the interval of d can't be computed by the compiler.
`delay` is a standard Faust function.

#### Usage

```
_ : delay(n,d) : _
```

Where:

* `n`: the max delay length in samples
* `d`: the delay length in samples (integer)
#### Test
```
de = library("delays.lib");
os = library("oscillators.lib");
delay_test = os.osc(440) : de.delay(44100, 22050);
```

TODO: add MBH np2

----

### `(de.)fdelay`

Simple `d` samples fractional delay based on 2 interpolated delay lines where `n` is
the maximum delay length as a number of samples.

`fdelay` is a standard Faust function.

#### Usage

```
_ : fdelay(n,d) : _
```

Where:

* `n`: the max delay length in samples
* `d`: the delay length in samples (float)

#### Test
```
de = library("delays.lib");
os = library("oscillators.lib");
fdelay_test = os.osc(440) : de.fdelay(44100, 22050.5);
```

----

### `(de.)sdelay`

s(mooth)delay: a mono delay that doesn't click and doesn't
transpose when the delay time is changed.

#### Usage

```
_ : sdelay(n,it,d) : _
```

Where:

* `n`: the max delay length in samples
* `it`: interpolation time (in samples), for example 1024
* `d`: the delay length in samples (float)

#### Test
```
de = library("delays.lib");
os = library("oscillators.lib");
sdelay_test = os.osc(440) : de.sdelay(44100, 1024, 22050.5);
```

----

### `(de.)prime_power_delays`

Prime Power Delay Line Lengths.

#### Usage

```
si.bus(N) : prime_power_delays(N,pathmin,pathmax) : si.bus(N);
```

Where:

* `N`: positive integer up to 16 (for higher powers of 2, extend 'primes' array below)
* `pathmin`: minimum acoustic ray length in the reverberator (in meters)
* `pathmax`: maximum acoustic ray length (meters) - think "room size"

#### Test
```
de = library("delays.lib");
prime_power_delays_test = de.prime_power_delays(4, 1, 10);
```

#### References

* [https://ccrma.stanford.edu/~jos/pasp/Prime_Power_Delay_Line.html](https://ccrma.stanford.edu/~jos/pasp/Prime_Power_Delay_Line.html)

## Lagrange Interpolation


----

### `(de.)fdelaylti` and `(de.)fdelayltv`

Fractional delay line using Lagrange interpolation.

#### Usage

```
_ : fdelaylt[i|v](N, n, d) : _
```

Where:

* `N=1,2,3,...` is the order of the Lagrange interpolation polynomial (constant numerical expression)
* `n`: the max delay length in samples
* `d`: the delay length in samples

`fdelaylti` is most efficient, but designed for constant/slowly-varying delay.
`fdelayltv` is more expensive and more robust when the delay varies rapidly.

Note: the requested delay should not be less than `(N-1)/2`.

#### Test
```
de = library("delays.lib");
os = library("oscillators.lib");
fdelaylti_test = os.osc(440) : de.fdelaylti(3, 44100, 22050.5);
fdelayltv_test = os.osc(440) : de.fdelayltv(3, 44100, 22050.5);
```

#### References

* [https://ccrma.stanford.edu/~jos/pasp/Lagrange_Interpolation.html](https://ccrma.stanford.edu/~jos/pasp/Lagrange_Interpolation.html)
* [Fixed-delay case](https://ccrma.stanford.edu/~jos/Interpolation/Efficient_Time_Invariant_Lagrange_Interpolation.html)
* [Variable-delay case](https://ccrma.stanford.edu/~jos/Interpolation/Time_Varying_Lagrange_Interpolation.html)
* Timo I. Laakso et al., "Splitting the Unit Delay - Tools for Fractional Delay Filter Design", IEEE Signal Processing Magazine, vol. 13, no. 1, pp. 30-60, Jan 1996.
* Philippe Depalle and Stephan Tassart, "Fractional Delay Lines using Lagrange Interpolators", ICMC Proceedings, pp. 341-343, 1996.

----

### `(de.)fdelay[N]`

For convenience, `fdelay1`, `fdelay2`, `fdelay3`, `fdelay4`, `fdelay5`
are also available where `N` is the order of the interpolation, built using `fdelayltv`.

## Thiran Allpass Interpolation

Thiran Allpass Interpolation.

#### References

* [https://ccrma.stanford.edu/~jos/pasp/Thiran_Allpass_Interpolators.html](https://ccrma.stanford.edu/~jos/pasp/Thiran_Allpass_Interpolators.html)

----

### `(de.)fdelay[N]a`

Delay lines interpolated using Thiran allpass interpolation.

#### Usage

```
_ : fdelay[N]a(n, d) : _
```

(exactly like `fdelay`)

Where:

* `N=1,2,3, or 4` is the order of the Thiran interpolation filter (constant numerical expression),
   and the delay argument is at least `N-1/2`. First-order: `d` at least 0.5, second-order: `d` at least 1.5,
   third-order: `d` at least 2.5, fourth-order: `d` at least 3.5.
* `n`: the max delay length in samples
* `d`: the delay length in samples

#### Test
```
de = library("delays.lib");
os = library("oscillators.lib");
fdelay2a_test = os.osc(440) : de.fdelay2a(44100, 22050.5);
```

#### Note

The interpolated delay should not be less than `N-1/2`.
(The allpass delay ranges from `N-1/2` to `N+1/2`).
This constraint can be alleviated by altering the code,
but be aware that allpass filters approach zero delay
by means of pole-zero cancellations.

Delay arguments too small will produce an UNSTABLE allpass!

Because allpass interpolation is recursive, it is not as robust
as Lagrange interpolation under time-varying conditions
(you may hear clicks when changing the delay rapidly).


## Others


----

### `(de.)multiTapSincDelay`


Variable delay line using multi-tap sinc interpolation.

This function implements a continuously variable delay line by superposing (2K+2) auxiliary delayed signals
whose positions and gains are determined by a sinc-based interpolation method. It extends the traditional
crossfade delay technique to significantly reduce spectral coloration artifacts, which are problematic in
applications like Wave Field Synthesis (WFS) and auralization.

Operation:

  - If tau1 and tau2 are very close (|tau2 - tau1| ≈ 0), a simple fixed fractional delay is applied
  - Otherwise, a variable delay is synthesized by:

     - Computing (2K+2) taps symmetrically distributed around tau1 and tau2
     - Applying sinc-based weighting to each tap, based on its offset from the target interpolated delay tau
     - Summing all the weighted taps to produce the output

Features:

  - Smooth delay variation without introducing Doppler pitch shifts
  - Significant reduction of comb-filter coloration compared to classical crossfading
  - Switching between fixed and variable delay modes to ensure stability

#### Usage

```
_ : multiTapSincDelay(K, MaxDelay, tau1, tau2, alpha) : _
```

Where:

* `K (integer)`: number of auxiliary tap pairs (a constant numerical expression). Total number of taps = 2*K + 2
* `MaxDelay`: maximum allowable delay in samples (buffer size)
* `tau1`: initial delay in samples (can be fractional)
* `tau2`: target delay in samples (can be fractional)
* `alpha`: interpolation factor between tau1 and tau2 (in [0,1] with 0 = tau1, 1 = tau2)

#### Test
```
de = library("delays.lib");
os = library("oscillators.lib");
multiTapSincDelay_test = os.osc(440) : de.multiTapSincDelay(2, 4096, 1024.0, 1536.0, 0.5);
```

#### References

*  T. Carpentier, "Implementation of a continuously variable delay line by crossfading between several tap delays", 2024: [https://hal.science/hal-04646939](https://hal.science/hal-04646939)
