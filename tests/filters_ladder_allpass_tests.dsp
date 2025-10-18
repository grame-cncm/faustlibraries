//----------------------------------------------------------------------------
// filters_ladder_allpass_tests.dsp
// Tests for ladder/lattice envelope helpers.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");

src = os.osc(440);
dual_src = os.osc(440), os.osc(660);

scatN_test = dual_src : fi.scatN(2, (1, 1), _);
scat_test = src : fi.scat(0.5, _);
allpassn_test = src : fi.allpassn(3, (0.3, 0.2, 0.1));
allpassnn_test = src : fi.allpassnn(3, (0.3, 0.2, 0.1));
allpassnkl_test = src : fi.allpassnkl(3, (0.3, 0.2, 0.1));
allpassn1m_test = src : fi.allpassn1m(3, (0.3, 0.2, 0.1));
