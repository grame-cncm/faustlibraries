#  routes.lib 

Routing library. Its official prefix is `ro`.

This library provides tools for managing and organizing audio and control signal
routing in Faust. It includes functions for channel mapping, splitting, merging, and
dynamic routing, as well as utilities for building multichannel processing structures.

The Routes library is organized into 1 section:

* [Functions Reference](#functions-reference)

#### References

* [https://github.com/grame-cncm/faustlibraries/blob/master/routes.lib](https://github.com/grame-cncm/faustlibraries/blob/master/routes.lib)

## Functions Reference


----

### `(ro.)cross`

Cross N signals: `(x1,x2,..,xn) -> (xn,..,x2,x1)`.
`cross` is a standard Faust function.

#### Usage

```
cross(N)
_,_,_ : cross(3) : _,_,_
```

Where:

* `N`: number of signals (int, as a constant numerical expression)

#### Test
```
ro = library("routes.lib");
os = library("oscillators.lib");
cross_test = (os.osc(200), os.osc(300), os.osc(400)) : ro.cross(3);
```

#### Note

Special case: `cross2`:

```
cross2 = _,cross(2),_;
```

----

### `(ro.)crossnn`

Cross two `bus(N)`s.

#### Usage

```
(si.bus(2*N)) : crossnn(N) : (si.bus(2*N))
```

Where:

* `N`: the number of signals in the `bus` (int, as a constant numerical expression)

#### Test
```
ro = library("routes.lib");
os = library("oscillators.lib");
crossnn_test = (os.osc(110), os.osc(220), os.osc(330), os.osc(440)) : ro.crossnn(2);
```

----

### `(ro.)crossn1`

Cross `bus(N)` and `bus(1)`.

#### Usage

```
(si.bus(N),_) : crossn1(N) : (_,si.bus(N))
```

Where:

* `N`: the number of signals in the first `bus` (int, as a constant numerical expression)

#### Test
```
ro = library("routes.lib");
os = library("oscillators.lib");
crossn1_test = (os.osc(100), os.osc(200), os.osc(300), os.osc(400)) : ro.crossn1(3);
```

----

### `(ro.)cross1n`

Cross `bus(1)` and `bus(N)`.

#### Usage

```
(_,si.bus(N)) : crossn1(N) : (si.bus(N),_)
```

Where:

* `N`: the number of signals in the second `bus` (int, as a constant numerical expression)

#### Test
```
ro = library("routes.lib");
os = library("oscillators.lib");
cross1n_test = (os.osc(150), os.osc(250), os.osc(350), os.osc(450)) : ro.cross1n(3);
```

----

### `(ro.)crossNM`

Cross `bus(N)` and `bus(M)`.

#### Usage

```
(si.bus(N),si.bus(M)) : crossNM(N,M) : (si.bus(M),si.bus(N))
```

Where:

* `N`: the number of signals in the first `bus` (int, as a constant numerical expression)
* `M`: the number of signals in the second `bus` (int, as a constant numerical expression)

#### Test
```
ro = library("routes.lib");
os = library("oscillators.lib");
crossNM_test = (os.osc(180), os.osc(280), os.osc(380), os.osc(480), os.osc(580)) : ro.crossNM(2,3);
```

----

### `(ro.)interleave`

Interleave R x C cables from column order to row order. That is, transpose the input CxR matrix, 
the first R inputs is the first row.

input : `x(0), x(1), x(2) ..., x(row*col-1)`

output: `x(0+0*row), x(0+1*row), x(0+2*row), ..., x(1+0*row), x(1+1*row), x(1+2*row), ...`



#### Usage

```
si.bus(R*C) : interleave(R,C) : si.bus(R*C)
```

Where:

* `R`: row length (int, as a constant numerical expression)
* `C`: column length (int, as a constant numerical expression)

#### Test
```
ro = library("routes.lib");
os = library("oscillators.lib");
interleave_test = (os.osc(200), os.osc(300), os.osc(400), os.osc(500)) : ro.interleave(2,2);
```

----

### `(ro.)butterfly`

Addition (first half) then substraction (second half) of interleaved signals.

#### Usage

```
si.bus(N) : butterfly(N) : si.bus(N)
```

Where:

* `N`: size of the butterfly (N is int, even and as a constant numerical expression)

#### Test
```
ro = library("routes.lib");
os = library("oscillators.lib");
butterfly_test = (os.osc(250), os.osc(350), os.osc(450), os.osc(550)) : ro.butterfly(4);
```

----

### `(ro.)hadamard`

Hadamard matrix function of size `N = 2^k`.

#### Usage

```
si.bus(N) : hadamard(N) : si.bus(N)
```

Where:

* `N`: `2^k`, size of the matrix (int, as a constant numerical expression)

#### Test
```
ro = library("routes.lib");
os = library("oscillators.lib");
hadamard_test = (os.osc(220), os.osc(330), os.osc(440), os.osc(550)) : ro.hadamard(4);
```

----

### `(ro.)recursivize`

Create a recursion from two arbitrary processors `p` and `q`.

#### Usage

```
_,_ : recursivize(p,q) : _,_

```

Where:

* `p`: the forward arbitrary processor
* `q`: the feedback arbitrary processor

#### Test
```
ro = library("routes.lib");
os = library("oscillators.lib");
recursivize_test = (os.osc(220), os.osc(330)) : ro.recursivize(*(0.5), *(0.3));
```

----

### `(ro.)bubbleSort`


Sort a set of N parallel signals in ascending order on-the-fly through
the Bubble Sort algorithm.

Mechanism: having a set of N parallel signals indexed from 0 to N - 1,
compare the first pair of signals and swap them if sig[0] > sig[1];
repeat the pair comparison for the signals sig[1] and sig[2], then again
recursively until reaching the signals sig[N - 2] and sig[N - 1]; by the end,
the largest element in the set will be placed last; repeat the process for
the remaining N - 1 signals until there is a single pair left.

Note that this implementation will always perform the worst-case
computation, O(n^2).

Even though the Bubble Sort algorithm is one of the least efficient ones,
it is a useful example of how automatic sorting can be implemented at the
signal level.

#### Usage

```
si.bus(N) : bubbleSort(N) : si.bus(N)

```

Where:

* `N`: the number of signals to be sorted (must be an int >= 0, as a constant numerical expression)

#### Test
```
ro = library("routes.lib");
bubbleSort_test = (
    hslider("bubbleSort:x0", 0.3, -1, 1, 0.01),
    hslider("bubbleSort:x1", -0.2, -1, 1, 0.01),
    hslider("bubbleSort:x2", 0.8, -1, 1, 0.01),
    hslider("bubbleSort:x3", -0.5, -1, 1, 0.01)
) : ro.bubbleSort(4);
```

#### References

* [https://en.wikipedia.org/wiki/Bubble_sort](https://en.wikipedia.org/wiki/Bubble_sort)
