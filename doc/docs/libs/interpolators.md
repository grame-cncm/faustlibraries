#  interpolators.lib 

A library to handle interpolation. Its official prefix is `it`.

This library provides interpolation algorithms for signal and control
processing. It includes linear, polynomial, spline, and higher-order interpolation
methods used in delay lines, envelope shaping, resampling, and parameter smoothing.

The Interpolators library is organized into 7 sections:

* [Two points interpolation functions](#two-points-interpolation-functions)
* [Four points interpolation functions](#four-points-interpolation-functions)
* [Two points interpolators](#two-points-interpolators)
* [Four points interpolators](#four-points-interpolators)
* [Generic piecewise linear interpolation](#generic-piecewise-linear-interpolation)
* [Lagrange based interpolators](#lagrange-based-interpolators)
* [Misc functions](#misc-functions)

The first four sections provide several basic interpolation functions, as well as interpolators
taking a `gen` circuit of N outputs producing values to be interpolated, triggered
by a `idv` read index signal. Two points and four points interpolations are implemented.

The `idv` parameter is to be used as a read index. In `-single` (= singleprecision) mode, 
a technique based on 2 signals with the pure integer index and a fractional part in the [0,1] 
range is used to avoid accumulating errors. In `-double` (= doubleprecision) or `-quad` (= quadprecision) modes, 
a standard implementation with a single fractional index signal is used. Three functions `int_part`, `frac_part` and `mak_idv` are available to manipulate the read index signal.

Here is a use-case with `waveform`. Here the signal given to `interpolator_XXX` uses the `idv` model.

```
waveform_interpolator(wf, step, interp) = interp(gen, idv)
with {
   gen(idx) = wf, (idx:max(0):min(size-1)) : rdtable with { size = wf:(_,!); };   /* waveform size */
   index = (+(step)~_)-step;  /* starting from 0 */
   idv = it.make_idv(index);  /* build the signal for interpolation in a generic way */
};

waveform_linear(wf, step) = waveform_interpolator(wf, step, it.interpolator_linear);
waveform_cosine(wf, step) = waveform_interpolator(wf, step, it.interpolator_cosine);
waveform_cubic(wf, step) = waveform_interpolator(wf, step, it.interpolator_cubic);

waveform_interp(wf, step, selector) = waveform_interpolator(wf, step, interp_select(selector))
with {
   /* adapts the argument order */
   interp_select(sel, gen, idv) = it.interpolator_select(gen, idv, sel);
};

waveform and index 
waveform_interpolator1(wf, idv, interp) = interp(gen, idv)
with {
   gen(idx) = wf, (idx:max(0):min(size-1)) : rdtable with { size = wf:(_,!); };   /* waveform size */
};

waveform_linear1(wf, idv) = waveform_interpolator1(wf, idv, it.interpolator_linear);
waveform_cosine1(wf, idv) = waveform_interpolator1(wf, idv, it.interpolator_cosine);
waveform_cubic1(wf, idv) = waveform_interpolator1(wf, idv, it.interpolator_cubic);

waveform_interp1(wf, idv, selector) = waveform_interpolator1(wf, idv, interp_select(selector))
with {
   /* adapts the argument order */
   interp_select(sel, gen, idv) = it.interpolator_select(gen, idv, sel);
};
```

Some tests here:

```
wf = waveform {0.0, 10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 50.0, 40.0, 30.0, 20.0, 10.0, 0.0};

process = waveform_linear(wf, step), waveform_cosine(wf, step), waveform_cubic(wf, step) with { step = 0.25; };

process = waveform_interp(wf, 0.25, nentry("algo", 0, 0, 3, 1));

process = waveform_interp1(wf, idv, nentry("algo", 0, 0, 3, 1))
with {
   step = 0.1;
   idv_aux = (+(step)~_)-step;  /* starting from 0 */
   idv = it.make_idv(idv_aux);  /* build the signal for interpolation in a generic way */
};

/* Test linear interpolation between 2 samples with a `(idx,dv)` signal built using a waveform */
linear_test = (idx,dv), it.interpolator_linear(gen, (idx,dv))
with {
   /* signal to interpolate (only 2 points here) */
   gen(id) = waveform {3.0, -1.0}, (id:max(0)) : rdtable;
   dv = waveform {0.0, 0.25, 0.50, 0.75, 1.0}, index : rdtable;
   idx = 0; 
   /* test index signal */
   index = (+(1)~_)-1;   /* starting from 0 */
};

/* Test cosine interpolation between 2 samples with a `(idx,dv)` signal built using a waveform */
cosine_test = (idx,dv), it.interpolator_cosine(gen, (idx,dv))
with {
   /* signal to interpolate (only 2 points here) */
   gen(id) = waveform {3.0, -1.0}, (id:max(0)) : rdtable;
   dv = waveform {0.0, 0.25, 0.50, 0.75, 1.0}, index : rdtable;
   idx = 0;
   /* test index signal */
   index = (+(1)~_)-1;   /* starting from 0 */
};

/* Test cubic interpolation between 4 samples with a `(idx,dv)` signal built using a waveform */
cubic_test = (idx,dv), it.interpolator_cubic(gen, (idx,dv))
with {
   /* signal to interpolate (only 4 points here) */
   gen(id) = waveform {-1.0, 2.0, 1.0, 4.0}, (id:max(0)) : rdtable;
   dv = waveform {0.0, 0.25, 0.50, 0.75, 1.0}, index : rdtable;
   idx = 0;
   /* test index signal */
   index = (+(1)~_)-1;   /* starting from 0 */
};
```

#### References

* [https://github.com/grame-cncm/faustlibraries/blob/master/interpolators.lib](https://github.com/grame-cncm/faustlibraries/blob/master/interpolators.lib)

## Two points interpolation functions


----

### `(it.)interpolate_linear`

Linear interpolation between 2 values.

#### Usage

```
interpolate_linear(dv,v0,v1) : _
```

Where:

* `dv`: in the fractional value in [0..1] range
* `v0`: is the first value
* `v1`: is the second value

#### Test
```
it = library("interpolators.lib");
interpolate_linear_test = it.interpolate_linear(0.5, 0.0, 1.0);
```

#### References

* [https://github.com/jamoma/JamomaCore/blob/master/Foundation/library/includes/TTInterpolate.h](https://github.com/jamoma/JamomaCore/blob/master/Foundation/library/includes/TTInterpolate.h)

----

### `(it.)interpolate_cosine`

Cosine interpolation between 2 values.

#### Usage

```
interpolate_cosine(dv,v0,v1) : _
```

Where:

* `dv`: in the fractional value in [0..1] range
* `v0`: is the first value
* `v1`: is the second value

#### Test
```
it = library("interpolators.lib");
interpolate_cosine_test = it.interpolate_cosine(0.5, 0.0, 1.0);
```

#### References

* [https://github.com/jamoma/JamomaCore/blob/master/Foundation/library/includes/TTInterpolate.h](https://github.com/jamoma/JamomaCore/blob/master/Foundation/library/includes/TTInterpolate.h)

## Four points interpolation functions


----

### `(it.)interpolate_cubic`

Cubic interpolation between 4 values.

#### Usage

```
interpolate_cubic(dv,v0,v1,v2,v3) : _
```

Where:

* `dv`: in the fractional value in [0..1] range
* `v0`: is the first value
* `v1`: is the second value
* `v2`: is the third value
* `v3`: is the fourth value

#### Test
```
it = library("interpolators.lib");
interpolate_cubic_test = it.interpolate_cubic(0.5, -1.0, 2.0, 1.0, 4.0);
```

#### References

* [https://www.paulinternet.nl/?page=bicubic](https://www.paulinternet.nl/?page=bicubic)

## Two points interpolators


----

### `(it.)interpolator_two_points`

Generic interpolator on two points (current and next index), assuming an increasing index.

#### Usage

```
interpolator_two_points(gen, idv, interpolate_two_points) : si.bus(outputs(gen))
```

Where:

* `gen`: a circuit with an 'idv' reader input that produces N outputs
* `idv`: a fractional read index expressed as a float value, or a (int,frac) pair
* `interpolate_two_points`: a two points interpolation function

#### Test
```
it = library("interpolators.lib");
ma = library("maths.lib");
interpolator_two_points_test = it.interpolator_two_points(gen, idv, it.interpolate_linear)
with {
    gen(idx) = waveform {0.0, 1.0, 4.0, 9.0, 16.0}, int(ma.modulo(idx, 5)) : rdtable;
    step = 0.25;
    idxFloat = ma.modulo((+(step)~_) - step, 4.0);
    idv = it.make_idv(idxFloat);
};
```

----

### `(it.)interpolator_linear`

Linear interpolator for a 'gen' circuit triggered by an 'idv' input to generate values.

#### Usage

```
interpolator_linear(gen, idv) : si.bus(outputs(gen))
```

Where:

* `gen`: a circuit with an 'idv' reader input that produces N outputs
* `idv`: a fractional read index expressed as a float value, or a (int,frac) pair

#### Test
```
it = library("interpolators.lib");
ma = library("maths.lib");
interpolator_linear_test = it.interpolator_linear(gen, idv)
with {
    gen(idx) = waveform {0.0, 1.0, 4.0, 9.0, 16.0}, int(ma.modulo(idx, 5)) : rdtable;
    step = 0.25;
    idxFloat = ma.modulo((+(step)~_) - step, 4.0);
    idv = it.make_idv(idxFloat);
};
```

----

### `(it.)interpolator_cosine`

Cosine interpolator for a 'gen' circuit triggered by an 'idv' input to generate values.

#### Usage

```
interpolator_cosine(gen, idv) : si.bus(outputs(gen))
```

Where:

* `gen`: a circuit with an 'idv' reader input that produces N outputs
* `idv`: a fractional read index expressed as a float value, or a (int,frac) pair

#### Test
```
it = library("interpolators.lib");
ma = library("maths.lib");
interpolator_cosine_test = it.interpolator_cosine(gen, idv)
with {
    gen(idx) = waveform {0.0, 1.0, 4.0, 9.0, 16.0}, int(ma.modulo(idx, 5)) : rdtable;
    step = 0.25;
    idxFloat = ma.modulo((+(step)~_) - step, 4.0);
    idv = it.make_idv(idxFloat);
};
```

## Four points interpolators


----

### `(it.)interpolator_four_points`

Generic interpolator on interpolator_four_points points (previous, current and two next indexes), assuming an increasing index.

#### Usage

```
interpolator_four_points(gen, idv, interpolate_four_points) : si.bus(outputs(gen))
```

Where:

* `gen`: a circuit with an 'idv' reader input that produces N outputs
* `idv`: a fractional read index expressed as a float value, or a (int,frac) pair
* `interpolate_four_points`: a four points interpolation function

#### Test
```
it = library("interpolators.lib");
ma = library("maths.lib");
interpolator_four_points_test = it.interpolator_four_points(gen, idv, it.interpolate_cubic)
with {
    gen(idx) = waveform {-1.0, 2.0, 1.0, 4.0, 7.0, 3.0}, int(ma.modulo(idx, 6)) : rdtable;
    step = 0.25;
    idxFloat = ma.modulo((+(step)~_) - step, 5.0);
    idv = it.make_idv(idxFloat);
};
```

----

### `(it.)interpolator_cubic`

Cubic interpolator for a 'gen' circuit triggered by an 'idv' input to generate values.

#### Usage

```
interpolator_cubic(gen, idv) : si.bus(outputs(gen))
```

Where:

* `gen`: a circuit with an 'idv' reader input that produces N outputs
* `idv`: a fractional read index expressed as a float value, or a (int,frac) pair

#### Test
```
it = library("interpolators.lib");
ma = library("maths.lib");
interpolator_cubic_test = it.interpolator_cubic(gen, idv)
with {
    gen(idx) = waveform {-1.0, 2.0, 1.0, 4.0, 7.0, 3.0}, int(ma.modulo(idx, 6)) : rdtable;
    step = 0.25;
    idxFloat = ma.modulo((+(step)~_) - step, 5.0);
    idv = it.make_idv(idxFloat);
};
```

----

### `(it.)interpolator_select`

Generic configurable interpolator (with selector between in [0..3]). The value 3 is used for no interpolation.

#### Usage

```
interpolator_select(gen, idv, sel) : _,_... (equal to N = outputs(gen))
```

Where:

* `gen`: a circuit with an 'idv' reader input that produces N outputs
* `idv`: a fractional read index expressed as a float value, or a (int,frac) pair
* `sel`: an interpolation algorithm selector in [0..3] (0 = linear, 1 = cosine, 2 = cubic, 3 = nointerp)

#### Test
```
it = library("interpolators.lib");
ma = library("maths.lib");
interpolator_select_test = it.interpolator_select(gen, idv, 2)
with {
    gen(idx) = waveform {-1.0, 2.0, 1.0, 4.0, 7.0, 3.0}, int(ma.modulo(idx, 6)) : rdtable;
    step = 0.25;
    idxFloat = ma.modulo((+(step)~_) - step, 5.0);
    idv = it.make_idv(idxFloat);
};
```

##  Generic piecewise linear interpolation 


----

### `(it.)lerp`

Linear interpolation between two points.

#### Usage

```
lerp(x0, x1, y0, y1, x) : si.bus(1);
```

Where:

* `x0`: x-coordinate origin
* `x1`: x-coordinate destination
* `y0`: y-coordinate origin
* `y1`: y-coordinate destination
* `x`: x-coordinate input

#### Test
```
it = library("interpolators.lib");
lerp_test = it.lerp(0.0, 10.0, -5.0, 5.0, 2.5);
```

----

### `(it.)piecewise`

Linear piecewise interpolation between N points.

#### Usage

```
piecewise(xList, yList, x) : si.bus(1);
```

Where:

* `xList`: x-coordinates list
* `yList`: y-coordinates list
* `x`: x-coordinate input

#### Example test program
The code below will output the values of linear segments going through the
y coordinates as the input goes from -5 to 5:

```
x = hslider("x", -5, -5.0, 5.0, .001);
process = it.piecewise((-5, -3, 0, 3, 5), (2, 0, 3, -3, -2), x);
```

#### Test
```
it = library("interpolators.lib");
piecewise_test = it.piecewise((-5, -2, 0, 3), (1, 0, 4, -1), os.osc(0.1));
```

## Lagrange based interpolators


----

### `(it.)lagrangeCoeffs`


This is a function to generate N + 1 coefficients for an Nth-order Lagrange
basis polynomial with arbitrary spacing of the points.

#### Usage

```
lagrangeCoeffs(N, xCoordsList, x) : si.bus(N + 1)
```

Where:

* `N`: order of the interpolation filter, known at compile-time
* `xCoordsList`: a list of N + 1 elements determining the x-axis coordinates of N + 1 values, known at compile-time
* `x`: a fractional position on the x-axis to obtain the interpolated y-value

#### Test
```
it = library("interpolators.lib");
lagrangeCoeffs_test = it.lagrangeCoeffs(2, (0.0, 0.5, 1.0), 0.25);
```

#### References

* [https://ccrma.stanford.edu/~jos/pasp/Lagrange_Interpolation.html](https://ccrma.stanford.edu/~jos/pasp/Lagrange_Interpolation.html)
* [https://en.wikipedia.org/wiki/Lagrange_polynomial](https://en.wikipedia.org/wiki/Lagrange_polynomial)

----

### `(it.)lagrangeInterpolation`


Nth-order Lagrange interpolator to interpolate between a set of arbitrarily spaced N + 1 points.

#### Usage

```
x , yCoords : lagrangeInterpolation(N, xCoordsList) : _
```

Where:

* `N`: order of the interpolator, known at compile-time
* `xCoordsList`: a list of N + 1 elements determining the x-axis spacing of the points, known at compile-time
* `x`: an x-axis position to interpolate between the y-values
* `yCoords`: N + 1 elements determining the values of the interpolation points

Example: find the centre position of a four-point set using an order-3
Lagrange function fitting the equally-spaced points [2, 5, -1, 3]:

```
N = 3;
xCoordsList = (0, 1, 2, 3);
x = N / 2.0;
yCoords = 2, 5, -1, 3;
process = x, yCoords : it.lagrangeInterpolation(N, xCoordsList);
```

which outputs ~1.938.

* Example: output the dashed curve showed on the Wikipedia page (top figure in [https://en.wikipedia.org/wiki/Lagrange_polynomial](https://en.wikipedia.org/wiki/Lagrange_polynomial)):

```
N = 3;
xCoordsList = (-9, -4, -1, 7);
x = os.phasor(16, 1) - 9;
yCoords = 5, 2, -2, 9;
process = x, yCoords : it.lagrangeInterpolation(N, xCoordsList);
```

#### Test
```
it = library("interpolators.lib");
lagrangeInterpolation_test = (lagrange_x, lagrange_y0, lagrange_y1, lagrange_y2, lagrange_y3) : it.lagrangeInterpolation(3, (0, 1, 2, 3))
with {
    lagrange_x = 1.5;
    lagrange_y0 = 2.0;
    lagrange_y1 = 5.0;
    lagrange_y2 = -1.0;
    lagrange_y3 = 3.0;
};
```

#### References

* [https://ccrma.stanford.edu/~jos/pasp/Lagrange_Interpolation.html](https://ccrma.stanford.edu/~jos/pasp/Lagrange_Interpolation.html)
* Sanfilippo and Parker 2021, "Combining zeroth and first‐order analysis with Lagrange polynomials to reduce artefacts in live concatenative granular processing." Proceedings of the DAFx conference 2021, Vienna, Austria.
* [https://dafx2020.mdw.ac.at/proceedings/papers/DAFx20in21_paper_38.pdf](https://dafx2020.mdw.ac.at/proceedings/papers/DAFx20in21_paper_38.pdf)

----

### `(it.)frdtable`


Look-up circular table with Nth-order Lagrange interpolation for fractional
indexes. The index is wrapped-around and the table is cycles for an index
span of size S, which is the table size in samples.

#### Usage

```
frdtable(N, S, init, idx) : _
```

Where:

* `N`: Lagrange interpolation order, known at compile-time
* `S`: table size in samples, known at compile-time
* `init`: the initial table content, known at compile-time
* `idx`: fractional index wrapped-around 0 and S

#### Example test program
Test the effectiveness of the 5th-order interpolation scheme by 
creating a table look-up oscillator using only 16 points of a sinewave; 
compare the result with a non-interpolated version:

```
N = 5;
S = 16;
index = os.phasor(S, 1000);
process = rdtable(S, os.sinwaveform(S), int(index)) ,
          it.frdtable(N, S, os.sinwaveform(S), index);
```

#### Test
```
it = library("interpolators.lib");
os = library("oscillators.lib");
frdtable_test = it.frdtable(3, 16, os.sinwaveform(16), os.phasor(16, 200));
```

----

### `(it.)frwtable`


Look-up updatable circular table with Nth-order Lagrange interpolation for
fractional indexes. The index is wrapped-around and the table is circular
indexes ranging from 0 to S, which is the table size in samples.

#### Usage

```
frwtable(N, S, init, w_idx, x, r_idx) : _
```

Where:

* `N`: Lagrange interpolation order, known at compile-time
* `S`: table size in samples, known at compile-time
* `init`: the initial table content, known at compile-time
* `w_idx`: it should be an INT between 0 and S - 1
* `x`: input signal written on the w_idx positions
* `r_idx`: fractional index wrapped-around 0 and S

#### Example test program
Test the effectiveness of the 5th-order interpolation scheme by
creating a table look-up oscillator using only 16 points of a sinewave;
compare the result with a non-interpolated version:

```
N = 5;
S = 16;
rIdx = os.phasor(S, 300);
wIdx = ba.period(S);
process = rwtable(S, os.sinwaveform(S), wIdx, os.sinwaveform(S), int(rIdx)) ,
          it.frwtable(N, S, os.sinwaveform(S), wIdx, os.sinwaveform(S), rIdx);
```

#### Test
```
it = library("interpolators.lib");
os = library("oscillators.lib");
ba = library("basics.lib");
frwtable_test = it.frwtable(3, 16, os.sinwaveform(16), ba.period(16), os.osc(220), os.phasor(16, 150));
```

## Misc functions


----

### `(it.)remap`

Linearly map from an input domain to an output range.

#### Usage

```
_ : remap(from1, from2, to1, to2) : _
```

Where:

* `from1`: the domain's lower bound.
* `from2`: the domain's upper bound.
* `to1`: the range's lower bound.
* `to2`: the range's upper bound.

Note that having `from1` == `from2` in the mapping will cause a division by zero that has to be taken in account.

#### Example test program
An oscillator remapped from [-1., 1.] to [100., 1000.]:
```
os.osc(440) : it.remap(-1., 1., 100., 1000.)
```

#### Test
```
it = library("interpolators.lib");
os = library("oscillators.lib");
remap_test = it.remap(-1.0, 1.0, 100.0, 1000.0, os.osc(0.5));
```
