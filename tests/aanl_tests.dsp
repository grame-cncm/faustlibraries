//----------------------------------------------------------------------------
// aanl_tests.dsp
// Tests for antialiased nonlinearities.
//----------------------------------------------------------------------------

aa = library("aanl.lib");
ba = library("basics.lib");
ma = library("maths.lib");
os = library("oscillators.lib");

sig = os.osc(110);
tanDomainSig = 0.25 * ma.PI * sig;
atanhDomainSig = 0.8 * sig;
acoshDomainSig = 1.0 + abs(sig);

ADAA1_test = aa.ADAA1(0.001, f, F1, sig)
    with {
        f(x) = aa.clip(-1.0, 1.0, x);
        F1(x) = ba.if((x <= 1.0) & (x >= -1.0), 0.5 * x^2, x * ma.signum(x) - 0.5);
    };

ADAA2_test = aa.ADAA2(0.001, f, F1, F2, sig)
    with {
        f(x) = aa.clip(-1.0, 1.0, x);
        F1(x) = ba.if((x <= 1.0) & (x >= -1.0), 0.5 * x^2, x * ma.signum(x) - 0.5);
        F2(x) = ba.if((x <= 1.0) & (x >= -1.0), (1.0 / 3.0) * x^3, ((0.5 * x^2) - 1.0 / 6.0) * ma.signum(x));
    };

hardclip_test = aa.hardclip(sig);
hardclip2_test = aa.hardclip2(sig);
cubic1_test = aa.cubic1(sig);
parabolic_test = aa.parabolic(sig);
parabolic2_test = aa.parabolic2(sig);
hyperbolic_test = aa.hyperbolic(sig);
hyperbolic2_test = aa.hyperbolic2(sig);
sinarctan_test = aa.sinarctan(sig);
sinarctan2_test = aa.sinarctan2(sig);
softclipQuadratic1_test = aa.softclipQuadratic1(sig);
softclipQuadratic2_test = aa.softclipQuadratic2(sig);

tanh1_test = aa.tanh1(sig);
arctan_test = aa.arctan(sig);
arctan2_test = aa.arctan2(sig);
asinh1_test = aa.asinh1(sig);
asinh2_test = aa.asinh2(sig);

cosine1_test = aa.cosine1(sig);
cosine2_test = aa.cosine2(sig);
arccos_test = aa.arccos(sig);
arccos2_test = aa.arccos2(sig);

acosh1_test = aa.acosh1(acoshDomainSig);
acosh2_test = aa.acosh2(acoshDomainSig);

sine_test = aa.sine(sig);
sine2_test = aa.sine2(sig);
arcsin_test = aa.arcsin(sig);
arcsin2_test = aa.arcsin2(sig);

tangent_test = aa.tangent(tanDomainSig);
atanh1_test = aa.atanh1(atanhDomainSig);
atanh2_test = aa.atanh2(atanhDomainSig);
