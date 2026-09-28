//----------------------------------------------------------------------------
// filters_ladder_allpass_tests.dsp
// Tests for ladder/lattice envelope helpers.
//----------------------------------------------------------------------------

ba = library("basics.lib");
fi = library("filters.lib");
no = library("noises.lib");
os = library("oscillators.lib");

src = os.osc(440);
dual_src = os.osc(440), os.osc(660);

scatN_test = dual_src : fi.scatN(2, (1, 1), _);
scat_test = src : fi.scat(0.5, _);
allpassn_test = src : fi.allpassn(3, (0.3, 0.2, 0.1));
allpassnn_test = src : fi.allpassnn(3, (0.3, 0.2, 0.1));
allpassnkl_test = src : fi.allpassnkl(3, (0.3, 0.2, 0.1));
allpassn1m_test = src : fi.allpassn1m(3, (0.3, 0.2, 0.1));

// full-scale noise, coefficients jumping every 24 samples
allpass1_noclip_test = no.noise : fi.allpass1_noclip(1, c)
with { c = select2(ba.pulsen(24, 48), 0.99, -0.99); };
allpass2_noclip_test = no.noise : fi.allpass2_noclip(1, c0, c1)
with {
  jump = ba.pulsen(24, 48);
  c0 = select2(jump, 0.98, -0.98);
  c1 = select2(jump, -1.96, 0.01);
};
