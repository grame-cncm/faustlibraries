//----------------------------------------------------------------------------
// maxmsp_tests.dsp
// Tests for the MaxMSP compatibility library.
//----------------------------------------------------------------------------

mm = library("maxmsp.lib");
os = library("oscillators.lib");

src = os.osc(440);

mm_atodb_test = 0.5 : mm.atodb;
mm_filtercoeff_test = mm.filtercoeff(1000, 6, 1).LPF;
mm_biquad_test = mm.biquad(src, 0.5, 0.2, 0.1, 0.1, 0.05);
mm_LPF_test = mm.LPF(src, 1000, 0, 1);
mm_HPF_test = mm.HPF(src, 1000, 0, 1);
mm_BPF_test = mm.BPF(src, 1000, 0, 1);
mm_notch_test = mm.notch(src, 1000, 0, 1);
mm_APF_test = mm.APF(src, 1000, 0, 1);
mm_peakingEQ_test = mm.peakingEQ(src, 1000, 6, 1);
mm_peakNotch_test = mm.peakNotch(src, 1000, 2, 1);
mm_lowShelf_test = mm.lowShelf(src, 500, 6, 1);
mm_highShelf_test = mm.highShelf(src, 2000, 6, 1);
mm_line_test = mm.line(hslider("value", 1, 0, 1, 0.01), 100);
