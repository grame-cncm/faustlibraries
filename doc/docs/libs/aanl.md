#  aanl.lib 

A library for antialiased nonlinearities. Its official prefix is `aa`. 

This library provides aliasing-suppressed nonlinearities through first-order 
and second-order approximations of continuous-time signals, functions,
and convolution based on antiderivatives. This technique is particularly 
effective if combined with low-factor oversampling, for example, operating
at 96 kHz or 192 kHz sample-rate.

The library contains trigonometric functions as well as other nonlinear 
functions such as bounded and unbounded saturators.

Due to their limited domains or ranges, some of these functions may not 
suitable for audio nonlinear processing or waveshaping, although
they have been included for completeness. Some other functions,
for example, tan() and tanh(), are only available with first-order
antialiasing due to the complexity of the antiderivative of the 
x * f(x) term, particularly because of the necessity of the dilogarithm 
function, which requires special implementation.

Future improvements to this library may include an adaptive
mechanism to set the ill-conditioned cases threshold to improve
performance in varying cases.

Note that the antialiasing functions introduce a delay in the path,
respectively half and one-sample delay for first and second-order functions.

Also note that due to division by differences, it is vital to use
double-precision or more to reduce errors.

The environment identifier for this library is `aa`. After importing
the standard libraries in Faust, the functions below can be called as `aa.function_name`.

#### References

