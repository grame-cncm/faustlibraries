//----------------------------------------------------------------------------
// filters_bandpass_bandstop_tests.dsp
// Tests for Butterworth bandpass/bandstop helper functions.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");
no = library("noises.lib");
ba = library("basics.lib");

src = os.osc(440);

bandpass_test = src : fi.bandpass(2, 500, 1500);
bandpass_lowband_test = no.noise : fi.bandpass(2, 100, 200);
bandpass_slider_test = no.noise : fi.bandpass(2, hslider("fl", 500, 20, 20000, 1), hslider("fu", 1500, 20, 20000, 1));
bandpass_modulated_test = no.noise : fi.bandpass(2, fl, 3*fl) with { tri = 1 - abs(2*ba.period(4800)/4800 - 1); fl = 20*pow(250, tri); };
bandstop_test = src : fi.bandstop(2, 500, 1500);
bandstop_wide_test = no.noise : fi.bandstop(2, 5000, 8000);
bandstop_slider_test = no.noise : fi.bandstop(2, hslider("fl", 500, 20, 20000, 1), hslider("fu", 1500, 20, 20000, 1));
bandstop_modulated_test = no.noise : fi.bandstop(2, fl, 3*fl) with { tri = 1 - abs(2*ba.period(4800)/4800 - 1); fl = 20*pow(250, tri); };
bandpass0_bandstop1_test = src : fi.bandpass0_bandstop1(0, 2, 500, 1500);
bandpass0_bandstop1_slider_test = no.noise : fi.bandpass0_bandstop1(0, 2, hslider("fl", 500, 20, 20000, 1), hslider("fu", 1500, 20, 20000, 1));
bandpass0_bandstop1_modulated_test = no.noise : fi.bandpass0_bandstop1(0, 2, fl, 3*fl) with { tri = 1 - abs(2*ba.period(4800)/4800 - 1); fl = 20*pow(250, tri); };
