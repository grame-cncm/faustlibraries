#  hoa.lib 

Higher-Order Ambisonics (HOA) library. Its official prefix is `ho`.

The HOA library provides functions and components for spatial audio rendering
and analysis using Higher-Order Ambisonics. It includes encoders, decoders,
rotators, and utilities for spherical harmonics and spatial transformations.
The library supports both 2D and 3D HOA processing workflows for immersive audio.

The HOA library is organized into 4 sections:

* [Encoding/decoding Functions](#encodingdecoding-functions)
* [Optimization Functions](#optimization-functions)
* [Spatial Sound Processes](#spatial-sound-processes)
* [3D Functions](#3d-functions)

#### References

* [https://github.com/grame-cncm/faustlibraries/blob/master/hoa.lib](https://github.com/grame-cncm/faustlibraries/blob/master/hoa.lib)

## Encoding/decoding Functions


----

### `(ho.)encoder`

Ambisonic encoder. Encodes a signal in the circular harmonics domain
depending on an order of decomposition and an angle.

#### Usage

```
encoder(N, x, a) : _
```

Where:

* `N`: the ambisonic order (constant numerical expression)
* `x`: the signal
* `a`: the angle

#### Test
```
ho = library("hoa.lib");
os = library("oscillators.lib");
encoder_test = ho.encoder(1, os.osc(440), 0.0);
```

----

### `(ho.)rEncoder`

Ambisonic encoder in 2D including source rotation. A mono signal is encoded at a certain ambisonic order
with two possible modes: either rotation with an angular speed, or static with a fixed angle (when speed is zero).

#### Usage

```
_ : rEncoder(N, sp, a, it) : _,_, ...
```

Where:

* `N`: the ambisonic order (constant numerical expression)
* `sp`: the azimuth speed expressed as angular speed (2PI/sec), positive or negative
* `a`: the fixed azimuth when the rotation stops (sp = 0) in radians
* `it` : interpolation time (in milliseconds) between the rotation and the fixed modes

#### Test
```
ho = library("hoa.lib");
os = library("oscillators.lib");
rEncoder_test = os.osc(440) : ho.rEncoder(1, 0.5, 0.0, 0.05);
```

----

### `(ho.)stereoEncoder`

Encoding of a stereo pair of channels with symetric angles (a/2, -a/2).

#### Usage

```
_,_ : stereoEncoder(N, a) : _,_, ...
```

Where:

* `N`: the ambisonic order (constant numerical expression)
* `a` : opening angle in radians, left channel at a/2 angle, right channel at -a/2 angle

#### Test
```
ho = library("hoa.lib");
os = library("oscillators.lib");
stereoEncoder_test = os.osc(440), os.osc(660) : ho.stereoEncoder(1, 1.0);
```

----

### `(ho.)multiEncoder`

Encoding of a set of P signals distributed on the unit circle according to a list of P speeds and P angles.

#### Usage

```
_,_, ... : multiEncoder(N, lspeed, langle, it) : _,_, ...
```

Where:

* `N`: the ambisonic order (constant numerical expression)
* `lspeed` : a list of P speeds in turns by second (one speed per input signal, positive or negative)
* `langle` : a list of P angles in radians on the unit circle to localize the sources (one angle per input signal)
* `it` : interpolation time (in milliseconds) between the rotation and the fixed modes.

#### Test
```
ho = library("hoa.lib");
os = library("oscillators.lib");
multiEncoder_test = os.osc(440), os.osc(660) : ho.multiEncoder(1, (0.0, 0.0), (0.0, 1.57), 0.05);
```

----

### `(ho.)decoder`

Decodes an ambisonics sound field for a circular array of loudspeakers.

#### Usage

```
_ : decoder(N, P) : _
```

Where:

* `N`: the ambisonic order (constant numerical expression)
* `P`: the number of speakers (constant numerical expression)

#### Test
```
ho = library("hoa.lib");
os = library("oscillators.lib");
ambi = ho.encoder(1, os.osc(440), 0.0);
decoder_test = ambi : ho.decoder(1, 4);
```

#### Note

The number of loudspeakers must be greater or equal to 2n+1.
It's preferable to use 2n+2 loudspeakers.

----

### `(ho.)decoderStereo`

Decodes an ambisonic sound field for stereophonic configuration.
An "home made" ambisonic decoder for stereophonic restitution
(30° - 330°): Sound field lose energy around 180°. You should
use `inPhase` optimization with ponctual sources.
#### Usage

```
_ : decoderStereo(N) : _
```

Where:

* `N`: the ambisonic order (constant numerical expression)

#### Test
```
ho = library("hoa.lib");
os = library("oscillators.lib");
ambi = ho.encoder(1, os.osc(440), 0.0);
decoderStereo_test = ambi : ho.decoderStereo(1);
```

----

### `(ho.)iBasicDecoder`

The irregular basic decoder is a simple decoder that projects the incoming ambisonic situation
to the loudspeaker situation (P loudspeakers) whatever it is, without compensation.
When there is a strong irregularity, there can be some discontinuity in the sound field.

#### Usage

```
_,_, ... : iBasicDecoder(N,la, direct, shift) : _,_, ...
```

Where:

* `N`: the ambisonic order (there are 2*N+1 inputs to this function)
* `la` : the list of P angles in degrees, for instance (0, 85, 182, 263) for four loudspeakers
* `direct`: 1 for direct mode, -1 for the indirect mode (changes the rotation direction)
* `shift` : angular shift in degrees to easily adjust angles

#### Test
```
ho = library("hoa.lib");
os = library("oscillators.lib");
ambi = ho.encoder(1, os.osc(440), 0.0);
iBasicDecoder_test = ambi : ho.iBasicDecoder(1, (0, 120, 240), 1, 0);
```

----

### `(ho.)circularScaledVBAP`

The function provides a circular scaled VBAP with all loudspeakers and the virtual source on the unit-circle.

#### Usage

```
_ : circularScaledVBAP(l, t) : _,_, ...
```

Where:

* `l` : the list of angles of the loudspeakers in degrees, for instance (0, 85, 182, 263) for four loudspeakers
* `t` : the current angle of the virtual source in degrees

#### Test
```
ho = library("hoa.lib");
os = library("oscillators.lib");
circularScaledVBAP_test = os.osc(440) : ho.circularScaledVBAP((0, 120, 240), 60);
```

----

### `(ho.)imlsDecoder`

Irregular decoder in 2D for an irregular configuration of P loudspeakers
using 2D VBAP for compensation.

#### Usage

```
_,_, ... : imlsDecoder(N,la, direct, shift) : _,_, ...
``` 

Where:

* `N`: the ambisonic order (constant numerical expression)
* `la` : the list of P angles in degrees, for instance (0, 85, 182, 263) for four loudspeakers
* `direct`: 1 for direct mode, -1 for the indirect mode (changes the rotation direction)
* `shift` : angular shift in degrees to easily adjust angles

#### Test
```
ho = library("hoa.lib");
os = library("oscillators.lib");
ambi = ho.encoder(1, os.osc(440), 0.0);
imlsDecoder_test = ambi : ho.imlsDecoder(1, (0, 90, 180, 270), 1, 0);
```

----

### `(ho.)iDecoder`

General decoder in 2D enabling an irregular multi-loudspeaker configuration
and to switch between multi-channel and stereo.

#### Usage

```
_,_, ... : iDecoder(N, la, direct, st, g) : _,_, ...
```

Where:

* `N`: the ambisonic order (constant numerical expression)
* `la`: the list of angles in degrees
* `direct`: 1 for direct mode, -1 for the indirect mode (changes the rotation direction)
* `shift` : angular shift in degrees to easily adjust angles
* `st`: 1 for stereo, 0 for multi-loudspeaker configuration. When 1, stereo sounds goes through the first two channels
* `g` : gain between 0 and 1

#### Test
```
ho = library("hoa.lib");
os = library("oscillators.lib");
ambi = ho.encoder(1, os.osc(440), 0.0);
iDecoder_test = (ambi, 0.0) : ho.iDecoder(1, (0, 120, 240), 1, 0, 0.8);
```

## Optimization Functions

Functions to weight the circular harmonics signals depending to the
ambisonics optimization.
It can be `basic` for no optimization, `maxRe` or `inPhase`.

----

### `(ho.)optimBasic`

The basic optimization has no effect and should be used for a perfect
circle of loudspeakers with one listener at the perfect center loudspeakers
array.

#### Usage

```
_ : optimBasic(N) : _
```

Where:

* `N`: the ambisonic order (constant numerical expression)

#### Test
```
ho = library("hoa.lib");
os = library("oscillators.lib");
ambi = ho.encoder(1, os.osc(440), 0.0);
optimBasic_test = ambi : ho.optimBasic(1);
```

----

### `(ho.)optimMaxRe`

The maxRe optimization optimizes energy vector. It should be used for an
auditory confined in the center of the loudspeakers array.

#### Usage

```
_ : optimMaxRe(N) : _
```

Where:

* `N`: the ambisonic order (constant numerical expression)

#### Test
```
ho = library("hoa.lib");
os = library("oscillators.lib");
ambi = ho.encoder(1, os.osc(440), 0.0);
optimMaxRe_test = ambi : ho.optimMaxRe(1);
```

----

### `(ho.)optimInPhase`

 The inPhase optimization optimizes energy vector and put all loudspeakers signals
in phase. It should be used for an auditory.

#### Usage

```
_ : optimInPhase(N) : _
```

Where:

* `N`: the ambisonic order (constant numerical expression)

#### Test
```
ho = library("hoa.lib");
os = library("oscillators.lib");
ambi = ho.encoder(1, os.osc(440), 0.0);
optimInPhase_test = ambi : ho.optimInPhase(1);
```

----

### `(ho.)optim`

Ambisonic optimizer including the three elementary optimizers:
`(ho).optimBasic`, `(ho).optimMaxRe` and `(ho.)optimInPhase`.

#### Usage

```
_,_, ... : optim(N, ot) : _,_, ...
```

Where:

* `N`: the ambisonic order (constant numerical expression)
* `ot` : optimization type (0 for `optimBasic`, 1 for `optimMaxRe`, 2 for `optimInPhase`)

#### Test
```
ho = library("hoa.lib");
os = library("oscillators.lib");
ambi = ho.encoder(1, os.osc(440), 0.0);
optim_test = ambi : ho.optim(1, 1);
```

----

### `(ho.)wider`

Can be used to wide the diffusion of a localized sound. The order
depending signals are weighted and appear in a logarithmic way to
have linear changes.

#### Usage

```
_ : wider(N,w) : _
```

Where:

* `N`: the ambisonic order (constant numerical expression)
* `w`: the width value between 0 - 1

#### Test
```
ho = library("hoa.lib");
os = library("oscillators.lib");
ambi = ho.encoder(1, os.osc(440), 0.0);
wider_test = ambi : ho.wider(1, 0.5);
```

----

### `(ho.)mirror`

Mirroring effect on the sound field.

#### Usage

```
_,_, ... : mirror(N, fa) : _,_, ...
```

Where:

* `N`: the ambisonic order (constant numerical expression)
* `fa` : mirroring type (1 = original sound field, 0 = original+mirrored sound field, -1 = mirrored sound field)

#### Test
```
ho = library("hoa.lib");
os = library("oscillators.lib");
ambi = ho.encoder(1, os.osc(440), 0.0);
mirror_test = ambi : ho.mirror(1, -1);
```

----

### `(ho.)map`

It simulates the distance of the source by applying a gain
on the signal and a wider processing on the soundfield.

#### Usage

```
map(N, x, r, a)
```

Where:

* `N`: the ambisonic order (constant numerical expression)
* `x`: the signal
* `r`: the radius
* `a`: the angle in radian

#### Test
```
ho = library("hoa.lib");
os = library("oscillators.lib");
map_test = ho.map(1, os.osc(440), 0.5, 0.0);
```

----

### `(ho.)rotate`

Rotates the sound field.

#### Usage

```
_ : rotate(N, a) : _
```

Where:

* `N`: the ambisonic order (constant numerical expression)
* `a`: the angle in radian

#### Test
```
ho = library("hoa.lib");
os = library("oscillators.lib");
rotate_test = ho.encoder(1, os.osc(440), 0.0) : ho.rotate(1, 0.78);
```

----

### `(ho.)scope`

Produces an XY pair of signals representing the ambisonic sound field.

#### Usage

```
_,_, ... : scope(N, rt) : _,_
```

Where:

* `N`: the ambisonic order (constant numerical expression)
* `rt` : refreshment time in milliseconds

#### Test
```
ho = library("hoa.lib");
os = library("oscillators.lib");
scope_test = ho.encoder(1, os.osc(440), 0.0) : ho.scope(1, 0.1);
```

## Spatial Sound Processes 

We propose implementations of processes intricated to the ambisonic model.
The process is implemented using as many instances as the number of harmonics at at certain order.
The key control parameters of these instances are computed thanks to distribution functions
(th functions below) and to a global driving factor.

----

### `(ho.).fxDecorrelation`

Spatial ambisonic decorrelation in fx mode.

`fxDecorrelation` applies decorrelations to spatial components already created.
The decorrelation is defined for each #i spatial component among P=2\*N+1 at the ambisonic order `N`
as a delay of 0 if factor `fa` is under a certain value 1-(i+1)/P and d\*F((i+1)/p) in the contrary case,
where `d` is the maximum delay applied (in samples) and F is a distribution function for durations.
The user can choose this delay time distribution among 22 different ones.
The delay increases according to the index of ambisonic components.
But it increases at each step and it is modulated by a threshold.
Therefore, delays are progressively revealed when the factor increases:

* when the factor is close to 0, only upper components are delayed;
* when the factor increases, more and more components are delayed.



#### Usage

```
_,_, ... : fxDecorrelation(N, d, wf, fa, fd, tf) : _,_, ...
```

Where:

* `N`: the ambisonic order (constant numerical expression)
* `d`: the maximum delay applied (in samples)
* `wf`: window frequency (in Hz) for the overlapped delay
* `fa`: decorrelation factor (between 0 and 1)
* `fd`: feedback / level of reinjection (between 0 and 1)
* `tf`: type of function of delay distribution (integer, between 0 and 21)

#### Test
```
ho = library("hoa.lib");
os = library("oscillators.lib");
fxDecorrelation_test = ho.encoder(1, os.osc(440), 0.0) : ho.fxDecorrelation(1, 64, 5, 0.5, 0.2, 0);
```

----

### `(ho.).synDecorrelation`

Spatial ambisonic decorrelation in syn mode.

`synDecorrelation` generates spatial decorrelated components in ambisonics from one mono signal.
The decorrelation is defined for each #i spatial component among P=2\*N+1 at the ambisonic order `N`
as a delay of 0 if factor `fa` is under a certain value 1-(i+1)/P and d\*F((i+1)/p) in the contrary case,
where `d` is the maximum delay applied (in samples) and F is a distribution function for durations.
The user can choose this delay time distribution among 22 different ones.
The delay increases according to the index of ambisonic components.
But it increases at each step and it is modulated by a threshold.
Therefore, delays are progressively revealed when the factor increases:

* when the factor is close to 0, only upper components are delayed;
* when the factor increases, more and more components are delayed.

When the factor is between [0; 1/P], upper harmonics are progressively faded and the level of the H0 component is compensated
to avoid source localization and to produce a large mono.



#### Usage

```
_,_, ... : synDecorrelation(N, d, wf, fa, fd, tf) : _,_, ...
```

Where:

* `N`: the ambisonic order (constant numerical expression)
* `d`: the maximum delay applied (in samples)
* `wf`: window frequency (in Hz) for the overlapped delay
* `fa`: decorrelation factor (between 0 and 1)
* `fd`: feedback / level of reinjection (between 0 and 1)
* `tf`: type of function of delay distribution (integer, between 0 and 21)

#### Test
```
ho = library("hoa.lib");
os = library("oscillators.lib");
synDecorrelation_test = os.osc(440) : ho.synDecorrelation(1, 64, 5, 0.5, 0.2, 0);
```

----

### `(ho.).fxRingMod`

Spatial ring modulation in syn mode.

`fxRingMod` applies ring modulation to spatial components already created.
The ring modulation is defined for each spatial component among P=2\*n+1 at the ambisonic order `N`.
For each spatial component #i, the result is either the original signal or a ring modulated signal
according to a threshold that is i/P.

The general process is drive by a factor `fa` between 0 and 1 and a modulation frequency `f0`.
If `fa` is greater than theshold (P-i-1)/P, the ith ring modulator is on with carrier frequency of f0\*(i+1)/P.
On the contrary, it provides the original signal.

Therefore ring modulators are progressively revealed when `fa` increases.



#### Usage

```
_,_, ... : fxRingMod(N, f0, fa, tf) : _,_, ...
```

Where:

* `N`: the ambisonic order (constant numerical expression)
* `f0`: the maximum delay applied (in samples)
* `fa`: decorrelation factor (between 0 and 1)
* `tf`: type of function of delay distribution (integer, between 0 and 21)

#### Test
```
ho = library("hoa.lib");
os = library("oscillators.lib");
fxRingMod_test = ho.encoder(1, os.osc(440), 0.0) : ho.fxRingMod(1, 200, 0.5, 0);
```

----

### `(ho.).synRingMod`

Spatial ring modulation in syn mode.

`synRingMod` generates spatial components in ambisonics from one mono signal thanks to ring modulation.
The ring modulation is defined for each spatial component among P=2\*n+1 at the ambisonic order `N`.
For each spatial component #i, the result is either the original signal or a ring modulated signal
according to a threshold that is i/P.

The general process is drive by a factor `fa` between 0 and 1 and a modulation frequency `f0`.
If `fa` is greater than theshold (P-i-1)/P, the ith ring modulator is on with carrier frequency of f0\*(i+1)/P.
On the contrary, it provides the original signal.

Therefore ring modulators are progressively revealed when `fa` increases.
When the factor is between [0; 1/P], upper harmonics are progressively faded and the level of the H0 component is compensated
to avoid source localization and to produce a large mono.



#### Usage

```
_,_, ... : synRingMod(N, f0, fa, tf) : _,_, ...
```

Where:

* `N`: the ambisonic order (constant numerical expression)
* `f0`: the maximum delay applied (in samples)
* `fa`: decorrelation factor (between 0 and 1)
* `tf`: type of function of delay distribution (integer, between 0 and 21)

#### Test
```
ho = library("hoa.lib");
os = library("oscillators.lib");
synRingMod_test = os.osc(440) : ho.synRingMod(1, 200, 0.5, 0);
```

## 3D Functions


----

### `(ho.)encoder3D`

Ambisonic encoder. Encodes a signal in the circular harmonics domain
depending on an order of decomposition, an angle and an elevation.

#### Usage

```
encoder3D(N, x, a, e) : _
```

Where:

* `N`: the ambisonic order (constant numerical expression)
* `x`: the signal
* `a`: the angle
* `e`: the elevation

#### Test
```
ho = library("hoa.lib");
os = library("oscillators.lib");
encoder3D_test = ho.encoder3D(1, os.osc(440), 0.0, 0.0);
```

----

### `(ho.)rEncoder3D`

Ambisonic encoder in 3D including source rotation. A mono signal is encoded at at certain ambisonic order
with two possible modes: either rotation with 2 angular speeds (azimuth and elevation), or static with a fixed pair of angles.

`rEncoder3D` is a standard Faust function.

#### Usage

```
_ : rEncoder3D(N, azsp, elsp, az, el, it) : _,_, ...
```

Where:

* `N`: the ambisonic order (constant numerical expression)
* `azsp`: the azimuth speed expressed as angular speed (2PI/sec), positive or negative
* `elsp`: the elevation speed expressed as angular speed (2PI/sec), positive or negative
* `az`: the fixed azimuth when the azimuth rotation stops (azsp = 0) in radians
* `el`: the fixed elevation when the elevation rotation stops (elsp = 0) in radians
* `it` : interpolation time (in milliseconds) between the rotation and the fixed modes

#### Test
```
ho = library("hoa.lib");
os = library("oscillators.lib");
rEncoder3D_test = os.osc(440) : ho.rEncoder3D(1, 0.5, 0.3, 0.0, 0.0, 0.05);
```

----

### `(ho.)optimBasic3D`

The basic optimization has no effect and should be used for a perfect
sphere of loudspeakers with one listener at the perfect center loudspeakers
array.

#### Usage

```
_ : optimBasic3D(N) : _
```

Where:

* `N`: the ambisonic order (constant numerical expression)

#### Test
```
ho = library("hoa.lib");
os = library("oscillators.lib");
ambi3D = ho.encoder3D(1, os.osc(440), 0.0, 0.0);
optimBasic3D_test = ambi3D : ho.optimBasic3D(1);
```

----

### `(ho.)optimMaxRe3D`

The maxRe optimization optimize energy vector. It should be used for an
auditory confined in the center of the loudspeakers array.

#### Usage

```
_ : optimMaxRe3D(N) : _
```

Where:

* `N`: the ambisonic order (constant numerical expression)

#### Test
```
ho = library("hoa.lib");
os = library("oscillators.lib");
ambi3D = ho.encoder3D(1, os.osc(440), 0.0, 0.0);
optimMaxRe3D_test = ambi3D : ho.optimMaxRe3D(1);
```

----

### `(ho.)optimInPhase3D`

The inPhase Optimization optimizes energy vector and put all loudspeakers signals
in phase. It should be used for an auditory.

#### Usage

```
_ : optimInPhase3D(N) : _
```

Where:

* `N`: the ambisonic order (constant numerical expression)

#### Test
```
ho = library("hoa.lib");
os = library("oscillators.lib");
ambi3D = ho.encoder3D(1, os.osc(440), 0.0, 0.0);
optimInPhase3D_test = ambi3D : ho.optimInPhase3D(1);
```

----

### `(ho.)optim3D`

Ambisonic optimizer including the three elementary optimizers:
`(ho).optimBasic3D`, `(ho).optimMaxRe3D` and `(ho.)optimInPhase3D`.

#### Usage

```
_,_, ... : optim3D(N, ot) : _,_, ...
```

Where:

* `N`: the ambisonic order (constant numerical expression)
* `ot` : optimization type (0 for optimBasic, 1 for optimMaxRe, 2 for optimInPhase)

#### Test
```
ho = library("hoa.lib");
os = library("oscillators.lib");
ambi3D = ho.encoder3D(1, os.osc(440), 0.0, 0.0);
optim3D_test = ambi3D : ho.optim3D(1, 2);
```
