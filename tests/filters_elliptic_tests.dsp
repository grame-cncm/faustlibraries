//----------------------------------------------------------------------------
// filters_elliptic_tests.dsp
// Tests for elliptic (Cauer) lowpass/highpass helper filters.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");

src = os.osc(440);

lowpass3e_test = src : fi.lowpass3e(1000);
lowpass6e_test = src : fi.lowpass6e(1000);
highpass3e_test = src : fi.highpass3e(1000);
highpass6e_test = src : fi.highpass6e(1000);
