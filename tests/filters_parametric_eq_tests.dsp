//----------------------------------------------------------------------------
// filters_parametric_eq_tests.dsp
// Tests for parametric equalizer helper functions.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");
ma = library("maths.lib");

src = os.osc(440);

lowshelf_test = src : fi.lowshelf(3, 6, 500);
low_shelf_test = src : fi.low_shelf(6, 500);
low_shelf1_test = fi.low_shelf1(6, 500, src);
low_shelf1_l_test = fi.low_shelf1_l(2, 500, src);
lowshelf_other_freq_test = fi.lowshelf_other_freq(3, 6, 500);

highshelf_test = src : fi.highshelf(3, 6, 2000);
high_shelf_test = src : fi.high_shelf(6, 2000);
high_shelf1_test = fi.high_shelf1(6, 2000, src);
high_shelf1_l_test = fi.high_shelf1_l(2, 2000, src);
highshelf_other_freq_test = fi.highshelf_other_freq(3, 6, 2000);

peak_eq_test = src : fi.peak_eq(6, 1000, 200);
peak_eq_cq_test = src : fi.peak_eq_cq(6, 1000, 4);
peak_eq_rm_test = src : fi.peak_eq_rm(6, 1000, tan(ma.PI*200/ma.SR));

spectral_tilt_test = src : fi.spectral_tilt(4, 200, 2000, -0.5);

levelfilter_test = fi.levelfilter(0.1, 200, src);
levelfilterN_test = src : fi.levelfilterN(3, 200, 0.1);
