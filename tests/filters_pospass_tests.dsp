//----------------------------------------------------------------------------
// filters_pospass_tests.dsp
// Tests for positive-pass (single-side-band) filters.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");

src = os.osc(440);

pospass_test = src : fi.pospass(3, 1000);
pospass6e_test = src : fi.pospass6e(1000);
