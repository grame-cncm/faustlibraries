#  spats.lib 

Spatialization (Spats) library. Its official prefix is `sp`.

This library provides spatialization in Faust.
It includes panning and wfs algorithms.

The Spats library is organized into 1 section:

* [Functions Reference](#functions-reference)

#### References

* [https://github.com/grame-cncm/faustlibraries/blob/master/spats.lib](https://github.com/grame-cncm/faustlibraries/blob/master/spats.lib)

## Functions Reference


----

### `(sp.)panner`

A simple linear stereo panner.
`panner` is a standard Faust function.

#### Usage

```
_ : panner(g) : _,_
```

Where:

* `g`: the panning (0-1)

#### Test
```
sp = library("spats.lib");
os = library("oscillators.lib");
panner_test = os.osc(220) : sp.panner(hslider("panner:pan", 0.3, 0, 1, 0.01));
```

----

### `(sp.)constantPowerPan`

Apply constant-power panning to a stereo signal. Each input channel's gain
is adjusted according to the pan position using a cosine/sine law: the left
input is scaled by cos(θ)/√2 and the right input by sin(θ)/√2, where
θ = π·p/2.

#### Normalization

A standard constant-power pan uses bare cos/sin gains, which peak at unity
(0 dB) when hard-panned and dip to 1/√2 (−3 dB) at center. This
implementation divides by √2, halving all gains:

* `p = 0`  : left = 1/√2 ≈ 0.707 (−3 dB), right = 0
* `p = 0.5`: left = 0.5 (−6 dB),          right = 0.5 (−6 dB)
* `p = 1`  : left = 0,                    right = 1/√2 ≈ 0.707 (−3 dB)

The /√2 factor makes the panner mono-safe: if the two output channels are
ever summed to mono, the worst case is center pan, where the mono signal
becomes 0.5*x + 0.5*y. Without the normalization, center pan would produce
≈ 0.707*x + 0.707*y, which can clip with correlated or in-phase material.
More generally, the normalization guarantees that the sum of the two gains
never exceeds unity for any pan position:

  gainLeft + gainRight = (cos θ + sin θ) / √2 ≤ 1

This holds because cos θ + sin θ has a maximum of √2 (at θ = π/4), and
√2/√2 = 1. The total power is also constant at 0.5 for all pan positions.

#### Usage

```
_,_ : constantPowerPan(p) : _,_
```

Where:

* `p`: the panning (0-1)

#### Test
```
sp = library("spats.lib");
os = library("oscillators.lib");
constantPowerPan_test = (os.osc(110), os.osc(220))
  : sp.constantPowerPan(hslider("constantPowerPan:pan", 0.4, 0, 1, 0.01));
```

----

### `(sp.)spat`

GMEM SPAT: n-outputs spatializer.
`spat` is a standard Faust function.

#### Usage

```
_ : spat(N,r,d) : si.bus(N)
```

Where:

* `N`: number of outputs (a constant numerical expression)
* `r`: rotation (between 0 et 1)
* `d`: distance of the source (between 0 et 1)

#### Test
```
sp = library("spats.lib");
os = library("oscillators.lib");
spat_test = os.osc(330)
  : sp.spat(4,
      hslider("spat:rotation", 0.25, 0, 1, 0.01),
      hslider("spat:distance", 0.5, 0, 1, 0.01));
```

----

### `(sp.)wfs`

Wave Field Synthesis algorithm for multiple sound sources. 
Implementation generalized starting from Pierre Lecomte version. 

#### Usage

```
wfs(xref, yref, zref, speakersDist, nSources, nSpeakers, inProc, xs, ys, zs) : si.bus(nSpeakers)
```

Where:

* `xref`: x-coordinate of the reference listening point in meters
* `yref`: y-coordinate of the reference listening point in meters
* `zref`: z-coordinate of the reference listening point in meters
* `speakersDist`: distance between speakers in meters (a constant numerical expression)
* `nSources`: number of sound sources (a constant numerical expression)
* `nSpeakers`: number of speakers (a constant numerical expression)
* `inProc`: per-source processor function, as a function of the source index
* `xs`: x-coordinate of the sound source in meters, as a function of the source index
* `ys`: y-coordinate of the sound source in meters, as a function of the source index
* `zs`: z-coordinate of the sound source in meters, as a function of the source index

#### Test
```
sp = library("spats.lib");
os = library("oscillators.lib");
wfs_proc(i) = *(0.5); // Simple gain processor
wfs_xs(i) = 0.0;
wfs_ys(i) = 1.0;
wfs_zs(i) = 0.0;
wfs_test = os.osc(440)
  : sp.wfs(0, 1, 0, 0.5, 1, 2, wfs_proc, wfs_xs, wfs_ys, wfs_zs);
```

----

### `(sp.)wfs_ui`

Wave Field Synthesis algorithm for multiple sound sources with a built-in UI.

#### Usage

```
wfs_ui(xref, yref, zref, speakersDist, nSources, nSpeakers) : si.bus(nSpeakers)
```

Where:

* `xref`: x-coordinate of the reference listening point in meters
* `yref`: y-coordinate of the reference listening point in meters
* `zref`: z-coordinate of the reference listening point in meters
* `speakersDist`: distance between speakers in meters
* `nSources`: number of sound sources (a constant numerical expression)
* `nSpeakers`: number of speakers (a constant numerical expression)

#### Test
```
sp = library("spats.lib");
os = library("oscillators.lib");
wfs_ui_test = os.osc(550)
  : sp.wfs_ui(0, 1, 0, 0.5, 1, 2);
```

#### Example test program

```
// Distance between speakers in meters
speakersDist = 0.0783;  

// Reference listening point (central position for WFS)
xref = 0;
yref = 1;
zref = 0;

Spatialize 4 sound sources on 16 speakers
process = wfs_ui(xref,yref,zref,speakersDist,4,16);
```

----

### `(sp.)spcap`

Speaker-Placement Correction Amplitude Panning (SPCAP).

SPCAP calculates panning gains for an arbitrary 2D loudspeaker 
layout by computing the angular distance between the virtual source 
and each speaker, and correcting for "speaker density" (groupings 
of speakers that would otherwise cause a volume imbalance).

Important note on physical distance: this algorithm only handles spatial
distribution based on azimuth angles. It does not compensate for volume drops
or acoustic delays caused by uneven physical distances of the speakers from
the listener. In a complete DSP chain, distance correction must be applied
downstream from this algorithm, individually per channel, using a delay line
for time alignment and a static gain trim to equalize acoustic pressure.

#### Usage

```
_ : spcap(N, alpha, th, theta_s) : si.bus(N)
```

Where:

* `N`: number of speakers (a constant numerical expression)
* `alpha`: panning sharpness/width (float signal, typical range 1.0 to 10.0)
* `th`: a function `th(i)` returning the physical azimuth angle of speaker `i` in radians
* `theta_s`: virtual source azimuth angle in radians (float signal)

#### Test

```
N = 4;
alpha = 2.0;
theta_s = 0.0;
spk_deg(0) = -135;
spk_deg(1) =  -45;
spk_deg(2) =   45;
spk_deg(3) =  135;
spk_angle(i) = spk_deg(i) * ma.PI / 180.0;

spcap_test = os.osc(440) : sp.spcap(N, alpha, spk_angle, theta_s);
```

#### References

* Ramy Sadek and Chris Kyriakakis, "A Novel Multichannel Panning Method for Standard and Arbitrary Loudspeaker Configurations", 2004. (DTIC Reference: ADA464895)
* [https://apps.dtic.mil/sti/tr/pdf/ADA464895.pdf](https://apps.dtic.mil/sti/tr/pdf/ADA464895.pdf)

----

### `(sp.)spcap_ui`

Speaker-Placement Correction Amplitude Panning with a built-in UI.
This is a convenience wrapper around `spcap` for interactive control of the
virtual source azimuth, the panning sharpness, and the physical azimuth of
each loudspeaker.

#### Usage

```
_ : spcap_ui(N) : si.bus(N)
```

Where:

* `N`: number of speakers (a constant numerical expression). The function has one
  input signal and produces `N` output signals, one per speaker

UI controls:

* `SPCAP/pan_sharpness`: panning sharpness parameter `alpha`. Higher values
  make the virtual source more focused around the closest speakers.
* `SPCAP/source_angle`: virtual source azimuth in degrees. The value is
  converted to radians before calling `spcap`.
* `SPCAP/Speaker%2i/angle`: physical azimuth of speaker `i` in degrees. The
  default layout is a regular circular distribution centered in each speaker
  sector, and can be edited from the UI.

Use `spcap` directly when the source angle, speaker angles, or sharpness
parameter must be supplied by an existing DSP expression instead of UI
controls.

#### Test

```
sp = library("spats.lib");
os = library("oscillators.lib");
spcap_ui_test = os.osc(440) : sp.spcap_ui(4);
```

#### Example test program

```
import("stdfaust.lib");

process = os.osc(440) : sp.spcap_ui(8);
```

----

### `(sp.)stereoize`

Transform an arbitrary processor `p` into a stereo processor with 2 inputs
and 2 outputs.

#### Usage

```
_,_ : stereoize(p) : _,_
```

Where:

* `p`: the arbitrary processor

#### Test
```
sp = library("spats.lib");
os = library("oscillators.lib");
stereoize_test = (os.osc(660), os.osc(770))
  : sp.stereoize(+);
```
