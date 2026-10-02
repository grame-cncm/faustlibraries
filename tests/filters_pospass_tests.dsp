//----------------------------------------------------------------------------
// filters_pospass_tests.dsp
// Tests for positive-pass (single-side-band) filters.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");
no = library("noises.lib");
ba = library("basics.lib");
ma = library("maths.lib");

src = os.tosc(440);

pospass_test = src : fi.pospass(3, 1000);
pospass_slider_test = no.noise : fi.pospass(3, hslider("fc", 1000, 20, 20000, 1));
pospass_modulated_test = no.noise : fi.pospass(3, 20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
pospass6e_test = os.tosc(440) : fi.pospass6e(100);
pospass6e_slider_test = no.noise : fi.pospass6e(hslider("fc", 100, 20, 20000, 1));
pospass6e_modulated_test = no.noise : fi.pospass6e(20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };

hilbert_test = os.tosc(440) : fi.hilbert(4, 20);
hilbert_slider_test = no.noise : fi.hilbert(4, hslider("fc", 20, 5, 500, 1));
hilbert_modulated_test = no.noise : fi.hilbert(4, 10*pow(10, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
