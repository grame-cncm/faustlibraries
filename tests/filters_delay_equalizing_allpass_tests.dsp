//----------------------------------------------------------------------------
// filters_delay_equalizing_allpass_tests.dsp
// Tests for special filter-bank delay-equalizing allpass helper functions.
//----------------------------------------------------------------------------

import("tosc.lib");  // the test source without phase drift (tosc.lib)
fi = library("filters.lib");
os = library("oscillators.lib");
no = library("noises.lib");
ba = library("basics.lib");

highpass_plus_lowpass_test = tosc(440) : fi.highpass_plus_lowpass(3, 1000);
highpass_plus_lowpass_slider_test = no.noise : fi.highpass_plus_lowpass(3, hslider("fc", 1000, 20, 20000, 1));
highpass_plus_lowpass_modulated_test = no.noise : fi.highpass_plus_lowpass(3, 20*pow(250, tri)) with { tri = 1 - abs(2*ba.period(4800)/4800 - 1); };
highpass_minus_lowpass_test = tosc(440) : fi.highpass_minus_lowpass(3, 1000);
highpass_minus_lowpass_slider_test = no.noise : fi.highpass_minus_lowpass(3, hslider("fc", 1000, 20, 20000, 1));
highpass_minus_lowpass_modulated_test = no.noise : fi.highpass_minus_lowpass(3, 20*pow(250, tri)) with { tri = 1 - abs(2*ba.period(4800)/4800 - 1); };
highpass_plus_lowpass_even_test = tosc(440), tosc(440) : fi.highpass_plus_lowpass_even(4, 1000);
highpass_plus_lowpass_even_slider_test = (no.noise <: _, _) : fi.highpass_plus_lowpass_even(4, hslider("fc", 1000, 20, 20000, 1));
highpass_plus_lowpass_even_modulated_test = (no.noise <: _, _) : fi.highpass_plus_lowpass_even(4, 20*pow(250, tri)) with { tri = 1 - abs(2*ba.period(4800)/4800 - 1); };
highpass_minus_lowpass_even_test = tosc(440), tosc(440) : fi.highpass_minus_lowpass_even(4, 1000);
highpass_minus_lowpass_even_slider_test = (no.noise <: _, _) : fi.highpass_minus_lowpass_even(4, hslider("fc", 1000, 20, 20000, 1));
highpass_minus_lowpass_even_modulated_test = (no.noise <: _, _) : fi.highpass_minus_lowpass_even(4, 20*pow(250, tri)) with { tri = 1 - abs(2*ba.period(4800)/4800 - 1); };
highpass_plus_lowpass_odd_test = tosc(440), tosc(440) : fi.highpass_plus_lowpass_odd(3, 1000);
highpass_plus_lowpass_odd_slider_test = (no.noise <: _, _) : fi.highpass_plus_lowpass_odd(3, hslider("fc", 1000, 20, 20000, 1));
highpass_plus_lowpass_odd_modulated_test = (no.noise <: _, _) : fi.highpass_plus_lowpass_odd(3, 20*pow(250, tri)) with { tri = 1 - abs(2*ba.period(4800)/4800 - 1); };
highpass_minus_lowpass_odd_test = tosc(440), tosc(440) : fi.highpass_minus_lowpass_odd(3, 1000);
highpass_minus_lowpass_odd_slider_test = (no.noise <: _, _) : fi.highpass_minus_lowpass_odd(3, hslider("fc", 1000, 20, 20000, 1));
highpass_minus_lowpass_odd_modulated_test = (no.noise <: _, _) : fi.highpass_minus_lowpass_odd(3, 20*pow(250, tri)) with { tri = 1 - abs(2*ba.period(4800)/4800 - 1); };
