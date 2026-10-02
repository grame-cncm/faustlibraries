//----------------------------------------------------------------------------
// filters_resonator_tests.dsp
// Tests for resonator helper functions.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");
no = library("noises.lib");
ba = library("basics.lib");
ma = library("maths.lib");

src = os.tosc(440);

resonlp_test = src : fi.resonlp(1000, 2, 0.8);
resonlp_slider_test = no.noise : fi.resonlp(hslider("fc", 1000, 20, 20000, 1), hslider("Q", 2, 0.5, 20, 0.01), hslider("gain", 0.8, 0, 1, 0.01));
resonlp_modulated_test = no.noise : fi.resonlp(20*pow(250, tri), 2, 0.8) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
resonhp_test = fi.resonhp(1000, 2, 0.8, src);
resonhp_slider_test = no.noise : fi.resonhp(hslider("fc", 1000, 20, 20000, 1), hslider("Q", 2, 0.5, 20, 0.01), hslider("gain", 0.8, 0, 1, 0.01));
resonhp_modulated_test = no.noise : fi.resonhp(20*pow(250, tri), 2, 0.8) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
resonbp_test = src : fi.resonbp(1000, 2, 0.8);
resonbp_slider_test = no.noise : fi.resonbp(hslider("fc", 1000, 20, 20000, 1), hslider("Q", 2, 0.5, 20, 0.01), hslider("gain", 0.8, 0, 1, 0.01));
resonbp_modulated_test = no.noise : fi.resonbp(20*pow(250, tri), 2, 0.8) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
