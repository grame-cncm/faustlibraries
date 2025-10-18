//----------------------------------------------------------------------------
// filters_linkwitz_riley_tests.dsp
// Tests for Linkwitz-Riley crossover helpers.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");

src = os.osc(440);

lowpassLR4_test = src : fi.lowpassLR4(1000);
highpassLR4_test = src : fi.highpassLR4(1000);
crossover2LR4_test = src : fi.crossover2LR4(1000);
crossover3LR4_test = src : fi.crossover3LR4(500, 2000);
crossover4LR4_test = src : fi.crossover4LR4(300, 1000, 3000);
crossover8LR4_test = src : fi.crossover8LR4(100, 200, 400, 800, 1600, 3200, 6400);
