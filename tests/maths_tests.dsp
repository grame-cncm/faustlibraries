//----------------------------------------------------------------------------
// maths_tests.dsp
// Tests for mathematics helper functions.
//----------------------------------------------------------------------------

ma = library("maths.lib");
os = library("oscillators.lib");
ba = library("basics.lib");

SR_test = ma.SR;
T_test = ma.T;
BS_test = ma.BS;
PI_test = ma.PI;
deg2rad_test = 45.0 : ma.deg2rad;
rad2deg_test = ma.PI : ma.rad2deg;
E_test = ma.E;
EPSILON_test = ma.EPSILON;
MIN_test = ma.MIN * 1e307;
MAX_test = ma.MAX;
INFINITY_test = ma.INFINITY == ma.MAX; // 1: ma.INFINITY is ma.MAX, in both precisions
FTZ_test = ((ma.MIN * 0.5) : ma.FTZ), ((ma.MIN * 1e307) : ma.FTZ);
copysign_test = (-1.0, 2.0) : ma.copysign;
neg_test = 3.5 : ma.neg;
not_test = 5 : ma.not;
sub_test = (3, 10) : ma.sub;
inv_test = 4.0 : ma.inv;
cbrt_test = 8.0 : ma.cbrt;
hypot_test = (3.0, 4.0) : ma.hypot;
ldexp_test = (1.5, 3) : ma.ldexp;
scalb_test = (2.0, -1) : ma.scalb;
log1p_test = 0.5 : ma.log1p;
log1p_slider_test = par(i, 7, ma.log1p(hslider("log1p:x%i", ba.take(i+1, X), -1, 1.0e30, 0.001))) with { X = (-0.9999990463256836, -0.75, -9.313225746154785e-10, 9.313225746154785e-10, 0.25, 1.0e7, 1.0e30); };
log1p_modulated_test = ma.log1p(1000.999*tri*tri*tri - 0.999) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
logb_test = 8.0 : ma.logb;
ilogb_test = 8.0 : ma.ilogb;
log2_test = 8.0 : ma.log2;
expm1_test = 0.5 : ma.expm1;
expm1_slider_test = par(i, 6, ma.expm1(hslider("expm1:x%i", ba.take(i+1, X), -1.0e5, 10, 0.001))) with { X = (-1.0e5, -200.0, -9.313225746154785e-10, 9.313225746154785e-10, 0.5, 10.0); };
expm1_modulated_test = ma.expm1(20*tri - 10) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
acosh_test = 1.5 : ma.acosh;
asinh_test = 0.5 : ma.asinh;
atanh_test = 0.5 : ma.atanh;
sinh_test = 0.5 : ma.sinh;
cosh_test = 0.5 : ma.cosh;
tanh_test = 0.5 : ma.tanh;
erf_test = 0.5 : ma.erf;
erfc_test = 0.5 : ma.erfc;
gamma_test = 3.0 : ma.gamma;
lgamma_test = 3.0 : ma.lgamma;
J0_test = 1.0 : ma.J0;
J1_test = 1.0 : ma.J1;
Jn_test = (2, 1.0) : ma.Jn;
Y0_test = 1.0 : ma.Y0;
Y1_test = 1.0 : ma.Y1;
Yn_test = (2, 1.0) : ma.Yn;
np2_test = 5 : ma.np2;
frac_test = 3.75 : ma.frac;
decimal_test = 3.75 : ma.decimal;
modulo_test = (-3, 4) : ma.modulo;
isnan_test = (os.tosc(1) - 2.0) : sqrt : ma.isnan;
isinf_test = (os.impulse - os.impulse) : log : ma.isinf;
nextafter_test = (1.0, 2.0) : ma.nextafter;
chebychev_test = 0.5 : ma.chebychev(3);
chebychevpoly_test = 0.5 : ma.chebychevpoly((1, 0, 1));
diffn_test = os.tosc(440) : ma.diffn;
signum_test = (-5.0) : ma.signum;
nextpow2_test = 10.0 : ma.nextpow2;
zc_test = os.tosc(440) : ma.zc;
unwrap_test = os.oscrc(100) : ma.unwrap(ma.PI);
primes_test = 10 : ma.primes;
