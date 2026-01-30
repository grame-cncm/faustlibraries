#  reducemaps.lib 

A library providing reduce/map operations in Faust. Its official prefix is
`rm`. 

The basic idea behind _reduce_ operations is to combine several values
into a single one by repeatedly applying a binary operation. A typical
example is finding the maximum of a set of values by repeatedly applying the
binary operation `max`.

In this reducemaps library, you'll find two types of _reduce_, depending on
whether you want to reduce n consecutive samples of the same signal or a set
of n parallel signals.

#### References

* [https://github.com/grame-cncm/faustlibraries/blob/master/reducemaps.lib](https://github.com/grame-cncm/faustlibraries/blob/master/reducemaps.lib)

----

### `(rm.)parReduce`

`parReduce(op,N)` combines a set of `N` parallel signals into a single one
using a binary operation `op`.

With `parReduce`, this reduction process simultaneously occurs on each half
of the incoming signals. In other words, `parReduce(max,256)` is equivalent
to `parReduce(max,128),parReduce(max,128) : max`.

To be used with `parReduce`, binary operation `op` must be associative.
Additionally, the concept of a binary operation extends to operations
that have `2*n` inputs and `n` outputs. For example, complex signals can be
simulated using two signals for the real and imaginary parts. In
such case, a binary operation would have 4 inputs and 2 outputs.

Please note also that `parReduce` is faster than `topReduce` or `botReduce`
for large number of signals. It is therefore the recommended operation
whenever `op` is associative.

#### Usage

```
_,...,_ : parReduce(op, N) : _
```

Where:

* `op`: is a binary operation 
* `N`: is the number of incomming signals (`N>0`). We use a capital letter
here to indicate that the number of incomming signals must be constant and
known at compile time.

#### Test
```
rm = library("reducemaps.lib");
parReduce_test = (1,2,3,4) : rm.parReduce(+, 4);
```

----

### `(rm.)topReduce`

`topReduce(op,N)` involves combining a set of `N` parallel signals into a
single one using a binary operation `op`. With `topReduce`, the reduction
process starts from the top two incoming signals, down to the bottom. In
other words, `topReduce(max,256)` is equivalent to `topReduce(max,255),_ : max`.

Contrary to `parReduce`, the binary operation `op` doesn't have to be
associative here. Like with `parReduce` the concept of a binary operation can be
extended to operations that have 2*n inputs and n outputs. For example,
complex signals can be simulated using two signals representing the real and
imaginary parts. In such cases, a binary operation would have 4 inputs and 2
outputs.

#### Usage

```
 _,...,_ : topReduce(op, N) : _
```

Where:

* `op`: is a binary operation
* `N`: is the number of incomming signals (`N>0`). We use a capital letter
here to indicate that the number of incomming signals must be constant and
known at compile time.

#### Test
```
rm = library("reducemaps.lib");
topReduce_test = (1,2,3,4) : rm.topReduce(+, 4);
```

----

### `(rm.)botReduce`

`botReduce(op,N)` combines a set of `N` parallel signals into a single one
using a binary operation `op`. With `botReduce`, the reduction process starts
from the bottom two incoming signals, up to the top. In other words,
`botReduce(max,256)` is equivalent to `_,botReduce(max,255): max`.

Contrary to `parReduce`, the binary operation `op` doesn't have to be
associative here. Like with `parReduce` the concept of a binary operation can be
extended to operations that have 2*n inputs and n outputs. For example,
complex signals can be simulated using two signals representing the real and
imaginary parts. In such cases, a binary operation would have 4 inputs and 2
outputs.

#### Usage

```
 _,...,_ : botReduce(op, N) : _
```

Where:

* op: is a binary operation
* N: is the number of incomming signals (`N>0`). We use a capital letter
here to indicate that the number of incomming signals must be constant and
known at compile time.

#### Test
```
rm = library("reducemaps.lib");
botReduce_test = (1,2,3,4) : rm.botReduce(+, 4);
```

----

### `(rm.)reduce`

Reduce a block of `n` consecutive samples of the incomming signal using a
binary operation `op`. For example: `reduce(max,128)` will compute the
maximun value of each block of 128 samples. Please note that the resulting
value, while computed continuously, will be constant for the duration of a
block. A new value is only produced at the end of a block. Note also that
blocks should be of at least one sample (n>0).

#### Usage

```
_ : reduce(op, n) : _
```

Where:

* `op`: is a binary operation
* `n`: is the number of consecutive samples in a block. 

#### Test
```
rm = library("reducemaps.lib");
reduce_test = rm.reduce(max, 4, hslider("reduce:input", 0, -1, 1, 0.01));
```

----

### `(rm.)reducemap`

Like `reduce` but a `foo` function is applied to the result. From
a mathematical point of view:
`reducemap(op,foo,n)` is equivalent to `reduce(op,n):foo`
but more efficient.

#### Usage

```
_ : reducemap(op, foo, n) : _
```

Where:

* `op`: is a binary operation
* `foo`: is a function applied to the result of the reduction
* `n`: is the number of consecutive samples in a block. 

#### Test
```
rm = library("reducemaps.lib");
reducemap_test = rm.reducemap(+, /(4), 4, hslider("reducemap:input", 0, -1, 1, 0.01));
```
