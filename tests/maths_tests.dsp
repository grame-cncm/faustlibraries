//----------------------------------------------------------------------------
// maths_tests.dsp
// Tests for mathematics helper functions.
//----------------------------------------------------------------------------

ma = library("maths.lib");
os = library("oscillators.lib");

SR_test = ma.SR;
T_test = ma.T;
BS_test = ma.BS;
PI_test = ma.PI;
deg2rad_test = 45.0 : ma.deg2rad;
rad2deg_test = ma.PI : ma.rad2deg;
E_test = ma.E;
EPSILON_test = ma.EPSILON;
MIN_test = ma.MIN;
MAX_test = ma.MAX;
FTZ_test = (ma.MIN * 0.5) : ma.FTZ;
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
logb_test = 8.0 : ma.logb;
ilogb_test = 8.0 : ma.ilogb;
log2_test = 8.0 : ma.log2;
expm1_test = 0.5 : ma.expm1;
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
modulo_test = (-3, 4) : ma.modulo;
isnan_test = 1.0 : ma.isnan;
isinf_test = 1.0 : ma.isinf;
chebychev_test = 0.5 : ma.chebychev(3);
chebychevpoly_test = 0.5 : ma.chebychevpoly((1, 0, 1));
diffn_test = os.osc(440) : ma.diffn;
signum_test = (-5.0) : ma.signum;
nextpow2_test = 10.0 : ma.nextpow2;
zc_test = os.osc(440) : ma.zc;
unwrap_test = os.oscrc(100) : ma.unwrap(ma.PI);
primes_test = 10 : ma.primes;
