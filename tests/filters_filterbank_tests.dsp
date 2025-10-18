//----------------------------------------------------------------------------
// filters_filterbank_tests.dsp
// Tests for arbitrary crossover filter bank helpers.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");

src = os.osc(440);

filterbank_test = src : fi.filterbank(3, (500, 2000));
filterbanki_test = src : fi.filterbanki(3, (500, 2000));
