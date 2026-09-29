//----------------------------------------------------------------------------
// filters_elliptic_tests.dsp
// Tests for elliptic (Cauer) lowpass/highpass helper filters.
//----------------------------------------------------------------------------

import("tosc.lib");  // the test source without phase drift (tosc.lib)
fi = library("filters.lib");
os = library("oscillators.lib");
no = library("noises.lib");
ba = library("basics.lib");

src = tosc(440);

lowpass3e_test = src : fi.lowpass3e(1000);
lowpass3e_slider_test = no.noise : fi.lowpass3e(hslider("fc", 1000, 20, 20000, 1));
lowpass6e_test = src : fi.lowpass6e(1000);
lowpass6e_slider_test = no.noise : fi.lowpass6e(hslider("fc", 1000, 20, 20000, 1));
highpass3e_test = src : fi.highpass3e(1000);
highpass3e_slider_test = no.noise : fi.highpass3e(hslider("fc", 1000, 20, 20000, 1));
highpass3e_modulated_test = no.noise : fi.highpass3e(20*pow(250, tri)) with { tri = 1 - abs(2*ba.period(4800)/4800 - 1); };
highpass6e_test = src : fi.highpass6e(1000);
highpass6e_slider_test = no.noise : fi.highpass6e(hslider("fc", 1000, 20, 20000, 1));
highpass6e_modulated_test = no.noise : fi.highpass6e(20*pow(250, tri)) with { tri = 1 - abs(2*ba.period(4800)/4800 - 1); };
