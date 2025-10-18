//----------------------------------------------------------------------------
// filters_state_variable_tests.dsp
// Tests for state-variable filter helpers and related utilities.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");

sig = os.osc(440);

svf_lp_test = fi.svf.lp(1000, 0.707, sig);
svf_bp_test = fi.svf.bp(1000, 0.707, sig);
svf_hp_test = fi.svf.hp(1000, 0.707, sig);
svf_notch_test = fi.svf.notch(1000, 0.707, sig);
svf_peak_test = fi.svf.peak(1000, 0.707, sig);
svf_ap_test = fi.svf.ap(1000, 0.707, sig);
svf_bell_test = fi.svf.bell(1000, 0.707, 6, sig);
svf_ls_test = fi.svf.ls(500, 0.707, 6, sig);
svf_hs_test = fi.svf.hs(3000, 0.707, 6, sig);

svf_morph_test = fi.svf_morph(1000, 0.707, 1, sig);
svf_notch_morph_test = fi.svf_notch_morph(1000, 0.707, 1, sig);

SVFTPT_SVF_test = fi.SVFTPT.SVF(1000, 0.707, sig);
SVFTPT_LP2_test = fi.SVFTPT.LP2(1000, 0.707, sig);
SVFTPT_HP2_test = fi.SVFTPT.HP2(1000, 0.707, sig);
SVFTPT_BP2_test = fi.SVFTPT.BP2(1000, 0.707, sig);
SVFTPT_BP2Norm_test = fi.SVFTPT.BP2Norm(1000, 0.707, sig);
SVFTPT_Notch2_test = fi.SVFTPT.Notch2(1000, 0.707, sig);
SVFTPT_AP2_test = fi.SVFTPT.AP2(1000, 0.707, sig);
SVFTPT_Peaking2_test = fi.SVFTPT.Peaking2(1000, 0.707, sig);

dynamicSmoothing_test = fi.dynamicSmoothing(0.5, 500, sig);
oneEuro_test = sig : fi.oneEuro(1, 0.5, 5);
