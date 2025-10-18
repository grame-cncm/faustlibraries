//----------------------------------------------------------------------------
// filters_resonator_tests.dsp
// Tests for resonator helper functions.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");

src = os.osc(440);

resonlp_test = src : fi.resonlp(1000, 2, 0.8);
resonhp_test = fi.resonhp(1000, 2, 0.8, src);
resonbp_test = src : fi.resonbp(1000, 2, 0.8);
