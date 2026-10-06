//----------------------------------------------------------------------------
// filters_kalman_tests.dsp
// Tests of filters.lib.
//----------------------------------------------------------------------------

ba = library("basics.lib");
fi = library("filters.lib");
no = library("noises.lib");
ma = library("maths.lib");

kalman_test = fi.kalman(1, 1, 1, 0.1, 1, 0.01, 1, 0, 0, z) with { P = int(ma.SR/10); z = 0.5*(1 - abs(2*ba.period(P)/P - 1)) + 0.1*no.noise; };
