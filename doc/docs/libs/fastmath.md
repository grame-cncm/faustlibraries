#  fastmath.lib 

Fast mathematical functions written in Faust. Its official prefix is `fa`.

This library provides approximations of `exp`, `log`, `pow`, `sin`, `cos`,
`tan` and `tanh` built only on the primitives that every backend implements
natively (arithmetic, comparisons, `select2`, `rint`, `min`, `max`, `abs`,
`sqrt`, integer casts and `rdtable`): no foreign function and no call of the
C library. They are meant for the computations made at every sample, which
Faust cannot hoist out of the loop: a waveshaper, a modulated filter, a
compressor's gain computer. Constant and control-rate arguments gain nothing,
since Faust computes them once; keep the exact functions there.

Where they pay depends on the backend:

* WebAssembly (the Faust IDE, faustwasm), where every math function is a call
  into JavaScript: 7x to 25x on the exponentials, 8x to 11x on `fsin`,
  `fcos`, `ftan`, `ftanh`, 2.3x to 5x on the logarithms and `fpow`;
* C++ on a desktop, where the C library costs 1 to 2 ns: 6x to 8x in a loop
  that the C++ compiler can then vectorize, 1.4x to 2.2x in a scalar loop for
  the exponentials and the trigonometric functions, nothing in a loop
  dominated by a recursion; the logarithms and `fpow` are slower there (0.3x
  to 0.4x): see their doc blocks;
* the interpreter, which pays an operation per instruction: they are 2.4x to
  15x slower, keep the C library there.

These figures, and those of the doc blocks, were measured in single
precision on an Apple M5 (Apple clang 21, Node 22). In double precision the
polynomials are longer and a NEON vector holds two values: in C++, 1.2x to
2.9x in a vectorized loop and 0.9x to 1.6x in a scalar one for the
exponentials, the trigonometric functions and `ftanh`, 0.2x to 0.5x for the
logarithms.

The names of the C functions (`exp`, `sin`...) are keywords of the language:
the functions of this library are named `fexp`, `fsin`... Two tiers: the
`fast` one (no suffix) is within a few ulps of the C library in single
precision and about 1e-16 in double precision, with coefficients of its own
for each precision; the `faster` one (suffix `_faster`) trades accuracy
(about 1e-4) for fewer operations, in every precision. The measured errors
and the domain of each function are in its doc block.

The Fast Math library is organized into 4 sections:

