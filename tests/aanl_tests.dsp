//----------------------------------------------------------------------------
// aanl_tests.dsp
// Tests for antialiased nonlinearities.
//----------------------------------------------------------------------------

aa = library("aanl.lib");
ba = library("basics.lib");
ma = library("maths.lib");
os = library("oscillators.lib");

sig = os.tosc(110);
tanDomainSig = 0.25 * ma.PI * sig;
atanhDomainSig = 0.8 * sig;
acoshDomainSig = 1.0 + abs(sig);

ADAA1_test = aa.ADAA1(0.001, f, F1, sig)
    with {
        f(x) = max(-1.0, min(1.0, x));
        F1(x) = ba.if((x <= 1.0) & (x >= -1.0), 0.5 * x^2, x * ma.signum(x) - 0.5);
    };

ADAA2_test = aa.ADAA2(0.001, f, F1, F2, sig)
    with {
        f(x) = max(-1.0, min(1.0, x));
        F1(x) = ba.if((x <= 1.0) & (x >= -1.0), 0.5 * x^2, x * ma.signum(x) - 0.5);
        F2(x) = ba.if((x <= 1.0) & (x >= -1.0), (1.0 / 3.0) * x^3, ((0.5 * x^2) - 1.0 / 6.0) * ma.signum(x));
    };

hardclip_test = aa.hardclip(sig);
hardclip2_test = aa.hardclip2(sig);
cubic1_test = aa.cubic1(sig);
cubic1_noise_test = aa.cubic1(2.0 * no.noise)
    with { no = library("noises.lib"); };
parabolic_test = aa.parabolic(sig);
parabolic_noise_test = aa.parabolic(4.0 * no.noise)
    with { no = library("noises.lib"); };
parabolic2_test = aa.parabolic2(sig);
parabolic2_noise_test = aa.parabolic2(4.0 * no.noise)
    with { no = library("noises.lib"); };
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
arccos2_noise_test = aa.arccos2(no.noise)
    with { no = library("noises.lib"); };

acosh1_test = aa.acosh1(acoshDomainSig);
acosh2_test = aa.acosh2(acoshDomainSig);

sine_test = aa.sine(sig);
sine2_test = aa.sine2(sig);
arcsin_test = aa.arcsin(sig);
arcsin2_test = aa.arcsin2(sig);

tangent_test = aa.tangent(tanDomainSig);
atanh1_test = aa.atanh1(atanhDomainSig);
atanh2_test = aa.atanh2(atanhDomainSig);

no = library("noises.lib");
foldSig = 4.0 * no.noise;
foldTri = 1.0 - abs(2.0 * ba.period(P) / P - 1.0) with { P = int(ma.SR / 10); };

triangleFold1_test = aa.triangleFold1(0.5, 0.9, foldSig);
triangleFold1_slider_test = aa.triangleFold1(hslider("t", 0.5, 0.05, 1.0, 0.01), hslider("r", 0.9, 0.5, 1.0, 0.001), foldSig);
triangleFold1_modulated_test = aa.triangleFold1(0.05 + 0.95 * (1.0 - foldTri), 0.5 + 0.5 * foldTri, foldSig);
triangleFold2_test = aa.triangleFold2(0.5, 0.9, foldSig);
triangleFold2_slider_test = aa.triangleFold2(hslider("t", 0.5, 0.05, 1.0, 0.01), hslider("r", 0.9, 0.5, 1.0, 0.001), foldSig);
triangleFold2_modulated_test = aa.triangleFold2(0.05 + 0.95 * (1.0 - foldTri), 0.5 + 0.5 * foldTri, foldSig);
sineFold1_test = aa.sineFold1(0.5, 0.8, foldSig);
sineFold1_slider_test = aa.sineFold1(hslider("t", 0.5, 0.05, 1.0, 0.01), hslider("r", 0.8, 0.5, 1.0, 0.001), foldSig);
sineFold1_modulated_test = aa.sineFold1(0.05 + 0.95 * (1.0 - foldTri), 0.5 + 0.5 * foldTri, foldSig);
sineFold2_test = aa.sineFold2(0.5, 0.8, foldSig);
sineFold2_slider_test = aa.sineFold2(hslider("t", 0.5, 0.05, 1.0, 0.01), hslider("r", 0.8, 0.5, 1.0, 0.001), foldSig);
sineFold2_modulated_test = aa.sineFold2(0.05 + 0.95 * (1.0 - foldTri), 0.5 + 0.5 * foldTri, foldSig);
