#  hysteresis.lib 

Hysteresis library. Its official prefix is `hy`.

This library provides physics-based magnetic hysteresis models for audio processing.
Suitable for transformer saturation, tape emulation, and magnetic effects.

Currently implemented models:

* Jiles-Atherton (ja_*) - Physics-based ferromagnetic hysteresis

The Hysteresis library is organized into 3 sections:

* [Jiles-Atherton Core](#jiles-atherton-core)
* [Jiles-Atherton Processors](#jiles-atherton-processors)
* [Jiles-Atherton UI Wrappers](#jiles-atherton-ui-wrappers)

#### Musical Character

The `c` (reversibility) and input calibration work together:

| Calibration | c    | Character                      |
|-------------|------|--------------------------------|
| -50 dB      | 0.25 | Forward, open, dynamic         |
| 0 dB        | 0.9  | Compressed, set back, controlled |

Blend between these extremes for different textures.

#### References

* [https://en.wikipedia.org/wiki/Jiles-Atherton_model](https://en.wikipedia.org/wiki/Jiles-Atherton_model)
* [https://github.com/grame-cncm/faustlibraries/blob/master/hysteresis.lib](https://github.com/grame-cncm/faustlibraries/blob/master/hysteresis.lib)

##  Jiles-Atherton Core 

The core hysteresis function implementing the Jiles-Atherton model with
4x cascaded substeps and cubic Hermite interpolation for smooth transients.

----

### `(hy.)ja_hysteresis`

Jiles-Atherton hysteresis core with 4x substep interpolation.
Implements magnetic hysteresis with smooth transient response using
cubic Hermite interpolation between samples.

#### Usage

```
_ : ja_hysteresis(Ms, a, alpha, k, c) : _
```

Where:

* `Ms`: saturation magnetization, controls maximum output level (100-1000, default 380)
* `a`: anhysteretic curve shape parameter (100-2000, default 720)
* `alpha`: mean-field coupling coefficient (0.001-0.1, default 0.015)
* `k`: coercivity, controls hysteresis loop width (50-1000, default 380)
* `c`: reversibility factor, ratio of reversible to irreversible magnetization (0-1, default 0.25)

#### Test
```
hy = library("hysteresis.lib");
os = library("oscillators.lib");
ba = library("basics.lib");
ma = library("maths.lib");
mono = os.tosc(100) * 0.5;
ja_hysteresis_test = mono : hy.ja_hysteresis(380, 720, 0.015, 380, 0.25);
ja_hysteresis_slider_test = os.tosc(100)*0.5 : hy.ja_hysteresis(hslider("ja_hysteresis:Ms", 380, 100, 1000, 1), hslider("ja_hysteresis:a", 720, 100, 2000, 1), hslider("ja_hysteresis:alpha", 0.015, 0, 0.1, 0.001), hslider("ja_hysteresis:k", 380, 100, 1000, 1), hslider("ja_hysteresis:c", 0.25, 0, 1, 0.01));
ja_hysteresis_modulated_test = os.tosc(100)*0.5 : hy.ja_hysteresis(380, 720, 0.015, 100*pow(10, tri), 0.25) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
```

#### References

* [https://en.wikipedia.org/wiki/Jiles-Atherton_model](https://en.wikipedia.org/wiki/Jiles-Atherton_model)
* [https://www.sciencedirect.com/science/article/abs/pii/S0304885321006466](https://www.sciencedirect.com/science/article/abs/pii/S0304885321006466)

##  Jiles-Atherton Processors 

Ready-to-use processors with gain staging and DC blocking.

----

### `(hy.)ja_processor`

Complete mono Jiles-Atherton hysteresis processor with drive control,
automatic gain compensation, and DC blocking.

#### Usage

```
_ : ja_processor(Ms, a, alpha, k, c, drive, trim) : _
```

Where:

* `Ms`: saturation magnetization (100-1000)
* `a`: anhysteretic curve shape (100-2000)
* `alpha`: mean-field coupling (0.001-0.1)
* `k`: coercivity/loop width (50-1000)
* `c`: reversibility factor (0-1)
* `drive`: input drive in linear gain (use ba.db2linear for dB)
* `trim`: output trim in linear gain (use ba.db2linear for dB)

#### Test
```
hy = library("hysteresis.lib");
ba = library("basics.lib");
os = library("oscillators.lib");
ma = library("maths.lib");
mono = os.tosc(100) * 0.5;
ja_processor_test = mono : hy.ja_processor(380, 720, 0.015, 380, 0.25, ba.db2linear(10), 1.0);
ja_processor_slider_test = os.tosc(100)*0.5 : hy.ja_processor(hslider("ja_processor:Ms", 380, 100, 1000, 1), hslider("ja_processor:a", 720, 100, 2000, 1), hslider("ja_processor:alpha", 0.015, 0, 0.1, 0.001), hslider("ja_processor:k", 380, 100, 1000, 1), hslider("ja_processor:c", 0.25, 0, 1, 0.01), hslider("ja_processor:drive", 3.1623, 0, 10, 0.0001), hslider("ja_processor:trim", 1.0, 0, 2, 0.01));
ja_processor_modulated_test = os.tosc(100)*0.5 : hy.ja_processor(380, 720, 0.015, 380, 0.25, ba.db2linear(20*tri), 1.0) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
```

----

### `(hy.)ja_processor_stereo`

Stereo Jiles-Atherton hysteresis processor applying identical processing
to both channels.

#### Usage

```
_,_ : ja_processor_stereo(Ms, a, alpha, k, c, drive, trim) : _,_
```

Where:

* `Ms`: saturation magnetization (100-1000)
* `a`: anhysteretic curve shape (100-2000)
* `alpha`: mean-field coupling (0.001-0.1)
* `k`: coercivity/loop width (50-1000)
* `c`: reversibility factor (0-1)
* `drive`: input drive in linear gain
* `trim`: output trim in linear gain

#### Test
```
hy = library("hysteresis.lib");
ba = library("basics.lib");
os = library("oscillators.lib");
stereo = os.tosc(100), os.tosc(150);
ja_processor_stereo_test = stereo : hy.ja_processor_stereo(380, 720, 0.015, 380, 0.25, ba.db2linear(10), 1.0);
```

##  Jiles-Atherton UI Wrappers 

Ready-to-use processors with built-in user interface controls.

----

### `(hy.)ja_processor_ui`

Mono Jiles-Atherton hysteresis processor with full UI controls for all parameters.
Includes smoothed controls and sensible defaults.

#### Usage

```
_ : ja_processor_ui : _
```

#### Test
```
hy = library("hysteresis.lib");
os = library("oscillators.lib");
mono = os.tosc(100) * 0.5;
ja_processor_ui_test = mono : hy.ja_processor_ui;
```

----

### `(hy.)ja_processor_stereo_ui`

Stereo Jiles-Atherton hysteresis processor with full UI controls.
Applies identical processing to both channels with shared parameters.

#### Usage

```
_,_ : ja_processor_stereo_ui : _,_
```

#### Test
```
hy = library("hysteresis.lib");
os = library("oscillators.lib");
stereo = os.tosc(100), os.tosc(150);
ja_processor_stereo_ui_test = stereo : hy.ja_processor_stereo_ui;
```