* [https://github.com/grame-cncm/faustlibraries/blob/master/aanl.lib](https://github.com/grame-cncm/faustlibraries/blob/master/aanl.lib)
* Reducing the Aliasing in Nonlinear Waveshaping Using Continuous-time Convolution, Julian Parker, Vadim Zavalishin, Efflam Le Bivic, DAFX, 2016
* [http://dafx16.vutbr.cz/dafxpapers/20-DAFx-16_paper_41-PN.pdf](http://dafx16.vutbr.cz/dafxpapers/20-DAFx-16_paper_41-PN.pdf)

## Auxiliary Functions


----

### `(aa.)Rsqrt`

Real-valued sqrt().

----

### `(aa.)Rlog`

Real-valued log().

----

### `(aa.)Rtan`

Real-valued tan().

----

### `(aa.)Racos`

Real-valued acos().

----

### `(aa.)Rasin`

Real-valued asin().

----

### `(aa.)Racosh`

Real-valued acosh()

----

### `(aa.)Rcosh`

Real-valued cosh().

----

### `(aa.)Rsinh`

Real-valued sinh().

----

### `(aa.)Ratanh`

Real-valued atanh().

----

### `(aa.)ADAA1`

Generalised first-order Antiderivative Anti-Aliasing (ADAA) function.

Implements a first-order ADAA approximation to reduce aliasing
in nonlinear audio processing.

#### Usage

```
_ : ADAA1(EPS, f, F1) : _
```

Where:

* `EPS`: a threshold for switching between safe and ill-conditioned paths
* `f`: a function that we want to process with ADAA
* `F1`: f's first antiderivative
#### Test
```
aa = library("aanl.lib");
ba = library("basics.lib");
ma = library("maths.lib");
os = library("oscillators.lib");
ADAA1_test = aa.ADAA1(0.001, f, F1, os.osc(110))
    with {
        f(x) = aa.clip(-1.0, 1.0, x);
        F1(x) = ba.if((x <= 1.0) & (x >= -1.0), 0.5 * x^2, x * ma.signum(x) - 0.5);
    };
```

----

### `(aa.)ADAA2`

Generalised second-order Antiderivative Anti-Aliasing (ADAA) function.

Implements a second-order ADAA approximation for even better aliasing reduction
at the cost of additional computation.
#### Usage

```
_ : ADAA2(EPS, f, F1, F2) : _
```

Where:

* `EPS`: a threshold for switching between safe and ill-conditioned paths
* `f`: a function that we want to process with ADAA
* `F1`: f's first antiderivative
* `F2`: f's second antiderivative
#### Test
```
aa = library("aanl.lib");
ba = library("basics.lib");
ma = library("maths.lib");
os = library("oscillators.lib");
ADAA2_test = aa.ADAA2(0.001, f, F1, F2, os.osc(110))
    with {
        f(x) = aa.clip(-1.0, 1.0, x);
        F1(x) = ba.if((x <= 1.0) & (x >= -1.0), 0.5 * x^2, x * ma.signum(x) - 0.5);
        F2(x) = ba.if((x <= 1.0) & (x >= -1.0), (1.0 / 3.0) * x^3, ((0.5 * x^2) - 1.0 / 6.0) * ma.signum(x));
    };
```

## Main functions


##  Saturators 


These antialiased saturators perform best with high-amplitude input
signals. If the input is only slightly saturated, hence producing
negligible aliasing, the trivial saturator may result in a better
overall output, as noise can be introduced by first and second ADAA
at low amplitudes. 

Once determining the lowest saturation level for which the antialiased 
functions perform adequately, it might be sensible to cross-fade
between the trivial and the antialiased saturators according to the
amplitude profile of the input signal.

----

### `(aa.)hardclip`


First-order ADAA hard-clip.

The domain of this function is ℝ; its theoretical range is [-1.0; 1.0].

#### Usage
```
_ : aa.hardclip : _
```
#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
hardclip_test = aa.hardclip(os.osc(110));
```

----

### `(aa.)hardclip2`


Second-order ADAA hard-clip.

The domain of this function is ℝ; its theoretical range is [-1.0; 1.0].

#### Usage
```
_ : aa.hardclip2 : _
```
#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
hardclip2_test = aa.hardclip2(os.osc(110));
```

----

### `(aa.)cubic1`


First-order ADAA cubic saturator.

The domain of this function is ℝ; its theoretical range is 
[-2.0/3.0; 2.0/3.0].

#### Usage
```
_ : aa.cubic1 : _
```
#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
cubic1_test = aa.cubic1(os.osc(110));
```

----

### `(aa.)parabolic`


First-order ADAA parabolic saturator.

The domain of this function is ℝ; its theoretical range is [-1.0; 1.0].

#### Usage
```
_ : aa.parabolic : _
```
#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
parabolic_test = aa.parabolic(os.osc(110));
```

----

### `(aa.)parabolic2`


Second-order ADAA parabolic saturator.

The domain of this function is ℝ; its theoretical range is [-1.0; 1.0].

#### Usage
```
_ : aa.parabolic2 : _
```
#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
parabolic2_test = aa.parabolic2(os.osc(110));
```

----

### `(aa.)hyperbolic`


First-order ADAA hyperbolic saturator.

The domain of this function is ℝ; its theoretical range is [-1.0; 1.0].

#### Usage
```
_ : aa.hyperbolic : _
```
#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
hyperbolic_test = aa.hyperbolic(os.osc(110));
```

----

### `(aa.)hyperbolic2`


Second-order ADAA hyperbolic saturator.

The domain of this function is ℝ; its theoretical range is [-1.0; 1.0].

#### Usage
```
_ : aa.hyperbolic2 : _
```
#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
hyperbolic2_test = aa.hyperbolic2(os.osc(110));
```

----

### `(aa.)sinarctan`


First-order ADAA sin(atan()) saturator.

The domain of this function is ℝ; its theoretical range is [-1.0; 1.0].

#### Usage
```
_ : aa.sinarctan : _
```
#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
sinarctan_test = aa.sinarctan(os.osc(110));
```

----

### `(aa.)sinarctan2`


Second-order ADAA sin(atan()) saturator.

The domain of this function is ℝ; its theoretical range is [-1.0; 1.0].

#### Usage
```
_ : aa.sinarctan2 : _
```
#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
sinarctan2_test = aa.sinarctan2(os.osc(110));
```

----

### `(aa.)softclipQuadratic1`


First-order ADAA quadratic softclip.

The domain of this function is ℝ; its theoretical range is [-1.0; 1.0].

#### Usage
```
_ : aa.softclipQuadratic1 : _
```
#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
softclipQuadratic1_test = aa.softclipQuadratic1(os.osc(110));
```

----

### `(aa.)softclipQuadratic2`


Second-order ADAA quadratic softclip.

The domain of this function is ℝ; its theoretical range is [-1.0; 1.0].

#### Usage
```
_ : aa.softclipQuadratic2 : _
```
#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
softclipQuadratic2_test = aa.softclipQuadratic2(os.osc(110));
```

----

### `(aa.)tanh1`


First-order ADAA tanh() saturator.

The domain of this function is ℝ; its theoretical range is [-1.0; 1.0].

#### Usage
```
_ : aa.tanh1 : _
```
#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
tanh1_test = aa.tanh1(os.osc(110));
```

----

### `(aa.)arctan`


First-order ADAA atan().

The domain of this function is ℝ; its theoretical range is [-π/2.0; π/2.0].

#### Usage
```
_ : aa.arctan : _
```
#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
arctan_test = aa.arctan(os.osc(110));
```

----

### `(aa.)arctan2`


Second-order ADAA atan().

The domain of this function is ℝ; its theoretical range is ]-π/2.0; π/2.0[.

#### Usage
```
_ : aa.arctan2 : _
```
#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
arctan2_test = aa.arctan2(os.osc(110));
```

----

### `(aa.)asinh1`


First-order ADAA asinh() saturator (unbounded).

The domain of this function is ℝ; its theoretical range is ℝ.

#### Usage
```
_ : aa.asinh1 : _
```
#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
asinh1_test = aa.asinh1(os.osc(110));
```

----

### `(aa.)asinh2`


Second-order ADAA asinh() saturator (unbounded).

The domain of this function is ℝ; its theoretical range is ℝ.

#### Usage
```
_ : aa.asinh2 : _
```
#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
asinh2_test = aa.asinh2(os.osc(110));
```

##  Trigonometry 

These functions are reliable if input signals are within their domains.

----

### `(aa.)cosine1`


First-order ADAA cos().

The domain of this function is ℝ; its theoretical range is [-1.0; 1.0].

#### Usage
```
_ : aa.cosine1 : _
```
#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
cosine1_test = aa.cosine1(os.osc(110));
```

----

### `(aa.)cosine2`


Second-order ADAA cos().

The domain of this function is ℝ; its theoretical range is [-1.0; 1.0].

#### Usage
```
_ : aa.cosine2 : _
```
#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
cosine2_test = aa.cosine2(os.osc(110));
```

----

### `(aa.)arccos`


First-order ADAA acos().

The domain of this function is [-1.0; 1.0]; its theoretical range is
[π; 0.0].

#### Usage
```
_ : aa.arccos : _
```
#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
arccos_test = aa.arccos(os.osc(110));
```

----

### `(aa.)arccos2`


Second-order ADAA acos().

The domain of this function is [-1.0; 1.0]; its theoretical range is 
[π; 0.0].

Note that this function is not accurate for low-amplitude or low-frequency 
input signals. In that case, the first-order ADAA arccos() can be used.

#### Usage
```
_ : aa.arccos2 : _
```
#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
arccos2_test = aa.arccos2(os.osc(110));
```

----

### `(aa.)acosh1`


First-order ADAA acosh(). 

The domain of this function is ℝ >= 1.0; its theoretical range is ℝ >= 0.0.

#### Usage
```
_ : aa.acosh1 : _
```
#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
acosh1_test = aa.acosh1(1.0 + abs(os.osc(110)));
```

----

### `(aa.)acosh2`


Second-order ADAA acosh().

The domain of this function is ℝ >= 1.0; its theoretical range is ℝ >= 0.0.

Note that this function is not accurate for low-frequency input signals. 
In that case, the first-order ADAA acosh() can be used.

#### Usage
```
_ : aa.acosh2 : _
```
#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
acosh2_test = aa.acosh2(1.0 + abs(os.osc(110)));
```

----

### `(aa.)sine`


First-order ADAA sin().

The domain of this function is ℝ; its theoretical range is ℝ.

#### Usage
```
_ : aa.sine : _
```
#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
sine_test = aa.sine(os.osc(110));
```

----

### `(aa.)sine2`


Second-order ADAA sin().

The domain of this function is ℝ; its theoretical range is ℝ.

#### Usage
```
_ : aa.sine2 : _
```
#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
sine2_test = aa.sine2(os.osc(110));
```

----

### `(aa.)arcsin`


First-order ADAA asin().

The domain of this function is [-1.0, 1.0]; its theoretical range is 
[-π/2.0; π/2.0].

#### Usage
```
_ : aa.arcsin : _
```
#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
arcsin_test = aa.arcsin(os.osc(110));
```

----

### `(aa.)arcsin2`


Second-order ADAA asin().

The domain of this function is [-1.0, 1.0]; its theoretical range is
[-π/2.0; π/2.0].

Note that this function is not accurate for low-frequency input signals.
In that case, the first-order ADAA asin() can be used.

#### Usage
```
_ : aa.arcsin2 : _
```
#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
arcsin2_test = aa.arcsin2(os.osc(110));
```

----

### `(aa.)tangent`


First-order ADAA tan().

The domain of this function is [-π/2.0; π/2.0]; its theoretical range is ℝ.

#### Usage
```
_ : aa.tangent : _
```
#### Test
```
aa = library("aanl.lib");
ma = library("maths.lib");
os = library("oscillators.lib");
tangent_test = aa.tangent(0.25 * ma.PI * os.osc(110));
```

----

### `(aa.)atanh1`


First-order ADAA atanh(). 

The domain of this function is [-1.0; 1.0]; its theoretical range is ℝ.

#### Usage
```
_ : aa.atanh1 : _
```
#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
atanh1_test = aa.atanh1(0.8 * os.osc(110));
```

----

### `(aa.)atanh2`


Second-order ADAA atanh().

The domain of this function is [-1.0; 1.0]; its theoretical range is ℝ.

#### Usage
```
_ : aa.atanh2 : _
```
#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
atanh2_test = aa.atanh2(0.8 * os.osc(110));
```
