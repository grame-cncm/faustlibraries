//----------------------------------------------------------------------------
// filters_delay_equalizing_allpass_tests.dsp
// Tests for special filter-bank delay-equalizing allpass helper functions.
//----------------------------------------------------------------------------

fi = library("filters.lib");

highpass_plus_lowpass_test = fi.highpass_plus_lowpass(3, 1000);
highpass_minus_lowpass_test = fi.highpass_minus_lowpass(3, 1000);
highpass_plus_lowpass_even_test = fi.highpass_plus_lowpass_even(4, 1000);
highpass_minus_lowpass_even_test = fi.highpass_minus_lowpass_even(4, 1000);
highpass_plus_lowpass_odd_test = fi.highpass_plus_lowpass_odd(3, 1000);
highpass_minus_lowpass_odd_test = fi.highpass_minus_lowpass_odd(3, 1000);
