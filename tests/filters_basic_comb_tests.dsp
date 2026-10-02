//----------------------------------------------------------------------------
// filters_basic_comb_tests.dsp
// Tests for basic and comb envelope helpers.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");
no = library("noises.lib");
ba = library("basics.lib");
ma = library("maths.lib");

src = os.tosc(440);

zero_test = src : fi.zero(0.5);
zero_slider_test = no.noise : fi.zero(hslider("z", 0.5, -1, 1, 0.01));
zero_modulated_test = no.noise : fi.zero(-0.9 + 1.8*tri) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
pole_test = src : fi.pole(0.9);
pole_slider_test = no.noise : fi.pole(hslider("p", 0.9, 0, 0.999, 0.001));
pole_modulated_test = no.noise : fi.pole(0.5 + 0.499*tri) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
integrator_test = src : fi.integrator;
dcblockerat_test = src : fi.dcblockerat(30);
dcblockerat_slider_test = no.noise : fi.dcblockerat(hslider("fb", 30, 1, 500, 1));
dcblockerat_modulated_test = no.noise : fi.dcblockerat(5*pow(40, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
dcblocker_test = src : fi.dcblocker;
lptN_test = src : fi.lptN(60, 0.1);
lptN_slider_test = no.noise : fi.lptN(60, hslider("tN", 0.1, 0.001, 1, 0.001));
lptN_modulated_test = no.noise : fi.lptN(60, 0.001*pow(1000, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
lptau_test = src : fi.lptau(0.1);
lptau_slider_test = no.noise : fi.lptau(hslider("tN", 0.1, 0.001, 1, 0.001));
lptau_modulated_test = no.noise : fi.lptau(0.001*pow(1000, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
lpt60_test = src : fi.lpt60(0.3);
lpt60_slider_test = no.noise : fi.lpt60(hslider("tN", 0.3, 0.001, 1, 0.001));
lpt60_modulated_test = no.noise : fi.lpt60(0.001*pow(1000, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
lpt19_test = src : fi.lpt19(0.2);
lpt19_slider_test = no.noise : fi.lpt19(hslider("tN", 0.2, 0.001, 1, 0.001));
lpt19_modulated_test = no.noise : fi.lpt19(0.001*pow(1000, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };

ff_comb_test = src : fi.ff_comb(2048, 64, 1, 0.7);
ff_comb_slider_test = no.noise : fi.ff_comb(2048, hslider("delay", 64, 1, 2047, 1), hslider("b0", 1, -1, 1, 0.01), hslider("bM", 0.7, -1, 1, 0.01));
ff_comb_modulated_test = no.noise : fi.ff_comb(2048, d, 1, 0.7) with { P = int(ma.SR/10); m = 112*(P - abs(2*ba.period(P) - P)); d = 16 + int((m - m % P)/P + 0.5); };
ff_fcomb_test = src : fi.ff_fcomb(2048, 64.5, 1, 0.7);
ff_fcomb_slider_test = no.noise : fi.ff_fcomb(2048, hslider("delay", 64.5, 1, 2047, 0.01), hslider("b0", 1, -1, 1, 0.01), hslider("bM", 0.7, -1, 1, 0.01));
ff_fcomb_modulated_test = no.noise : fi.ff_fcomb(2048, 16 + 112*tri, 1, 0.7) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
ffcombfilter_test = src : fi.ffcombfilter(2048, 64, 0.7);
ffcombfilter_slider_test = no.noise : fi.ffcombfilter(2048, hslider("delay", 64, 1, 2047, 1), hslider("g", 0.7, -1, 1, 0.01));
ffcombfilter_modulated_test = no.noise : fi.ffcombfilter(2048, d, 0.7) with { P = int(ma.SR/10); m = 112*(P - abs(2*ba.period(P) - P)); d = 16 + int((m - m % P)/P + 0.5); };
fb_comb_common_test = src : fi.fb_comb_common(@, 64, 0.8, 0.6);
fb_comb_common_slider_test = no.noise : fi.fb_comb_common(@, hslider("delay", 64, 1, 2047, 1), hslider("b0", 0.8, -1, 1, 0.01), hslider("aN", 0.6, -1, 1, 0.01));
fb_comb_common_modulated_test = no.noise : fi.fb_comb_common(@, d, 0.8, 0.6) with { P = int(ma.SR/10); m = 112*(P - abs(2*ba.period(P) - P)); d = 16 + int((m - m % P)/P + 0.5) : max(16) : min(128); };
fb_comb_test = src : fi.fb_comb(2048, 64, 0.7, 0.6);
fb_comb_slider_test = no.noise : fi.fb_comb(2048, hslider("delay", 64, 1, 2047, 1), hslider("b0", 0.7, -1, 1, 0.01), hslider("aN", 0.6, -1, 1, 0.01));
fb_comb_modulated_test = no.noise : fi.fb_comb(2048, d, 0.7, 0.6) with { P = int(ma.SR/10); m = 112*(P - abs(2*ba.period(P) - P)); d = 16 + int((m - m % P)/P + 0.5); };
fb_fcomb_test = src : fi.fb_fcomb(2048, 64.5, 0.7, 0.6);
fb_fcomb_slider_test = no.noise : fi.fb_fcomb(2048, hslider("delay", 64.5, 1, 2047, 0.01), hslider("b0", 0.7, -1, 1, 0.01), hslider("aN", 0.6, -1, 1, 0.01));
fb_fcomb_modulated_test = no.noise : fi.fb_fcomb(2048, 16 + 112*tri, 0.7, 0.6) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
rev1_test = src : fi.rev1(2048, 64, 0.6);
rev1_slider_test = no.noise : fi.rev1(2048, hslider("delay", 64, 1, 2047, 1), hslider("g", 0.6, -1, 1, 0.01));
rev1_modulated_test = no.noise : fi.rev1(2048, d, 0.6) with { P = int(ma.SR/10); m = 112*(P - abs(2*ba.period(P) - P)); d = 16 + int((m - m % P)/P + 0.5); };
fbcombfilter_test = src : fi.fbcombfilter(2048, 64, 0.6);
fbcombfilter_slider_test = no.noise : fi.fbcombfilter(2048, hslider("delay", 64, 1, 2047, 1), hslider("g", 0.6, -1, 1, 0.01));
fbcombfilter_modulated_test = no.noise : fi.fbcombfilter(2048, d, 0.6) with { P = int(ma.SR/10); m = 112*(P - abs(2*ba.period(P) - P)); d = 16 + int((m - m % P)/P + 0.5); };
ffbcombfilter_test = src : fi.ffbcombfilter(2048, 64.5, 0.6);
ffbcombfilter_slider_test = no.noise : fi.ffbcombfilter(2048, hslider("delay", 64.5, 1, 2047, 0.01), hslider("g", 0.6, -1, 1, 0.01));
ffbcombfilter_modulated_test = no.noise : fi.ffbcombfilter(2048, 16 + 112*tri, 0.6) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
allpass_comb_test = src : fi.allpass_comb(2048, 64, 0.6);
allpass_comb_slider_test = no.noise : fi.allpass_comb(2048, hslider("delay", 64, 1, 2047, 1), hslider("aN", 0.6, -1, 1, 0.01));
allpass_comb_modulated_test = no.noise : fi.allpass_comb(2048, d, 0.6) with { P = int(ma.SR/10); m = 112*(P - abs(2*ba.period(P) - P)); d = 16 + int((m - m % P)/P + 0.5); };
allpass_fcomb_test = src : fi.allpass_fcomb(2048, 64.5, 0.6);
allpass_fcomb_slider_test = no.noise : fi.allpass_fcomb(2048, hslider("delay", 64.5, 1, 2047, 0.01), hslider("aN", 0.6, -1, 1, 0.01));
allpass_fcomb_modulated_test = no.noise : fi.allpass_fcomb(2048, 16 + 112*tri, 0.6) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
rev2_test = src : fi.rev2(2048, 64, 0.6);
rev2_slider_test = no.noise : fi.rev2(2048, hslider("delay", 64, 1, 2047, 1), hslider("g", 0.6, -1, 1, 0.01));
rev2_modulated_test = no.noise : fi.rev2(2048, d, 0.6) with { P = int(ma.SR/10); m = 112*(P - abs(2*ba.period(P) - P)); d = 16 + int((m - m % P)/P + 0.5); };
allpass_fcomb5_test = src : fi.allpass_fcomb5(2048, 64.5, 0.6);
allpass_fcomb5_slider_test = no.noise : fi.allpass_fcomb5(2048, hslider("delay", 64.5, 1, 2047, 0.01), hslider("aN", 0.6, -1, 1, 0.01));
allpass_fcomb5_modulated_test = no.noise : fi.allpass_fcomb5(2048, 16 + 112*tri, 0.6) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
allpass_fcomb1a_test = src : fi.allpass_fcomb1a(2048, 64.5, 0.6);
allpass_fcomb1a_slider_test = no.noise : fi.allpass_fcomb1a(2048, hslider("delay", 64.5, 1, 2047, 0.01), hslider("aN", 0.6, -1, 1, 0.01));
allpass_fcomb1a_modulated_test = no.noise : fi.allpass_fcomb1a(2048, 16 + 112*tri, 0.6) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
