#  basics.lib 

Basics library. Its official prefix is `ba`.

This library provides reusable building blocks for core DSP and Faust
programming. It typically includes low-level utilities for math, routing,
signal conditioning, timing, control, and helper components used across
higher-level libraries.

The Basics library is organized into 8 sections:

* [Conversion Tools](#conversion-tools)
* [Counters and Time/Tempo Tools](#counters-and-timetempo-tools)
* [Array Processing/Pattern Matching](#array-processingpattern-matching)
* [Function tabulation](#function-tabulation)
* [Selectors (Conditions)](#selectors-conditions)
* [Other](#other)
* [Sliding Reduce](#sliding-reduce)
* [Parallel Operators](#parallel-operators)

#### References

* [https://github.com/grame-cncm/faustlibraries/blob/master/basics.lib](https://github.com/grame-cncm/faustlibraries/blob/master/basics.lib)

## Conversion Tools


----

### `(ba.)samp2sec`

Converts a number of samples to a duration in seconds at the current sampling rate (see `ma.SR`).
`samp2sec` is a standard Faust function.

#### Usage

```
samp2sec(n) : _
```

Where:

* `n`: number of samples

#### Test
```
ba = library("basics.lib");
samp2sec_test = ba.samp2sec(512);
```

----

### `(ba.)sec2samp`

Converts a duration in seconds to a number of samples at the current sampling rate (see `ma.SR`).
`samp2sec` is a standard Faust function.

#### Usage

```
sec2samp(d) : _
```

Where:

* `d`: duration in seconds

#### Test
```
ba = library("basics.lib");
sec2samp_test = ba.sec2samp(0.01);
```

----

### `(ba.)db2linear`

dB-to-linear value converter. It can be used to convert an amplitude in dB to a linear gain ]0-N].
`db2linear` is a standard Faust function.

#### Usage

```
db2linear(l) : _
```

Where:

* `l`: amplitude in dB

#### Test
```
ba = library("basics.lib");
db2linear_test = ba.db2linear(-6);
```

----

### `(ba.)linear2db`

linea-to-dB value converter. It can be used to convert a linear gain ]0-N] to an amplitude in dB.
`linear2db` is a standard Faust function.

#### Usage

```
linear2db(g) : _
```

Where:

* `g`: a linear gain

#### Test
```
ba = library("basics.lib");
linear2db_test = ba.linear2db(0.5);
```

----

### `(ba.)lin2LogGain`

Converts a linear gain (0-1) to a log gain (0-1).

#### Usage

```
lin2LogGain(n) : _
```

Where:

* `n`: the linear gain

#### Test
```
ba = library("basics.lib");
lin2LogGain_test = ba.lin2LogGain(0.5);
```

----

### `(ba.)log2LinGain`

Converts a log gain (0-1) to a linear gain (0-1).

#### Usage

```
log2LinGain(n) : _
```

Where:

* `n`: the log gain

#### Test
```
ba = library("basics.lib");
log2LinGain_test = ba.log2LinGain(0.25);
```

----

### `(ba.)tau2pole`

Returns a real pole giving exponential decay.
Note that t60 (time to decay 60 dB) is ~6.91 time constants.
`tau2pole` is a standard Faust function.

#### Usage

```
_ : smooth(tau2pole(tau)) : _
```

Where:

* `tau`: time-constant in seconds

tau2pole(tau) = exp(-1.0/(tau*ma.SR));

#### Test
```
ba = library("basics.lib");
tau2pole_test = ba.tau2pole(0.01);
```

----

### `(ba.)pole2tau`

Returns the time-constant, in seconds, corresponding to the given real,
positive pole in (0-1).
`pole2tau` is a standard Faust function.

#### Usage

```
pole2tau(pole) : _
```

Where:

* `pole`: the pole

#### Test
```
ba = library("basics.lib");
pole2tau_test = ba.pole2tau(0.9);
```

----

### `(ba.)midikey2hz`

Converts a MIDI key number to a frequency in Hz (MIDI key 69 = A440).
`midikey2hz` is a standard Faust function.

#### Usage

```
midikey2hz(mk) : _
```

Where:

* `mk`: the MIDI key number

#### Test
```
ba = library("basics.lib");
midikey2hz_test = ba.midikey2hz(60);
```

----

### `(ba.)hz2midikey`

Converts a frequency in Hz to a MIDI key number (MIDI key 69 = A440).
`hz2midikey` is a standard Faust function.

#### Usage

```
hz2midikey(freq) : _
```

Where:

* `freq`: frequency in Hz

#### Test
```
ba = library("basics.lib");
hz2midikey_test = ba.hz2midikey(440);
```

----

### `(ba.)semi2ratio`

Converts semitones in a frequency multiplicative ratio.
`semi2ratio` is a standard Faust function.

#### Usage

```
semi2ratio(semi) : _
```

Where:

* `semi`: number of semitone

#### Test
```
ba = library("basics.lib");
semi2ratio_test = ba.semi2ratio(7);
```

----

### `(ba.)ratio2semi`

Converts a frequency multiplicative ratio in semitones.
`ratio2semi` is a standard Faust function.

#### Usage

```
ratio2semi(ratio) : _
```

Where:

* `ratio`: frequency multiplicative ratio

#### Test
```
ba = library("basics.lib");
ratio2semi_test = ba.ratio2semi(2.0);
```

----

### `(ba.)cent2ratio`

Converts cents in a frequency multiplicative ratio.

#### Usage

```
cent2ratio(cent) : _
```

Where:

* `cent`: number of cents

#### Test
```
ba = library("basics.lib");
cent2ratio_test = ba.cent2ratio(100);
```

----

### `(ba.)ratio2cent`

Converts a frequency multiplicative ratio in cents.

#### Usage

```
ratio2cent(ratio) : _
```

Where:

* `ratio`: frequency multiplicative ratio

#### Test
```
ba = library("basics.lib");
ratio2cent_test = ba.ratio2cent(1.5);
```

----

### `(ba.)pianokey2hz`

Converts a piano key number to a frequency in Hz (piano key 49 = A440).

#### Usage

```
pianokey2hz(pk) : _
```

Where:

* `pk`: the piano key number

#### Test
```
ba = library("basics.lib");
pianokey2hz_test = ba.pianokey2hz(49);
```

----

### `(ba.)hz2pianokey`

Converts a frequency in Hz to a piano key number (piano key 49 = A440).

#### Usage

```
hz2pianokey(freq) : _
```

Where:

* `freq`: frequency in Hz

#### Test
```
ba = library("basics.lib");
hz2pianokey_test = ba.hz2pianokey(440);
```

## Counters and Time/Tempo Tools


----

### `(ba.)counter`

Starts counting 0, 1, 2, 3..., and raise the current integer value
at each upfront of the trigger.

#### Usage

```
counter(trig) : _
```

Where:

* `trig`: the trigger signal, each upfront will move the counter to the next integer

#### Test
```
ba = library("basics.lib");
counter_test = ba.counter(button("trig"));
```

----

### `(ba.)countdown`

Starts counting down from n included to 0. While trig is 1 the output is n.
The countdown starts with the transition of trig from 1 to 0. At the end
of the countdown the output value will remain at 0 until the next trig.
`countdown` is a standard Faust function.

#### Usage

```
countdown(n,trig) : _
```

Where:

* `n`: the starting point of the countdown
* `trig`: the trigger signal (1: start at `n`; 0: decrease until 0)

#### Test
```
ba = library("basics.lib");
countdown_test = ba.countdown(8, button("trig"));
```

----

### `(ba.)countup`

Starts counting up from 0 to n included. While trig is 1 the output is 0.
The countup starts with the transition of trig from 1 to 0. At the end
of the countup the output value will remain at n until the next trig.
`countup` is a standard Faust function.

#### Usage

```
countup(n,trig) : _
```

Where:

* `n`: the maximum count value
* `trig`: the trigger signal (1: start at 0; 0: increase until `n`)

#### Test
```
ba = library("basics.lib");
countup_test = ba.countup(8, button("trig"));
```

----

### `(ba.)sweep`

Counts from 0 to `period-1` repeatedly, generating a
sawtooth waveform, like `os.lf_rawsaw`,
starting at 1 when `run` transitions from 0 to 1.
Outputs zero while `run` is 0.

#### Usage

```
sweep(period,run) : _
```

#### Test
```
ba = library("basics.lib");
sweep_test = ba.sweep(64, checkbox("run"));
```

----

### `(ba.)time`

A simple counter that produces the sequence of 0,1,2...N integer values.
`time` is a standard Faust function.

#### Usage

```
time : _
```

#### Test
```
ba = library("basics.lib");
time_test = ba.time;
```

----

### `(ba.)ramp`

A linear ramp with a slope of '(+/-)1/n' samples to reach the next target value.

#### Usage

```
_ : ramp(n) : _
```
Where:

* `n`: number of samples to increment/decrement the value by one

#### Test
```
ba = library("basics.lib");
os = library("oscillators.lib");
ramp_test = os.osc(1) : ba.ramp(256);
```

----

### `(ba.)line`

A ramp interpolator that generates a linear transition to reach a target value:

 - the interpolation process restarts each time a new and distinct input value is received
 - it utilizes 'n' samples to achieve the transition to the target value
 - after reaching the target value, the output value is maintained.

#### Usage

```
_ : line(n) : _
```
Where:

* `n`: number of samples to reach the new target received at its input

#### Test
```
ba = library("basics.lib");
os = library("oscillators.lib");
line_test = os.osc(1) : ba.line(256);
```

----

### `(ba.)tempo`

Converts a tempo in BPM into a number of samples.

#### Usage

```
tempo(t) : _
```

Where:

* `t`: tempo in BPM

#### Test
```
ba = library("basics.lib");
tempo_test = ba.tempo(120);
```

----

### `(ba.)period`

Basic sawtooth wave of period `p`.

#### Usage

```
period(p) : _
```

Where:

* `p`: period as a number of samples

NOTE: may be this should go in oscillators.lib
#### Test
```
ba = library("basics.lib");
period_test = ba.period(64);
```

----

### `(ba.)spulse`

Produces a single pulse of n samples when trig goes from 0 to 1.

#### Usage

```
spulse(n,trig) : _
```

Where:

* `n`: pulse length as a number of samples
* `trig`: the trigger signal (1: start the pulse)

#### Test
```
ba = library("basics.lib");
spulse_test = ba.spulse(32, button("trig"));
```

----

### `(ba.)pulse`

Pulses (like 10000) generated at period `p`.

#### Usage

```
pulse(p) : _
```

Where:

* `p`: period as a number of samples

NOTE: may be this should go in oscillators.lib
#### Test
```
ba = library("basics.lib");
pulse_test = ba.pulse(64);
```

----

### `(ba.)pulsen`

Pulses (like 11110000) of length `n` generated at period `p`.

#### Usage

```
pulsen(n,p) : _
```

Where:

* `n`: pulse length as a number of samples
* `p`: period as a number of samples

NOTE: may be this should go in oscillators.lib
#### Test
```
ba = library("basics.lib");
pulsen_test = ba.pulsen(8, 64);
```

----

### `(ba.)cycle`

Split nonzero input values into `n` cycles.

#### Usage

```
_ : cycle(n) : si.bus(n)
```

Where:

* `n`: the number of cycles/output signals

#### Test
```
ba = library("basics.lib");
cycle_test = button("gate") : ba.cycle(3);
```

----

### `(ba.)beat`

Pulses at tempo `t` in BPM.
`beat` is a standard Faust function.

#### Usage

```
beat(t) : _
```

Where:

* `t`: tempo in BPM

#### Test
```
ba = library("basics.lib");
beat_test = ba.beat(120);
```

----

### `(ba.)pulse_countup`

Starts counting up pulses. While trig is 1 the output is
counting up, while trig is 0 the counter is reset to 0.

#### Usage

```
_ : pulse_countup(trig) : _
```

Where:

* `trig`: the trigger signal (1: start at next pulse; 0: reset to 0)

#### Test
```
ba = library("basics.lib");
pulse_countup_test = ba.pulse_countup(button("run"));
```

----

### `(ba.)pulse_countdown`

Starts counting down pulses. While trig is 1 the output is
counting down, while trig is 0 the counter is reset to 0.

#### Usage

```
_ : pulse_countdown(trig) : _
```

Where:

* `trig`: the trigger signal (1: start at next pulse; 0: reset to 0)

#### Test
```
ba = library("basics.lib");
pulse_countdown_test = ba.pulse_countdown(button("run"));
```

----

### `(ba.)pulse_countup_loop`

Starts counting up pulses from 0 to n included. While trig is 1 the output is
counting up, while trig is 0 the counter is reset to 0. At the end
of the countup (n) the output value will be reset to 0.

#### Usage

```
_ : pulse_countup_loop(n,trig) : _
```

Where:

* `n`: the highest number of the countup (included) before reset to 0
* `trig`: the trigger signal (1: start at next pulse; 0: reset to 0)

#### Test
```
ba = library("basics.lib");
pulse_countup_loop_test = ba.pulse_countup_loop(4, button("run"));
```

----

### `(ba.)pulse_countdown_loop`

Starts counting down pulses from 0 to n included. While trig is 1 the output
is counting down, while trig is 0 the counter is reset to 0. At the end
of the countdown (n) the output value will be reset to 0.

#### Usage

```
_ : pulse_countdown_loop(n,trig) : _
```

Where:

* `n`: the highest number of the countup (included) before reset to 0
* `trig`: the trigger signal (1: start at next pulse; 0: reset to 0)

#### Test
```
ba = library("basics.lib");
pulse_countdown_loop_test = ba.pulse_countdown_loop(4, button("run"));
```

----

### `(ba.)resetCtr`

Function that lets through the mth impulse out of
each consecutive group of `n` impulses.

#### Usage

```
_ : resetCtr(n,m) : _
```

Where:

* `n`: the total number of impulses being split
* `m`: index of impulse to allow to be output

#### Test
```
ba = library("basics.lib");
resetCtr_test = ba.pulse(16) : ba.resetCtr(4, 2);
```

## Array Processing/Pattern Matching


----

### `(ba.)count`

Count the number of elements of list l.
`count` is a standard Faust function.

#### Usage

```
count(l)
count((10,20,30,40)) -> 4
```

Where:

* `l`: list of elements

#### Test
```
ba = library("basics.lib");
count_test = ba.count((10,20,30,40));
```

----

### `(ba.)take`

Take an element from a list.
`take` is a standard Faust function.

#### Usage

```
take(P,l)
take(3,(10,20,30,40)) -> 30
```

Where:

* `P`: position (int, known at compile time, P > 0)
* `l`: list of elements

#### Test
```
ba = library("basics.lib");
take_test = ba.take(3, (10,20,30,40));
```

----

### `(ba.)pick`

Pick the nth element from a list.
Similar to `ba.take(n+1,l)` but faster and more powerful.

#### Usage

```
pick(l,n) : _
```

Where:

* `l`: list of elements
* `n`: index of element to pick, compile time constant.
       if n < 0 or n >= length of `l`, `pick()` outputs 0.

#### Example test program

```
pick((10,20,30,40), 2) -> 30
```

```
pick(si.bus(3), 1) // same as !,_,!
```

while `ba.take(2, si.bus(3))` acts as `_`.

Unlike `take()`, `pick()` always flattens the list, so
`pick((10,(20,30),40), 1)` outputs `20`, not `20,30`.

#### Test
```
ba = library("basics.lib");
pick_test = ba.pick((10,20,30,40), 2);
```

----

### `(ba.)pickN`

Select the inputs listed in `O` among `N` at compile time.

#### Usage

```
si.bus(N) : pickN(N,O) : si.bus(outputs(O))
```

Where:

* `N`: number of inputs, compile time constant
* `O`: list of the inputs to select, compile time constants

#### Example test program

```
pickN(4,2) : _  // same as selector(2,4) but faster
```

```
pick(4,(1,3)) : _,_ // same as !,_,!,_
```

```
pickN(4,(1,3), (10,20,30,40)) -> (20,40)
```

```
process = pickN(2, (1,0,0,1)) // same as `process(x,y) = y,x,x,y`
```

#### Test
```
ba = library("basics.lib");
pickN_test = (1,2,3,4) : ba.pickN(4, (0,2));
```

----

### `(ba.)subseq`

Extract a part of a list.

#### Usage

```
subseq(l, P, N)
subseq((10,20,30,40,50,60), 1, 3) -> (20,30,40)
subseq((10,20,30,40,50,60), 4, 1) -> 50
```

Where:

* `l`: list
* `P`: start point (int, known at compile time, 0: begin of list)
* `N`: number of elements (int, known at compile time)

#### Note:

Faust doesn't have proper lists. Lists are simulated with parallel
compositions and there is no empty list.

#### Test
```
ba = library("basics.lib");
subseq_test = ba.subseq((10,20,30,40,50), 1, 3);
```

## Function tabulation

The purpose of function tabulation is to speed up the computation of heavy functions over an interval, 
so that the computation at runtime can be faster than directly using the function. 
Two techniques are implemented: 

* `tabulate` computes the function in a table and read the points using interpolation. `tabulateNd` is the N dimensions version of `tabulate`

* `tabulate_chebychev` uses Chebyshev polynomial approximation

#### Comparison program example 
```
process = line(50000, r0, r1) <: FX-tb,FX-ch : par(i, 2, maxerr)
with {
   C = 0;
   FX = sin; 
   NX = 50; 
   CD = 3;
   r0 = 0;
   r1 = ma.PI;
   tb(x) = ba.tabulate(C, FX, NX*(CD+1), r0, r1, x).cub;
   ch(x) = ba.tabulate_chebychev(C, FX, NX, CD, r0, r1, x);
   maxerr = abs : max ~ _;
   line(n, x0, x1) = x0 + (ba.time%n)/n * (x1-x0);
};
```

----

### `(ba.)tabulate`

Tabulate a 1D function over the range [r0, r1] for access via nearest-value, linear, cubic interpolation.
In other words, the uniformly tabulated function can be evaluated using interpolation of order 0 (none), 1 (linear), or 3 (cubic).

#### Usage

```
tabulate(C, FX, S, r0, r1, x).(val|lin|cub) : _
```

* `C`: whether to dynamically force the `x` value to the range [r0, r1]: 1 forces the check, 0 deactivates it (constant numerical expression)
* `FX`: unary function Y=F(X) with one output (scalar function of one variable) 
* `S`: size of the table in samples (constant numerical expression)
* `r0`: minimum value of argument x
* `r1`: maximum value of argument x

```
tabulate(C, FX, S, r0, r1, x).val uses the value in the table closest to x
```

```
tabulate(C, FX, S, r0, r1, x).lin evaluates at x using linear interpolation between the closest stored values
```

```
tabulate(C, FX, S, r0, r1, x).cub evaluates at x using cubic interpolation between the closest stored values
```

#### Example test program

```
midikey2hz(mk) = ba.tabulate(1, ba.midikey2hz, 512, 0, 127, mk).lin;
process = midikey2hz(ba.time), ba.midikey2hz(ba.time);
```

#### Test
```
ba = library("basics.lib");
tabulate_test = ba.tabulate(1, ba.midikey2hz, 128, 0, 127, 60).lin;
```

----

### `(ba.)tabulate_chebychev`

Tabulate a 1D function over the range [r0, r1] for access via Chebyshev polynomial approximation.
In contrast to `(ba.)tabulate`, which interpolates only between tabulated samples, `(ba.)tabulate_chebychev`
stores coefficients of Chebyshev polynomials that are evaluated to provide better approximations in many cases.
Two new arguments controlling this are NX, the number of segments into which [r0, r1] is divided, and CD,
the maximum Chebyshev polynomial degree to use for each segment. A `rdtable` of size NX*(CD+1) is internally used.

Note that processing `r1` the last point in the interval is not safe. So either be sure the input stays in [r0, r1[ 
or use `C = 1`.

#### Usage

```
_ : tabulate_chebychev(C, FX, NX, CD, r0, r1) : _
```

* `C`: whether to dynamically force the value to the range [r0, r1]: 1 forces the check, 0 deactivates it (constant numerical expression)
* `FX`: unary function Y=F(X) with one output (scalar function of one variable)
* `NX`: number of segments for uniformly partitioning [r0, r1] (constant numerical expression)
* `CD`: maximum polynomial degree for each Chebyshev polynomial (constant numerical expression)
* `r0`: minimum value of argument x
* `r1`: maximum value of argument x

#### Example test program

```
midikey2hz_chebychev(mk) = ba.tabulate_chebychev(1, ba.midikey2hz, 100, 4, 0, 127, mk);
process = midikey2hz_chebychev(ba.time), ba.midikey2hz(ba.time);
```

#### Test
```
ba = library("basics.lib");
tabulate_chebychev_test = ba.tabulate_chebychev(1, ba.midikey2hz, 32, 4, 0, 127, 60);
```

----

### `(ba.)tabulateNd`

Tabulate an nD function for access via nearest-value or linear or cubic interpolation. In other words, the tabulated function can be evaluated using interpolation of order 0 (none), 1 (linear), or 3 (cubic).  

The table size and parameter range of each dimension can and must be separately specified. You can use it anywhere you have an expensive function with multiple parameters with known ranges. You could use it to build a wavetable synth, for example.

The number of dimensions is deduced from the number of parameters you give, see below.

Note that processing the last point in each interval is not safe. So either be sure the inputs stay in their respective ranges, or use `C = 1`. Similarly for the first point when doing cubic interpolation.

#### Usage

```
tabulateNd(C, function, (parameters) ).(val|lin|cub) : _
```

* `C`: whether to dynamically force the parameter values for each dimension to the ranges specified in parameters: 1 forces the check, 0 deactivates it (constant numerical expression)
* `function`: the function we want to tabulate. Can have any number of inputs, but needs to have just one output.
* `(parameters)`: sizes, ranges and read values. Note: these need to be in brackets, to make them one entity.  

  If N is the number of dimensions, we need:

  * N times `S`: number of values to store for this dimension (constant numerical expression)
  * N times `r0`: minimum value of this dimension
  * N times `r1`: maximum value of this dimension
  * N times `x`: read value of this dimension

By providing these parameters, you indirectly specify the number of dimensions; it's the number of parameters divided by 4.

The user facing functions are:
```
tabulateNd(C, function, S, parameters).val
```
 - Uses the value in the table closest to x.
```
tabulateNd(C, function, S, parameters).lin
```
 - Evaluates at x using linear interpolation between the closest stored values.
```
tabulateNd(C, function, S, parameters).cub
```
 - Evaluates at x using cubic interpolation between the closest stored values.


#### Example test program

```
powSin(x,y) = sin(pow(x,y)); // The function we want to tabulate
powSinTable(x,y) = ba.tabulateNd(1, powSin, (sizeX,sizeY, rx0,ry0, rx1,ry1, x,y) ).lin;
sizeX = 512; // table size of the first parameter
sizeY = 512; // table size of the second parameter
rx0 = 2; // start of the range of the first parameter
ry0 = 2; // start of the range of the second parameter
rx1 = 10; // end of the range of the first parameter
ry1 = 10; // end of the range of the second parameter
x = hslider("x", rx0, rx0, rx1, 0.001):si.smoo;
y = hslider("y", ry0, ry0, ry1, 0.001):si.smoo;
process = powSinTable(x,y), powSin(x,y);
```

#### Working principle

The ``.val`` function just outputs the closest stored value.
The ``.lin`` and ``.cub`` functions interpolate in N dimensions.

##### Multi dimensional interpolation

To understand what it means to interpolate in N dimensions, here's a quick reminder on the general principle of 2D linear interpolation:

* We have a grid of values, and we want to find the value at a point (x, y) within this grid.  
* We first find the four closest points (A, B, C, D) in the grid surrounding the point (x, y).  

Then, we perform linear interpolation in the x-direction between points A and B, and between points C and D. This gives us two new points E and F. Finally, we perform linear interpolation in the y-direction between points E and F to get our value.

To implement this in Faust, we need N sequential groups of interpolators, where N is the number of dimensions.  
Each group feeds into the next, with the last "group" being a single interpolator, and the group before it containing one interpolator for each input of the group it's feeding.

Some examples:

* Our 2D linear example has two interpolators feeding into one.
* A 3D linear interpolator has four interpolators feeding into two, feeding into one.
* A 2D cubic interpolater has four interpolators feeding into one.
* A 3D cubic interpolator has sixteen interpolators feeding into four, feeding into one.

To understand which values we need to look up, let's consider the 2D linear example again.
The four values going into the first group represent the four closest points (A, B, C, D) mentioned above.

1) The first interpolator gets:

* The closest value that is stored (A)
* The next value in the x dimension, keeping y fixed (B)

2) The second interpolator gets:

* One step over in the y dimension, keeping x fixed (C)
* One step over in both the x dimension and the y dimension (D)

The outputs of these two interpolators are points E and F.
In other words: the interpolated x values and, respectively, the following y values:

* The closest stored value of the y dimension
* One step forward in the y dimension

The last interpolator takes these two values and interpolates them in the y dimension.

To generalize for N dimensions and linear interpolation:

* The first group has 2^(n-1) parallel interpolators interpolating in the first dimension.
* The second group has 2^(n-2) parallel interpolators interpolating in the second dimension.
* The process continues until the n-th group, which has a single interpolator interpolating in the n-th dimension.

The same principle applies to the cubic interpolation in nD. The only difference is that there would be 4^(n-1) parallel interpolators in the first group, compared to 2^(n-1) for linear interpolation.

This is what the ``mixers`` function does.

Besides the values, each interpolator also needs to know the weight of each value in it's output.  
Let's call this `d`, like in ``ba.interpolate``. It is the same for each group of interpolators, since it correlates to a dimension.  
It's value is calculated the similarly to ``ba.interpolate``:

* First we prepare a "float table read-index" for that dimension (``id`` in ``ba.tabulate``)
* If the table only had that dimension and it could read a float index, what would it be.
* Then we ``int`` the float index to get the value we have stored that is closest to, but lower than the input value; the actual index for that dimension.
Our ``d`` is the difference between the float index and the actual index.

The ``ids`` function calculates the ``id`` for each dimension and inside the ``mixer`` function they get turned into ``d``s.

##### Storage method

The elephant in the room is: how do we get these indexes? For that we need to know how the values are stored.
We use one big table to store everything.

To understand the concept, let's look at the 2D example again, and then we'll extend it to 3d and the general nD case.

Let's say we have a 2D table with dimensions A and B where:
A has 3 values between 0 and 5 and B has 4 values between 0 and 1.
The 1D array representation of this 2D table will have a size of 3 * 4 = 12.

The values are stored in the following way:

* First 3 values: A is 0, then 3, then 5 while B is at 0.
* Next 3 values: A changes from 0 to 5 while B is at 1/3.
* Next 3 values: A changes from 0 to 5 while B is at 2/3.
* Last 3 values: A changes from 0 to 5 while B is at 1.

For the 3D example, let's extend the 2D example with an additional dimension C having 2 values between 0 and 2.
The total size will be 3 * 4 * 2 = 24.

The values are stored like so:

* First 3 values: A changes from 0 to 5, B is at 0, and C is at 0.
* Next 3 values: A changes from 0 to 5, B is at 1/3, and C is at 0.
* Next 3 values: A changes from 0 to 5, B is at 2/3, and C is at 0.
* Next 3 values: A changes from 0 to 5, B is at 1, and C is at 0.

The last 12 values are the same as the first 12, but with C at 2.

For the general n-dimensional case, we iterate through all dimensions, changing the values of the innermost dimension first, then moving towards the outer dimensions.

##### Read indexes

To get the float read index (``id``) corresponding to a particular dimension, we scale the function input value to be between 0 and 1, and multiply it by the size of that dimension minus one.

To understand how we get the ``readIndex``for ``.val``, let's work trough how we'd do it in our 2D linear example.  
For simplicity's sake, the ranges of the inputs to our ``function`` are both 0 to 1.  
Say we wanted to read the value closest to ``x=0.5`` and ``y=0``, so the ``id`` of ``x`` is ``1`` (the second value) and the ``id`` of ``y`` is 0 (first value). In this case, the read index is just the ``id`` of ``x``, rounded to the nearest integer, just like in ``ba.tabulate``.

If we want to read the value belonging to ``x=0.5`` and ``y=2/3``, things get more complicated. The ``id`` for ``y`` is now ``2``, the third value. For each step in the ``y`` direction, we need to increase the index by ``3``, the number of values that are stored for ``x``. So the influence of the ``y`` is:  the size of ``x`` times the rounded ``id`` of ``y``. The final read index is the rounded ``id`` of ``x`` plus the influence of ``y``.

For the general nD case, we need to do the same operation N times, each feeding into the next. This operation is the ``riN`` function. We take four parameters: the size of the dimension before it ``prevSize``, the index of the previous dimension ``prevIX``, the current size ``sizeX`` and the current id ``idX``.  ``riN`` has 2 outputs, the size, for feeding into the next dimension's ``prevSize``, and the read index feeding into the next dimension's ``prevIX``.  
The size is the ``sizeX`` times ``prevSize``. The read index is the rounded ``idX`` times ``prevSize`` added to the ``prevIX``. Our final ``readIndex`` is the read index output of the last dimension.

To get the read values for the  interpolators need a pattern of offsets in each dimension, since we are looking for the read indexes surrounding the point of interest. These offsets are best explained by looking at the code of ``tabulate2d``, the hardcoded 2D version:

```
tabulate2d(C,function, sizeX,sizeY, rx0,ry0, rx1,ry1, x,y) =
  environment {
    size = sizeX*sizeY;
    // Maximum X index to access
    midX = sizeX-1;
    // Maximum Y index to access
    midY = sizeY-1;
    // Maximum total index to access
    mid = size-1;
    // Create the table
    wf = function(wfX,wfY);
    // Prepare the 'float' table read index for X
    idX = (x-rx0)/(rx1-rx0)*midX;
    // Prepare the 'float' table read index for Y
    idY = ((y-ry0)/(ry1-ry0))*midY;
    // table creation X:
    wfX =
      rx0+float(ba.time%sizeX)*(rx1-rx0)
      /float(midX);
    // table creation Y:
    wfY =
      ry0+
      ((float(ba.time-(ba.time%sizeX))
        /float(sizeX))
       *(ry1-ry0))
      /float(midY);

    // Limit the table read index in [0, mid] if C = 1
    rid(x,mid, 0) = x;
    rid(x,mid, 1) = max(0, min(x, mid));

    // Tabulate a binary 'FX' function on a range [rx0, rx1] [ry0, ry1]
    val(x,y) =
      rdtable(size, wf, readIndex);
    readIndex =
      rid(
        rid(int(idX+0.5),midX, C)
        +yOffset
      , mid, C);
    yOffset = sizeX*rid(int(idY),midY,C);

    // Tabulate a binary 'FX' function over the range [rx0, rx1] [ry0, ry1] with linear interpolation
    lin =
      it.interpolate_linear(
        dy
      , it.interpolate_linear(dx,v0,v1)
      , it.interpolate_linear(dx,v2,v3))
    with {
      i0 = rid(int(idX), midX, C)+yOffset;
      i1 = i0+1;
      i2 = i0+sizeX;
      i3 = i1+sizeX;
      dx  = idX-int(idX);
      dy  = idY-int(idY);
      v0 = rdtable(size, wf, rid(i0, mid, C));
      v1 = rdtable(size, wf, rid(i1, mid, C));
      v2 = rdtable(size, wf, rid(i2, mid, C));
      v3 = rdtable(size, wf, rid(i3, mid, C));
    };

    // Tabulate a binary 'FX' function over the range [rx0, rx1] [ry0, ry1] with cubic interpolation
    cub =
      it.interpolate_cubic(
        dy
      , it.interpolate_cubic(dx,v0,v1,v2,v3)
      , it.interpolate_cubic(dx,v4,v5,v6,v7)
      , it.interpolate_cubic(dx,v8,v9,v10,v11)
      , it.interpolate_cubic(dx,v12,v13,v14,v15)
      )
    with {
      i0  = i4-sizeX;
      i1  = i5-sizeX;
      i2  = i6-sizeX;
      i3  = i7-sizeX;

      i4  = i5-1;
      i5  = rid(int(idX), midX, C)+yOffset;
      i6  = i5+1;
      i7  = i6+1;

      i8  = i4+sizeX;
      i9  = i5+sizeX;
      i10 = i6+sizeX;
      i11 = i7+sizeX;

      i12 = i4+(2*sizeX);
      i13 = i5+(2*sizeX);
      i14 = i6+(2*sizeX);
      i15 = i7+(2*sizeX);

      dx  = idX-int(idX);
      dy  = idY-int(idY);
      v0  = rdtable(size, wf, rid(i0 , mid, C));
      v1  = rdtable(size, wf, rid(i1 , mid, C));
      v2  = rdtable(size, wf, rid(i2 , mid, C));
      v3  = rdtable(size, wf, rid(i3 , mid, C));
      v4  = rdtable(size, wf, rid(i4 , mid, C));
      v5  = rdtable(size, wf, rid(i5 , mid, C));
      v6  = rdtable(size, wf, rid(i6 , mid, C));
      v7  = rdtable(size, wf, rid(i7 , mid, C));
      v8  = rdtable(size, wf, rid(i8 , mid, C));
      v9  = rdtable(size, wf, rid(i9 , mid, C));
      v10 = rdtable(size, wf, rid(i10, mid, C));
      v11 = rdtable(size, wf, rid(i11, mid, C));
      v12 = rdtable(size, wf, rid(i12, mid, C));
      v13 = rdtable(size, wf, rid(i13, mid, C));
      v14 = rdtable(size, wf, rid(i14, mid, C));
      v15 = rdtable(size, wf, rid(i15, mid, C));
    };
  };
```

In the interest of brevity, we'll stop explaining here. If you have any more questions, feel free to open an issue on [faustlibraries](https://github.com/grame-cncm/faustlibraries) and tag @magnetophon.

#### Test
```
ba = library("basics.lib");
powSin(x,y) = sin(pow(x,y));
tabulateNd_test = ba.tabulateNd(1, powSin, (8,8, 2.0,2.0, 8.0,8.0, 3.0,4.0)).lin;
```

## Selectors (Conditions)


----

### `(ba.)if`

if-then-else implemented with a select2. WARNING: since `select2` is strict (always evaluating both branches),
the resulting if does not have the usual "lazy" semantic of the C if form, and thus cannot be used to
protect against forbidden computations like division-by-zero for instance.

#### Usage

*   `if(cond, then, else) : _`

Where:

* `cond`: condition
* `then`: signal selected while cond is true
* `else`: signal selected while cond is false

#### Test
```
ba = library("basics.lib");
if_test = ba.if(1, 0.5, -0.5);
```

----

### `(ba.)ifNc`

if-then-elseif-then-...elsif-then-else implemented on top of `ba.if`.

#### Usage

```
   ifNc((cond1,then1, cond2,then2, ... condN,thenN, else)) : _
or
   ifNc(Nc, cond1,then1, cond2,then2, ... condN,thenN, else) : _
or
   cond1,then1, cond2,then2, ... condN,thenN, else : ifNc(Nc) : _
```

Where:

* `Nc` : number of branches/conditions (constant numerical expression)
* `condX`: condition
* `thenX`: signal selected if condX is the 1st true condition
* `else`: signal selected if all the cond1-condN conditions are false

#### Example test program

```
   process(x,y) = ifNc((x<y,-1, x>y,+1, 0));
or
   process(x,y) = ifNc(2, x<y,-1, x>y,+1, 0);
or
   process(x,y) = x<y,-1, x>y,+1, 0 : ifNc(2);
```

outputs `-1` if `x<y`, `+1` if `x>y`, `0` otherwise.

#### Test
```
ba = library("basics.lib");
ifNc_test = ba.ifNc((1, 10, 0, 20, 30));
```

----

### `(ba.)ifNcNo`

`ifNcNo(Nc,No)` is similar to `ifNc(Nc)` above but then/else branches have `No` outputs.

#### Usage

```
   ifNcNo(Nc,No, cond1,then1, cond2,then2, ... condN,thenN, else) : sig.bus(No)
```

Where:

* `Nc` : number of branches/conditions (constant numerical expression)
* `No` : number of outputs (constant numerical expression)
* `condX`: condition
* `thenX`: list of No signals selected if condX is the 1st true condition
* `else`: list of No signals selected if all the cond1-condN conditions are false

#### Example test program

```
   process(x) = ifNcNo(2,3, x<0, -1,-1,-1, x>0, 1,1,1, 0,0,0);
```

outputs `-1,-1,-1` if `x<0`, `1,1,1` if `x>0`, `0,0,0` otherwise.

#### Test
```
ba = library("basics.lib");
ifNcNo_test = (1, 10, 0, 20, 30) : ba.ifNcNo(2, 1);
```

----

### `(ba.)selector`

Selects the ith input among N at compile time.

#### Usage

```
selector(I,N)
_,_,_,_ : selector(2,4) : _ // selects the 3rd input among 4
```

Where:

* `I`: input to select (int, numbered from 0, known at compile time)
* `N`: number of inputs (int, known at compile time, N > I)

There is also `cselector` for selecting among complex input signals of the form (real,imag).


#### Test
```
ba = library("basics.lib");
selector_test = (0.1, 0.2, 0.3, 0.4) : ba.selector(2, 4);
```

----

### `(ba.)select2stereo`

Select between 2 stereo signals.

#### Usage

```
_,_,_,_ : select2stereo(bpc) : _,_
```

Where:

* `bpc`: the selector switch (0/1)

#### Test
```
ba = library("basics.lib");
select2stereo_test = ba.select2stereo(1, (0.1,0.2, 0.3,0.4));
```

----

### `(ba.)selectn`

Selects the ith input among N at run time.

#### Usage

```
selectn(N,i)
_,_,_,_ : selectn(4,2) : _ // selects the 3rd input among 4
```

Where:

* `N`: number of inputs (int, known at compile time, N > 0)
* `i`: input to select (int, numbered from 0)

#### Example test program

```
N = 64;
process = par(n, N, (par(i,N,i) : selectn(N,n)));
```

#### Test
```
ba = library("basics.lib");
selectn_test = (1,2,3,4) : ba.selectn(4, 2);
```

----

### `(ba.)selectbus`

Select a bus among `NUM_BUSES` buses, where each bus has `BUS_SIZE` outputs.
The order of the signal inputs should be the signals of the first bus, the
signals of the second bus, and so on.

#### Usage

```
process = si.bus(BUS_SIZE*NUM_BUSES) : selectbus(BUS_SIZE, NUM_BUSES, id) : si.bus(BUS_SIZE);
```

Where:

* `BUS_SIZE`: number of outputs from each bus (int, known at compile time).
* `NUM_BUSES`: number of buses (int, known at compile time).
* `id`: index of the bus to select (int, `0<=id<NUM_BUSES`)

#### Test
```
ba = library("basics.lib");
selectbus_test = (1,2,3,4) : ba.selectbus(2, 2, 1);
```

----

### `(ba.)selectxbus`

Like `ba.selectbus`, but with a cross-fade when selecting the bus using the same 
technique than `ba.selectmulti`.

#### Usage

```
process = si.bus(BUS_SIZE*NUM_BUSES) : selectbus(BUS_SIZE, NUM_BUSES, FADE, id) : si.bus(BUS_SIZE);
```

Where:

* `BUS_SIZE`: number of outputs from each bus (int, known at compile time).
* `NUM_BUSES`: number of buses (int, known at compile time).
* `fade`: number of samples for the crossfade.
* `id`: index of the bus to select (int, `0<=id<NUM_BUSES`)

#### Test
```
ba = library("basics.lib");
selectxbus_test = (1,2,3,4) : ba.selectxbus(2, 2, 16, checkbox("bus"));
```

----

### `(ba.)selectmulti`

Selects the ith circuit among N at run time (all should have the same number of inputs and outputs)
with a crossfade.

#### Usage

```
selectmulti(n,lgen,id)
```

Where:

* `n`: crossfade in samples
* `lgen`: list of circuits
* `id`: circuit to select (int, numbered from 0)

#### Example test program

```
process = selectmulti(ma.SR/10, ((3,9),(2,8),(5,7)), nentry("choice", 0, 0, 2, 1));
process = selectmulti(ma.SR/10, ((_*3,_*9),(_*2,_*8),(_*5,_*7)), nentry("choice", 0, 0, 2, 1));
```

#### Test
```
ba = library("basics.lib");
os = library("oscillators.lib");
ma = library("maths.lib");
effects = ((_*0.5,_*0.5),(_*0.25,_*0.25));
choice = int(checkbox("choice"));
selectmulti_test = (os.osc(440), os.osc(660)) : ba.selectmulti(ma.SR/100, effects, choice);
```

----

### `(ba.)selectoutn`

Route input to the output among N at run time.

#### Usage

```
_ : selectoutn(N, i) : si.bus(N)
```

Where:

* `N`: number of outputs (int, known at compile time, N > 0)
* `i`: output number to route to (int, numbered from 0) (i.e. slider)

#### Example test program

```
process = 1 : selectoutn(3, sel) : par(i, 3, vbargraph("v.bargraph %i", 0, 1));
sel = hslider("volume", 0, 0, 2, 1) : int;
```

#### Test
```
ba = library("basics.lib");
selectoutn_test = 1 : ba.selectoutn(3, 1);
```

## Other


----

### `(ba.)latch`

Latch input on the rising edge of trig.
Captures ("records") the input x whenever trig crosses from ≤0 to >0,
and holds the last captured value at all other times.

#### Usage
```
_ : latch(trig) : _
```

Where:

* `trig`: trigger signal. A rising edge (≤0 → >0) samples the input.

#### Test
```
ba = library("basics.lib");
os = library("oscillators.lib");
latch_test = os.osc(2) : ba.latch(button("hold"));
```

----

### `(ba.)sAndH`

Sample And Hold: "records" the input when trig is 1, outputs a frozen value when trig is 0.
`sAndH` is a standard Faust function.

#### Usage

```
_ : sAndH(trig) : _
```

Where:

* `trig`: hold trigger (0 for hold, 1 for bypass)

#### Test
```
ba = library("basics.lib");
os = library("oscillators.lib");
sAndH_test = os.osc(2) : ba.sAndH(button("hold"));
```

----

### `(ba.)tAndH`

Test And Hold: "records" the input when pred(input) is true, outputs a frozen value otherwise.

#### Usage

```
_ : tAndH(pred) : _
```

Where:

* `pred`: predicate to test the input

#### Test
```
ba = library("basics.lib");
os = library("oscillators.lib");
isPositive(x) = x > 0.0;
tAndH_test = os.osc(2) : ba.tAndH(isPositive);
```

----

### `(ba.)downSample`

Down sample a signal. WARNING: this function doesn't change the
rate of a signal, it just holds samples...
`downSample` is a standard Faust function.

#### Usage

```
_ : downSample(freq) : _
```

Where:

* `freq`: new rate in Hz

#### Test
```
ba = library("basics.lib");
os = library("oscillators.lib");
downSample_test = os.osc(440) : ba.downSample(11025);
```

----

### `(ba.)downSampleCV`


A version of `ba.downSample` where the frequency parameter has
been replaced by an `amount` parameter that is in the range zero
to one. WARNING: this function doesn't change the rate of a
signal, it just holds samples...

#### Usage
```
_ : downSampleCV(amount) : _
```
Where:

* `amount`: The amount of down-sampling to perform [0..1]

#### Test
```
ba = library("basics.lib");
os = library("oscillators.lib");
downSampleCV_test = os.osc(440) : ba.downSampleCV(0.5);
```

----

### `(ba.)peakhold`

Outputs current max value above zero.

#### Usage

```
_ : peakhold(mode) : _
```

Where:

`mode` means:

 0 - Pass through. A single sample 0 trigger will work as a reset.

 1 - Track and hold max value.

#### Test
```
ba = library("basics.lib");
os = library("oscillators.lib");
peakhold_test = os.osc(440) : ba.peakhold(1);
```

----

### `(ba.)peakholder`


While peak-holder functions are scarcely discussed in the literature
(please do send me an email if you know otherwise), common sense
tells that the expected behaviour should be as follows: the absolute
value of the input signal is compared with the output of the peak-holder;
if the input is greater or equal to the output, a new peak is detected
and sent to the output; otherwise, a timer starts and the current peak
is held for N samples; once the timer is out and no new peaks have been
detected, the absolute value of the current input becomes the new peak.

#### Usage

```
_ : peakholder(holdTime) : _
```

Where:

* `holdTime`: hold time in samples

#### Test
```
ba = library("basics.lib");
os = library("oscillators.lib");
peakholder_test = os.osc(440) : ba.peakholder(ba.sec2samp(0.1));
```

----

### `(ba.)kr2ar`

Force a control rate signal to be used as an audio rate signal.

#### Usage

```
hslider("freq", 200, 200, 2000, 0.1) : kr2ar;
```

#### Test
```
ba = library("basics.lib");
kr2ar_test = button("gate") : ba.kr2ar;
```

----

### `(ba.)impulsify`

Turns a signal into an impulse with the value of the current sample
(0.3,0.2,0.1 becomes 0.3,0.0,0.0). This function is typically used with a
`button` to turn its output into an impulse. `impulsify` is a standard Faust
function.

#### Usage

```
button("gate") : impulsify;
```

#### Test
```
ba = library("basics.lib");
os = library("oscillators.lib");
impulsify_test = os.osc(440) : ba.impulsify;
```

----

### `(ba.)automat`

Record and replay in a loop the successives values of the input signal.

#### Usage

```
hslider(...) : automat(t, size, init) : _
```

Where:

* `t`: tempo in BPM
* `size`: number of items in the loop
* `init`: init value in the loop

#### Test
```
ba = library("basics.lib");
autoControl = hslider("autoControl", 0.2, 0, 1, 0.01);
automat_test = autoControl : ba.automat(120, 4, 0.0);
```

----

### `(ba.)bpf`

bpf is an environment (a group of related definitions) that can be used to
create break-point functions. It contains three functions:

* `start(x,y)` to start a break-point function
* `end(x,y)` to end a break-point function
* `point(x,y)` to add intermediate points to a break-point function, using linear interpolation

A minimal break-point function must contain at least a start and an end point:

```
f = bpf.start(x0,y0) : bpf.end(x1,y1);
```

A more involved break-point function can contains any number of intermediate
points:

```
f = bpf.start(x0,y0) : bpf.point(x1,y1) : bpf.point(x2,y2) : bpf.end(x3,y3);
```

In any case the `x_{i}` must be in increasing order (for all `i`, `x_{i} < x_{i+1}`).
For example the following definition:

```
f = bpf.start(x0,y0) : ... : bpf.point(xi,yi) : ... : bpf.end(xn,yn);
```

implements a break-point function f such that:

* `f(x) = y_{0}` when `x < x_{0}`
* `f(x) = y_{n}` when `x > x_{n}`
* `f(x) = y_{i} + (y_{i+1}-y_{i})*(x-x_{i})/(x_{i+1}-x_{i})` when `x_{i} <= x`
and `x < x_{i+1}`

In addition to `bpf.point`, there are also `step` and `curve` functions:

* `step(x,y)` to add a flat section
* `step_end(x,y)` to end with a flat section
* `curve(B,x,y)` to add a curved section
* `curve_end(B,x,y)` to end with a curved section

These functions can be combined with the other `bpf` functions.

Here's an example using `bpf.step`:

`f(x) = x : bpf.start(0,0) : bpf.step(.2,.3) : bpf.step(.4,.6) : bpf.step_end(1,1);`

For `x < 0.0`, the output is 0.0.
For `0.0 <= x < 0.2`, the output is 0.0.
For `0.2 <= x < 0.4`, the output is 0.3.
For `0.4 <= x < 1.0`, the output is 0.6.
For `1.0 <= x`, the output is 1.0

For the `curve` functions, `B` (compile-time constant)
is a "bias" value strictly greater than zero and less than or equal to 1. When `B` is 0.5, the
output curve is exactly linear and equivalent to `bpf.point`. When `B` is less than 0.5, the
output is biased towards the `y` value of the previous breakpoint. When `B` is greater than 0.5,
the output is biased towards the `y` value of the curve breakpoint. Here's an example:

`f = bpf.start(0,0) : bpf.curve(.15,.5,.5) : bpf.curve_end(.85,1,1);`

In the following example, the output is biased towards zero (the latter y value) instead of
being a linear ramp from 1 to 0.

`f = bpf.start(0,1) : bpf.curve_end(.9,1,0);`

`bpf` is a standard Faust function.

----

### `(ba.)listInterp`

Linearly interpolates between the elements of a list.

#### Usage

```
index = 1.69; // range is 0-4
process = listInterp((800,400,350,450,325),index);
```

Where:

* `index`: the index (float) to interpolate between the different values.
The range of `index` depends on the size of the list.

#### Test
```
ba = library("basics.lib");
listInterp_test = ba.listInterp((800,400,350,450,325), 1.5);
```

----

### `(ba.)bypass1`

Takes a mono input signal, route it to `e` and bypass it if `bpc = 1`.
When bypassed, `e` is feed with zeros so that its state is cleanup up.
`bypass1` is a standard Faust function.

#### Usage

```
_ : bypass1(bpc,e) : _
```

Where:

* `bpc`: bypass switch (0/1)
* `e`: a mono effect

#### Test
```
ba = library("basics.lib");
os = library("oscillators.lib");
bypass1_test = os.osc(440) : ba.bypass1(button("bypass"), *(0.5));
```

----

### `(ba.)bypass2`

Takes a stereo input signal, route it to `e` and bypass it if `bpc = 1`.
When bypassed, `e` is feed with zeros so that its state is cleanup up.
`bypass2` is a standard Faust function.

#### Usage

```
_,_ : bypass2(bpc,e) : _,_
```

Where:

* `bpc`: bypass switch (0/1)
* `e`: a stereo effect

#### Test
```
ba = library("basics.lib");
os = library("oscillators.lib");
bypass2_test = (os.osc(440), os.osc(660)) : ba.bypass2(button("bypass"), par(i,2, *(0.5)));
```

----

### `(ba.)bypass1to2`

Bypass switch for effect `e` having mono input signal and stereo output.
Effect `e` is bypassed if `bpc = 1`.When bypassed, `e` is feed with zeros
so that its state is cleanup up.
`bypass1to2` is a standard Faust function.

#### Usage

```
_ : bypass1to2(bpc,e) : _,_
```

Where:

* `bpc`: bypass switch (0/1)
* `e`: a mono-to-stereo effect

#### Test
```
ba = library("basics.lib");
os = library("oscillators.lib");
monoToStereo(x) = (x*0.5, x*0.25);
bypass1to2_test = os.osc(440) : ba.bypass1to2(button("bypass"), monoToStereo);
```

----

### `(ba.)bypass_fade`

Bypass an arbitrary (N x N) circuit with 'n' samples crossfade.
Inputs and outputs signals are faded out when 'e' is bypassed,
so that 'e' state is cleanup up.
Once bypassed the effect is replaced by `par(i,N,_)`.
Bypassed circuits can be chained.

#### Usage

```
_ : bypass_fade(n,b,e) : _
or
_,_ : bypass_fade(n,b,e) : _,_
```
* `n`: number of samples for the crossfade
* `b`: bypass switch (0/1)
* `e`: N x N circuit

#### Example test program

```
process = bypass_fade(ma.SR/10, checkbox("bypass echo"), echo);
process = bypass_fade(ma.SR/10, checkbox("bypass reverb"), freeverb);
```

#### Test
```
ba = library("basics.lib");
os = library("oscillators.lib");
bypass_fade_test = (os.osc(440), os.osc(660)) : ba.bypass_fade(128, button("bypass"), par(i,2, *(0.5)));
```

----

### `(ba.)toggle`

Triggered by the change of 0 to 1, it toggles the output value
between 0 and 1.

#### Usage

```
_ : toggle : _
```
#### Example test program

```
button("toggle") : toggle : vbargraph("output", 0, 1)
(an.amp_follower(0.1) > 0.01) : toggle : vbargraph("output", 0, 1) // takes audio input
```

#### Test
```
ba = library("basics.lib");
toggle_test = ba.toggle(button("trig"));
```

----

### `(ba.)on_and_off`

The first channel set the output to 1, the second channel to 0.

#### Usage

```
_,_ : on_and_off : _
```

#### Example test program

```
button("on"), button("off") : on_and_off : vbargraph("output", 0, 1)
```

#### Test
```
ba = library("basics.lib");
on_and_off_test = button("on"), button("off") : ba.on_and_off;
```

----

### `(ba.)bitcrusher`

Produce distortion by reduction of the signal resolution.

#### Usage

```
_ : bitcrusher(nbits) : _
```

Where:

* `nbits`: the number of bits of the wanted resolution

#### Test
```
ba = library("basics.lib");
os = library("oscillators.lib");
bitcrusher_test = os.osc(440) : ba.bitcrusher(8);
```

----

### `(ba.)mulaw_bitcrusher`

Produce distortion by reducing the signal resolution using μ-law compression.

#### Usage

```
_ : mulaw_bitcrusher(mu,nbits) : _
```

Where:

* `mu`: controls the degree of μ-law compression, larger values result in stronger compression
* `nbits`: the number of bits of the wanted resolution

#### Description

The `mulaw_bitcrusher` applies a combination of μ-law compression, quantization, and expansion 
to create a non-linear bitcrushed effect. This method retains finer detail in lower-amplitude signals 
compared to linear bitcrushing, making it suitable for creative sound design.

#### Theory

1. **μ-law Compression**:
   emphasizes lower-amplitude signals by applying a logarithmic curve to the signal.
   The formula used is:
   ```
   F(x) = ma.signum(x) * log(1 + mu * abs(x)) / log(1 + mu);
   ```
2. **Quantization**:
   reduces the signal resolution to `nbits` by rounding values to the nearest step within the specified bit depth.

3. **μ-law Expansion**:
   reverses the compression applied earlier to restore the signal to its original dynamic range:
   ```
   F⁻¹(y) = ma.signum(y) * (pow(1 + mu, abs(y)) - 1) / mu;
   ```

#### Example test program

```
process = os.osc(440) : mulaw_bitcrusher(255, 8);
```

In this example, a sine wave at 440 Hz is passed through the μ-law bitcrusher, with a compression
parameter `mu` of 255 and 8-bit quantization. This creates a distorted, "lo-fi" effect.

#### Test
```
ba = library("basics.lib");
os = library("oscillators.lib");
mulaw_bitcrusher_test = os.osc(440) : ba.mulaw_bitcrusher(2.0, 8);
```
#### References

* [https://en.wikipedia.org/wiki/Μ-law_algorithm](https://en.wikipedia.org/wiki/Μ-law_algorithm)

## Sliding Reduce

Provides various operations on the last n samples using a high order
`slidingReduce(op,n,maxN,disabledVal,x)` fold-like function:

* `slidingSum(n)`: the sliding sum of the last n input samples, CPU-light
* `slidingSump(n,maxN)`: the sliding sum of the last n input samples, numerically stable "forever"
* `slidingMax(n,maxN)`: the sliding max of the last n input samples
* `slidingMin(n,maxN)`: the sliding min of the last n input samples
* `slidingMean(n)`: the sliding mean of the last n input samples, CPU-light
* `slidingMeanp(n,maxN)`: the sliding mean of the last n input samples, numerically stable "forever"
* `slidingRMS(n)`: the sliding RMS of the last n input samples, CPU-light
* `slidingRMSp(n,maxN)`: the sliding RMS of the last n input samples, numerically stable "forever"

#### Working Principle

If we want the maximum of the last 8 values, we can do that as:

```
simpleMax(x) =
 (
   (
     max(x@0,x@1),
     max(x@2,x@3)
   ) :max
 ),
 (
   (
     max(x@4,x@5),
     max(x@6,x@7)
   ) :max
 )
 :max;
```

`max(x@2,x@3)` is the same as `max(x@0,x@1)@2` but the latter re-uses a
value we already computed,so is more efficient. Using the same trick for
values 4 trough 7, we can write:

```
efficientMax(x)=
 (
   (
     max(x@0,x@1),
     max(x@0,x@1)@2
   ) :max
 ),
 (
   (
     max(x@0,x@1),
     max(x@0,x@1)@2
   ) :max@4
 )
 :max;
```

We can rewrite it recursively, so it becomes possible to get the maximum at
have any number of values, as long as it's a power of 2.

```
recursiveMax =
 case {
   (1,x) => x;
   (N,x) => max(recursiveMax(N/2,x), recursiveMax(N/2,x)@(N/2));
 };
```

What if we want to look at a number of values that's not a power of 2?
For each value, we will have to decide whether to use it or not.
If n is bigger than the index of the value, we use it, otherwise we replace
it with (`0-(ma.MAX)`):

```
variableMax(n,x) =
 max(
   max(
     (
       (x@0 : useVal(0)),
       (x@1 : useVal(1))
     ):max,
     (
       (x@2 : useVal(2)),
       (x@3 : useVal(3))
     ):max
   ),
   max(
     (
       (x@4 : useVal(4)),
       (x@5 : useVal(5))
     ):max,
     (
       (x@6 : useVal(6)),
       (x@7 : useVal(7))
     ):max
   )
 )
with {
 useVal(i) = select2((n>=i) , (0-(ma.MAX)),_);
};
```

Now it becomes impossible to re-use any values. To fix that let's first look
at how we'd implement it using recursiveMax, but with a fixed n that is not
a power of 2. For example, this is how you'd do it with `n=3`:

```
binaryMaxThree(x) =
 (
   recursiveMax(1,x)@0, // the first x
   recursiveMax(2,x)@1  // the second and third x
 ):max;
```

`n=6`

```
binaryMaxSix(x) =
 (
   recursiveMax(2,x)@0, // first two
   recursiveMax(4,x)@2  // third trough sixth
 ):max;
```

Note that `recursiveMax(2,x)` is used at a different delay then in
`binaryMaxThree`, since it represents 1 and 2, not 2 and 3. Each block is
delayed the combined size of the previous blocks.

`n=7`

```
binaryMaxSeven(x) =
 (
   (
     recursiveMax(1,x)@0, // first x
     recursiveMax(2,x)@1  // second and third
   ):max,
   (
     recursiveMax(4,x)@3  // fourth trough seventh
   )
 ):max;
```

To make a variable version, we need to know which powers of two are used,
and at which delay time.

Then it becomes a matter of:

* lining up all the different block sizes in parallel: `sequentialOperatorParOut()`
* delaying each the appropriate amount: `sumOfPrevBlockSizes()`
* turning it on or off: `useVal()`
* getting the maximum of all of them: `parallelOp()`

In Faust, we can only do that for a fixed maximum number of values: `maxN`, known at compile time.

----

### `(ba.)slidingReduce`

Fold-like high order function. Apply a commutative binary operation `op` to
the last `n` consecutive samples of a signal `x`. For example :
`slidingReduce(max,128,128,0-(ma.MAX))` will compute the maximum of the last
128 samples. The output is updated each sample, unlike reduce, where the
output is constant for the duration of a block.

#### Usage

```
_ : slidingReduce(op,n,maxN,disabledVal) : _
```

Where:

* `n`: the number of values to process
* `maxN`: the maximum number of values to process (int, known at compile time, maxN > 0)
* `op`: the operator. Needs to be a commutative one.
* `disabledVal`: the value to use when we want to ignore a value.

In other words, `op(x,disabledVal)` should equal to `x`. For example,
`+(x,0)` equals `x` and `min(x,ma.MAX)` equals `x`. So if we want to
calculate the sum, we need to give 0 as `disabledVal`, and if we want the
minimum, we need to give `ma.MAX` as `disabledVal`.

#### Test
```
ba = library("basics.lib");
os = library("oscillators.lib");
ma = library("maths.lib");
slidingReduce_test = os.osc(440) : ba.slidingReduce(max, 64, 64, 0 - ma.MAX);
```

----

### `(ba.)slidingSum`

The sliding sum of the last n input samples.

It will eventually run into numerical trouble when there is a persistent dc component.
If that matters in your application, use the more CPU-intensive `ba.slidingSump`.

#### Usage

```
_ : slidingSum(n) : _
```

Where:

* `n`: the number of values to process

#### Test
```
ba = library("basics.lib");
os = library("oscillators.lib");
slidingSum_test = os.osc(440) : ba.slidingSum(64);
```

----

### `(ba.)slidingSump`

The sliding sum of the last n input samples.

It uses a lot more CPU than `ba.slidingSum`, but is numerically stable "forever" in return.

#### Usage

```
_ : slidingSump(n,maxN) : _
```

Where:

* `n`: the number of values to process
* `maxN`: the maximum number of values to process (int, known at compile time, maxN > 0)

#### Test
```
ba = library("basics.lib");
os = library("oscillators.lib");
slidingSump_test = os.osc(440) : ba.slidingSump(64, 128);
```

----

### `(ba.)slidingMax`

The sliding maximum of the last n input samples.

#### Usage

```
_ : slidingMax(n,maxN) : _
```

Where:

* `n`: the number of values to process
* `maxN`: the maximum number of values to process (int, known at compile time, maxN > 0)

#### Test
```
ba = library("basics.lib");
os = library("oscillators.lib");
ma = library("maths.lib");
slidingMax_test = os.osc(440) : ba.slidingMax(64, 128);
```

----

### `(ba.)slidingMin`

The sliding minimum of the last n input samples.

#### Usage

```
_ : slidingMin(n,maxN) : _
```

Where:

* `n`: the number of values to process
* `maxN`: the maximum number of values to process (int, known at compile time, maxN > 0)

#### Test
```
ba = library("basics.lib");
os = library("oscillators.lib");
ma = library("maths.lib");
slidingMin_test = os.osc(440) : ba.slidingMin(64, 128);
```

----

### `(ba.)slidingMean`

The sliding mean of the last n input samples.

It will eventually run into numerical trouble when there is a persistent dc component.
If that matters in your application, use the more CPU-intensive `ba.slidingMeanp`.

#### Usage

```
_ : slidingMean(n) : _
```

Where:

* `n`: the number of values to process

#### Test
```
ba = library("basics.lib");
os = library("oscillators.lib");
slidingMean_test = os.osc(440) : ba.slidingMean(64);
```

----

### `(ba.)slidingMeanp`

The sliding mean of the last n input samples.

It uses a lot more CPU than `ba.slidingMean`, but is numerically stable "forever" in return.

#### Usage

```
_ : slidingMeanp(n,maxN) : _
```

Where:

* `n`: the number of values to process
* `maxN`: the maximum number of values to process (int, known at compile time, maxN > 0)

#### Test
```
ba = library("basics.lib");
os = library("oscillators.lib");
slidingMeanp_test = os.osc(440) : ba.slidingMeanp(64, 128);
```

----

### `(ba.)slidingRMS`

The root mean square of the last n input samples.

It will eventually run into numerical trouble when there is a persistent dc component.
If that matters in your application, use the more CPU-intensive `ba.slidingRMSp`.

#### Usage

```
_ : slidingRMS(n) : _
```

Where:

* `n`: the number of values to process

#### Test
```
ba = library("basics.lib");
os = library("oscillators.lib");
slidingRMS_test = os.osc(440) : ba.slidingRMS(64);
```

----

### `(ba.)slidingRMSp`

The root mean square of the last n input samples.

It uses a lot more CPU than `ba.slidingRMS`, but is numerically stable "forever" in return.

#### Usage

```
_ : slidingRMSp(n,maxN) : _
```

Where:

* `n`: the number of values to process
* `maxN`: the maximum number of values to process (int, known at compile time, maxN > 0)

#### Test
```
ba = library("basics.lib");
os = library("oscillators.lib");
slidingRMSp_test = os.osc(440) : ba.slidingRMSp(64, 128);
```

## Parallel Operators

Provides various operations on N parallel inputs using a high order
`parallelOp(op,N,x)` function:

* `parallelMax(N)`: the max of n parallel inputs
* `parallelMin(N)`: the min of n parallel inputs
* `parallelMean(N)`: the mean of n parallel inputs
* `parallelRMS(N)`: the RMS of n parallel inputs

----

### `(ba.)parallelOp`

Apply a commutative binary operation `op` to N parallel inputs.

#### usage

```
si.bus(N) : parallelOp(op,N) : _
```

where:

* `N`: the number of parallel inputs known at compile time
* `op`: the operator which needs to be commutative

#### Test
```
ba = library("basics.lib");
parallelOp_test = (0.2, 0.5, 0.1) : ba.parallelOp(max, 3);
```

----

### `(ba.)parallelMax`

The maximum of N parallel inputs.

#### Usage

```
si.bus(N) : parallelMax(N) : _
```

Where:

* `N`: the number of parallel inputs known at compile time

#### Test
```
ba = library("basics.lib");
parallelMax_test = (0.2, 0.5, 0.1) : ba.parallelMax(3);
```

----

### `(ba.)parallelMin`

The minimum of N parallel inputs.

#### Usage

```
si.bus(N) : parallelMin(N) : _
```

Where:

* `N`: the number of parallel inputs known at compile time

#### Test
```
ba = library("basics.lib");
parallelMin_test = (0.2, 0.5, 0.1) : ba.parallelMin(3);
```

----

### `(ba.)parallelMean`

The mean of N parallel inputs.

#### Usage

```
si.bus(N) : parallelMean(N) : _
```

Where:

* `N`: the number of parallel inputs known at compile time

#### Test
```
ba = library("basics.lib");
parallelMean_test = (0.2, 0.5, 0.1) : ba.parallelMean(3);
```

----

### `(ba.)parallelRMS`

The RMS of N parallel inputs.

#### Usage

```
si.bus(N) : parallelRMS(N) : _
```

Where:

* `N`: the number of parallel inputs known at compile time

#### Test
```
ba = library("basics.lib");
parallelRMS_test = (0.2, 0.5, 0.1) : ba.parallelRMS(3);
```
