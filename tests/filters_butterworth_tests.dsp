//----------------------------------------------------------------------------
// filters_butterworth_tests.dsp
// Tests for basic Butterworth helper filters.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");
no = library("noises.lib");

src = os.osc(440);

lowpass_test = src : fi.lowpass(4, 2000);
lowpass_lowfc_test = no.noise : fi.lowpass(3, 10.1);
highpass_test = src : fi.highpass(4, 500);
highpass_lowfc_test = no.noise : fi.highpass(3, 10.1);
lowpass0_highpass1_test = src : fi.lowpass0_highpass1(0, 2, 1000);
