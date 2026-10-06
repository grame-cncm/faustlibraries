//----------------------------------------------------------------------------
// maxmsp_tests.dsp
// Tests for the MaxMSP compatibility library.
//----------------------------------------------------------------------------

mm = library("maxmsp.lib");
os = library("oscillators.lib");

mm_atodb_test = 0.5 : mm.atodb;
mm_filtercoeff_test = mm.filtercoeff(1000, 6, 1).LPF;
mm_biquad_test = mm.biquad(os.tosc(440), 0.5, 0.2, 0.1, 0.1, 0.05);
mm_LPF_test = mm.LPF(os.tosc(440), 1000, 0, 1);
mm_HPF_test = mm.HPF(os.tosc(440), 1000, 0, 1);
mm_BPF_test = mm.BPF(os.tosc(440), 1000, 0, 1);
mm_notch_test = mm.notch(os.tosc(440), 1000, 0, 1);
mm_APF_test = mm.APF(os.tosc(440), 1000, 0, 1);
mm_peakingEQ_test = mm.peakingEQ(os.tosc(440), 1000, 6, 1);
mm_peakNotch_test = mm.peakNotch(os.tosc(440), 1000, 2, 1);
mm_lowShelf_test = mm.lowShelf(os.tosc(440), 500, 6, 1);
mm_highShelf_test = mm.highShelf(os.tosc(440), 2000, 6, 1);
mm_line_test = mm.line(hslider("value", 1, 0, 1, 0.01), 100);
// 0.1 ms at 48 kHz is 4.8 samples, rounded to 5: no overshoot
mm_line_frac_test = mm.line(os.lf_squarewavepos(100), 0.1);
