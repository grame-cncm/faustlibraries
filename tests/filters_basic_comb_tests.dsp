//----------------------------------------------------------------------------
// filters_basic_comb_tests.dsp
// Tests for basic and comb envelope helpers.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");

src = os.osc(440);

zero_test = src : fi.zero(0.5);
pole_test = src : fi.pole(0.9);
integrator_test = src : fi.integrator;
dcblockerat_test = src : fi.dcblockerat(30);
dcblocker_test = src : fi.dcblocker;
lptN_test = src : fi.lptN(60, 0.1);
lptau_test = src : fi.lptau(0.1);
lpt60_test = src : fi.lpt60(0.3);
lpt19_test = src : fi.lpt19(0.2);

ff_comb_test = src : fi.ff_comb(2048, 64, 1, 0.7);
ff_fcomb_test = src : fi.ff_fcomb(2048, 64.5, 1, 0.7);
ffcombfilter_test = src : fi.ffcombfilter(2048, 64, 0.7);
fb_comb_common_test = src : fi.fb_comb_common(@, 64, 0.8, 0.6);
fb_comb_test = src : fi.fb_comb(2048, 64, 0.7, 0.6);
fb_fcomb_test = src : fi.fb_fcomb(2048, 64.5, 0.7, 0.6);
rev1_test = src : fi.rev1(2048, 64, 0.6);
fbcombfilter_test = src : fi.fbcombfilter(2048, 64, 0.6);
ffbcombfilter_test = src : fi.ffbcombfilter(2048, 64.5, 0.6);
allpass_comb_test = src : fi.allpass_comb(2048, 64, 0.6);
allpass_fcomb_test = src : fi.allpass_fcomb(2048, 64.5, 0.6);
rev2_test = src : fi.rev2(2048, 64, 0.6);
allpass_fcomb5_test = src : fi.allpass_fcomb5(2048, 64.5, 0.6);
allpass_fcomb1a_test = src : fi.allpass_fcomb1a(2048, 64.5, 0.6);
