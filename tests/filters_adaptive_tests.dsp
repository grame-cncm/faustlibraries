//----------------------------------------------------------------------------
// filters_adaptive_tests.dsp
// Tests for LMS/NLMS adaptive filters.
//----------------------------------------------------------------------------

fi = library("filters.lib");
no = library("noises.lib");

lms_test = no.noise, (no.noise : @(3)*0.5 + no.noise@(1)*0.25) : fi.lms(8, 0.01);
nlms_test = no.noise, (no.noise : @(3)*0.5 + no.noise@(1)*0.25) : fi.nlms(8, 0.5);
adaptFIR_test = no.noise, (no.noise : @(3)*0.5 + no.noise@(1)*0.25)
    : fi.adaptFIR(8, 0.01);
