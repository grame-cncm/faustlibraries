#  tonestacks.lib 

A library of guitar amplifier tone stack emulations, from the Guitarix
project, based on the circuit analysis of D.T. Yeh (some component values
taken from the CAPS plugin suite). Each model is the classic passive
treble/middle/bass network of a well-known amplifier, discretized by
bilinear transform from its schematic component values.

The models are normally used through their own namespace:

```
ts = library("tonestacks.lib");
process = ts.jcm2000(t,m,l);
```

#### References

* [https://github.com/grame-cncm/faustlibraries/blob/master/tonestacks.lib](https://github.com/grame-cncm/faustlibraries/blob/master/tonestacks.lib)
* D.T. Yeh and J.O. Smith, "Discretization of the '59 Fender Bassman Tone
  Stack", Proc. of the 9th Int. Conference on Digital Audio Effects (DAFx-06).

----

### `tonestack`

Generic tone stack: computes the bilinear-transformed transfer function
of the classic passive treble/middle/bass network from its schematic
component values. All the amplifier models below are instances of this
function with measured component values.

#### Usage

```
_ : tonestack(C1,C2,C3,R1,R2,R3,R4,t,m,l) : _
```

Where:

* `C1`, `C2`, `C3`: capacitor values of the network, in Farads
* `R1`, `R2`, `R3`, `R4`: resistor values of the network, in Ohms
* `t`: treble control, between 0 and 1
* `m`: middle control, between 0 and 1
* `l`: bass control, between 0 and 1

----

### `bassman`

![bassman — response plots](../img/ts_bassman.svg)

Tone stack of the 1959 Fender Bassman 5F6-A.

#### Usage

```
_ : bassman(t,m,l) : _
```

Where:

* `t`: treble control, between 0 and 1
* `m`: middle control, between 0 and 1
* `l`: bass control, between 0 and 1

----

### `mesa`

![mesa — response plots](../img/ts_mesa.svg)

Tone stack of the Mesa Boogie Mark.

#### Usage

```
_ : mesa(t,m,l) : _
```

Where:

* `t`: treble control, between 0 and 1
* `m`: middle control, between 0 and 1
* `l`: bass control, between 0 and 1

----

### `twin`

![twin — response plots](../img/ts_twin.svg)

Tone stack of the 1969 Fender Twin Reverb AA270.

#### Usage

```
_ : twin(t,m,l) : _
```

Where:

* `t`: treble control, between 0 and 1
* `m`: middle control, between 0 and 1
* `l`: bass control, between 0 and 1

----

### `princeton`

![princeton — response plots](../img/ts_princeton.svg)

Tone stack of the 1964 Fender Princeton AA1164.

#### Usage

```
_ : princeton(t,m,l) : _
```

Where:

* `t`: treble control, between 0 and 1
* `m`: middle control, between 0 and 1
* `l`: bass control, between 0 and 1

----

### `jcm800`

![jcm800 — response plots](../img/ts_jcm800.svg)

Tone stack of the Marshall JCM-800 Lead 100 (model 2203).

#### Usage

```
_ : jcm800(t,m,l) : _
```

Where:

* `t`: treble control, between 0 and 1
* `m`: middle control, between 0 and 1
* `l`: bass control, between 0 and 1

----

### `jcm2000`

![jcm2000 — response plots](../img/ts_jcm2000.svg)

Tone stack of the Marshall JCM-2000 Lead.

#### Usage

```
_ : jcm2000(t,m,l) : _
```

Where:

* `t`: treble control, between 0 and 1
* `m`: middle control, between 0 and 1
* `l`: bass control, between 0 and 1

----

### `jtm45`

![jtm45 — response plots](../img/ts_jtm45.svg)

Tone stack of the Marshall JTM 45.

#### Usage

```
_ : jtm45(t,m,l) : _
```

Where:

* `t`: treble control, between 0 and 1
* `m`: middle control, between 0 and 1
* `l`: bass control, between 0 and 1

----

### `mlead`

![mlead — response plots](../img/ts_mlead.svg)

Tone stack of the 1967 Marshall Major Lead 200.

#### Usage

```
_ : mlead(t,m,l) : _
```

Where:

* `t`: treble control, between 0 and 1
* `m`: middle control, between 0 and 1
* `l`: bass control, between 0 and 1

----

### `m2199`

![m2199 — response plots](../img/ts_m2199.svg)

Tone stack of the Marshall M2199 30W solid state.

#### Usage

```
_ : m2199(t,m,l) : _
```

Where:

* `t`: treble control, between 0 and 1
* `m`: middle control, between 0 and 1
* `l`: bass control, between 0 and 1

----

### `ac30`

![ac30 — response plots](../img/ts_ac30.svg)

Tone stack of the Vox AC-30.

#### Usage

```
_ : ac30(t,m,l) : _
```

Where:

* `t`: treble control, between 0 and 1
* `m`: middle control, between 0 and 1
* `l`: bass control, between 0 and 1

----

### `ac15`

![ac15 — response plots](../img/ts_ac15.svg)

Tone stack of the Vox AC-15.

#### Usage

```
_ : ac15(t,m,l) : _
```

Where:

* `t`: treble control, between 0 and 1
* `m`: middle control, between 0 and 1
* `l`: bass control, between 0 and 1

----

### `soldano`

![soldano — response plots](../img/ts_soldano.svg)

Tone stack of the Soldano SLO 100.

#### Usage

```
_ : soldano(t,m,l) : _
```

Where:

* `t`: treble control, between 0 and 1
* `m`: middle control, between 0 and 1
* `l`: bass control, between 0 and 1

----

### `sovtek`

![sovtek — response plots](../img/ts_sovtek.svg)

Tone stack of the Sovtek MIG 100H.

#### Usage

```
_ : sovtek(t,m,l) : _
```

Where:

* `t`: treble control, between 0 and 1
* `m`: middle control, between 0 and 1
* `l`: bass control, between 0 and 1

----

### `peavey`

![peavey — response plots](../img/ts_peavey.svg)

Tone stack of the Peavey C20.

#### Usage

```
_ : peavey(t,m,l) : _
```

Where:

* `t`: treble control, between 0 and 1
* `m`: middle control, between 0 and 1
* `l`: bass control, between 0 and 1

----

### `ibanez`

![ibanez — response plots](../img/ts_ibanez.svg)

Tone stack of the Ibanez GX20.

#### Usage

```
_ : ibanez(t,m,l) : _
```

Where:

* `t`: treble control, between 0 and 1
* `m`: middle control, between 0 and 1
* `l`: bass control, between 0 and 1

----

### `roland`

![roland — response plots](../img/ts_roland.svg)

Tone stack of the Roland Cube 60.

#### Usage

```
_ : roland(t,m,l) : _
```

Where:

* `t`: treble control, between 0 and 1
* `m`: middle control, between 0 and 1
* `l`: bass control, between 0 and 1

----

### `ampeg`

![ampeg — response plots](../img/ts_ampeg.svg)

Tone stack of the Ampeg VL 501.

#### Usage

```
_ : ampeg(t,m,l) : _
```

Where:

* `t`: treble control, between 0 and 1
* `m`: middle control, between 0 and 1
* `l`: bass control, between 0 and 1

----

### `ampeg_rev`

![ampeg_rev — response plots](../img/ts_ampeg_rev.svg)

Tone stack of the Ampeg Reverbrocket.

#### Usage

```
_ : ampeg_rev(t,m,l) : _
```

Where:

* `t`: treble control, between 0 and 1
* `m`: middle control, between 0 and 1
* `l`: bass control, between 0 and 1

----

### `bogner`

![bogner — response plots](../img/ts_bogner.svg)

Tone stack of the Bogner Triple Giant preamp.

#### Usage

```
_ : bogner(t,m,l) : _
```

Where:

* `t`: treble control, between 0 and 1
* `m`: middle control, between 0 and 1
* `l`: bass control, between 0 and 1

----

### `groove`

![groove — response plots](../img/ts_groove.svg)

Tone stack of the Groove Tubes Trio preamp.

#### Usage

```
_ : groove(t,m,l) : _
```

Where:

* `t`: treble control, between 0 and 1
* `m`: middle control, between 0 and 1
* `l`: bass control, between 0 and 1

----

### `crunch`

![crunch — response plots](../img/ts_crunch.svg)

Tone stack of the Hughes & Kettner.

#### Usage

```
_ : crunch(t,m,l) : _
```

Where:

* `t`: treble control, between 0 and 1
* `m`: middle control, between 0 and 1
* `l`: bass control, between 0 and 1

----

### `fender_blues`

![fender_blues — response plots](../img/ts_fender_blues.svg)

Tone stack of the Fender Blues Junior.

#### Usage

```
_ : fender_blues(t,m,l) : _
```

Where:

* `t`: treble control, between 0 and 1
* `m`: middle control, between 0 and 1
* `l`: bass control, between 0 and 1

----

### `fender_default`

![fender_default — response plots](../img/ts_fender_default.svg)

Tone stack of the Fender (generic).

#### Usage

```
_ : fender_default(t,m,l) : _
```

Where:

* `t`: treble control, between 0 and 1
* `m`: middle control, between 0 and 1
* `l`: bass control, between 0 and 1

----

### `fender_deville`

![fender_deville — response plots](../img/ts_fender_deville.svg)

Tone stack of the Fender Hot Rod DeVille.

#### Usage

```
_ : fender_deville(t,m,l) : _
```

Where:

* `t`: treble control, between 0 and 1
* `m`: middle control, between 0 and 1
* `l`: bass control, between 0 and 1

----

### `gibsen`

![gibsen — response plots](../img/ts_gibsen.svg)

Tone stack of the Gibson GS12 Reverbrocket.

#### Usage

```
_ : gibsen(t,m,l) : _
```

Where:

* `t`: treble control, between 0 and 1
* `m`: middle control, between 0 and 1
* `l`: bass control, between 0 and 1
