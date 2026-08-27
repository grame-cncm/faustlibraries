#  tubes.lib 

Vacuum tube amplifier stage emulations from the Guitarix project. The
transfer curve of each tube is stored as a precomputed table
(`tubetable_*`), interpolated at run time; `tubestage` wraps one table
into a complete gain stage with its cathode-capacitor highpass. The
`T1_*`/`T2_*`/`T3_*` functions below instantiate the first, second and
third preamp stage of each supported tube model.

The models are normally used through their own namespace:

```
tu = library("tubes.lib");
process = tu.T1_12AX7 : *(preamp) : tu.T2_12AX7;
```

#### References

* [https://github.com/grame-cncm/faustlibraries/blob/master/tubes.lib](https://github.com/grame-cncm/faustlibraries/blob/master/tubes.lib)
* [https://github.com/brummer10/guitarix](https://github.com/brummer10/guitarix)

----

### `rtable`

Read one entry of a `waveform` table (`rdtable` with the index
truncated to an int).

#### Usage

```
rtable(table, r) : _
```

Where:

* `table`: a `waveform` primitive
* `r`: the index to read (truncated to an int)

----

### `inverse`

Change the sign of the input signal x.

#### Usage

```
_ : inverse : _
```

----

### `ccopysign`

Compose the magnitude of `f` with the sign of `x`, following the
`sign` convention below.

#### Usage

```
ccopysign(f, x) : _
```

Where:

* `f`: the signal giving the magnitude
* `x`: the signal giving the sign

----

### `sign`, `invsign`

Sign (-1 for x<0, 1 otherwise) and reversed sign (1 for x<0, -1
otherwise) of a signal x.

#### Usage

```
_ : sign : _
_ : invsign : _
```

----

### `interpolation`

Interpolate linearly between the entries `i` and `i+1` of a table with
coefficient `f`.

#### Usage

```
interpolation(table, f, i) : _
```

Where:

* `table`: a `waveform` primitive
* `f`: interpolation coefficient between 0 and 1
* `i`: the lower table index

----

### `boundIndex`

Bound an index to the table boundaries [0, size-1].

#### Usage

```
boundIndex(size, index) : _
```

----

### `boundFactor`

Bound the interpolation factor at the table edges: returns 0 when the
unbounded index falls below the table, and keeps the last entry
reachable when it falls above.

#### Usage

```
boundFactor(size, factor, index) : _
```

Where:

* `size`: the table size
* `factor`: the unbounded fractional index
* `index`: the bounded integer index (from `boundIndex`)

----

### `tubeF`

Look up `x` in a transfer-curve table with linear interpolation: maps
the input range starting at `low` onto the table entries, `step`
entries per input unit, bounded to the table edges.

#### Usage

```
_ : tubeF(table, low, high, step, size) : _
```

Where:

* `table`: a `waveform` primitive holding the transfer curve
* `low`: input value mapped to the first entry
* `high`: input value mapped to the last entry (informative)
* `step`: number of table entries per input unit
* `size`: the table size used for bounding

----

### `getFactor`

The interpolation factor `tubeF` feeds to `interpolation`: the
fractional part of the table index of `x`, bounded at the table edges.

#### Usage

```
getFactor(low, step, size, x) : _
```

----

### `tubestage`, `tubestage130_20`, `tubestageF`

![tubestage — response plots](../img/tu_tubestage.svg)

One complete triode gain stage: table-driven waveshaping followed by the
highpass formed by the cathode capacitor and resistor.
`tubestageF(tb,vplus,divider,fck,Rk,Vk0)` is the fully parameterized form;
`tubestage(tb,fck,Rk,Vk0)` uses the standard 250V supply with divider 40,
and `tubestage130_20(tb,fck,Rk,Vk0)` a 130V supply with divider 20.

#### Usage

```
_ : tubestage(tb,fck,Rk,Vk0) : _
_ : tubestage130_20(tb,fck,Rk,Vk0) : _
_ : tubestageF(tb,vplus,divider,fck,Rk,Vk0) : _
```

Where:

* `tb`: a tube transfer-curve table (one of the `tubetable_*` waveforms)
* `vplus`: supply voltage in Volts (`tubestageF` only)
* `divider`: output voltage divider factor (`tubestageF` only)
* `fck`: cutoff frequency in Hz of the cathode highpass
* `Rk`: cathode resistor value in Ohms
* `Vk0`: quiescent cathode voltage in Volts

----

### `T1_12AX7`, `T2_12AX7`, `T3_12AX7`

![T1_12AX7 — response plots](../img/tu_T1_12AX7.svg)

First, second and third preamp stage of a 12AX7 (high-gain dual triode, the classic guitar preamp tube),
with the bias values used by the Guitarix amplifiers.

#### Usage

```
_ : T1_12AX7 : _
```

----

### `T1_12AT7`, `T2_12AT7`, `T3_12AT7`

![T1_12AT7 — response plots](../img/tu_T1_12AT7.svg)

First, second and third preamp stage of a 12AT7 (medium-gain dual triode),
with the bias values used by the Guitarix amplifiers.

#### Usage

```
_ : T1_12AT7 : _
```

----

### `T1_12AU7`, `T2_12AU7`, `T3_12AU7`

![T1_12AU7 — response plots](../img/tu_T1_12AU7.svg)

First, second and third preamp stage of a 12AU7 (low-gain dual triode),
with the bias values used by the Guitarix amplifiers.

#### Usage

```
_ : T1_12AU7 : _
```

----

### `T1_6V6`, `T2_6V6`, `T3_6V6`

![T1_6V6 — response plots](../img/tu_T1_6V6.svg)

First, second and third preamp stage of a 6V6 (beam power tetrode, wired as a triode),
with the bias values used by the Guitarix amplifiers.

#### Usage

```
_ : T1_6V6 : _
```

----

### `T1_6DJ8`, `T2_6DJ8`, `T3_6DJ8`

![T1_6DJ8 — response plots](../img/tu_T1_6DJ8.svg)

First, second and third preamp stage of a 6DJ8 / ECC88 (low-noise dual triode),
with the bias values used by the Guitarix amplifiers.

#### Usage

```
_ : T1_6DJ8 : _
```

----

### `T1_6C16`, `T2_6C16`, `T3_6C16`

![T1_6C16 — response plots](../img/tu_T1_6C16.svg)

First, second and third preamp stage of a 6C16 (single triode),
with the bias values used by the Guitarix amplifiers.

#### Usage

```
_ : T1_6C16 : _
```

----

### `tubetable_6C16_0`, `tubetable_6C16_1`, `tubetable_6C16_rtable_0`, `tubetable_6C16_rtable_1`

Precomputed transfer-curve tables of the 6C16 triode, sampled at the
two operating points used by the `T1_6C16`..`T3_6C16` stages (`_0` and
`_1`). The `_rtable_*` forms read one raw entry.

#### Usage

```
_ : tubestage(tubetable_6C16_0,fck,Rk,Vk0) : _
tubetable_6C16_rtable_0(r) : _
```

----

### `tubetable_6DJ8_0`, `tubetable_6DJ8_1`, `tubetable_6DJ8_rtable_0`, `tubetable_6DJ8_rtable_1`

Precomputed transfer-curve tables of the 6DJ8 triode, sampled at the
two operating points used by the `T1_6DJ8`..`T3_6DJ8` stages (`_0` and
`_1`). The `_rtable_*` forms read one raw entry.

#### Usage

```
_ : tubestage130_20(tubetable_6DJ8_0,fck,Rk,Vk0) : _
tubetable_6DJ8_rtable_0(r) : _
```

----

### `tubetable_6V6_0`, `tubetable_6V6_1`, `tubetable_6V6_rtable_0`, `tubetable_6V6_rtable_1`

Precomputed transfer-curve tables of the 6V6 tube, sampled at the two
operating points used by the `T1_6V6`..`T3_6V6` stages (`_0` and
`_1`). The `_rtable_*` forms read one raw entry.

#### Usage

```
_ : tubestage(tubetable_6V6_0,fck,Rk,Vk0) : _
tubetable_6V6_rtable_0(r) : _
```

----

### `tubetable_12AT7_0`, `tubetable_12AT7_1`, `tubetable_12AT7_rtable_0`, `tubetable_12AT7_rtable_1`

Precomputed transfer-curve tables of the 12AT7 triode, sampled at the
two operating points used by the `T1_12AT7`..`T3_12AT7` stages (`_0`
and `_1`). The `_rtable_*` forms read one raw entry.

#### Usage

```
_ : tubestage(tubetable_12AT7_0,fck,Rk,Vk0) : _
tubetable_12AT7_rtable_0(r) : _
```

----

### `tubetable_12AU7_0`, `tubetable_12AU7_1`, `tubetable_12AU7_rtable_0`, `tubetable_12AU7_rtable_1`

Precomputed transfer-curve tables of the 12AU7 tube, sampled at the
two operating points used by the `T1_12AU7`..`T3_12AU7` stages (`_0`
and `_1`). The `_rtable_*` forms read one raw entry.

#### Usage

```
_ : tubestage(tubetable_12AU7_0,fck,Rk,Vk0) : _
tubetable_12AU7_rtable_0(r) : _
```

----

### `tubetable_12AX7_0`, `tubetable_12AX7_1`, `tubetable_12AX7_rtable_0`, `tubetable_12AX7_rtable_1`

Precomputed transfer-curve tables of the 12AX7 triode, sampled at the
two operating points used by the `T1_12AX7`..`T3_12AX7` stages (`_0`
and `_1`). The `_rtable_*` forms read one raw entry.

#### Usage

```
_ : tubestage(tubetable_12AX7_0,fck,Rk,Vk0) : _
tubetable_12AX7_rtable_0(r) : _
```
