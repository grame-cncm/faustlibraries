//----------------------------------------------------------------------------
// filters_useful_special_tests.dsp
// Tests for useful special-case filters.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");

src = os.osc(440);

tf2np_test = src : fi.tf2np(0.6, 0.3, 0.2, -0.5, 0.2);
wgr_test = fi.wgr(440, 0.995, src);
nlf2_test = fi.nlf2(440, 0.995, src);
apnl_test = fi.apnl(0.5, -0.5, src);
