//----------------------------------------------------------------------------
// filters_bandpass_bandstop_tests.dsp
// Tests for Butterworth bandpass/bandstop helper functions.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");

src = os.osc(440);

bandpass_test = src : fi.bandpass(2, 500, 1500);
bandstop_test = src : fi.bandstop(2, 500, 1500);
bandpass0_bandstop1_test = src : fi.bandpass0_bandstop1(0, 2, 500, 1500);
