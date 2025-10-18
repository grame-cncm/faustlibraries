//----------------------------------------------------------------------------
// filters_elliptic_bandpass_tests.dsp
// Tests for elliptic bandpass helpers.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");

src = os.osc(440);

bandpass6e_test = src : fi.bandpass6e(500, 1500);
bandpass12e_test = src : fi.bandpass12e(500, 1500);
