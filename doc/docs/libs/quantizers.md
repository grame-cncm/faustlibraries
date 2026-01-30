#  quantizers.lib 

Quantizers library. Its official prefix is `qu`.

This library provides utilities for pitch and signal quantization in Faust.
It includes functions for mapping continuous inputs to discrete musical scales.

The Quantizers library is organized into 1 section:

* [Functions Reference](#functions-reference)

#### References

* [https://github.com/grame-cncm/faustlibraries/blob/master/quantizers.lib](https://github.com/grame-cncm/faustlibraries/blob/master/quantizers.lib)

## Functions Reference


----

### `(qu.)quantize`

Configurable frequency quantization tool. Snaps input frequencies to exact scale notes.
Works for positive audio frequencies.

#### Usage

```
_ : quantize(rf,nl) : _
```

Where:

* `rf` : frequency of the root note of the scale
* `nl` : list of frequency ratios for each note relative to root

#### Test
```
qu = library("quantizers.lib");
quantize_test = qu.quantize(440, qu.ionian, hslider("input", 450, 100, 1000, 1));
```

#### Example
```
process = quantize(440, (1, 1.125, 1.25, 1.333, 1.5));
```

----

### `(qu.)quantizeSmoothed`

Configurable frequency quantization tool. Smoothly transitions between scale notes.
Works for positive audio frequencies.

#### Usage

```
_ : quantizeSmoothed(rf,nl) : _
```

Where:

* `rf` : frequency of the root note of the scale
* `nl` : list of frequency ratios for each note relative to root

#### Test
```
qu = library("quantizers.lib");
quantizeSmoothed_test = qu.quantizeSmoothed(440, qu.ionian, hslider("input", 450, 100, 1000, 1));
```

#### Example
```
process = quantizeSmoothed(440, dodeca);
```

----

### `(qu.)ionian`

List of the frequency ratios of the notes of the ionian mode.

#### Usage
```
_ : quantize(rf,ionian) : _
```

Where:

* `rf`: frequency of the root note of the scale

#### Test
```
qu = library("quantizers.lib");
ionian_test = qu.quantize(220, qu.ionian, 260);
```

----

### `(qu.)dorian`

List of the frequency ratios of the notes of the dorian mode.

#### Usage
```
_ : quantize(rf,dorian) : _
```

Where:

* `rf`: frequency of the root note of the scale

#### Test
```
qu = library("quantizers.lib");
dorian_test = qu.quantize(220, qu.dorian, 260);
```

----

### `(qu.)phrygian`

List of the frequency ratios of the notes of the phrygian mode.

#### Usage
```
_ : quantize(rf,phrygian) : _
```

Where:

* `rf`: frequency of the root note of the scale

#### Test
```
qu = library("quantizers.lib");
phrygian_test = qu.quantize(220, qu.phrygian, 260);
```

----

### `(qu.)lydian`

List of the frequency ratios of the notes of the lydian mode.

#### Usage
```
_ : quantize(rf,lydian) : _
```

Where:

* `rf`: frequency of the root note of the scale

#### Test
```
qu = library("quantizers.lib");
lydian_test = qu.quantize(220, qu.lydian, 260);
```

----

### `(qu.)mixo`

List of the frequency ratios of the notes of the mixolydian mode.

#### Usage
```
_ : quantize(rf,mixo) : _
```

Where:

* `rf`: frequency of the root note of the scale

#### Test
```
qu = library("quantizers.lib");
mixo_test = qu.quantize(220, qu.mixo, 260);
```

----

### `(qu.)eolian`

List of the frequency ratios of the notes of the eolian mode.

#### Usage
```
_ : quantize(rf,eolian) : _
```

Where:

* `rf`: frequency of the root note of the scale

#### Test
```
qu = library("quantizers.lib");
eolian_test = qu.quantize(220, qu.eolian, 260);
```

----

### `(qu.)locrian`

List of the frequency ratios of the notes of the locrian mode.

#### Usage
```
_ : quantize(rf,locrian) : _
```

Where:

* `rf`: frequency of the root note of the scale

#### Test
```
qu = library("quantizers.lib");
locrian_test = qu.quantize(220, qu.locrian, 260);
```

----

### `(qu.)pentanat`

List of the frequency ratios of the notes of the pythagorean tuning for the minor pentatonic scale.

#### Usage
```
_ : quantize(rf,pentanat) : _
```

Where:

* `rf`: frequency of the root note of the scale

#### Test
```
qu = library("quantizers.lib");
pentanat_test = qu.quantize(220, qu.pentanat, 260);
```

----

### `(qu.)kumoi`

List of the frequency ratios of the notes of the kumoijoshi, the japanese pentatonic scale.

#### Usage
```
_ : quantize(rf,kumoi) : _
```

Where:

* `rf`: frequency of the root note of the scale

#### Test
```
qu = library("quantizers.lib");
kumoi_test = qu.quantize(220, qu.kumoi, 260);
```

----

### `(qu.)natural`

List of the frequency ratios of the notes of the natural major scale.

#### Usage
```
_ : quantize(rf,natural) : _
```

Where:

* `rf`: frequency of the root note of the scale

#### Test
```
qu = library("quantizers.lib");
natural_test = qu.quantize(220, qu.natural, 260);
```

----

### `(qu.)dodeca`

List of the frequency ratios of the notes of the dodecaphonic scale.

#### Usage
```
_ : quantize(rf,dodeca) : _
```

Where:

* `rf`: frequency of the root note of the scale

#### Test
```
qu = library("quantizers.lib");
dodeca_test = qu.quantize(220, qu.dodeca, 260);
```

----

### `(qu.)dimin`

List of the frequency ratios of the notes of the diminished scale.

#### Usage
```
_ : quantize(rf,dimin) : _
```

Where:

* `rf`: frequency of the root note of the scale

#### Test
```
qu = library("quantizers.lib");
dimin_test = qu.quantize(220, qu.dimin, 260);
```

----

### `(qu.)penta`

List of the frequency ratios of the notes of the minor pentatonic scale.

#### Usage
```
_ : quantize(rf,penta) : _
```

Where:

* `rf`: frequency of the root note of the scale

#### Test
```
qu = library("quantizers.lib");
penta_test = qu.quantize(220, qu.penta, 260);
```
