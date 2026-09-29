//----------------------------------------------------------------------------
// filters_filterbank_tests.dsp
// Tests for arbitrary crossover filter bank helpers.
//----------------------------------------------------------------------------

import("tosc.lib");  // the test source without phase drift (tosc.lib)
fi = library("filters.lib");
os = library("oscillators.lib");

src = tosc(440);

filterbank_test = src : fi.filterbank(3, (500, 2000));
filterbanki_test = src : fi.filterbanki(3, (500, 2000));
