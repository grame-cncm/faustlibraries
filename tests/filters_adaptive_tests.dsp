//----------------------------------------------------------------------------
// filters_adaptive_tests.dsp
// Tests for LMS/NLMS adaptive filters.
//----------------------------------------------------------------------------

fi = library("filters.lib");
no = library("noises.lib");

x = no.noise;
d = x@3 * 0.5 + x@1 * 0.25;

lms_test = x, d : fi.lms(8, 0.05);
nlms_test = x, d : fi.nlms(8, 0.5);
