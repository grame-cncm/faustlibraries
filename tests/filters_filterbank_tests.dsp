//----------------------------------------------------------------------------
// filters_filterbank_tests.dsp
// Tests for arbitrary crossover filter bank helpers.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");
no = library("noises.lib");

src = os.tosc(440);

filterbank_test = src : fi.filterbank(3, (500, 2000));
filterbanki_test = src : fi.filterbanki(3, (500, 2000));
filterbanki_o5_sum_test = no.noise : fi.filterbanki(5, (500, 1000, 2000)) :> _;
