//----------------------------------------------------------------------------
// filters_linkwitz_riley_tests.dsp
// Tests for Linkwitz-Riley crossover helpers.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");
no = library("noises.lib");
ba = library("basics.lib");
ma = library("maths.lib");

src = os.tosc(440);

lowpassLR4_test = src : fi.lowpassLR4(1000);
lowpassLR4_slider_test = no.noise : fi.lowpassLR4(hslider("fc", 1000, 20, 20000, 1));
lowpassLR4_modulated_test = no.noise : fi.lowpassLR4(20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
highpassLR4_test = src : fi.highpassLR4(1000);
highpassLR4_slider_test = no.noise : fi.highpassLR4(hslider("fc", 1000, 20, 20000, 1));
highpassLR4_modulated_test = no.noise : fi.highpassLR4(20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
crossover2LR4_test = src : fi.crossover2LR4(1000);
crossover2LR4_slider_test = no.noise : fi.crossover2LR4(hslider("fc", 1000, 20, 20000, 1));
crossover2LR4_modulated_test = no.noise : fi.crossover2LR4(20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
crossover3LR4_test = src : fi.crossover3LR4(500, 2000);
crossover3LR4_slider_test = no.noise : fi.crossover3LR4(hslider("cf1", 500, 20, 20000, 1), hslider("cf2", 2000, 20, 20000, 1));
crossover3LR4_modulated_test = no.noise : fi.crossover3LR4(cf, 4*cf) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); cf = 20*pow(60, tri); };
crossover4LR4_test = src : fi.crossover4LR4(300, 1000, 3000);
crossover4LR4_slider_test = no.noise : fi.crossover4LR4(hslider("cf1", 300, 20, 20000, 1), hslider("cf2", 1000, 20, 20000, 1), hslider("cf3", 3000, 20, 20000, 1));
crossover4LR4_modulated_test = no.noise : fi.crossover4LR4(cf, 3*cf, 9*cf) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); cf = 20*pow(25, tri); };
crossover8LR4_test = src : fi.crossover8LR4(100, 200, 400, 800, 1600, 3200, 6400);
crossover8LR4_slider_test = no.noise : fi.crossover8LR4(hslider("cf1", 100, 20, 20000, 1), hslider("cf2", 200, 20, 20000, 1), hslider("cf3", 400, 20, 20000, 1), hslider("cf4", 800, 20, 20000, 1), hslider("cf5", 1600, 20, 20000, 1), hslider("cf6", 3200, 20, 20000, 1), hslider("cf7", 6400, 20, 20000, 1));
crossover8LR4_modulated_test = no.noise : fi.crossover8LR4(cf, 2*cf, 4*cf, 8*cf, 16*cf, 32*cf, 64*cf) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); cf = 20*pow(4, tri); };
