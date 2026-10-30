//----------------------------------------------------------------------------
// platform_tests.dsp
// Tests of platform.lib.
//----------------------------------------------------------------------------

pl = library("platform.lib");

pl_SR_test = pl.SR;
pl_BS_test = pl.BS > 0;
tablesize_test = pl.tablesize;
