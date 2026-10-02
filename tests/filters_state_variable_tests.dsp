//----------------------------------------------------------------------------
// filters_state_variable_tests.dsp
// Tests for state-variable filter helpers and related utilities.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");
no = library("noises.lib");
ba = library("basics.lib");

sig = os.tosc(440);

svf_lp_test = fi.svf.lp(1000, 0.707, sig);
svf_bp_test = fi.svf.bp(1000, 0.707, sig);
svf_hp_test = fi.svf.hp(1000, 0.707, sig);
svf_notch_test = fi.svf.notch(1000, 0.707, sig);
svf_peak_test = fi.svf.peak(1000, 0.707, sig);
svf_ap_test = fi.svf.ap(1000, 0.707, sig);
svf_bell_test = fi.svf.bell(1000, 0.707, 6, sig);
svf_ls_test = fi.svf.ls(500, 0.707, 6, sig);
svf_hs_test = fi.svf.hs(3000, 0.707, 6, sig);
svf_slider_test = no.noise : fi.svf.bell(hslider("fc", 1000, 20, 20000, 1), hslider("Q", 0.707, 0.5, 20, 0.01), hslider("gain", 6, -24, 24, 0.1));
svf_modulated_test = no.noise : fi.svf.lp(20*pow(250, tri), 0.707) with { tri = 1 - abs(2*ba.period(4800)/4800 - 1); };

svf_morph_test = fi.svf_morph(1000, 0.707, 1, sig);
svf_morph_slider_test = fi.svf_morph(hslider("fc", 1000, 20, 20000, 1), hslider("Q", 0.707, 0.5, 20, 0.01), hslider("blend", 1, 0, 2, 0.01), no.noise);
svf_morph_modulated_test = fi.svf_morph(20*pow(250, tri), 0.707, 2*tri, no.noise) with { tri = 1 - abs(2*ba.period(4800)/4800 - 1); };
svf_notch_morph_test = fi.svf_notch_morph(1000, 0.707, 1, sig);
svf_notch_morph_slider_test = fi.svf_notch_morph(hslider("fc", 1000, 20, 20000, 1), hslider("Q", 0.707, 0.5, 20, 0.01), hslider("blend", 1, 0, 2, 0.01), no.noise);
svf_notch_morph_modulated_test = fi.svf_notch_morph(20*pow(250, tri), 0.707, 2*tri, no.noise) with { tri = 1 - abs(2*ba.period(4800)/4800 - 1); };

SVFTPT_SVF_test = fi.SVFTPT.SVF(1000, 0.707, sig);
SVFTPT_LP2_test = fi.SVFTPT.LP2(1000, 0.707, sig);
SVFTPT_HP2_test = fi.SVFTPT.HP2(1000, 0.707, sig);
SVFTPT_BP2_test = fi.SVFTPT.BP2(1000, 0.707, sig);
SVFTPT_BP2Norm_test = fi.SVFTPT.BP2Norm(1000, 0.707, sig);
SVFTPT_Notch2_test = fi.SVFTPT.Notch2(1000, 0.707, sig);
SVFTPT_AP2_test = fi.SVFTPT.AP2(1000, 0.707, sig);
SVFTPT_Peaking2_test = fi.SVFTPT.Peaking2(1000, 0.707, sig);
SVFTPT_slider_test = fi.SVFTPT.SVF(hslider("fc", 1000, 20, 20000, 1), hslider("Q", 0.707, 0.5, 20, 0.01), no.noise);
SVFTPT_modulated_test = fi.SVFTPT.SVF(20*pow(250, tri), 0.707, no.noise) with { tri = 1 - abs(2*ba.period(4800)/4800 - 1); };

dynamicSmoothing_test = fi.dynamicSmoothing(0.5, 500, sig);
dynamicSmoothing_slider_test = fi.dynamicSmoothing(hslider("sensitivity", 0.5, 0, 1, 0.01), hslider("fc", 500, 20, 20000, 1), no.noise);
dynamicSmoothing_modulated_test = fi.dynamicSmoothing(0.5, 20*pow(250, tri), no.noise) with { tri = 1 - abs(2*ba.period(4800)/4800 - 1); };
oneEuro_test = sig : fi.oneEuro(1, 0.5, 5);
oneEuro_slider_test = no.noise : fi.oneEuro(hslider("derivativeCutoff", 1, 0.1, 10, 0.1), hslider("beta", 0.5, 0, 1, 0.01), hslider("minCutoff", 5, 0.1, 50, 0.1));
oneEuro_modulated_test = no.noise : fi.oneEuro(1, 0.5, pow(50, tri)) with { tri = 1 - abs(2*ba.period(4800)/4800 - 1); };
