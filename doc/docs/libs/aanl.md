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

The Antialiased Nonlinearities library is organized into 3 sections:

* [Auxiliary Functions](#auxiliary-functions)
* [Saturators](#saturators)
* [Trigonometry](#trigonometry)

#### References

* [https://github.com/grame-cncm/faustlibraries/blob/master/aanl.lib](https://github.com/grame-cncm/faustlibraries/blob/master/aanl.lib)
* Reducing the Aliasing in Nonlinear Waveshaping Using Continuous-time Convolution, Julian Parker, Vadim Zavalishin, Efflam Le Bivic, DAFX, 2016
* [http://dafx16.vutbr.cz/dafxpapers/20-DAFx-16_paper_41-PN.pdf](http://dafx16.vutbr.cz/dafxpapers/20-DAFx-16_paper_41-PN.pdf)

## Auxiliary Functions


----

### `(aa.)Rsqrt`

![Rsqrt — response plots](../img/aa_Rsqrt.svg)

Real-valued sqrt(): a negative input is clamped to 0, so that the output
is never NaN.

#### Usage

```
Rsqrt(x) : _
```

Where:

* `x`: input signal


----

### `(aa.)Rlog`

![Rlog — response plots](../img/aa_Rlog.svg)

Real-valued log(): the input is clamped to `ma.EPSILON` from below, so
that the output stays finite.

#### Usage

```
Rlog(x) : _
```

Where:

* `x`: input signal


----

### `(aa.)Rtan`

![Rtan — response plots](../img/aa_Rtan.svg)

Real-valued tan(): the input is clipped to [-ma.MAX, ma.MAX].

#### Usage

```
Rtan(x) : _
```

Where:

* `x`: input signal


----

### `(aa.)Racos`

![Racos — response plots](../img/aa_Racos.svg)

Real-valued acos(): the input is clipped to [-1, 1].

#### Usage

```
Racos(x) : _
```

Where:

* `x`: input signal


----

### `(aa.)Rasin`

![Rasin — response plots](../img/aa_Rasin.svg)

Real-valued asin(): the input is clipped to [-1, 1].

#### Usage

```
Rasin(x) : _
```

Where:

* `x`: input signal


----

### `(aa.)Racosh`

![Racosh — response plots](../img/aa_Racosh.svg)

Real-valued acosh(): the input is clipped to [1, ma.MAX].

#### Usage

```
Racosh(x) : _
```

Where:

* `x`: input signal


----

### `(aa.)Rcosh`

![Rcosh — response plots](../img/aa_Rcosh.svg)

Real-valued cosh(): the output is limited to `ma.MAX`.

#### Usage

```
Rcosh(x) : _
```

Where:

* `x`: input signal


----

### `(aa.)Rsinh`

![Rsinh — response plots](../img/aa_Rsinh.svg)

Real-valued sinh(): the output is clipped to [-ma.MAX, ma.MAX].

#### Usage

```
Rsinh(x) : _
```

Where:

* `x`: input signal


----

### `(aa.)Ratanh`

![Ratanh — response plots](../img/aa_Ratanh.svg)

Real-valued atanh(): the input is clipped to
[-1 + ma.EPSILON, 1 - ma.EPSILON].

#### Usage

```
Ratanh(x) : _
```

Where:

* `x`: input signal


----

### `(aa.)ADAA1`

Generalised first-order Antiderivative Anti-Aliasing (ADAA) function.

Implements a first-order ADAA approximation to reduce aliasing
in nonlinear audio processing.

#### Usage

```
ADAA1(EPS, f, F1, x) : _
```

Where:

* `EPS`: a threshold for switching between safe and ill-conditioned paths
* `f`: a function that we want to process with ADAA
* `F1`: f's first antiderivative
* `x`: input signal

#### Test
```
aa = library("aanl.lib");
ba = library("basics.lib");
ma = library("maths.lib");
os = library("oscillators.lib");
sig = os.tosc(110);
ADAA1_test = aa.ADAA1(0.001, f, F1, sig)
    with {
        f(x) = max(-1.0, min(1.0, x));
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
ADAA2(EPS, f, F1, F2, x) : _
```

Where:

* `EPS`: a threshold for switching between safe and ill-conditioned paths
* `f`: a function that we want to process with ADAA
* `F1`: f's first antiderivative
* `F2`: the antiderivative of x * f(x), as in `aa.hardclip2` (not the second
  antiderivative of f)
* `x`: input signal

#### Test
```
aa = library("aanl.lib");
ba = library("basics.lib");
ma = library("maths.lib");
os = library("oscillators.lib");
sig = os.tosc(110);
ADAA2_test = aa.ADAA2(0.001, f, F1, F2, sig)
    with {
        f(x) = max(-1.0, min(1.0, x));
        F1(x) = ba.if((x <= 1.0) & (x >= -1.0), 0.5 * x^2, x * ma.signum(x) - 0.5);
        F2(x) = ba.if((x <= 1.0) & (x >= -1.0), (1.0 / 3.0) * x^3, ((0.5 * x^2) - 1.0 / 6.0) * ma.signum(x));
    };
```

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

![hardclip — response plots](../img/aa_hardclip.svg)


First-order ADAA hard-clip.

The domain of this function is ℝ; its theoretical range is [-1.0; 1.0].

#### Usage
```
hardclip(x) : _
```

Where:

* `x`: input signal

#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
sig = os.tosc(110);
hardclip_test = aa.hardclip(sig);
```

----

### `(aa.)hardclip2`

![hardclip2 — response plots](../img/aa_hardclip2.svg)


Second-order ADAA hard-clip.

The domain of this function is ℝ; its theoretical range is [-1.0; 1.0].

#### Usage
```
hardclip2(x) : _
```

Where:

* `x`: input signal

#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
sig = os.tosc(110);
hardclip2_test = aa.hardclip2(sig);
```

----

### `(aa.)cubic1`

![cubic1 — response plots](../img/aa_cubic1.svg)


First-order ADAA cubic saturator.

The domain of this function is ℝ; its theoretical range is 
[-2.0/3.0; 2.0/3.0].

#### Usage
```
cubic1(x) : _
```

Where:

* `x`: input signal

#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
sig = os.tosc(110);
cubic1_test = aa.cubic1(sig);
cubic1_noise_test = aa.cubic1(2.0 * no.noise)
    with { no = library("noises.lib"); };
```

----

### `(aa.)parabolic`

![parabolic — response plots](../img/aa_parabolic.svg)


First-order ADAA parabolic saturator.

The domain of this function is ℝ; its theoretical range is [-1.0; 1.0].

#### Usage
```
parabolic(x) : _
```

Where:

* `x`: input signal

#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
sig = os.tosc(110);
parabolic_test = aa.parabolic(sig);
parabolic_noise_test = aa.parabolic(4.0 * no.noise)
    with { no = library("noises.lib"); };
```

----

### `(aa.)parabolic2`

![parabolic2 — response plots](../img/aa_parabolic2.svg)


Second-order ADAA parabolic saturator.

The domain of this function is ℝ; its theoretical range is [-1.0; 1.0].

#### Usage
```
parabolic2(x) : _
```

Where:

* `x`: input signal

#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
sig = os.tosc(110);
parabolic2_test = aa.parabolic2(sig);
parabolic2_noise_test = aa.parabolic2(4.0 * no.noise)
    with { no = library("noises.lib"); };
```

----

### `(aa.)hyperbolic`

![hyperbolic — response plots](../img/aa_hyperbolic.svg)


First-order ADAA hyperbolic saturator.

The domain of this function is ℝ; its theoretical range is [-1.0; 1.0].

#### Usage
```
hyperbolic(x) : _
```

Where:

* `x`: input signal

#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
sig = os.tosc(110);
hyperbolic_test = aa.hyperbolic(sig);
```

----

### `(aa.)hyperbolic2`

![hyperbolic2 — response plots](../img/aa_hyperbolic2.svg)


Second-order ADAA hyperbolic saturator.

The domain of this function is ℝ; its theoretical range is [-1.0; 1.0].

#### Usage
```
hyperbolic2(x) : _
```

Where:

* `x`: input signal

#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
sig = os.tosc(110);
hyperbolic2_test = aa.hyperbolic2(sig);
```

----

### `(aa.)sinarctan`

![sinarctan — response plots](../img/aa_sinarctan.svg)


First-order ADAA sin(atan()) saturator.

The domain of this function is ℝ; its theoretical range is [-1.0; 1.0].

#### Usage
```
sinarctan(x) : _
```

Where:

* `x`: input signal

#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
sig = os.tosc(110);
sinarctan_test = aa.sinarctan(sig);
```

----

### `(aa.)sinarctan2`

![sinarctan2 — response plots](../img/aa_sinarctan2.svg)


Second-order ADAA sin(atan()) saturator.

The domain of this function is ℝ; its theoretical range is [-1.0; 1.0].

#### Usage
```
sinarctan2(x) : _
```

Where:

* `x`: input signal

#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
sig = os.tosc(110);
sinarctan2_test = aa.sinarctan2(sig);
```

----

### `(aa.)softclipQuadratic1`

![softclipQuadratic1 — response plots](../img/aa_softclipQuadratic1.svg)


First-order ADAA quadratic softclip.

The domain of this function is ℝ; its theoretical range is [-1.0; 1.0].

#### Usage
```
softclipQuadratic1(x) : _
```

Where:

* `x`: input signal

#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
sig = os.tosc(110);
softclipQuadratic1_test = aa.softclipQuadratic1(sig);
```

----

### `(aa.)softclipQuadratic2`

![softclipQuadratic2 — response plots](../img/aa_softclipQuadratic2.svg)


Second-order ADAA quadratic softclip.

The domain of this function is ℝ; its theoretical range is [-1.0; 1.0].

#### Usage
```
softclipQuadratic2(x) : _
```

Where:

* `x`: input signal

#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
sig = os.tosc(110);
softclipQuadratic2_test = aa.softclipQuadratic2(sig);
```

----

### `(aa.)tanh1`

![tanh1 — response plots](../img/aa_tanh1.svg)


First-order ADAA tanh() saturator.

The domain of this function is ℝ; its theoretical range is [-1.0; 1.0].

#### Usage
```
tanh1(x) : _
```

Where:

* `x`: input signal

#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
sig = os.tosc(110);
tanh1_test = aa.tanh1(sig);
```

----

### `(aa.)arctan`

![arctan — response plots](../img/aa_arctan.svg)


First-order ADAA atan().

The domain of this function is ℝ; its theoretical range is [-π/2.0; π/2.0].

#### Usage
```
arctan(x) : _
```

Where:

* `x`: input signal

#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
sig = os.tosc(110);
arctan_test = aa.arctan(sig);
```

----

### `(aa.)arctan2`

![arctan2 — response plots](../img/aa_arctan2.svg)


Second-order ADAA atan().

The domain of this function is ℝ; its theoretical range is ]-π/2.0; π/2.0[.

#### Usage
```
arctan2(x) : _
```

Where:

* `x`: input signal

#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
sig = os.tosc(110);
arctan2_test = aa.arctan2(sig);
```

----

### `(aa.)asinh1`

![asinh1 — response plots](../img/aa_asinh1.svg)


First-order ADAA asinh() saturator (unbounded).

The domain of this function is ℝ; its theoretical range is ℝ.

#### Usage
```
asinh1(x) : _
```

Where:

* `x`: input signal

#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
sig = os.tosc(110);
asinh1_test = aa.asinh1(sig);
```

----

### `(aa.)asinh2`

![asinh2 — response plots](../img/aa_asinh2.svg)


Second-order ADAA asinh() saturator (unbounded).

The domain of this function is ℝ; its theoretical range is ℝ.

#### Usage
```
asinh2(x) : _
```

Where:

* `x`: input signal

#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
sig = os.tosc(110);
asinh2_test = aa.asinh2(sig);
```

##  Trigonometry 

These functions are reliable if input signals are within their domains.

----

### `(aa.)cosine1`

![cosine1 — response plots](../img/aa_cosine1.svg)


First-order ADAA cos().

The domain of this function is ℝ; its theoretical range is [-1.0; 1.0].

#### Usage
```
cosine1(x) : _
```

Where:

* `x`: input signal

#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
sig = os.tosc(110);
cosine1_test = aa.cosine1(sig);
```

----

### `(aa.)cosine2`

![cosine2 — response plots](../img/aa_cosine2.svg)


Second-order ADAA cos().

The domain of this function is ℝ; its theoretical range is [-1.0; 1.0].

#### Usage
```
cosine2(x) : _
```

Where:

* `x`: input signal

#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
sig = os.tosc(110);
cosine2_test = aa.cosine2(sig);
```

----

### `(aa.)arccos`

![arccos — response plots](../img/aa_arccos.svg)


First-order ADAA acos().

The domain of this function is [-1.0; 1.0]; its theoretical range is
[π; 0.0].

#### Usage
```
arccos(x) : _
```

Where:

* `x`: input signal

#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
sig = os.tosc(110);
arccos_test = aa.arccos(sig);
```

----

### `(aa.)arccos2`

![arccos2 — response plots](../img/aa_arccos2.svg)


Second-order ADAA acos().

The domain of this function is [-1.0; 1.0]; its theoretical range is 
[π; 0.0].

Note that this function is not accurate for low-amplitude or low-frequency 
input signals. In that case, the first-order ADAA arccos() can be used.

#### Usage
```
arccos2(x) : _
```

Where:

* `x`: input signal

#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
sig = os.tosc(110);
arccos2_test = aa.arccos2(sig);
arccos2_noise_test = aa.arccos2(no.noise)
    with { no = library("noises.lib"); };
```

----

### `(aa.)acosh1`

![acosh1 — response plots](../img/aa_acosh1.svg)


First-order ADAA acosh(). 

The domain of this function is ℝ >= 1.0; its theoretical range is ℝ >= 0.0.

#### Usage
```
acosh1(x) : _
```

Where:

* `x`: input signal

#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
acoshDomainSig = 1.0 + abs(sig);
sig = os.tosc(110);
acosh1_test = aa.acosh1(acoshDomainSig);
```

----

### `(aa.)acosh2`

![acosh2 — response plots](../img/aa_acosh2.svg)


Second-order ADAA acosh().

The domain of this function is ℝ >= 1.0; its theoretical range is ℝ >= 0.0.

Note that this function is not accurate for low-frequency input signals. 
In that case, the first-order ADAA acosh() can be used.

#### Usage
```
acosh2(x) : _
```

Where:

* `x`: input signal

#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
acoshDomainSig = 1.0 + abs(sig);
sig = os.tosc(110);
acosh2_test = aa.acosh2(acoshDomainSig);
```

----

### `(aa.)sine`

![sine — response plots](../img/aa_sine.svg)


First-order ADAA sin().

The domain of this function is ℝ; its theoretical range is ℝ.

#### Usage
```
sine(x) : _
```

Where:

* `x`: input signal

#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
sig = os.tosc(110);
sine_test = aa.sine(sig);
```

----

### `(aa.)sine2`

![sine2 — response plots](../img/aa_sine2.svg)


Second-order ADAA sin().

The domain of this function is ℝ; its theoretical range is ℝ.

#### Usage
```
sine2(x) : _
```

Where:

* `x`: input signal

#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
sig = os.tosc(110);
sine2_test = aa.sine2(sig);
```

----

### `(aa.)arcsin`

![arcsin — response plots](../img/aa_arcsin.svg)


First-order ADAA asin().

The domain of this function is [-1.0, 1.0]; its theoretical range is 
[-π/2.0; π/2.0].

#### Usage
```
arcsin(x) : _
```

Where:

* `x`: input signal

#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
sig = os.tosc(110);
arcsin_test = aa.arcsin(sig);
```

----

### `(aa.)arcsin2`

![arcsin2 — response plots](../img/aa_arcsin2.svg)


Second-order ADAA asin().

The domain of this function is [-1.0, 1.0]; its theoretical range is
[-π/2.0; π/2.0].

Note that this function is not accurate for low-frequency input signals.
In that case, the first-order ADAA asin() can be used.

#### Usage
```
arcsin2(x) : _
```

Where:

* `x`: input signal

#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
sig = os.tosc(110);
arcsin2_test = aa.arcsin2(sig);
```

----

### `(aa.)tangent`

![tangent — response plots](../img/aa_tangent.svg)


First-order ADAA tan().

The domain of this function is [-π/2.0; π/2.0]; its theoretical range is ℝ.

#### Usage
```
tangent(x) : _
```

Where:

* `x`: input signal

#### Test
```
aa = library("aanl.lib");
ma = library("maths.lib");
os = library("oscillators.lib");
tanDomainSig = 0.25 * ma.PI * sig;
sig = os.tosc(110);
tangent_test = aa.tangent(tanDomainSig);
```

----

### `(aa.)atanh1`

![atanh1 — response plots](../img/aa_atanh1.svg)


First-order ADAA atanh(). 

The domain of this function is [-1.0; 1.0]; its theoretical range is ℝ.

#### Usage
```
atanh1(x) : _
```

Where:

* `x`: input signal

#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
atanhDomainSig = 0.8 * sig;
sig = os.tosc(110);
atanh1_test = aa.atanh1(atanhDomainSig);
```

----

### `(aa.)atanh2`

![atanh2 — response plots](../img/aa_atanh2.svg)


Second-order ADAA atanh().

The domain of this function is [-1.0; 1.0]; its theoretical range is ℝ.

#### Usage
```
atanh2(x) : _
```

Where:

* `x`: input signal

#### Test
```
aa = library("aanl.lib");
os = library("oscillators.lib");
atanhDomainSig = 0.8 * sig;
sig = os.tosc(110);
atanh2_test = aa.atanh2(atanhDomainSig);
```
