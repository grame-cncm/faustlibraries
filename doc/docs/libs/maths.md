#  maths.lib 

Maths library. Its official prefix is `ma`.

This library provides mathematical functions and utilities for numerical
computations in Faust. It includes trigonometric, exponential, logarithmic, and
statistical functions, constants, and complex-number
operations used throughout Faust DSP and control code.

The Maths library is organized into 1 section:

* [Functions Reference](#functions-reference)

Some functions are implemented as Faust foreign functions of `math.h` functions
that are not part of Faust's primitives. Defines also various constants and several
utilities.

#### References

* [https://github.com/grame-cncm/faustlibraries/blob/master/maths.lib](https://github.com/grame-cncm/faustlibraries/blob/master/maths.lib)

## Functions Reference


----

### `(ma.)SR`

Current sampling rate given at init time. Constant during program execution.

#### Usage

```
SR : _
```

Where:

* `SR`: initialization-time sampling rate constant

#### Test
```
ma = library("maths.lib");
SR_test = ma.SR;
```

----

### `(ma.)T`

Current sample duration in seconds computed from the sampling rate given at init time. Constant during program execution.

#### Usage

```
T : _
```

Where:

* `T`: sample duration (`1/SR`) constant

#### Test
```
ma = library("maths.lib");
T_test = ma.T;
```

----

### `(ma.)BS`

Current block-size. Can change during the execution at each block.

#### Usage

```
BS : _
```

Where:

* `BS`: current processing block size

#### Test
```
ma = library("maths.lib");
BS_test = ma.BS;
```

----

### `(ma.)PI`

Constant PI in double precision.

#### Usage

```
PI : _
```

Where:

* `PI`: double-precision π constant

#### Test
```
ma = library("maths.lib");
PI_test = ma.PI;
```

----

### `(ma.)deg2rad`

Convert degrees to radians.

#### Usage

```
45. : deg2rad
```

Where:

* input: angle in degrees to convert

#### Test
```
ma = library("maths.lib");
deg2rad_test = 45.0 : ma.deg2rad;
```

----

### `(ma.)rad2deg`

Convert radians to degrees.

#### Usage

```
ma.PI : rad2deg
```

Where:

* input: angle in radians to convert

#### Test
```
ma = library("maths.lib");
rad2deg_test = ma.PI : ma.rad2deg;
```

----

### `(ma.)E`

Constant e in double precision.

#### Usage

```
E : _
```

Where:

* `E`: double-precision Euler's number constant

#### Test
```
ma = library("maths.lib");
E_test = ma.E;
```

----

### `(ma.)EPSILON`

Constant EPSILON available in simple/double/quad precision, 
as defined in the [floating-point standard](https://en.wikipedia.org/wiki/IEEE_754) 
and [machine epsilon](https://en.wikipedia.org/wiki/Machine_epsilon), 
that is smallest positive number such that `1.0 + EPSILON != 1.0`.

#### Usage

```
EPSILON : _
```

Where:

* `EPSILON`: machine epsilon constant for the current floating-point precision

#### Test
```
ma = library("maths.lib");
EPSILON_test = ma.EPSILON;
```

----

### `(ma.)MIN`

Constant MIN available in simple/double/quad precision (minimal positive value).

#### Usage

```
MIN : _
```

Where:

* `MIN`: minimal positive normalized value for the current precision

#### Test
```
ma = library("maths.lib");
MIN_test = ma.MIN;
```

----

### `(ma.)MAX`

Constant MAX available in simple/double/quad precision (maximal positive value).

#### Usage

```
MAX : _
```

Where:

* `MAX`: maximal finite value for the current precision

#### Test
```
ma = library("maths.lib");
MAX_test = ma.MAX;
```

----

### `(ma.)FTZ`

Flush to zero: force samples under the "maximum subnormal number"
to be zero. Usually not needed in C++ because the architecture
file take care of this, but can be useful in JavaScript for instance.

#### Usage

```
_ : FTZ : _
```

Where:

* `x`: input signal to flush if its magnitude is subnormal

#### Test
```
ma = library("maths.lib");
FTZ_test = (ma.MIN * 0.5) : ma.FTZ;
```

#### References

* [http://docs.oracle.com/cd/E19957-01/806-3568/ncg_math.html](http://docs.oracle.com/cd/E19957-01/806-3568/ncg_math.html)

----

### `(ma.)copysign`

Changes the sign of x (first input) to that of y (second input).

#### Usage

```
_,_ : copysign : _
```

Where:

* `x`: value whose magnitude is preserved
* `y`: value providing the sign

#### Test
```
ma = library("maths.lib");
copysign_test = (-1.0, 2.0) : ma.copysign;
```

----

### `(ma.)neg`

Invert the sign (-x) of a signal.

#### Usage

```
_ : neg : _
```

Where:

* `x`: value to negate

#### Test
```
ma = library("maths.lib");
neg_test = 3.5 : ma.neg;
```

----

### `(ma.)not`

Bitwise `not` implemented with [xor](https://faustdoc.grame.fr/manual/syntax/#xor-primitive) as `not(x) = x xor -1;`.
So working regardless of the size of the integer, assuming negative numbers in two's complement.

#### Usage

```
_ : not : _
```

Where:

* `x`: integer input value

#### Test
```
ma = library("maths.lib");
not_test = 5 : ma.not;
```

----

### `(ma.)sub(x,y)`

Subtract `x` and `y`.

#### Usage

```
_,_ : sub : _
```

Where:

* `x`: first operand
* `y`: second operand

#### Test
```
ma = library("maths.lib");
sub_test = (3, 10) : ma.sub;
```

----

### `(ma.)inv`

Compute the inverse (1/x) of the input signal.

#### Usage

```
_ : inv : _
```

Where:

* `x`: denominator input (non-zero)

#### Test
```
ma = library("maths.lib");
inv_test = 4.0 : ma.inv;
```

----

### `(ma.)cbrt`

Computes the cube root of of the input signal.

#### Usage

```
_ : cbrt : _
```

Where:

* `x`: value whose cube root is computed

#### Test
```
ma = library("maths.lib");
cbrt_test = 8.0 : ma.cbrt;
```

----

### `(ma.)hypot`

Computes the euclidian distance of the two input signals
sqrt(x*x+y*y) without undue overflow or underflow.

#### Usage

```
_,_ : hypot : _
```

Where:

* `x`: first operand
* `y`: second operand

#### Test
```
ma = library("maths.lib");
hypot_test = (3.0, 4.0) : ma.hypot;
```

----

### `(ma.)ldexp`

Takes two input signals: x and n, and multiplies x by 2 to the power n.

#### Usage

```
_,_ : ldexp : _
```

Where:

* `x`: significand input
* `n`: exponent (integer) input

#### Test
```
ma = library("maths.lib");
ldexp_test = (1.5, 3) : ma.ldexp;
```

----

### `(ma.)scalb`

Takes two input signals: x and n, and multiplies x by 2 to the power n.

#### Usage

```
_,_ : scalb : _
```

Where:

* `x`: significand input
* `n`: exponent (integer) input

#### Test
```
ma = library("maths.lib");
scalb_test = (2.0, -1) : ma.scalb;
```

----

### `(ma.)log1p`

Computes log(1 + x) without undue loss of accuracy when x is nearly zero.

#### Usage

```
_ : log1p : _
```

Where:

* `x`: offset used in `log(1 + x)` (must be greater than -1)

#### Test
```
ma = library("maths.lib");
log1p_test = 0.5 : ma.log1p;
```

----

### `(ma.)logb`

Return exponent of the input signal as a floating-point number.

#### Usage

```
_ : logb : _
```

Where:

* `x`: positive value whose exponent part is returned

#### Test
```
ma = library("maths.lib");
logb_test = 8.0 : ma.logb;
```

----

### `(ma.)ilogb`

Return exponent of the input signal as an integer number.

#### Usage

```
_ : ilogb : _
```

Where:

* `x`: positive value whose exponent part is returned

#### Test
```
ma = library("maths.lib");
ilogb_test = 8.0 : ma.ilogb;
```

----

### `(ma.)log2`

Returns the base 2 logarithm of x.

#### Usage

```
_ : log2 : _
```

Where:

* `x`: positive value whose base-2 logarithm is computed

#### Test
```
ma = library("maths.lib");
log2_test = 8.0 : ma.log2;
```

----

### `(ma.)expm1`

Return exponent of the input signal minus 1 with better precision.

#### Usage

```
_ : expm1 : _
```

Where:

* `x`: input value used for the `exp(x) - 1` computation

#### Test
```
ma = library("maths.lib");
expm1_test = 0.5 : ma.expm1;
```

----

### `(ma.)acosh`

Computes the principle value of the inverse hyperbolic cosine
of the input signal.

#### Usage

```
_ : acosh : _
```

Where:

* `x`: input value (greater than or equal to 1)

#### Test
```
ma = library("maths.lib");
acosh_test = 1.5 : ma.acosh;
```

----

### `(ma.)asinh`

Computes the inverse hyperbolic sine of the input signal.

#### Usage

```
_ : asinh : _
```

Where:

* `x`: input value

#### Test
```
ma = library("maths.lib");
asinh_test = 0.5 : ma.asinh;
```

----

### `(ma.)atanh`

Computes the inverse hyperbolic tangent of the input signal.

#### Usage

```
_ : atanh : _
```

Where:

* `x`: input value in (-1, 1)

#### Test
```
ma = library("maths.lib");
atanh_test = 0.5 : ma.atanh;
```

----

### `(ma.)sinh`

Computes the hyperbolic sine of the input signal.

#### Usage

```
_ : sinh : _
```

Where:

* `x`: input value

#### Test
```
ma = library("maths.lib");
sinh_test = 0.5 : ma.sinh;
```

----

### `(ma.)cosh`

Computes the hyperbolic cosine of the input signal.

#### Usage

```
_ : cosh : _
```

Where:

* `x`: input value

#### Test
```
ma = library("maths.lib");
cosh_test = 0.5 : ma.cosh;
```

----

### `(ma.)tanh`

Computes the hyperbolic tangent of the input signal.

#### Usage

```
_ : tanh : _
```

Where:

* `x`: input value

#### Test
```
ma = library("maths.lib");
tanh_test = 0.5 : ma.tanh;
```

----

### `(ma.)erf`

Computes the error function of the input signal.

#### Usage

```
_ : erf : _
```

Where:

* `x`: input value

#### Test
```
ma = library("maths.lib");
erf_test = 0.5 : ma.erf;
```

----

### `(ma.)erfc`

Computes the complementary error function of the input signal.

#### Usage

```
_ : erfc : _
```

Where:

* `x`: input value

#### Test
```
ma = library("maths.lib");
erfc_test = 0.5 : ma.erfc;
```

----

### `(ma.)gamma`

Computes the gamma function of the input signal.

#### Usage

```
_ : gamma : _
```

Where:

* `x`: positive input value

#### Test
```
ma = library("maths.lib");
gamma_test = 3.0 : ma.gamma;
```

----

### `(ma.)lgamma`

Calculates the natural logorithm of the absolute value of
the gamma function of the input signal.

#### Usage

```
_ : lgamma : _
```

Where:

* `x`: positive input value

#### Test
```
ma = library("maths.lib");
lgamma_test = 3.0 : ma.lgamma;
```

----

### `(ma.)J0`

Computes the Bessel function of the first kind of order 0
of the input signal.

#### Usage

```
_ : J0 : _
```

Where:

* `x`: input value

#### Test
```
ma = library("maths.lib");
J0_test = 1.0 : ma.J0;
```

----

### `(ma.)J1`

Computes the Bessel function of the first kind of order 1
of the input signal.

#### Usage

```
_ : J1 : _
```

Where:

* `x`: input value

#### Test
```
ma = library("maths.lib");
J1_test = 1.0 : ma.J1;
```

----

### `(ma.)Jn`

Computes the Bessel function of the first kind of order n
(first input signal) of the second input signal.

#### Usage

```
_,_ : Jn : _
```

Where:

* `n`: integer order
* `x`: input value

#### Test
```
ma = library("maths.lib");
Jn_test = (2, 1.0) : ma.Jn;
```

----

### `(ma.)Y0`

Computes the linearly independent Bessel function of the second kind
of order 0 of the input signal.

#### Usage

```
_ : Y0 : _
```

Where:

* `x`: positive input value

#### Test
```
ma = library("maths.lib");
Y0_test = 1.0 : ma.Y0;
```

----

### `(ma.)Y1`

Computes the linearly independent Bessel function of the second kind
of order 1 of the input signal.

#### Usage

```
_ : Y0 : _
```

Where:

* `x`: positive input value

#### Test
```
ma = library("maths.lib");
Y1_test = 1.0 : ma.Y1;
```

----

### `(ma.)Yn`

Computes the linearly independent Bessel function of the second kind
of order n (first input signal) of the second input signal.

#### Usage

```
_,_ : Yn : _
```

Where:

* `n`: integer order
* `x`: positive input value

#### Test
```
ma = library("maths.lib");
Yn_test = (2, 1.0) : ma.Yn;
```

----

### `(ma.)fabs`, `(ma.)fmax`, `(ma.)fmin`

Just for compatibility...

```
fabs = abs
fmax = max
fmin = min
```

----

### `(ma.)np2`

Gives the next power of 2 of x.

#### Usage

```
np2(n) : _
```

Where:

* `n`: an integer

#### Test
```
ma = library("maths.lib");
np2_test = 5 : ma.np2;
```

----

### `(ma.)frac`

Gives the fractional part of n.

#### Usage

```
frac(n) : _
```

Where:

* `n`: a decimal number

#### Test
```
ma = library("maths.lib");
frac_test = 3.75 : ma.frac;
```

----

### `(ma.)modulo`

Modulus operation using the `(x%y+y)%y` formula to ensures the result is always non-negative, even if `x` is negative.

#### Usage

```
modulo(x,y) : _
```

Where:

* `x`: the numerator
* `y`: the denominator

#### Test
```
ma = library("maths.lib");
modulo_test = (-3, 4) : ma.modulo;
```

----

### `(ma.)isnan`

Return non-zero if x is a NaN.

#### Usage

```
isnan(x)
_ : isnan : _
```

Where:

* `x`: signal to analyse

#### Test
```
ma = library("maths.lib");
isnan_test = 1.0 : ma.isnan;
```

----

### `(ma.)isinf`

Return non-zero if x is a positive or negative infinity.

#### Usage

```
isinf(x)
_ : isinf : _
```

Where:

* `x`: signal to analyse

#### Test
```
ma = library("maths.lib");
isinf_test = 1.0 : ma.isinf;
```

----

### `(ma.)chebychev`

Chebychev transformation of order N.

#### Usage

```
_ : chebychev(N) : _
```

Where:

* `N`: the order of the polynomial, a constant numerical expression

#### Semantics

```
T[0](x) = 1,
T[1](x) = x,
T[n](x) = 2x*T[n-1](x) - T[n-2](x)
```

#### Test
```
ma = library("maths.lib");
chebychev_test = 0.5 : ma.chebychev(3);
```

#### References

* [http://en.wikipedia.org/wiki/Chebyshev_polynomial](http://en.wikipedia.org/wiki/Chebyshev_polynomial)

----

### `(ma.)chebychevpoly`

Linear combination of the first Chebyshev polynomials.

#### Usage

```
_ : chebychevpoly((c0,c1,...,cn)) : _
```

Where:

* `cn`: the different Chebychevs polynomials such that:
chebychevpoly((c0,c1,...,cn)) = Sum of chebychev(i)*ci

#### Test
```
ma = library("maths.lib");
chebychevpoly_test = 0.5 : ma.chebychevpoly((1, 0, 1));
```

#### References

* [http://www.csounds.com/manual/html/chebyshevpoly.html](http://www.csounds.com/manual/html/chebyshevpoly.html)

----

### `(ma.)diffn`

Negated first-order difference.

#### Usage

```
_ : diffn : _
```

Where:

* `x`: input signal

#### Test
```
ma = library("maths.lib");
os = library("oscillators.lib");
diffn_test = os.osc(440) : ma.diffn;
```

----

### `(ma.)signum`

The signum function signum(x) is defined as
-1 for x<0, 0 for x==0, and 1 for x>0.

#### Usage

```
_ : signum : _
```

Where:

* `x`: input value

#### Test
```
ma = library("maths.lib");
signum_test = (-5.0) : ma.signum;
```

----

### `(ma.)nextpow2`

The nextpow2(x) returns the lowest integer m such that
2^m >= x.

#### Usage

```
2^nextpow2(n) : _
```
Useful for allocating delay lines, e.g., 
```
delay(2^nextpow2(maxDelayNeeded), currentDelay);
```

Where:

* `n`: positive value whose next power-of-two exponent is computed

#### Test
```
ma = library("maths.lib");
nextpow2_test = 10.0 : ma.nextpow2;
```

----

### `(ma.)zc`

Indicator function for zero-crossing: it returns 1 if a zero-crossing
occurs, 0 otherwise.

#### Usage

```
_ : zc : _
```

Where:

* `x`: input signal to monitor for zero crossings

#### Test
```
ma = library("maths.lib");
os = library("oscillators.lib");
zc_test = os.osc(440) : ma.zc;
```

----

### `(ma.)unwrap` 

Unwrap the input signal so that successive output values never differ
by more than `pi`, switching to a 2*pi-complementary value when needed.

#### Usage

```
_ : unwrap(pi) : _
```

Where:

* `pi`: maximum discontinuity between the output values (typically `ma.PI`)

#### Test
```
ma = library("maths.lib");
os = library("oscillators.lib");
unwrap_test = os.oscrc(100) : ma.unwrap(ma.PI);
```

#### Example test program

```
process = 0 - os.oscrc(1000)          // the true phase is either -PI or +PI
        : an.resonator(1,1000) : !,_  // oscillates between -PI and +PI
        : ma.unwrap(ma.PI);           // oscillates near +PI
```


----

### `(ma.)primes`

Return the n-th prime using a waveform primitive. Note that primes(0) is 2,
primes(1) is 3, and so on. The waveform is length 2048, so the largest
precomputed prime is primes(2047) which is 17863.

#### Usage

```
_ : primes : _
```

Where:

* `x`: index of the prime number sequence (0-based).

#### Test
```
ma = library("maths.lib");
primes_test = 10 : ma.primes;
```
