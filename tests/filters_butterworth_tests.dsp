//----------------------------------------------------------------------------
// filters_butterworth_tests.dsp
// Tests for basic Butterworth helper filters.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");
no = library("noises.lib");
ba = library("basics.lib");
ma = library("maths.lib");

src = os.tosc(440);

lowpass_test = src : fi.lowpass(4, 2000);
lowpass_lowfc_test = no.noise : fi.lowpass(3, 10.1);
lowpass_slider_test = no.noise : fi.lowpass(4, hslider("fc", 2000, 20, 20000, 1));
lowpass_modulated_test = no.noise : fi.lowpass(4, 20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
lowpass_jump_test = no.noise : fi.lowpass(4, 20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
highpass_test = src : fi.highpass(4, 500);
highpass_lowfc_test = no.noise : fi.highpass(3, 10.1);
highpass_slider_test = no.noise : fi.highpass(4, hslider("fc", 500, 20, 20000, 1));
highpass_modulated_test = no.noise : fi.highpass(4, 20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
highpass_jump_test = no.noise : fi.highpass(4, 20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
lowpass0_highpass1_test = src : fi.lowpass0_highpass1(0, 2, 1000);
lowpass0_highpass1_slider_test = no.noise : fi.lowpass0_highpass1(0, 2, hslider("fc", 1000, 20, 20000, 1));
lowpass0_highpass1_modulated_test = no.noise : fi.lowpass0_highpass1(0, 2, 20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
lowpass0_highpass1_jump_test = no.noise : fi.lowpass0_highpass1(0, 2, 20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
