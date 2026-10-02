//----------------------------------------------------------------------------
// filters_parametric_eq_tests.dsp
// Tests for parametric equalizer helper functions.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");
ma = library("maths.lib");
no = library("noises.lib");
ba = library("basics.lib");

src = os.tosc(440);

lowshelf_test = src : fi.lowshelf(3, 6, 500);
lowshelf_slider_test = no.noise : fi.lowshelf(3, hslider("L0", 6, -24, 24, 0.1), hslider("fc", 500, 20, 20000, 1));
lowshelf_modulated_test = no.noise : fi.lowshelf(3, 6, 20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
lowshelf_jump_test = no.noise : fi.lowshelf(3, 6, 20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
low_shelf_test = src : fi.low_shelf(6, 500);
low_shelf_slider_test = no.noise : fi.low_shelf(hslider("L0", 6, -24, 24, 0.1), hslider("fc", 500, 20, 20000, 1));
low_shelf_modulated_test = no.noise : fi.low_shelf(6, 20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
low_shelf_jump_test = no.noise : fi.low_shelf(6, 20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
low_shelf1_test = fi.low_shelf1(2, 500, src);
low_shelf1_slider_test = no.noise : fi.low_shelf1(hslider("L0", 2, -24, 24, 0.1), hslider("fc", 500, 20, 20000, 1));
low_shelf1_modulated_test = no.noise : fi.low_shelf1(2, 20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
low_shelf1_jump_test = no.noise : fi.low_shelf1(2, 20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
low_shelf1_l_test = fi.low_shelf1_l(2, 500, src);
low_shelf1_l_slider_test = no.noise : fi.low_shelf1_l(hslider("G0", 2, 0, 16, 0.01), hslider("fc", 500, 20, 20000, 1));
low_shelf1_l_modulated_test = no.noise : fi.low_shelf1_l(2, 20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
low_shelf1_l_jump_test = no.noise : fi.low_shelf1_l(2, 20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
lowshelf_other_freq_test = fi.lowshelf_other_freq(3, 6, 500);
lowshelf_other_freq_slider_test = fi.lowshelf_other_freq(3, hslider("L0", 6, -24, 24, 0.1), hslider("fc", 500, 20, 20000, 1));
lowshelf_other_freq_modulated_test = fi.lowshelf_other_freq(3, 6, 20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
lowshelf_other_freq_jump_test = fi.lowshelf_other_freq(3, 6, 20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };

highshelf_test = src : fi.highshelf(3, 6, 2000);
highshelf_slider_test = no.noise : fi.highshelf(3, hslider("Lpi", 6, -24, 24, 0.1), hslider("fc", 2000, 20, 20000, 1));
highshelf_modulated_test = no.noise : fi.highshelf(3, 6, 20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
highshelf_jump_test = no.noise : fi.highshelf(3, 6, 20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
high_shelf_test = src : fi.high_shelf(6, 2000);
high_shelf_slider_test = no.noise : fi.high_shelf(hslider("Lpi", 6, -24, 24, 0.1), hslider("fc", 2000, 20, 20000, 1));
high_shelf_modulated_test = no.noise : fi.high_shelf(6, 20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
high_shelf_jump_test = no.noise : fi.high_shelf(6, 20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
high_shelf1_test = fi.high_shelf1(6, 2000, src);
high_shelf1_slider_test = no.noise : fi.high_shelf1(hslider("Lpi", 6, -24, 24, 0.1), hslider("fc", 2000, 20, 20000, 1));
high_shelf1_modulated_test = no.noise : fi.high_shelf1(6, 20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
high_shelf1_jump_test = no.noise : fi.high_shelf1(6, 20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
high_shelf1_l_test = fi.high_shelf1_l(2, 2000, src);
high_shelf1_l_slider_test = no.noise : fi.high_shelf1_l(hslider("Gpi", 2, 0, 16, 0.01), hslider("fc", 2000, 20, 20000, 1));
high_shelf1_l_modulated_test = no.noise : fi.high_shelf1_l(2, 20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
high_shelf1_l_jump_test = no.noise : fi.high_shelf1_l(2, 20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
highshelf_other_freq_test = fi.highshelf_other_freq(3, 6, 2000);
highshelf_other_freq_slider_test = fi.highshelf_other_freq(3, hslider("Lpi", 6, -24, 24, 0.1), hslider("fc", 2000, 20, 20000, 1));
highshelf_other_freq_modulated_test = fi.highshelf_other_freq(3, 6, 20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
highshelf_other_freq_jump_test = fi.highshelf_other_freq(3, 6, 20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };

peak_eq_test = src : fi.peak_eq(6, 1000, 200);
peak_eq_slider_test = no.noise : fi.peak_eq(hslider("Lfx", 6, -24, 24, 0.1), hslider("fc", 1000, 20, 20000, 1), hslider("B", 200, 1, 5000, 1));
peak_eq_modulated_test = no.noise : fi.peak_eq(6, fx, fx/5) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); fx = 20*pow(250, tri); };
peak_eq_cq_test = src : fi.peak_eq_cq(6, 1000, 4);
peak_eq_cq_slider_test = no.noise : fi.peak_eq_cq(hslider("Lfx", 6, -24, 24, 0.1), hslider("fc", 1000, 20, 20000, 1), hslider("Q", 4, 0.5, 20, 0.01));
peak_eq_cq_modulated_test = no.noise : fi.peak_eq_cq(6, 20*pow(250, tri), 4) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
peak_eq_rm_test = src : fi.peak_eq_rm(6, 1000, tan(ma.PI*200/ma.SR));
peak_eq_rm_slider_test = no.noise : fi.peak_eq_rm(hslider("Lfx", 6, -24, 24, 0.1), hslider("fc", 1000, 20, 20000, 1), tan(ma.PI*hslider("B", 200, 1, 5000, 1)/ma.SR));
peak_eq_rm_modulated_test = no.noise : fi.peak_eq_rm(6, fx, tan(ma.PI*fx/5/ma.SR)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); fx = 20*pow(250, tri); };

spectral_tilt_test = src : fi.spectral_tilt(4, 200, 2000, -0.5);
spectral_tilt_slider_test = no.noise : fi.spectral_tilt(4, hslider("f0", 200, 20, 2000, 1), hslider("bw", 2000, 100, 10000, 1), hslider("alpha", -0.5, -1, 1, 0.01));
spectral_tilt_modulated_test = no.noise : fi.spectral_tilt(4, 200, 2000, -1 + 2*tri) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
spectral_tilt_jump_test = no.noise : fi.spectral_tilt(4, 200, 2000, -1 + 2*sq) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };

levelfilter_test = fi.levelfilter(0.1, 200, src);
levelfilter_slider_test = fi.levelfilter(hslider("L", 0.1, -60, 20, 0.1), hslider("fc", 200, 20, 20000, 1), no.noise);
levelfilter_modulated_test = fi.levelfilter(0.1, 20*pow(250, tri), no.noise) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
levelfilter_jump_test = fi.levelfilter(0.1, 20*pow(250, sq), no.noise) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
levelfilterN_test = src : fi.levelfilterN(3, 200, 0.1);
levelfilterN_slider_test = no.noise : fi.levelfilterN(3, hslider("fc", 200, 20, 20000, 1), hslider("L", 0.1, -60, 20, 0.1));
levelfilterN_modulated_test = no.noise : fi.levelfilterN(3, 20*pow(250, tri), 0.1) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
levelfilterN_jump_test = no.noise : fi.levelfilterN(3, 20*pow(250, sq), 0.1) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
