//----------------------------------------------------------------------------
// filters_direct_ladder_tests.dsp
// Tests for direct-form and ladder filters.
//----------------------------------------------------------------------------

ba = library("basics.lib");
fi = library("filters.lib");
os = library("oscillators.lib");
si = library("signals.lib");
no = library("noises.lib");
ma = library("maths.lib");

src = os.tosc(440);

iir_test = src : fi.iir((0.5, 0.5), (0.3));
fir_test = src : fi.fir((0.2, 0.2, 0.2, 0.2, 0.2));
convN_test = (src <: si.bus(3)) : fi.convN(3, (0.3, 0.2, 0.1, 0.05));
conv_test = src : fi.conv((0.25, 0.25, 0.25, 0.25));

tf1_test = src : fi.tf1(0.5, 0.25, -0.4);
tf2_test = src : fi.tf2(0.1, 0.2, 0.1, -0.5, 0.06);
tf3_test = src : fi.tf3(0.1, 0.3, 0.3, 0.1, -0.9, 0.26, -0.024);
notchw_test = src : fi.notchw(200, 1000);
notchw_slider_test = no.noise : fi.notchw(hslider("width", 200, 10, 2000, 1), hslider("freq", 1000, 20, 20000, 1));
notchw_modulated_test = no.noise : fi.notchw(100, 200*pow(25, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
notchw_jump_test = no.noise : fi.notchw(100, 200*pow(25, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
notchw_audio_modulated_test = 0.1*no.noise : fi.notchw(fc/10, fc) with { fc = max(20, 1000*(1 + 0.9*os.tosc(500))); };

tf21_test = src : fi.tf21(0.1, 0.2, 0.1, -0.5, 0.06);
tf22_test = src : fi.tf22(0.1, 0.2, 0.1, -0.5, 0.06);
tf22t_test = src : fi.tf22t(0.1, 0.2, 0.1, -0.5, 0.06);
tf21t_test = src : fi.tf21t(0.1, 0.2, 0.1, -0.5, 0.06);

av2sv_test = fi.av2sv((-0.4, 0.1)) : si.bus(2);
bvav2nuv_test = fi.bvav2nuv((0.1, 0.2, 0.3), (-0.4, 0.1)) : si.bus(3);

iir_lat2_test = src : fi.iir_lat2((0.1, 0.2, 0.3), (-0.4, 0.1));
allpassnt_test = src : fi.allpassnt(2, (0.3, -0.2)) : si.bus(3);
iir_kl_test = src : fi.iir_kl((0.1, 0.2, 0.3), (-0.4, 0.1));
allpassnklt_test = src : fi.allpassnklt(2, (0.3, -0.2)) : si.bus(3);
iir_lat1_test = src : fi.iir_lat1((0.1, 0.2, 0.3), (-0.4, 0.1));
allpassn1mt_test = src : fi.allpassn1mt(2, (0.3, -0.2)) : si.bus(3);
iir_nl_test = src : fi.iir_nl((0.1, 0.2, 0.3), (-0.4, 0.1));
allpassnnlt_test = src : fi.allpassnnlt(2, (0.3, -0.2)) : si.bus(3);
allpassnnlt_product_test = no.noise : fi.allpassnnlt(1, 0.5*hslider("s", 0.6, -1, 1, 0.01)) : si.bus(2);
TF2_legacy_test = os.tosc(440) : fi.TF2(0.2, 0.4, 0.2, -0.5, 0.3);
tf2_tpt_test = no.noise : fi.tf2_tpt(P, S, fq, 0, 0, fq) with { fc = 1000; om = 0 - ma.expm1(0 - ma.PI*fc/10/ma.SR); r = 1 - om; th = 2*ma.PI*fc/ma.SR; P = om*om + 4*r*sin(0.5*th)^2; S = om*om + 4*r*cos(0.5*th)^2; fq = om*(2 - om); };
tf2_tpt_slider_test = no.noise : fi.tf2_tpt(P, S, fq, 0, 0, fq) with { fc = hslider("fc", 1000, 20, 20000, 1); om = 0 - ma.expm1(0 - ma.PI*fc/10/ma.SR); r = 1 - om; th = 2*ma.PI*fc/ma.SR; P = om*om + 4*r*sin(0.5*th)^2; S = om*om + 4*r*cos(0.5*th)^2; fq = om*(2 - om); };
tf2_tpt_modulated_test = no.noise : fi.tf2_tpt(P, S, fq, 0, 0, fq) with { Pd = int(ma.SR/10); tri = 1 - abs(2*ba.period(Pd)/Pd - 1); fc = 20*pow(250, tri); om = 0 - ma.expm1(0 - ma.PI*fc/10/ma.SR); r = 1 - om; th = 2*ma.PI*fc/ma.SR; P = om*om + 4*r*sin(0.5*th)^2; S = om*om + 4*r*cos(0.5*th)^2; fq = om*(2 - om); };
tf2_tpt_jump_test = no.noise : fi.tf2_tpt(P, S, fq, 0, 0, fq) with { Pd = int(ma.SR/10); sq = ba.period(2*Pd) < Pd; fc = 20*pow(250.0, sq); om = 0 - ma.expm1(0 - ma.PI*fc/10/ma.SR); r = 1 - om; th = 2*ma.PI*fc/ma.SR; P = om*om + 4*r*sin(0.5*th)^2; S = om*om + 4*r*cos(0.5*th)^2; fq = om*(2 - om); };
tf2_tpt_audio_modulated_test = 0.1*no.noise : fi.tf2_tpt(P, S, fq, 0, 0, fq) with { fc = max(20, 1000*(1 + 0.9*os.tosc(500))); om = 0 - ma.expm1(0 - ma.PI*fc/10/ma.SR); r = 1 - om; th = 2*ma.PI*fc/ma.SR; P = om*om + 4*r*sin(0.5*th)^2; S = om*om + 4*r*cos(0.5*th)^2; fq = om*(2 - om); };