* [Exponentials](#exponentials)
* [Logarithms and powers](#logarithms-and-powers)
* [Trigonometric functions](#trigonometric-functions)
* [Hyperbolic tangent](#hyperbolic-tangent)

#### How

Faust has no primitive that reads or builds the bits of a float, the core of
the C fast-math libraries. 2^n comes from a table of the powers of two (254
entries in single precision, 2046 in double), and the exponent of `x` from a
ladder of comparisons, which makes the logarithms slower than the
exponentials. The polynomials are minimax fits on the reduced ranges,
evaluated by Horner's scheme; `scripts/fit_fastmath.py` computes them and
prints their errors. The range reductions are protected from the
reassociations of the Faust normalizer by `min(ma.MAX)`, an identity it does
not see through, and squares are written `x * min(x, ma.MAX)`: the normalizer
turns `x * x` into `x^2`, which the WebAssembly backend of older compilers
calls as `Math.pow`.

#### References

* [https://github.com/grame-cncm/faustlibraries/blob/master/fastmath.lib](https://github.com/grame-cncm/faustlibraries/blob/master/fastmath.lib)
* `scripts/fit_fastmath.py` (the coefficients) and `scripts/fastmath_accuracy.py`
  (the measured errors)

## Exponentials

`fexp2`, `fexp`, `fexp10` and `fdb2linear`, and their `_faster` variants. 2^x
is 2^n, from a table, times 2^f, a polynomial of f = x - rint(x); the
argument is clamped to the range of the normal floats, so that the result
saturates at the smallest and the largest normal float instead of an overflow
or a denormal. The others scale their argument first, which makes their
relative error grow with it: the product rounds to the precision of the
argument.

----

### `(fa.)fexp2`

2 raised to the power `x`, computed in Faust: a fast replacement of `2^x`.

The result saturates at the smallest normal float (2^-126 in single
precision, 2^-1022 in double) below and at 2^127 (2^1023) above. A NaN
gives a meaningless result. The index into the table of 2^n is also bounded
by a comparison of `x`, false for a NaN, so that a NaN does not become an
invalid index: a compiler whose WebAssembly conversion to an integer traps
would stop the module (`fexp2_nan_test`). The compiler removes this
comparison where it proves `x` bounded. The same holds for every function
built on `fexp2`. Measured maximum relative error: 1.6e-7 in single
precision, 2.2e-16 in double (x from -125 to 127). About 2.8x faster than
`2^x` in a C++ loop that it lets the compiler vectorize, 1.4x in a scalar
loop, 24x in WebAssembly.

#### Usage

```
fexp2(x) : _
```

Where:

* `x`: the exponent

#### Test
```
fa = library("fastmath.lib");
ba = library("basics.lib");
ma = library("maths.lib");
fexp2_test = fa.fexp2(3.3);
fexp2_slider_test = par(i, 6, fa.fexp2(hslider("fexp2:x%i", ba.take(i+1, X), -20, 20, 0.001))) with { X = (-20.0, -0.5, 0.0, 0.3, 10.5, 20.0); };
fexp2_modulated_test = fa.fexp2(40*tri - 20) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
fexp2_nan_test = select2(y < 1e6, 0.0, y) with { i = ba.time % 4; y = fa.fexp2(select2(i == 3, 4*i - 6, (i - 3) * (ma.MAX * 2))); };
```

----

### `(fa.)fexp2_faster`

2 raised to the power `x`, with a polynomial of degree 3: fewer operations
than `fexp2`, for a relative error of about 1e-4 in every precision
(measured: 1.0e-4 in both precisions). It saturates as `fexp2` does.

#### Usage

```
fexp2_faster(x) : _
```

Where:

* `x`: the exponent

#### Test
```
fa = library("fastmath.lib");
ba = library("basics.lib");
ma = library("maths.lib");
fexp2_faster_test = fa.fexp2_faster(3.3);
fexp2_faster_slider_test = par(i, 6, fa.fexp2_faster(hslider("fexp2_faster:x%i", ba.take(i+1, X), -20, 20, 0.001))) with { X = (-20.0, -0.5, 0.0, 0.3, 10.5, 20.0); };
fexp2_faster_modulated_test = fa.fexp2_faster(40*tri - 20) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
```

----

### `(fa.)fexp`

e raised to the power `x`, computed in Faust: a fast replacement of `exp`.

It computes `fexp2(x / ln 2)`. The result saturates below about -87.3 and
above 88.0 in single precision (-708.4 and 709.1 in double). Measured maximum
relative error: 3.8e-6 in single precision, 6.2e-15 in double, for |x| up to
80; it grows with `|x|`, the rounding of `x / ln 2` being multiplied by it.
About 2.8x faster than `exp` in a C++ loop that it lets the compiler
vectorize, 1.6x in a scalar loop, 7x in WebAssembly.

#### Usage

```
fexp(x) : _
```

Where:

* `x`: the exponent

#### Test
```
fa = library("fastmath.lib");
ba = library("basics.lib");
ma = library("maths.lib");
fexp_test = fa.fexp(2.3);
fexp_slider_test = par(i, 6, fa.fexp(hslider("fexp:x%i", ba.take(i+1, X), -14, 14, 0.001))) with { X = (-14.0, -1.0, 0.0, 0.5, 7.3, 14.0); };
fexp_modulated_test = fa.fexp(28*tri - 14) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
```

----

### `(fa.)fexp_faster`

e raised to the power `x`, built on `fexp2_faster`: relative error about 1e-4
(measured: 1.0e-4 in both precisions).

#### Usage

```
fexp_faster(x) : _
```

Where:

* `x`: the exponent

#### Test
```
fa = library("fastmath.lib");
ba = library("basics.lib");
ma = library("maths.lib");
fexp_faster_test = fa.fexp_faster(2.3);
fexp_faster_slider_test = par(i, 6, fa.fexp_faster(hslider("fexp_faster:x%i", ba.take(i+1, X), -14, 14, 0.001))) with { X = (-14.0, -1.0, 0.0, 0.5, 7.3, 14.0); };
fexp_faster_modulated_test = fa.fexp_faster(28*tri - 14) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
```

----

### `(fa.)fexp10`

10 raised to the power `x`, computed in Faust: a fast replacement of `10^x`.

It computes `fexp2(x * log2(10))`. Measured maximum relative error: 4.6e-6 in
single precision, 9.3e-15 in double, for |x| up to 37.

#### Usage

```
fexp10(x) : _
```

Where:

* `x`: the exponent

#### Test
```
fa = library("fastmath.lib");
ba = library("basics.lib");
ma = library("maths.lib");
fexp10_test = fa.fexp10(1.3);
fexp10_slider_test = par(i, 6, fa.fexp10(hslider("fexp10:x%i", ba.take(i+1, X), -6, 6, 0.001))) with { X = (-6.0, -0.5, 0.0, 0.3, 3.1, 6.0); };
fexp10_modulated_test = fa.fexp10(12*tri - 6) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
```

----

### `(fa.)fdb2linear`

Convert a level in dB to a linear gain: a fast replacement of `ba.db2linear`
(`pow(10, l/20)`), for a gain computed at every sample, as in a compressor.

It computes `fexp2(l * log2(10)/20)`. Measured maximum relative error: 1.6e-6
in single precision, 4.4e-15 in double, from -300 to +300 dB. About 2.7x
faster than `ba.db2linear` in a C++ loop that it lets the compiler vectorize,
1.5x in a scalar loop, 21x in WebAssembly.

#### Usage

```
fdb2linear(l) : _
```

Where:

* `l`: the level in dB

#### Test
```
fa = library("fastmath.lib");
ba = library("basics.lib");
ma = library("maths.lib");
fdb2linear_test = fa.fdb2linear(-6.0);
fdb2linear_slider_test = par(i, 6, fa.fdb2linear(hslider("fdb2linear:l%i", ba.take(i+1, X), -120, 24, 0.01))) with { X = (-120.0, -60.0, -6.0, 0.0, 6.0, 24.0); };
fdb2linear_modulated_test = fa.fdb2linear(144*tri - 120) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
```

----

### `(fa.)fdb2linear_faster`

Convert a level in dB to a linear gain, built on `fexp2_faster`: relative
error about 1e-4, 0.001 dB (measured: 1.0e-4 in both precisions).

#### Usage

```
fdb2linear_faster(l) : _
```

Where:

* `l`: the level in dB

#### Test
```
fa = library("fastmath.lib");
ba = library("basics.lib");
ma = library("maths.lib");
fdb2linear_faster_test = fa.fdb2linear_faster(-6.0);
fdb2linear_faster_slider_test = par(i, 6, fa.fdb2linear_faster(hslider("fdb2linear_faster:l%i", ba.take(i+1, X), -120, 24, 0.01))) with { X = (-120.0, -60.0, -6.0, 0.0, 6.0, 24.0); };
fdb2linear_faster_modulated_test = fa.fdb2linear_faster(144*tri - 120) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
```

## Logarithms and powers

`flog2`, `flog`, `flog10`, `flinear2db`, their `_faster` and `_sqrt`
variants, and `fpow`. The exponent of `x` comes from a ladder of comparisons
(x is scaled by 2^126 when below 1, then 2^64, 2^32 ... 2^1 are divided out
where they fit; 2^1022 and 2^512 ... 2^1 in double precision): branchless and
exact, but 8 to 11 comparisons, selections and multiplications. The
logarithms therefore gain where the C library is expensive (WebAssembly 2.3x
to 3.2x, Cmajor), and are slower than it on a desktop in C++ (0.3x in a
scalar loop): see the `_sqrt` variants for a bounded domain. `x` must be
positive and normal.

----

### `(fa.)flog2`

Base-2 logarithm of `x`, computed in Faust: a fast replacement of `log2`.

The mantissa is in [sqrt(1/2), sqrt(2)); its logarithm is a polynomial of `m
- 1` in single precision, of `t^2`, `t = (m - 1)/(m + 1)`, in double.
Measured maximum absolute error: 1.9e-7 in single precision, 2.2e-16 in
double, over the whole range of the floats. `x` must be positive and normal
(from 2^-126 in single precision, 2^-1022 in double).

#### Usage

```
flog2(x) : _
```

Where:

* `x`: a positive value

#### Test
```
fa = library("fastmath.lib");
ba = library("basics.lib");
ma = library("maths.lib");
flog2_test = fa.flog2(7.3);
flog2_slider_test = par(i, 6, fa.flog2(hslider("flog2:x%i", ba.take(i+1, X), 1e-6, 1000, 1e-6))) with { X = (1e-6, 0.01, 0.5, 1.0, 7.3, 1000.0); };
flog2_modulated_test = fa.flog2(10.0^(9*tri - 6)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
```

----

### `(fa.)flog2_faster`

Base-2 logarithm of `x`, with a polynomial of degree 5 for the mantissa:
absolute error about 1.5e-5 in every precision (measured: 1.5e-5 in both
precisions). The ladder is that of `flog2`.

#### Usage

```
flog2_faster(x) : _
```

Where:

* `x`: a positive value

#### Test
```
fa = library("fastmath.lib");
ba = library("basics.lib");
ma = library("maths.lib");
flog2_faster_test = fa.flog2_faster(7.3);
flog2_faster_slider_test = par(i, 6, fa.flog2_faster(hslider("flog2_faster:x%i", ba.take(i+1, X), 1e-6, 1000, 1e-6))) with { X = (1e-6, 0.01, 0.5, 1.0, 7.3, 1000.0); };
flog2_faster_modulated_test = fa.flog2_faster(10.0^(9*tri - 6)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
```

----

### `(fa.)flog2_sqrt`

Base-2 logarithm of `x` in [2^-32, 2^32] (about -192 dB to +192 dB), without
the ladder: six square roots bring `x` into [sqrt(1/2), sqrt(2)], and
`log2(x) = 64 log2(x^(1/64))`. The factor 64 multiplies the error of the
polynomial and of the roots (measured maximum absolute error: 1.2e-5 in
single precision, 2.1e-14 in double); in exchange it costs about half of
`flog2`, and gains 1.9x on the C library in a C++ loop that it lets the
compiler vectorize, 5x in WebAssembly.

#### Usage

```
flog2_sqrt(x) : _
```

Where:

* `x`: a value in [2^-32, 2^32]

#### Test
```
fa = library("fastmath.lib");
ba = library("basics.lib");
ma = library("maths.lib");
flog2_sqrt_test = fa.flog2_sqrt(7.3);
flog2_sqrt_slider_test = par(i, 6, fa.flog2_sqrt(hslider("flog2_sqrt:x%i", ba.take(i+1, X), 1e-9, 1e9, 1e-9))) with { X = (1e-9, 0.001, 0.5, 1.0, 100.0, 1e9); };
flog2_sqrt_modulated_test = fa.flog2_sqrt(10.0^(18*tri - 9)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
```

----

### `(fa.)flog`

Natural logarithm of `x`, computed in Faust: a fast replacement of `log`.

It computes `ln 2 * flog2(x)`. Measured maximum absolute error: 4.1e-6 in
single precision, 1.4e-14 in double, an ulp of the result at the ends of the
range of the floats (ln 2^-125 = -86.6).

#### Usage

```
flog(x) : _
```

Where:

* `x`: a positive value

#### Test
```
fa = library("fastmath.lib");
ba = library("basics.lib");
ma = library("maths.lib");
flog_test = fa.flog(7.3);
flog_slider_test = par(i, 6, fa.flog(hslider("flog:x%i", ba.take(i+1, X), 1e-6, 1000, 1e-6))) with { X = (1e-6, 0.01, 0.5, 1.0, 7.3, 1000.0); };
flog_modulated_test = fa.flog(10.0^(9*tri - 6)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
```

----

### `(fa.)flog10`

Base-10 logarithm of `x`, computed in Faust: a fast replacement of `log10`.

It computes `log10(2) * flog2(x)`. Measured maximum absolute error: 3.7e-6 in
single precision, 7.1e-15 in double, an ulp of the result at the ends of the
range of the floats.

#### Usage

```
flog10(x) : _
```

Where:

* `x`: a positive value

#### Test
```
fa = library("fastmath.lib");
ba = library("basics.lib");
ma = library("maths.lib");
flog10_test = fa.flog10(7.3);
flog10_slider_test = par(i, 6, fa.flog10(hslider("flog10:x%i", ba.take(i+1, X), 1e-6, 1000, 1e-6))) with { X = (1e-6, 0.01, 0.5, 1.0, 7.3, 1000.0); };
flog10_modulated_test = fa.flog10(10.0^(9*tri - 6)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
```

----

### `(fa.)flinear2db`

Convert a linear gain to a level in dB: a fast replacement of `ba.linear2db`
(`20*log10(x)`), for a level computed at every sample, as in a compressor's
detector.

It computes `20 log10(2) * flog2(x)`. Measured maximum absolute error: 4.0e-5
in single precision, 1.1e-13 in double (an ulp of the result at 2^-125, -750
dB) dB. `x` must be positive and normal: unlike `ba.linear2db`, it does not
clamp 0 to the smallest float.

#### Usage

```
flinear2db(x) : _
```

Where:

* `x`: a positive linear gain

#### Test
```
fa = library("fastmath.lib");
ba = library("basics.lib");
ma = library("maths.lib");
flinear2db_test = fa.flinear2db(0.5);
flinear2db_slider_test = par(i, 6, fa.flinear2db(hslider("flinear2db:x%i", ba.take(i+1, X), 1e-6, 1000, 1e-6))) with { X = (1e-6, 0.01, 0.5, 1.0, 7.3, 1000.0); };
flinear2db_modulated_test = fa.flinear2db(10.0^(9*tri - 6)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
```

----

### `(fa.)flinear2db_faster`

Convert a linear gain to a level in dB, built on `flog2_faster`: absolute
error about 1e-4 dB (measured: 1.3e-4 in single precision, 8.8e-5 in double
dB).

#### Usage

```
flinear2db_faster(x) : _
```

Where:

* `x`: a positive linear gain

#### Test
```
fa = library("fastmath.lib");
ba = library("basics.lib");
ma = library("maths.lib");
flinear2db_faster_test = fa.flinear2db_faster(0.5);
flinear2db_faster_slider_test = par(i, 6, fa.flinear2db_faster(hslider("flinear2db_faster:x%i", ba.take(i+1, X), 1e-6, 1000, 1e-6))) with { X = (1e-6, 0.01, 0.5, 1.0, 7.3, 1000.0); };
flinear2db_faster_modulated_test = fa.flinear2db_faster(10.0^(9*tri - 6)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
```

----

### `(fa.)flinear2db_sqrt`

Convert a linear gain in [2^-32, 2^32] to a level in dB (about -192 dB to
+192 dB), built on `flog2_sqrt`: measured maximum absolute error 7.4e-5 in
single precision, 1.4e-13 in double dB, at about half the cost of
`flinear2db`.

#### Usage

```
flinear2db_sqrt(x) : _
```

Where:

* `x`: a linear gain in [2^-32, 2^32]

#### Test
```
fa = library("fastmath.lib");
ba = library("basics.lib");
ma = library("maths.lib");
flinear2db_sqrt_test = fa.flinear2db_sqrt(0.5);
flinear2db_sqrt_slider_test = par(i, 6, fa.flinear2db_sqrt(hslider("flinear2db_sqrt:x%i", ba.take(i+1, X), 1e-9, 1e9, 1e-9))) with { X = (1e-9, 0.001, 0.5, 1.0, 100.0, 1e9); };
flinear2db_sqrt_modulated_test = fa.flinear2db_sqrt(10.0^(18*tri - 9)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
```

----

### `(fa.)fpow`

`x` raised to the power `y`, `x` positive, computed in Faust: a fast
replacement of `pow(x, y)` when both vary at every sample.

It computes `fexp2(y * flog2(x))`. Measured maximum relative error: 6.7e-7 in
single precision, 6.5e-16 in double, for x from 2^-10 to 2^10 and y = 2.5. A
constant integer exponent needs none of it: Faust expands `x^3` into
multiplications. Like the logarithms, it gains in WebAssembly (5x) and loses
on a desktop in C++.

#### Usage

```
fpow(x, y) : _
```

Where:

* `x`: a positive base
* `y`: the exponent

#### Test
```
fa = library("fastmath.lib");
ba = library("basics.lib");
ma = library("maths.lib");
fpow_test = fa.fpow(2.7, 1.3);
fpow_slider_test = par(i, 4, fa.fpow(hslider("fpow:x%i", ba.take(i+1, X), 0.001, 100, 0.001), hslider("fpow:y%i", ba.take(i+1, Y), -3, 3, 0.001))) with { X = (0.001, 0.5, 2.7, 100.0); Y = (-3.0, 0.5, 1.3, 3.0); };
fpow_modulated_test = fa.fpow(10.0^(4*tri - 2), 6*tri - 3) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
```

## Trigonometric functions

`fsin2pi` and `fcos2pi` (in turns), `fsin` and `fcos` (in radians), `ftanpi`
and `ftan`, and the `_faster` variants of the sines. The argument in turns is
reduced by `x - rint(x)`, which is exact, and folded into a quarter of a
period, where the sine is an odd polynomial: in turns, the error does not
grow with the argument, which an oscillator's phase in turns benefits from;
in radians, the division by 2 pi rounds to the precision of the argument.

----

### `(fa.)fsin2pi`

Sine of `2*pi*x`, `x` in turns, computed in Faust: a fast replacement of
`sin(2*ma.PI*x)`, and a more accurate one for a large `x`, whose product by
`2*ma.PI` rounds.

Measured maximum absolute error: 1.5e-7 in single precision, 3.6e-16 in
double, up to 1000 turns, for any `x` with fractional bits (|x| < 2^22 turns
in single precision). About 6x faster than `sin(2*ma.PI*x)` in a C++ loop
that it lets the compiler vectorize, 1.7x in a scalar loop, 11x in
WebAssembly.

#### Usage

```
fsin2pi(x) : _
```

Where:

* `x`: the angle in turns

#### Test
```
fa = library("fastmath.lib");
ba = library("basics.lib");
ma = library("maths.lib");
fsin2pi_test = fa.fsin2pi(0.1);
fsin2pi_slider_test = par(i, 6, fa.fsin2pi(hslider("fsin2pi:x%i", ba.take(i+1, X), -1000.5, 1000.5, 0.0001))) with { X = (-1000.5, -0.75, -0.1, 0.2, 0.7, 1000.3); };
fsin2pi_modulated_test = fa.fsin2pi(200*tri - 100) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
```

----

### `(fa.)fsin2pi_faster`

Sine of `2*pi*x`, `x` in turns, with an odd polynomial of degree 5: absolute
error about 7e-5 in every precision (measured: 6.8e-5 in both precisions).

#### Usage

```
fsin2pi_faster(x) : _
```

Where:

* `x`: the angle in turns

#### Test
```
fa = library("fastmath.lib");
ba = library("basics.lib");
ma = library("maths.lib");
fsin2pi_faster_test = fa.fsin2pi_faster(0.1);
fsin2pi_faster_slider_test = par(i, 6, fa.fsin2pi_faster(hslider("fsin2pi_faster:x%i", ba.take(i+1, X), -1000.5, 1000.5, 0.0001))) with { X = (-1000.5, -0.75, -0.1, 0.2, 0.7, 1000.3); };
fsin2pi_faster_modulated_test = fa.fsin2pi_faster(200*tri - 100) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
```

----

### `(fa.)fcos2pi`

Cosine of `2*pi*x`, `x` in turns: `fsin2pi(x + 1/4)` (measured maximum
absolute error: 1.5e-7 in single precision, 3.6e-16 in double).

#### Usage

```
fcos2pi(x) : _
```

Where:

* `x`: the angle in turns

#### Test
```
fa = library("fastmath.lib");
ba = library("basics.lib");
ma = library("maths.lib");
fcos2pi_test = fa.fcos2pi(0.1);
fcos2pi_slider_test = par(i, 6, fa.fcos2pi(hslider("fcos2pi:x%i", ba.take(i+1, X), -1000.5, 1000.5, 0.0001))) with { X = (-1000.5, -0.75, -0.1, 0.2, 0.7, 1000.3); };
fcos2pi_modulated_test = fa.fcos2pi(200*tri - 100) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
```

----

### `(fa.)fsin`

Sine of `x`, `x` in radians, computed in Faust: a fast replacement of `sin`.

It computes `fsin2pi(x / (2 pi))`. Measured maximum absolute error: 2.2e-7 in
single precision, 4.4e-16 in double, for |x| up to pi; 8.8e-5 and 1.5e-13 up
to 1000; for a large `x`, the rounding of `x / (2 pi)` adds about `|x| *
2^-24` in single precision (9e-5 at 1000), which `fsin2pi` avoids. About 7.7x
faster than `sin` in a C++ loop that it lets the compiler vectorize, 2.2x in
a scalar loop, 11x in WebAssembly.

#### Usage

```
fsin(x) : _
```

Where:

* `x`: the angle in radians

#### Test
```
fa = library("fastmath.lib");
ba = library("basics.lib");
ma = library("maths.lib");
fsin_test = fa.fsin(0.7);
fsin_slider_test = par(i, 6, fa.fsin(hslider("fsin:x%i", ba.take(i+1, X), -1000, 1000, 0.001))) with { X = (-1000.0, -3.0, -0.1, 0.5, 3.0, 1000.0); };
fsin_modulated_test = fa.fsin(20*tri - 10) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
```

----

### `(fa.)fsin_faster`

Sine of `x`, `x` in radians, built on `fsin2pi_faster`: absolute error about
7e-5 (measured: 6.8e-5 in both precisions).

#### Usage

```
fsin_faster(x) : _
```

Where:

* `x`: the angle in radians

#### Test
```
fa = library("fastmath.lib");
ba = library("basics.lib");
ma = library("maths.lib");
fsin_faster_test = fa.fsin_faster(0.7);
fsin_faster_slider_test = par(i, 6, fa.fsin_faster(hslider("fsin_faster:x%i", ba.take(i+1, X), -1000, 1000, 0.001))) with { X = (-1000.0, -3.0, -0.1, 0.5, 3.0, 1000.0); };
fsin_faster_modulated_test = fa.fsin_faster(20*tri - 10) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
```

----

### `(fa.)fcos`

Cosine of `x`, `x` in radians, computed in Faust: a fast replacement of
`cos`. It computes `fcos2pi(x / (2 pi))` (measured maximum absolute error:
2.1e-7 in single precision, 3.9e-16 in double, for |x| up to pi).

#### Usage

```
fcos(x) : _
```

Where:

* `x`: the angle in radians

#### Test
```
fa = library("fastmath.lib");
ba = library("basics.lib");
ma = library("maths.lib");
fcos_test = fa.fcos(0.7);
fcos_slider_test = par(i, 6, fa.fcos(hslider("fcos:x%i", ba.take(i+1, X), -1000, 1000, 0.001))) with { X = (-1000.0, -3.0, -0.1, 0.5, 3.0, 1000.0); };
fcos_modulated_test = fa.fcos(20*tri - 10) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
```

----

### `(fa.)ftanpi`

Tangent of `pi*x`, computed in Faust: a fast replacement of `tan(ma.PI*x)`,
as in the prewarping of a bilinear filter whose cutoff is modulated,
`ftanpi(fc/ma.SR)`.

`x - rint(x)` is folded into [0, 1/4] by symmetry; there the tangent is a
rational function (single precision) or the ratio of two sines (double), and
its reciprocal beyond 1/4: one division in both cases. Measured maximum
relative error: 2.3e-7 in single precision, 6.6e-16 in double, for |x| up to
0.49. The result is infinite at `x = 1/2`.

#### Usage

```
ftanpi(x) : _
```

Where:

* `x`: the angle in half turns

#### Test
```
fa = library("fastmath.lib");
ba = library("basics.lib");
ma = library("maths.lib");
ftanpi_test = fa.ftanpi(0.1);
ftanpi_slider_test = par(i, 6, fa.ftanpi(hslider("ftanpi:x%i", ba.take(i+1, X), -0.49, 0.49, 0.0001))) with { X = (-0.49, -0.25, 0.0, 0.1, 0.3, 0.49); };
ftanpi_modulated_test = fa.ftanpi(0.98*tri - 0.49) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
```

----

### `(fa.)ftan`

Tangent of `x`, `x` in radians, computed in Faust: a fast replacement of
`tan`. It computes `ftanpi(x / pi)` (measured maximum relative error: 1.6e-6
in single precision, 2.7e-15 in double, for |x| up to 1.5 (the rounding of
x/pi grows near the poles)). About 6.6x faster than `tan` in a C++ loop that
it lets the compiler vectorize, 1.8x in a scalar loop, 8x in WebAssembly.

#### Usage

```
ftan(x) : _
```

Where:

* `x`: the angle in radians

#### Test
```
fa = library("fastmath.lib");
ba = library("basics.lib");
ma = library("maths.lib");
ftan_test = fa.ftan(0.7);
ftan_slider_test = par(i, 6, fa.ftan(hslider("ftan:x%i", ba.take(i+1, X), -1.5, 1.5, 0.001))) with { X = (-1.5, -0.7, 0.0, 0.3, 1.0, 1.5); };
ftan_modulated_test = fa.ftan(3*tri - 1.5) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
```

## Hyperbolic tangent

`ftanh` and `ftanh_faster`, for a saturation computed at every sample.

----

### `(fa.)ftanh`

Hyperbolic tangent of `x`, computed in Faust: a fast replacement of
`ma.tanh`.

In single precision, an odd rational function on [-9, 9], the argument
clamped there and the result to [-1, 1]: measured maximum absolute error
5.5e-6, not float accuracy. In double precision, an odd polynomial below 1/4
and `1 - 2/(e^(2|x|) + 1)` above: 2.2e-16. About 6.8x faster than `ma.tanh`
in a C++ loop that it lets the compiler vectorize, 2x in a scalar loop, 1.5x
on the critical path of a feedback loop, 10x in WebAssembly.

#### Usage

```
ftanh(x) : _
```

Where:

* `x`: the input

#### Test
```
fa = library("fastmath.lib");
ba = library("basics.lib");
ma = library("maths.lib");
ftanh_test = fa.ftanh(0.7);
ftanh_slider_test = par(i, 7, fa.ftanh(hslider("ftanh:x%i", ba.take(i+1, X), -20, 20, 0.001))) with { X = (-20.0, -2.0, -0.1, 0.0, 0.5, 3.0, 20.0); };
ftanh_modulated_test = fa.ftanh(10*tri - 5) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
```

----

### `(fa.)ftanh_faster`

Hyperbolic tangent of `x`, the Pade approximant `x (27 + x^2)/(27 + 9 x^2)`,
the argument clamped to [-3, 3]: absolute error about 0.024 in every
precision (measured: 0.024), a soft clipper rather than `tanh`, at the lowest
cost.

#### Usage

```
ftanh_faster(x) : _
```

Where:

* `x`: the input

#### Test
```
fa = library("fastmath.lib");
ba = library("basics.lib");
ma = library("maths.lib");
ftanh_faster_test = fa.ftanh_faster(0.7);
ftanh_faster_slider_test = par(i, 7, fa.ftanh_faster(hslider("ftanh_faster:x%i", ba.take(i+1, X), -20, 20, 0.001))) with { X = (-20.0, -2.0, -0.1, 0.0, 0.5, 3.0, 20.0); };
ftanh_faster_modulated_test = fa.ftanh_faster(10*tri - 5) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
```
