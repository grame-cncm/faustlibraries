//----------------------------------------------------------------------------
// filters_delay_equalizing_allpass_tests.dsp
// Tests for special filter-bank delay-equalizing allpass helper functions.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");
no = library("noises.lib");
ba = library("basics.lib");
ma = library("maths.lib");

highpass_plus_lowpass_test = os.tosc(440) : fi.highpass_plus_lowpass(3, 1000);
highpass_plus_lowpass_slider_test = no.noise : fi.highpass_plus_lowpass(3, hslider("fc", 1000, 20, 20000, 1));
highpass_plus_lowpass_modulated_test = no.noise : fi.highpass_plus_lowpass(3, 20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
highpass_minus_lowpass_test = os.tosc(440) : fi.highpass_minus_lowpass(3, 1000);
highpass_minus_lowpass_slider_test = no.noise : fi.highpass_minus_lowpass(3, hslider("fc", 1000, 20, 20000, 1));
highpass_minus_lowpass_modulated_test = no.noise : fi.highpass_minus_lowpass(3, 20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
highpass_minus_lowpass_jump_test = no.noise : fi.highpass_minus_lowpass(3, 20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
highpass_plus_lowpass_even_test = os.tosc(440), os.tosc(440) : fi.highpass_plus_lowpass_even(4, 1000);
highpass_plus_lowpass_even_slider_test = (no.noise <: _, _) : fi.highpass_plus_lowpass_even(4, hslider("fc", 1000, 20, 20000, 1));
highpass_plus_lowpass_even_modulated_test = (no.noise <: _, _) : fi.highpass_plus_lowpass_even(4, 20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
highpass_plus_lowpass_even_jump_test = (no.noise <: _, _) : fi.highpass_plus_lowpass_even(4, 20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
highpass_minus_lowpass_even_test = os.tosc(440), os.tosc(440) : fi.highpass_minus_lowpass_even(4, 1000);
highpass_minus_lowpass_even_slider_test = (no.noise <: _, _) : fi.highpass_minus_lowpass_even(4, hslider("fc", 1000, 20, 20000, 1));
highpass_minus_lowpass_even_modulated_test = (no.noise <: _, _) : fi.highpass_minus_lowpass_even(4, 20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
highpass_minus_lowpass_even_jump_test = (no.noise <: _, _) : fi.highpass_minus_lowpass_even(4, 20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
highpass_plus_lowpass_odd_test = os.tosc(440), os.tosc(440) : fi.highpass_plus_lowpass_odd(3, 1000);
highpass_plus_lowpass_odd_slider_test = (no.noise <: _, _) : fi.highpass_plus_lowpass_odd(3, hslider("fc", 1000, 20, 20000, 1));
highpass_plus_lowpass_odd_modulated_test = (no.noise <: _, _) : fi.highpass_plus_lowpass_odd(3, 20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
highpass_plus_lowpass_odd_jump_test = (no.noise <: _, _) : fi.highpass_plus_lowpass_odd(3, 20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
highpass_minus_lowpass_odd_test = os.tosc(440), os.tosc(440) : fi.highpass_minus_lowpass_odd(3, 1000);
highpass_minus_lowpass_odd_slider_test = (no.noise <: _, _) : fi.highpass_minus_lowpass_odd(3, hslider("fc", 1000, 20, 20000, 1));
highpass_minus_lowpass_odd_modulated_test = (no.noise <: _, _) : fi.highpass_minus_lowpass_odd(3, 20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
highpass_minus_lowpass_odd_jump_test = (no.noise <: _, _) : fi.highpass_minus_lowpass_odd(3, 20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
