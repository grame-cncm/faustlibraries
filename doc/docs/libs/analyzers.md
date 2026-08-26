#  analyzers.lib 

Analyzers library. Its official prefix is `an`.

This library provides reusable building blocks for audio
signal *analysis* and metering. It includes functions and
components for measuring levels, extracting features, and
computing statistics useful in visualization, diagnostics,
adaptive processing, and music information retrieval.

The Analyzers library is organized into 7 sections:

* [Amplitude Tracking](#amplitude-tracking)
* [Adaptive Frequency Analysis](#adaptive-frequency-analysis)
* [Spectrum-Analyzers](#spectrum-analyzers)
* [Mth-Octave Spectral Level](#mth-octave-spectral-level)
* [Arbritary-Crossover Filter-Banks and Spectrum Analyzers](#arbritary-crossover-filter-banks-and-spectrum-analyzers)
* [Fast Fourier Transform (fft) and its Inverse (ifft)](#fast-fourier-transform-fft-and-its-inverse-ifft)
* [Test signal generators](#test-signal-generators)

#### References

* [https://github.com/grame-cncm/faustlibraries/blob/master/analyzers.lib](https://github.com/grame-cncm/faustlibraries/blob/master/analyzers.lib)

## Amplitude Tracking


----

### `(an.)abs_envelope_rect`

Absolute value average with moving-average algorithm.

#### Usage

```
_ : abs_envelope_rect(period) : _
```

Where:

* `period`: sets the averaging frame in seconds

#### Test
```
an = library("analyzers.lib");
os = library("oscillators.lib");
mono = os.osc(220);
abs_envelope_rect_test = an.abs_envelope_rect(0.05, mono);
```

----

### `(an.)abs_envelope_tau`

Absolute value average with one-pole lowpass and tau response 
(see [filters.lib](https://faustlibraries.grame.fr/libs/filters/)).

#### Usage

```
_ : abs_envelope_tau(period) : _
```

Where:

* `period`: (time to decay by 1/e) sets the averaging frame in secs

#### Test
```
an = library("analyzers.lib");
os = library("oscillators.lib");
mono = os.osc(220);
abs_envelope_tau_test = an.abs_envelope_tau(0.05, mono);
```

----

### `(an.)abs_envelope_t60`

Absolute value average with one-pole lowpass and t60 response
(see [filters.lib](https://faustlibraries.grame.fr/libs/filters/)).

#### Usage

```
_ : abs_envelope_t60(period) : _
```

Where:

* `period`: (time to decay by 60 dB) sets the averaging frame in secs

#### Test
```
an = library("analyzers.lib");
os = library("oscillators.lib");
mono = os.osc(220);
abs_envelope_t60_test = an.abs_envelope_t60(0.05, mono);
```

----

### `(an.)abs_envelope_t19`

Absolute value average with one-pole lowpass and t19 response
(see [filters.lib](https://faustlibraries.grame.fr/libs/filters/)).

#### Usage

```
_ : abs_envelope_t19(period) : _
```

Where:

* `period`: (time to decay by 1/e^2.2) sets the averaging frame in secs

#### Test
```
an = library("analyzers.lib");
os = library("oscillators.lib");
mono = os.osc(220);
abs_envelope_t19_test = an.abs_envelope_t19(0.05, mono);
```

----

### `(an.)amp_follower`, `(an.)peak_envelope`

Classic analog audio envelope follower with infinitely fast rise and
exponential decay.  The amplitude envelope instantaneously follows
the absolute value going up, but then floats down exponentially.

`amp_follower` is a standard Faust function.

#### Usage

```
_ : amp_follower(rel) : _
```

Where:

* `rel`: release time = amplitude-envelope time-constant (sec) going down

#### Test
```
an = library("analyzers.lib");
os = library("oscillators.lib");
mono = os.osc(220);
amp_follower_test = mono : an.amp_follower(0.05);
```

#### References

* Musical Engineer's Handbook, Bernie Hutchins, Ithaca NY
* 1975 Electronotes Newsletter, Bernie Hutchins

----

### `(an.)amp_follower_ud`

Envelope follower with different up and down time-constants
(also called a "peak detector").

#### Usage

```
   _ : amp_follower_ud(att,rel) : _
```

Where:

* `att`: attack time = amplitude-envelope time constant (sec) going up
* `rel`: release time = amplitude-envelope time constant (sec) going down

#### Test
```
an = library("analyzers.lib");
os = library("oscillators.lib");
mono = os.osc(220);
amp_follower_ud_test = mono : an.amp_follower_ud(0.002, 0.05);
```

#### Note

We assume rel >> att.  Otherwise, consider rel ~ max(rel,att).
For audio, att is normally faster (smaller) than rel (e.g., 0.001 and 0.01).
Use `amp_follower_ar` below to remove this restriction.

#### References

* "Digital Dynamic Range Compressor Design --- A Tutorial and Analysis", by
  Dimitrios Giannoulis, Michael Massberg, and Joshua D. Reiss
*   [https://www.eecs.qmul.ac.uk/~josh/documents/2012/GiannoulisMassbergReiss-dynamicrangecompression-JAES2012.pdf](https://www.eecs.qmul.ac.uk/~josh/documents/2012/GiannoulisMassbergReiss-dynamicrangecompression-JAES2012.pdf)

----

### `(an.)amp_follower_ar`

Envelope follower with independent attack and release times. The
release can be shorter than the attack (unlike in `amp_follower_ud`
above).

#### Usage

```
_ : amp_follower_ar(att,rel) : _
```

Where:

* `att`: attack time = amplitude-envelope time constant (sec) going up
* `rel`: release time = amplitude-envelope time constant (sec) going down

#### Test
```
an = library("analyzers.lib");
os = library("oscillators.lib");
mono = os.osc(220);
amp_follower_ar_test = mono : an.amp_follower_ar(0.002, 0.05);
```

----

### `(an.)ms_envelope_rect`

Mean square with moving-average algorithm.

#### Usage

```
_ : ms_envelope_rect(period) : _
```

Where:

* `period`: sets the averaging frame in secs

#### Test
```
an = library("analyzers.lib");
os = library("oscillators.lib");
mono = os.osc(220);
ms_envelope_rect_test = an.ms_envelope_rect(0.05, mono);
```

----

### `(an.)ms_envelope_tau`

Mean square average with one-pole lowpass and tau response
(see [filters.lib](https://faustlibraries.grame.fr/libs/filters/)).

#### Usage

```
_ : ms_envelope_tau(period) : _
```

Where:

* `period`: (time to decay by 1/e) sets the averaging frame in secs

#### Test
```
an = library("analyzers.lib");
os = library("oscillators.lib");
mono = os.osc(220);
ms_envelope_tau_test = an.ms_envelope_tau(0.05, mono);
```

----

### `(an.)ms_envelope_t60`

Mean square with one-pole lowpass and t60 response 
(see [filters.lib](https://faustlibraries.grame.fr/libs/filters/)).

#### Usage

```
_ : ms_envelope_t60(period) : _
```

Where:

* `period`: (time to decay by 60 dB) sets the averaging frame in secs

#### Test
```
an = library("analyzers.lib");
os = library("oscillators.lib");
mono = os.osc(220);
ms_envelope_t60_test = an.ms_envelope_t60(0.05, mono);
```

----

### `(an.)ms_envelope_t19`

Mean square with one-pole lowpass and t19 response 
(see [filters.lib](https://faustlibraries.grame.fr/libs/filters/)).

#### Usage

```
_ : ms_envelope_t19(period) : _
```

Where:

* `period`: (time to decay by 1/e^2.2) sets the averaging frame in secs

#### Test
```
an = library("analyzers.lib");
os = library("oscillators.lib");
mono = os.osc(220);
ms_envelope_t19_test = an.ms_envelope_t19(0.05, mono);
```

----

### `(an.)rms_envelope_rect`

Root mean square with moving-average algorithm.

#### Usage

```
_ : rms_envelope_rect(period) : _
```

Where:

* `period`: sets the averaging frame in secs

#### Test
```
an = library("analyzers.lib");
os = library("oscillators.lib");
mono = os.osc(220);
rms_envelope_rect_test = an.rms_envelope_rect(0.05, mono);
```

----

### `(an.)rms_envelope_tau`

Root mean square with one-pole lowpass and tau response 
(see [filters.lib](https://faustlibraries.grame.fr/libs/filters/)).

#### Usage

```
_ : rms_envelope_tau(period) : _
```

Where:

* `period`: (time to decay by 1/e) sets the averaging frame in secs

#### Test
```
an = library("analyzers.lib");
os = library("oscillators.lib");
mono = os.osc(220);
rms_envelope_tau_test = an.rms_envelope_tau(0.05, mono);
```

----

### `(an.)rms_envelope_t60`

Root mean square with one-pole lowpass and t60 response 
(see [filters.lib](https://faustlibraries.grame.fr/libs/filters/)).

#### Usage

```
_ : rms_envelope_t60(period) : _
```

Where:

* `period`: (time to decay by 60 dB) sets the averaging frame in secs

#### Test
```
an = library("analyzers.lib");
os = library("oscillators.lib");
mono = os.osc(220);
rms_envelope_t60_test = an.rms_envelope_t60(0.05, mono);
```

----

### `(an.)rms_envelope_t19`

Root mean square with one-pole lowpass and t19 response 
(see [filters.lib](https://faustlibraries.grame.fr/libs/filters/)).

#### Usage

```
_ : rms_envelope_t19(period) : _
```

Where:

* `period`: (time to decay by 1/e^2.2) sets the averaging frame in secs

#### Test
```
an = library("analyzers.lib");
os = library("oscillators.lib");
mono = os.osc(220);
rms_envelope_t19_test = an.rms_envelope_t19(0.05, mono);
```

----

### `(an.)zcr`

Zero-crossing rate (ZCR) with one-pole lowpass averaging based on the tau 
constant. It outputs an index between 0 and 1 at a desired analysis frame. 
The ZCR of a signal correlates with the noisiness [Gouyon et al. 2000] and 
the spectral centroid [Herrera-Boyer et al. 2006] of a signal. 
For sinusoidal signals, the ZCR can be multiplied by ma.SR/2 and used
as a frequency detector. For example, it can be deployed as a
computationally efficient adaptive mechanism for automatic Larsen
suppression.

#### Usage

```
_ : zcr(tau) : _
```

Where:

* `tau`: (time to decay by e^-1) sets the averaging frame in seconds.

#### Test
```
an = library("analyzers.lib");
os = library("oscillators.lib");
mono = os.osc(220);
zcr_test = an.zcr(0.01, mono);
```

## Adaptive Frequency Analysis


----

### `(an.)pitchTracker`


This function implements a pitch-tracking algorithm by means of 
zero-crossing rate analysis and adaptive low-pass filtering. The design
is based on the algorithm described in [this tutorial (section 2.2)](https://github.com/grame-cncm/faust/blob/master-dev/documentation/misc/Faust_tutorial2.pdf).

#### Usage

```
_ : pitchTracker(N, tau) : _
```

Where:

* `N`: a constant numerical expression, sets the order of the low-pass filter, which
 determines the sensitivity of the algorithm for signals where partials are
 stronger than the fundamental frequency.
* `tau`: response time in seconds based on exponentially-weighted averaging with tau time-constant. See [https://ccrma.stanford.edu/~jos/st/Exponentials.html](https://ccrma.stanford.edu/~jos/st/Exponentials.html).

#### Test
```
an = library("analyzers.lib");
os = library("oscillators.lib");
mono = os.osc(220);
pitchTracker_test = an.pitchTracker(4, 0.02, mono);
```

----

### `(an.)spectralCentroid`


This function implements a time-domain spectral centroid by means of RMS 
measurements and adaptive crossover filtering. The weight difference of the
upper and lower spectral powers are used to recursively adjust the crossover
cutoff so that the system (minimally) oscillates around a balancing point.

Unlike block processing techniques such as FFT, this algorithm provides
continuous measurements and fast response times. Furthermore, when providing
input signals that are spectrally sparse, the algorithm will output a 
logarithmic measure of the centroid, which is perceptually desirable for
musical applications. For example, if the input signal is the combination
of three tones at 1000, 2000, and 4000 Hz, the centroid will be the middle
octave.

#### Usage

```
_ : spectralCentroid(nonlinearity, tau) : _
```

Where:

* `nonlinearity`: a boolean to activate or deactivate nonlinear integration. The 
 nonlinear function is useful to improve stability with very short response times 
 such as .001 <= tau <= .005 , otherwise, the nonlinearity may reduce precision.
* `tau`: response time in seconds based on exponentially-weighted averaging with tau time-constant. See [https://ccrma.stanford.edu/~jos/st/Exponentials.html](https://ccrma.stanford.edu/~jos/st/Exponentials.html).

#### Example:

 `process = os.osc(500) + os.osc(1000) + os.osc(2000) + os.osc(4000) + os.osc(8000) : an.spectralCentroid(1, .001);`

#### Test
```
an = library("analyzers.lib");
os = library("oscillators.lib");
rich = os.osc(440) + os.osc(880);
spectralCentroid_test = rich : an.spectralCentroid(1, 0.01);
```

#### References

 Sanfilippo, D. (2021). Time-Domain Adaptive Algorithms for Low- and High-Level 
 Audio Information Processing. Computer Music Journal, 45(1), 24-38.

## Spectrum-Analyzers

Spectrum-analyzers split the input signal into a bank of parallel signals, one for
each spectral band. They are related to the Mth-Octave Filter-Banks in `filters.lib`.
The documentation of this library contains more details about the implementation.
The parameters are:

* `M`: number of band-slices per octave (>1)
* `N`: total number of bands (>2)
* `ftop` = upper bandlimit of the Mth-octave bands (<SR/2)

In addition to the Mth-octave output signals, there is a highpass signal
containing frequencies from ftop to SR/2, and a "dc band" lowpass signal
containing frequencies from 0 (dc) up to the start of the Mth-octave bands.
Thus, the N output signals are:
```
highpass(ftop), MthOctaveBands(M,N-2,ftop), dcBand(ftop*2^(-M*(N-1)))
```

A Spectrum-Analyzer is defined here as any band-split whose bands span
the relevant spectrum, but whose band-signals do not
necessarily sum to the original signal, either exactly or to within an
allpass filtering. Spectrum analyzer outputs are normally at least nearly
"power complementary", i.e., the power spectra of the individual bands
sum to the original power spectrum (to within some negligible tolerance).

#### Increasing Channel Isolation

Go to higher filter orders - see Regalia et al. or Vaidyanathan (cited
below) regarding the construction of more aggressive recursive
filter-banks using elliptic or Chebyshev prototype filters.

#### References

* "Tree-structured complementary filter banks using all-pass sections", Regalia et al., IEEE Trans. Circuits & Systems, CAS-34:1470-1484, Dec. 1987
* "Multirate Systems and Filter Banks", P. Vaidyanathan, Prentice-Hall, 1993
* Elementary filter theory: [https://ccrma.stanford.edu/~jos/filters/](https://ccrma.stanford.edu/~jos/filters/)

----

### `(an.)mth_octave_analyzer`, `(an.)mth_octave_analyzer3`, `(an.)mth_octave_analyzer5`, `(an.)mth_octave_analyzer6e`, `(an.)mth_octave_analyzer_default`

Octave analyzer.
`mth_octave_analyzer[N]` are standard Faust functions.

#### Usage
```
_ : mth_octave_analyzer(O,M,ftop,N) : par(i,N,_) // Oth-order Butterworth
_ : mth_octave_analyzer6e(M,ftop,N) : par(i,N,_) // 6th-order elliptic
```

Also for convenience:

```
_ : mth_octave_analyzer3(M,ftop,N) : par(i,N,_) // 3d-order Butterworth
_ : mth_octave_analyzer5(M,ftop,N) : par(i,N,_) // 5th-order Butterworth
mth_octave_analyzer_default = mth_octave_analyzer6e;
```

Where:

* `O`: (odd) order of filter used to split each frequency band into two
* `M`: number of band-slices per octave
* `ftop`: highest band-split crossover frequency (e.g., 20 kHz)
* `N`: total number of bands (including dc and Nyquist)

#### Test
```
an = library("analyzers.lib");
os = library("oscillators.lib");
mono = os.osc(220);
mth_octave_analyzer_test = mono : an.mth_octave_analyzer(3, 3, 8000, 5);
```

## Mth-Octave Spectral Level

Spectral Level: display (in bargraphs) the average signal level in each spectral band.

----

### `(an.)mth_octave_spectral_level6e`, `(an.)mth_octave_spectral_level_default`, `(an.)spectral_level`

Spectral level display.

#### Usage:

```
_ : mth_octave_spectral_level6e(M,ftop,NBands,tau,dB_offset) : _
```

Where:

* `M`: bands per octave
* `ftop`: lower edge frequency of top band
* `NBands`: number of passbands (including highpass and dc bands),
* `tau`: spectral display averaging-time (time constant) in seconds,
* `dB_offset`: constant dB offset in all band level meters.

Also for convenience:

```
mth_octave_spectral_level_default = mth_octave_spectral_level6e;
spectral_level = mth_octave_spectral_level(2,10000,20);
```

#### Test
```
an = library("analyzers.lib");
os = library("oscillators.lib");
mono = os.osc(220);
mth_octave_spectral_level6e_test = mono : an.mth_octave_spectral_level6e(3, 8000, 5, 0.05, 0);
```

----

### `(an.)octave_analyzer`, `(an.)half_octave_analyzer`, `(an.)third_octave_analyzer`, `(an.)octave_filterbank`, `(an.)half_octave_filterbank`, `(an.)third_octave_filterbank`

A bunch of special cases based on the different analyzer functions described above:

```
third_octave_analyzer(N) = mth_octave_analyzer_default(3,10000,N);
third_octave_filterbank(N) = mth_octave_filterbank_default(3,10000,N);
half_octave_analyzer(N) = mth_octave_analyzer_default(2,10000,N);
half_octave_filterbank(N) = mth_octave_filterbank_default(2,10000,N);
octave_filterbank(N) = mth_octave_filterbank_default(1,10000,N);
octave_analyzer(N) = mth_octave_analyzer_default(1,10000,N);
```

#### Usage

See `mth_octave_spectral_level_demo` in `demos.lib`.

## Arbritary-Crossover Filter-Banks and Spectrum Analyzers

These are similar to the Mth-octave analyzers above, except that the
band-split frequencies are passed explicitly as arguments.

----

### `(an.)analyzer`

Analyzer.

#### Usage

```
_ : analyzer(O,freqs) : par(i,N,_) // No delay equalizer
```

Where:

* `O`: band-split filter order (ODD integer required for filterbank[i])
* `freqs`: (fc1,fc2,...,fcNs) [in numerically ascending order], where
          Ns=N-1 is the number of octave band-splits
          (total number of bands N=Ns+1).

If frequencies are listed explicitly as arguments, enclose them in parens:

```
_ : analyzer(3,(fc1,fc2)) : _,_,_
```

#### Test
```
an = library("analyzers.lib");
os = library("oscillators.lib");
mono = os.osc(220);
analyzer_test = mono : an.analyzer(3, (500, 2000));
```

##  Fast Fourier Transform (fft) and its Inverse (ifft) 

Sliding FFTs that compute a rectangularly windowed FFT each sample.

----

### `(an.)goertzelOpt` 

Optimized Goertzel filter. 

#### Usage

```
_ : goertzelOpt(freq,n) : _
```

Where:

* `freq`: frequency to be analyzed
* `n`: the Goertzel block size

#### Test
```
an = library("analyzers.lib");
os = library("oscillators.lib");
goertzelOpt_test = an.goertzelOpt(440, 128, os.osc(440));
```

#### References

* [https://en.wikipedia.org/wiki/Goertzel_algorithm](https://en.wikipedia.org/wiki/Goertzel_algorithm)

----

### `(an.)goertzelComp` 

Complex Goertzel filter. 

#### Usage

```
_ : goertzelComp(freq,n) : _
```

Where:

* `freq`: frequency to be analyzed
* `n`: the Goertzel block size

#### Test
```
an = library("analyzers.lib");
os = library("oscillators.lib");
goertzelComp_test = an.goertzelComp(440, 128, os.osc(440));
```

#### References

* [https://en.wikipedia.org/wiki/Goertzel_algorithm](https://en.wikipedia.org/wiki/Goertzel_algorithm)

----

### `(an.)goertzel` 

Same as [`goertzelOpt`](#goertzelopt). 

#### Usage

```
_ : goertzel(freq,n) : _
```

Where:

* `freq`: frequency to be analyzed
* `n`: the Goertzel block size

#### Test
```
an = library("analyzers.lib");
os = library("oscillators.lib");
goertzel_test = an.goertzel(440, 128, os.osc(440));
```

#### References

* [https://en.wikipedia.org/wiki/Goertzel_algorithm](https://en.wikipedia.org/wiki/Goertzel_algorithm)

----

### `(an.)resonator` 

Efficient low-latency single-frequency resonator. It estimates 
the magnitude and phase of a single target frequency `f`
in real time, with minimal memory and CPU usage, without the need for
FFT or windowing.

#### Usage

```faust
_ : resonator(N,f) : _,_ // magnitude, phase
```

Where:

* `N`: smoothing filter order (compile-time constant).
       - N > 1: smoother magnitude/phase estimates, but slower response at low f
       - N = 1: faster response at low f, less stable at any f
* `f`: frequency to be analyzed (Hz).

#### Test
```
an = library("analyzers.lib");
os = library("oscillators.lib");
mono = os.osc(220);
resonator_test = mono : an.resonator(2, 440);
```

#### Algorithm

Internally, the resonator maintains a quadrature oscillator at `f`
and accumulates the projection of the input signal onto its sine and
cosine components. These projections are smoothed using an exponential
moving average (EWMA) whose decay factor depends on `f`:

```
sf(f) = 1 − exp(−f / (log(1+f) * SR))
```

Magnitude and phase are then computed from the smoothed projections:

```
magnitude = sqrt(so² + co²) * 2
phase     = atan2(so, co)
```
#### Example

```faust
F = nentry("F", 1000, 0, 10000, 0.001);
process = ba.line(ma.SR, ma.SR/2) : os.oscrs
         <: par(i, 4, resonator(i+1, F) : _,!);
```

#### Advantages
* Ultra-low latency: single-sample recursive update
* No FFT or windowing required
* Frequency-dependent smoothing for better stability at low f
* Scales linearly with the number of resonators

#### References

* [https://alexandrefrancois.org/assets/publications/FrancoisARJ-ICMC2025.pdf](https://alexandrefrancois.org/assets/publications/FrancoisARJ-ICMC2025.pdf)

##  FFT Subsystem 

Sliding FFT/IFFT for complex and real signals, with the conversion and display
helpers they rely on.

**Complex vector representation.** Throughout this section, a *complex vector
signal* of length `N` is a bank of `2*N` parallel real signals holding
interleaved (real, imaginary) pairs: `(r0,i0), (r1,i1), ..., (rN-1,iN-1)`.
This is the convention enforced by `si.cbus(N)`, and it is the input and
output format of `an.fft` and `an.ifft`. A *real vector signal* of length `N`
is simply `N` parallel real signals (`si.bus(N)`). The `rtorv`/`rtocv`/`rvtocv`
functions convert a scalar signal or a real vector into these formats, and the
`c_*` functions operate on complex vectors.

----

### `(an.)c_magsq`

Squared magnitude of each bin of a complex vector signal.

#### Usage

```
si.cbus(N) : c_magsq(N) : si.bus(N)
```

Where:

* `N`: number of complex bins (power of 2 in FFT contexts)
* input: `N` complex signals as interleaved (real, imaginary) pairs
* output: `N` real signals, the `k`-th one being `r(k)^2 + i(k)^2`

----

### `(an.)c_magdb`

Magnitude in dB (power) of each bin of a complex vector signal:
`10*log10(r^2 + i^2)`, floored at `ma.EPSILON` to avoid `log10(0)`.

#### Usage

```
si.cbus(N) : c_magdb(N) : si.bus(N)
```

Where:

* `N`: number of complex bins
* input: `N` complex signals as interleaved (real, imaginary) pairs
* output: `N` real signals giving the power of each bin in dB

----

### `(an.)c_select_pos_freqs`

Select the `N/2+1` non-negative-frequency bins (dc up to and including
Nyquist) out of an `N`-bin complex spectrum, discarding the redundant
negative-frequency bins of a real signal's spectrum.
`select_pos_freqs(N)` is the same selection for a real vector
(e.g. a power spectrum).

#### Usage

```
si.cbus(N) : c_select_pos_freqs(N) : si.cbus(N/2+1)
si.bus(N) : select_pos_freqs(N) : si.bus(N/2+1)
```

Where:

* `N`: full spectrum size (power of 2)
* output: bins `0..N/2` (dc and Nyquist included)

----

### `(an.)rtorv`, `(an.)rtocv`, `(an.)rvtocv`

Convert a real signal to the vector formats used by `an.fft`:

* `rtorv(N,x)`: real scalar signal to length-`N` real vector holding the last
  `N` samples of `x`: `(x, x@1, ..., x@(N-1))`
* `rtocv(N,x)`: real scalar signal to length-`N` complex vector holding the
  last `N` samples of `x` with zero imaginary parts: `(x,0), (x@1,0), ...`
* `rvtocv(N)`: length-`N` real vector to length-`N` complex vector with zero
  imaginary parts

#### Usage

```
rtorv(N,x) : si.bus(N)
rtocv(N,x) : si.cbus(N)
si.bus(N) : rvtocv(N) : si.cbus(N)
```

Where:

* `N`: vector size (power of 2 in FFT contexts, known at compile time)
* `x`: a real (scalar) input signal

#### Test
```
an = library("analyzers.lib");
os = library("oscillators.lib");
rtocv_test = an.rtocv(8, os.osc(220));
```

----

### `(an.)bit_reverse_shuffle`, `(an.)c_bit_reverse_shuffle`, `(an.)bit_reverse_selector`

Bit-reversal permutation of a vector signal, as performed on the input of a
decimation-in-time radix-2 FFT. `bit_reverse_shuffle(N)` permutes a real
vector, `c_bit_reverse_shuffle(N)` a complex vector. Used internally by
`an.fft` and `an.ifft`.

#### Usage

```
si.bus(N) : bit_reverse_shuffle(N) : si.bus(N)
si.cbus(N) : c_bit_reverse_shuffle(N) : si.cbus(N)
```

Where:

* `N`: vector size (must be a power of 2)

----

### `(an.)fft`, `(an.)fftb`

Fast Fourier Transform (FFT).

#### Usage

```
si.cbus(N) : fft(N) : si.cbus(N)
```

Where:

* `si.cbus(N)`: a bus of N complex signals, each specified by real and imaginary parts:
  (r0,i0), (r1,i1), (r2,i2), ...
* `N`: FFT size (must be a power of 2: 2,4,8,16,... known at compile time)
* `fft(N)`: a length-`N` FFT for complex signals (radix 2)
* `output`: a bank of N complex signals containing the complex spectrum over time:
  (R0, I0), (R1,I1), ...
  - The dc component is (R0,I0), where I0=0 for real input signals.

FFTs of Real Signals:

* To perform a sliding FFT over a real input signal, you can say
```
process = signal : an.rtocv(N) : an.fft(N);
```
where `an.rtocv` converts a real (scalar) signal to a complex vector signal having a zero imaginary part.

  * See `an.rfft_analyzer_c` (in `analyzers.lib`) and related functions for more detailed usage examples.

  * Use `an.rfft_spectral_level(N,tau,dB_offset)` to display the power spectrum of a real signal.

  * See `dm.fft_spectral_level_demo(N)` in `demos.lib` for an example GUI driving `an.rfft_spectral_level()`.

#### Test
```
an = library("analyzers.lib");
os = library("oscillators.lib");
mono = os.osc(220);
fft_test = an.rtocv(8, mono) : an.fft(8);
```

#### References

* [Decimation-in-time (DIT) Radix-2 FFT](https://cnx.org/contents/zmcmahhR@7/Decimation-in-time-DIT-Radix-2)

#### Implementation notes

`fft(N)` is `c_bit_reverse_shuffle(N)` followed by `fftb(N)`, the radix-2
butterfly core, which expects its input already in bit-reversed order.

----

### `(an.)ifft`, `(an.)ifftb`

Inverse Fast Fourier Transform (IFFT).

#### Usage

```
si.cbus(N) : ifft(N) : si.cbus(N)
```

Where:

* `N`: IFFT size (power of 2)
* Input is a complex spectrum represented as interleaved real and imaginary parts:
  (R0, I0), (R1,I1), (R2,I2), ...
* Output is a bank of N complex signals giving the complex signal in the time domain:
  (r0, i0), (r1,i1), (r2,i2), ...

#### Test
```
an = library("analyzers.lib");
os = library("oscillators.lib");
mono = os.osc(220);
ifft_test = (an.rtocv(8, mono) : an.fft(8)) : an.ifft(8);
```

#### Implementation notes

`ifft(N)` is `c_bit_reverse_shuffle(N)` followed by `ifftb(N)`, the
conjugate butterfly core (which also applies the `1/N` scaling), so that
`an.fft(N) : an.ifft(N)` is the identity.

----

### `(an.)rfft_analyzer_c`, `(an.)rfft_analyzer_db`, `(an.)rfft_analyzer_magsq`

Sliding FFT analyzers for a real input signal, built from `an.fft`:

* `rfft_analyzer_c(N)`: complex spectrum, bins 0 to N/2 (dc to Nyquist)
* `rfft_analyzer_db(N)`: power of each bin in dB
* `rfft_analyzer_magsq(N)`: squared magnitude of each bin

"Sliding" means the `N`-point FFT is recomputed every sample over the last
`N` input samples, with no windowing (rectangular window) and no hop.

#### Usage

```
_ : rfft_analyzer_c(N) : si.cbus(N/2+1)
_ : rfft_analyzer_db(N) : si.bus(N/2+1)
_ : rfft_analyzer_magsq(N) : si.bus(N/2+1)
```

Where:

* `N`: FFT size (must be a power of 2 known at compile time)
* input: a real (scalar) signal
* output: the `N/2+1` non-negative-frequency bins, complex for
  `rfft_analyzer_c` (interleaved real/imaginary pairs), real for the others

#### Test
```
an = library("analyzers.lib");
os = library("oscillators.lib");
rfft_analyzer_db_test = os.osc(220) : an.rfft_analyzer_db(8);
```

----

### `(an.)rfft_spectral_level`

Real-signal FFT power spectrum display: passes the signal through unchanged
and shows the smoothed level of each of the `N/2+1` non-negative-frequency
bins in a bank of dB bargraphs.

#### Usage

```
_ : rfft_spectral_level(N,tau,dB_offset) : _
```

Where:

* `N`: FFT size (must be a power of 2 known at compile time)
* `tau`: display averaging-time (time constant) in seconds
* `dB_offset`: constant dB offset applied to all band level meters

See `dm.fft_spectral_level_demo(N)` in `demos.lib` for an example GUI.

##  Test signal generators 

Signal generators for testing purposes.

----

### `(an.)logsweep`

Logarithmic sine sweep generator.

#### Usage

```
logsweep(fs,fe,dur) : _
```

Where:

* `fs`: start frequency in Hz
* `fe`: end frequency in Hz
* `dur`: duration of the sweep in seconds

#### Test
```
an = library("analyzers.lib");
logsweep_test = an.logsweep(20, 2000, 5);
```

----

### `(an.)linsweep`

Linear sine sweep generator.

#### Usage

```
linsweep(fs,fe,dur) : _
```

Where:

* `fs`: start frequency in Hz
* `fe`: end frequency in Hz
* `dur`: duration of the sweep in seconds

#### Test
```
an = library("analyzers.lib");
linsweep_test = an.linsweep(20, 2000, 5);
```
