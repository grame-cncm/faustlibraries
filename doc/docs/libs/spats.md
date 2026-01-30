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

Apply the constant power pan rule to a stereo signal.
The channels are not respatialized. Their gains are simply
adjusted. A pan of 0 preserves the left channel and silences
the right channel. A pan of 1 has the opposite effect.
A pan value of 0.5 applies a gain of 0.5 to both channels. 

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
  : sp.wfs(0, 1, 0, 0.5, 1, 2, wfs_inGain, wfs_proc, wfs_xs, wfs_ys, wfs_zs);
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
