//----------------------------------------------------------------------------
// filters_elliptic_bandpass_tests.dsp
// Tests for elliptic bandpass helpers.
//----------------------------------------------------------------------------

import("tosc.lib");  // the test source without phase drift (tosc.lib)
fi = library("filters.lib");
os = library("oscillators.lib");
no = library("noises.lib");
ba = library("basics.lib");

src = tosc(440);

bandpass6e_test = src : fi.bandpass6e(500, 1500);
bandpass6e_slider_test = no.noise : fi.bandpass6e(hslider("fl", 500, 20, 20000, 1), hslider("fu", 1500, 20, 20000, 1));
bandpass6e_modulated_test = no.noise : fi.bandpass6e(fl, 3*fl) with { tri = 1 - abs(2*ba.period(4800)/4800 - 1); fl = 20*pow(250, tri); };
bandpass12e_test = src : fi.bandpass12e(500, 1500);
bandpass12e_slider_test = no.noise : fi.bandpass12e(hslider("fl", 500, 20, 20000, 1), hslider("fu", 1500, 20, 20000, 1));
bandpass12e_modulated_test = no.noise : fi.bandpass12e(fl, 3*fl) with { tri = 1 - abs(2*ba.period(4800)/4800 - 1); fl = 20*pow(250, tri); };
