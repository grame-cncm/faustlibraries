//----------------------------------------------------------------------------
// filters_useful_special_tests.dsp
// Tests for useful special-case filters.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");
no = library("noises.lib");
ba = library("basics.lib");
ma = library("maths.lib");

src = os.tosc(440);

tf2np_test = src : fi.tf2np(0.6, 0.3, 0.2, -0.5, 0.2);
wgr_test = fi.wgr(440, 0.995, src);
wgr_slider_test = fi.wgr(hslider("freq", 440, 20, 5000, 1), hslider("r", 0.995, 0.9, 1, 0.001), no.noise);
wgr_modulated_test = fi.wgr(100*pow(20, tri), 0.995, no.noise) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
wgr_zero_freq_test = fi.wgr(1000*(ba.time >= 100), 0.995, no.noise);
nlf2_test = fi.nlf2(440, 0.995, src);
nlf2_slider_test = fi.nlf2(hslider("freq", 440, 20, 5000, 1), hslider("r", 0.995, 0.9, 1, 0.001), no.noise);
nlf2_modulated_test = fi.nlf2(100*pow(20, tri), 0.995, no.noise) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
nlf2_jump_test = fi.nlf2(100*pow(20, sq), 0.995, no.noise) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
apnl_test = fi.apnl(0.5, -0.5, src);
apnl_noise_test = fi.apnl(0.9, 0.1, no.noise);
itu_r_bs_1770_4_kfilter_test = src : fi.itu_r_bs_1770_4_kfilter;
