#  signals.lib 

Signals library. Its official prefix is `si`.

This library provides fundamental signal processing operations for Faust,
including generators, combinators, selectors, and basic DSP utilities. It defines
essential functions used across all Faust libraries for building and manipulating
audio and control signals.

The Signals library is organized into 1 section:

* [Functions Reference](#functions-reference)

#### References

* [https://github.com/grame-cncm/faustlibraries/blob/master/signals.lib](https://github.com/grame-cncm/faustlibraries/blob/master/signals.lib)

## Functions Reference


----

### `(si.)bus`

Put N cables in parallel.
`bus` is a standard Faust function.

#### Usage

```
bus(N)
bus(4) : _,_,_,_
```

Where:

* `N`: is an integer known at compile time that indicates the number of parallel cables

#### Test
```
si = library("signals.lib");
bus_test = (
    hslider("bus:x0", 0.25, -1, 1, 0.01),
    hslider("bus:x1", -0.5, -1, 1, 0.01),
    hslider("bus:x2", 0.75, -1, 1, 0.01)
) : si.bus(3);
```

----

### `(si.)block`

Block - terminate N signals.
`block` is a standard Faust function.

#### Usage

```
bus(N) : block(N)
```

Where:

* `N`: the number of signals to be blocked known at compile time 

#### Test
```
si = library("signals.lib");
block_test = (
    hslider("block:x0", 0.5, -1, 1, 0.01),
    hslider("block:x1", -0.25, -1, 1, 0.01)
) : (si.block(1), _);
```

----

### `(si.)interpolate`

Linear interpolation between two signals.

#### Usage

```
_,_ : interpolate(i) : _
```

Where:

* `i`: interpolation control between 0 and 1 (0: first input; 1: second input)

#### Test
```
si = library("signals.lib");
os = library("oscillators.lib");
interpolate_test = si.interpolate(
    hslider("interpolate:mix", 0.5, 0, 1, 0.01),
    os.tosc(220),
    os.tosc(440)
);
```

----

### `(si.)repeat`

Repeat an effect N time(s) and take the parallel sum of all
intermediate buses.

#### Usage

```
bus(inputs(FX)) : repeat(N, FX) : bus(outputs(FX))
```

Where:

* `N`: Number of repetitions, minimum of 1, a constant numerical expression 
* `FX`: an arbitrary effect (N inputs and N outputs) that will be repeated

#### Test
```
si = library("signals.lib");
repeat_test = hslider("repeat:input", 0.5, -1, 1, 0.01) : si.repeat(3, *(0.5));
```

Example 1:
```
process = repeat(2, dm.zita_light) : _*.5,_*.5;
```

Example 2:
```
N = 4;
C = 2;
fx(i) = i+1, par(j, C, @(i*5000));
process = 0, si.bus(C) : repeat(N, fx) : !, par(i, C, _*.2/N);
```

#### References

* [https://github.com/orlarey/presentation-compilateur-faust/blob/master/slides.pdf](https://github.com/orlarey/presentation-compilateur-faust/blob/master/slides.pdf)

----

### `(si.)smoo`

Smoothing function based on `smooth` ideal to smooth UI signals
(sliders, etc.) down. Approximately, this is a 7 Hz one-pole
low-pass considering the coefficient calculation:
   exp(-2pi*CF/SR).

`smoo` is a standard Faust function.

#### Usage

```
hslider(...) : smoo;
```

#### Test
```
si = library("signals.lib");
smoo_test = hslider("smoo:input", 0.5, -1, 1, 0.01) : si.smoo;
```

----

### `(si.)polySmooth`

A smoothing function based on `smooth` that doesn't smooth when a
trigger signal is given. This is very useful when making
polyphonic synthesizer to make sure that the value of the parameter
is the right one when the note is started.

#### Usage

```
hslider(...) : polySmooth(g,s,d) : _
```

Where:

* `g`: the gate/trigger signal used when making polyphonic synths
* `s`: the smoothness (see `smooth`)
* `d`: the number of samples to wait before the signal start being
    smoothed after `g` switched to 1

#### Test
```
si = library("signals.lib");
polySmooth_test = hslider("polySmooth:input", 0.5, -1, 1, 0.01)
  : si.polySmooth(button("polySmooth:gate"), 0.999, 32);
```

----

### `(si.)smoothAndH`

A smoothing function based on `smooth` that holds its output
signal when a trigger is sent to it. This feature is convenient
when implementing polyphonic instruments to prevent some
smoothed parameter to change when a note-off event is sent.

#### Usage

```
hslider(...) : smoothAndH(g,s) : _
```

Where:

* `g`: the hold signal (0 for hold, 1 for bypass)
* `s`: the smoothness (see `smooth`)

#### Test
```
si = library("signals.lib");
smoothAndH_test = hslider("smoothAndH:input", 0.5, -1, 1, 0.01)
  : si.smoothAndH(button("smoothAndH:hold"), 0.999);
```

----

### `(si.)bsmooth`

Block smooth linear interpolation during a block of samples (given by the `ma.BS` value).

#### Usage

```
hslider(...) : bsmooth : _
```

#### Test
```
si = library("signals.lib");
bsmooth_test = hslider("bsmooth:input", 0.5, -1, 1, 0.01) : si.bsmooth;
```

----

### `(si.)dot`

Dot product for two vectors of size N.

#### Usage

```
bus(N), bus(N) : dot(N) : _
```

Where:

* `N`: size of the vectors (int, must be known at compile time)

#### Test
```
si = library("signals.lib");
os = library("oscillators.lib");
dot_test = (
    os.tosc(100), os.tosc(200), os.tosc(300),
    os.tosc(400), os.tosc(500), os.tosc(600)
) : si.dot(3);
```

----

### `(si.)smooth`

Exponential smoothing by a unity-dc-gain one-pole lowpass.
`smooth` is a standard Faust function. The input is typically a control
signal (`hslider(...) : smooth(s)`). The pole `s` is usually computed
from a smoothing time constant `tau` in seconds with `ba.tau2pole(tau)`
(see the example).

#### Usage

```
_ : smooth(s) : _
```

Where:

* `s`: smoothness between 0 and 1. s=0 for no smoothing, s=0.999 is "very smooth",
s>1 is unstable, and s=1 yields the zero signal for all inputs.
The exponential time-constant is approximately 1/(1-s) samples, when s is close to
(but less than) 1.

#### Example

```
_ : smooth(ba.tau2pole(tau)) : _   // tau: smoothing time constant in seconds
```

#### Test
```
si = library("signals.lib");
ba = library("basics.lib");
ma = library("maths.lib");
no = library("noises.lib");
smooth_test = hslider("smooth:input", 0.5, -1, 1, 0.01) : si.smooth(0.9);
smooth_slider_test = no.noise : si.smooth(hslider("smooth:s", 0.999, 0, 0.9999, 0.0001));
smooth_modulated_test = no.noise : si.smooth(1 - 0.1*pow(0.001, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
smooth_jump_test = no.noise : si.smooth(1 - 0.1*pow(0.001, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
```

#### References

* [https://ccrma.stanford.edu/~jos/mdft/Convolution_Example_2_ADSR.html](https://ccrma.stanford.edu/~jos/mdft/Convolution_Example_2_ADSR.html)
* [https://ccrma.stanford.edu/~jos/aspf/Appendix_B_Inspecting_Assembly.html](https://ccrma.stanford.edu/~jos/aspf/Appendix_B_Inspecting_Assembly.html)

----

### `(si.)smoothq`

Smoothing with continuously variable curves from Exponential to Linear, with a constant time.

#### Usage

```
_ : smoothq(time, q) : _;
```

Where:

* `time`: seconds to reach target
* `q`: curve shape (between 0..1, 0 is Exponential, 1 is Linear)

#### Test
```
si = library("signals.lib");
ba = library("basics.lib");
ma = library("maths.lib");
no = library("noises.lib");
smoothq_test = hslider("smoothq:input", 0.5, -1, 1, 0.01) : si.smoothq(0.25, 0.5);
smoothq_linear_test = select2(ba.period(2*P) < P, -1, 1) : si.smoothq(0.25, 1)
with { P = int(ma.SR/4); };
smoothq_slider_test = no.noise : ba.sAndH(ba.period(Q) == 0) : si.smoothq(hslider("smoothq:time", 0.25, 0.001, 1, 0.001), hslider("smoothq:q", 0.5, 0, 1, 0.01)) with { Q = int(ma.SR/30); };
smoothq_modulated_test = no.noise : ba.sAndH(ba.period(Q) == 0) : si.smoothq(0.001*pow(1000, tri), 0.5) with { Q = int(ma.SR/30); P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
smoothq_jump_test = no.noise : ba.sAndH(ba.period(Q) == 0) : si.smoothq(0.001*pow(1000, sq), 0.5) with { Q = int(ma.SR/30); P = int(ma.SR/10); sq = ba.period(2*P) < P; };
```

----

### `(si.)cbus`

N parallel cables for complex signals.
`cbus` is a standard Faust function.

#### Usage

```
cbus(N)
cbus(4) : (r0,i0), (r1,i1), (r2,i2), (r3,i3)
```

Where:

* `N`: is an integer known at compile time that indicates the number of parallel cables.
* each complex number is represented by two real signals as (real,imag)

#### Test
```
si = library("signals.lib");
os = library("oscillators.lib");
cbus_test = (
    os.tosc(100), os.tosc(150),
    os.tosc(200), os.tosc(250)
) : si.cbus(2);
```

----

### `(si.)cmul`

Multiply two complex signals pointwise.
`cmul` is a standard Faust function.
Each complex number is represented by two real signals as (real,imag):
the inputs `(r1,i1)` are the real and imaginary parts of signal 1.

#### Usage

```
(r1,i1) : cmul(r2,i2) : (_,_)
```

Where:

* `r2`, `i2`: real and imaginary parts of signal 2

#### Test
```
si = library("signals.lib");
os = library("oscillators.lib");
cmul_test = si.cmul(
    os.tosc(110), os.tosc(220),
    os.tosc(330), os.tosc(440)
);
```

----

### `(si.)cconj`

Complex conjugation of a (complex) signal.
`cconj` is a standard Faust function.

#### Usage

```
(r1,i1) : cconj : (_,_)
```

Where:

* Each complex number is represented by two real signals as (real,imag), so
- `(r1,i1)` = real and imaginary parts of the input signal
- `(r1,-i1)` = real and imaginary parts of the output signal

#### Test
```
si = library("signals.lib");
os = library("oscillators.lib");
cconj_test = (os.tosc(210), os.tosc(310)) : si.cconj;
```

----

### `(si.)onePoleSwitching`

One pole filter with independent attack and release times.

#### Usage

```
_ : onePoleSwitching(att,rel) : _
```

Where:

* `att`: the attack tau time constant in second
* `rel`: the release tau time constant in second

#### Test
```
si = library("signals.lib");
ba = library("basics.lib");
ma = library("maths.lib");
no = library("noises.lib");
onePoleSwitching_test = hslider("onePoleSwitching:input", 0.5, -1, 1, 0.01)
  : si.onePoleSwitching(0.05, 0.2);
onePoleSwitching_slider_test = no.noise : si.onePoleSwitching(hslider("onePoleSwitching:att", 0.05, 0.001, 1, 0.001), hslider("onePoleSwitching:rel", 0.2, 0.001, 1, 0.001));
onePoleSwitching_modulated_test = no.noise : si.onePoleSwitching(0.001*pow(1000, tri), 0.001*pow(1000, 1 - tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
onePoleSwitching_jump_test = no.noise : si.onePoleSwitching(0.001*pow(1000, sq), 0.001*pow(1000, 1 - sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
```

----

### `(si.)lag_ud`

Lag filter with separate times for the up (attack) and down (release)
directions. Alias of `onePoleSwitching`, kept for backward compatibility.

#### Usage

```
_ : lag_ud(up,dn) : _
```

Where:

* `up`: the attack tau time constant in second
* `dn`: the release tau time constant in second

#### Test
```
si = library("signals.lib");
lag_ud_test = hslider("lag_ud:input", 0.5, -1, 1, 0.01) : si.lag_ud(0.05, 0.2);
```

----

### `(si.)rev`

Reverse the input signal by blocks of n>0 samples. `rev(1)` is the indentity
function. `rev(n)` has a latency of `n-1` samples.

#### Usage

```
_ : rev(n) : _
```

Where:

* `n`: the block size in samples

#### Test
```
si = library("signals.lib");
os = library("oscillators.lib");
rev_test = os.tosc(440) : si.rev(32);
```

----

### `(si.)vecOp`


This function is a generalisation of Faust's iterators such as `prod` and
`sum`, and it allows to perform operations on an arbitrary number of
vectors, provided that they all have the same length. Unlike Faust's
iterators `prod` and `sum` where the vector size is equal to one and the 
vector space dimension must be specified by the user, this function will 
infer the vector space dimension and vector size based on the vectors list 
that we provide.

The outputs of the function are equal to the vector size, whereas the
number of inputs is dependent on whether the elements of the vectors
provided expect an incoming signal themselves or not. We will see a
clarifying example later; in general, the number of total inputs will
be the sum of the inputs in each input vector.

Note that we must provide a list of at least two vectors, each with a size 
that is greater or equal to one.

#### Usage

```
bus(inputs(vectorsList)) : vecOp(vectorsList, op) : bus(outputs(ba.take(1, vectorsList)))
```

Where:

* `vectorsList`: is a list of vectors
* `op`: is a two-input, one-output operator

#### Test
```
si = library("signals.lib");
vecOp_test = si.vecOp((v0, v1), +)
with {
    v0 = (hslider("vecOp:v0_0", 0.1, -1, 1, 0.01), hslider("vecOp:v0_1", 0.2, -1, 1, 0.01));
    v1 = (hslider("vecOp:v1_0", 0.3, -1, 1, 0.01), hslider("vecOp:v1_1", 0.4, -1, 1, 0.01));
};
```

For example, consider the following vectors lists:

     v0 = (0 , 1 , 2 , 3);
     v1 = (4 , 5 , 6 , 7);
     v2 = (8 , 9 , 10 , 11);
     v3 = (12 , 13 , 14 , 15);
     v4 = (+(16) , _ , 18 , *(19));
     vv = (v0 , v1 , v2 , v3);

Although Faust has limitations for list processing, these vectors can be
combined or processed individually.

If we do:

     process = vecOp(v0, +);

the function will deduce a vector space of dimension equal to four and 
a vector length equal to one. Note that this is equivalent to writing:

     process = v0 : sum(i, 4, _);

Similarly, we can write:

     process = vecOp((v0 , v1), *) :> _;

and we have a dimension-two space and length-four vectors. This is the dot 
product between vectors v0 and v1, which is equivalent to writing:

     process = v0 , v1 : dot(4);

The examples above have no inputs, as none of the elements of the vectors
expect inputs. On the other hand, we can write:

     process = vecOp((v4 , v4), +);

and the function will have six inputs and four outputs, as each vector
has three of the four elements expecting an input, times two, as the two
input vectors are identical.

Finally, we can write:

     process = vecOp(vv, &);

to perform the bitwise AND on all the elements at the same position in 
each vector, having dimension equal to the vector length equal to four.

Or even:

     process = vecOp((vv , vv), &);

which gives us a dimension equal to two, and a vector size equal to sixteen.

For a more practical use-case, this is how we can implement a time-invariant
feedback delay network with Hadamard matrix:

     N = 4;
     normalisation = 1.0 / sqrt(N);
     coeffVec = par(i, N, .99 * normalisation);
     delVec = par(i, N, (i + 1) * 3);
     process = vecOp((si.bus(N) , si.bus(N)), +) ~ 
         vecOp((vecOp((ro.hadamard(N) , coeffVec), *) , delVec), @);


----

### `(si.)bpar`

Balanced `par` where the repeated expression doesn't depend on a variable.
The built-in `par` is implemented as an unbalanced tree, and also has
to substitute the variable into the repeated expression, which is expensive
even when the variable doesn't appear. This version is implemented as a
balanced tree (which allows node reuse during tree traversal) and also
doesn't search for the variable. This can be much faster than `par` to compile.

#### Usage

```
bus(N * inputs(f)) : bpar(N, f) : bus(N * outputs(f))
```

Where:

* `N`: number of repetitions, minimum 1, a constant numerical expression
* `f`: an arbitrary expression

#### Test
```
si = library("signals.lib");
os = library("oscillators.lib");
bpar_test = (os.tosc(120), os.tosc(240), os.tosc(360)) : si.bpar(3, *(0.5));
```

Example:
```
// square each of 4000 inputs
process = si.bpar(4000, (_ <: _, _ : *));
```


----

### `(si.)bsum`

Balanced `sum`, see `si.bpar`.

#### Usage

```
bus(N * inputs(f)) : bsum(N, f) : _
```

Where:

* `N`: number of repetitions, minimum 1, a constant numerical expression
* `f`: an arbitrary expression with 1 output.

#### Test
```
si = library("signals.lib");
os = library("oscillators.lib");
bsum_test = (os.tosc(100), os.tosc(200), os.tosc(300)) : si.bsum(3, *(0.5));
```

Example:
```
// square each of 1000 inputs and add the results
process = si.bsum(1000, (_ <: _, _ : *));
```

----

### `(si.)bprod`

Balanced `prod`, see `si.bpar`.

#### Usage

```
bus(N * inputs(f)) : bprod(N, f) : _
```

Where:

* `N`: number of repetitions, minimum 1, a constant numerical expression
* `f`: an arbitrary expression with 1 output.

#### Test
```
si = library("signals.lib");
bprod_test = (
    hslider("bprod:x0", 0.5, 0, 2, 0.01),
    hslider("bprod:x1", 0.8, 0, 2, 0.01)
) : si.bprod(2, _);
```

Example:
```
// Add 8000 consecutive inputs (in pairs) and multiply the results
process = si.bprod(4000, +);
```

----

### `(si.)cumsum`

Cumulative sum of `N` signals: output `k` is the sum of inputs `0` to `k`.
The inputs need not sum to 1; for a cumulative distribution, normalize them
first (`si.normalizeL1`).

#### Usage

```
bus(N) : cumsum(N) : bus(N)
```

Where:

* `N`: number of signals (int, known at compile time, at least 1)

#### Test
```
si = library("signals.lib");
cumsum_test = (0.1, 0.2, 0.3, 0.4) : si.cumsum(4);
```

----

### `(si.)normalizeL1`, `(si.)normalizeL2`

Scale `N` signals by a common factor so that their L1 norm (sum of absolute
values, `normalizeL1`) or L2 norm (square root of the sum of squares,
`normalizeL2`) is 1. For non-negative inputs, `normalizeL1` turns weights into
probabilities; `normalizeL2` turns gains into equal-power gains. The output is
not finite when all the inputs are 0.

#### Usage

```
bus(N) : normalizeL1(N) : bus(N)
bus(N) : normalizeL2(N) : bus(N)
```

Where:

* `N`: number of signals (int, known at compile time)

#### Test
```
si = library("signals.lib");
normalizeL1_test = (0.1, -0.2, 0.4) : si.normalizeL1(3);
normalizeL2_test = (0.1, -0.2, 0.4) : si.normalizeL2(3);
```

----

### `(si.)softmax`

Softmax of `N` signals: `exp(x_k/temp)` normalized to sum to 1, which turns
arbitrary scores (logits) into probabilities. A high temperature flattens the
distribution toward uniform; a low one sharpens it toward the largest input.
The maximum is subtracted before `exp`, so the output is finite for any
finite input.

#### Usage

```
bus(N) : softmax(N, temp) : bus(N)
```

Where:

* `N`: number of signals (int, known at compile time)
* `temp`: temperature, greater than 0

#### Test
```
si = library("signals.lib");
ba = library("basics.lib");
ma = library("maths.lib");
softmax_test = (-0.1, 0.2, 0.3, -0.2) : si.softmax(4, 0.5);
softmax_slider_test = (-0.1, 0.2, 0.3, -0.2) : si.softmax(4, hslider("softmax:temp", 0.5, 0.01, 10, 0.01));
softmax_modulated_test = (-0.1, 0.2, 0.3, -0.2) : si.softmax(4, 0.01 + tri) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
```

#### References

* [https://en.wikipedia.org/wiki/Softmax_function](https://en.wikipedia.org/wiki/Softmax_function)
