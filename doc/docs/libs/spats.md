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
* `speakersDist`: distance between speakers in meters
* `nSources`: number of sound sources
* `nSpeakers`: number of speakers
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
wfs_ui(xref, yref, zref, speakersDist, nSources, nSpeaker) : si.bus(nSpeakers)
```

Where:

* `xref`: x-coordinate of the reference listening point in meters
* `yref`: y-coordinate of the reference listening point in meters
* `zref`: z-coordinate of the reference listening point in meters
* `speakersDist`: distance between speakers in meters
* `nSources`: number of sound sources
* `nSpeakers`: number of speakers

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
