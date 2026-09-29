//----------------------------------------------------------------------------
// filters_mth_octave_filterbank_tests.dsp
// Tests for Mth-octave filter bank helpers.
//----------------------------------------------------------------------------

import("tosc.lib");  // the test source without phase drift (tosc.lib)
fi = library("filters.lib");
os = library("oscillators.lib");

sig = tosc(440);

mth_octave_filterbank_test = sig : fi.mth_octave_filterbank(3, 2, 8000, 2);
mth_octave_filterbank_alt_test = sig : fi.mth_octave_filterbank_alt(3, 2, 8000, 2);
mth_octave_filterbank3_test = sig : fi.mth_octave_filterbank3(2, 8000, 2);
mth_octave_filterbank5_test = sig : fi.mth_octave_filterbank5(2, 8000, 2);
mth_octave_filterbank_default_test = sig : fi.mth_octave_filterbank_default(2, 8000, 2);
