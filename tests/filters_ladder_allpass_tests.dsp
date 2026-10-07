//----------------------------------------------------------------------------
// filters_ladder_allpass_tests.dsp
// Tests for ladder/lattice envelope helpers.
//----------------------------------------------------------------------------

ba = library("basics.lib");
fi = library("filters.lib");
ma = library("maths.lib");
no = library("noises.lib");
os = library("oscillators.lib");

src = os.tosc(440);
dual_src = os.tosc(440), os.tosc(660);

scatN_test = dual_src : fi.scatN(2, (1, 1), _);
scat_test = src : fi.scat(0.5, _);
allpassn_test = src : fi.allpassn(3, (0.3, 0.2, 0.1));
allpassnn_test = src : fi.allpassnn(3, (0.3, 0.2, 0.1));
allpassnkl_test = src : fi.allpassnkl(3, (0.3, 0.2, 0.1));
allpassn1m_test = src : fi.allpassn1m(3, (0.3, 0.2, 0.1));

// constant coefficients, input low enough that the output never reaches M:
// same output as fi.tf1(0.5, 1, 0.5) and fi.tf2(0.81, -1.27, 1, -1.27, 0.81)
allpass1_noclip_test = no.noise * 0.5 : fi.allpass1_noclip(1, 0.5);
allpass2_noclip_test = no.noise * 0.3 : fi.allpass2_noclip(1, 0.81, -1.27);
// full-scale noise, coefficients from sliders
allpass1_noclip_slider_test = no.noise : fi.allpass1_noclip(M, c)
with {
  M = hslider("M", 1, 0.1, 1, 0.01);
  c = hslider("c", 0.5, -0.99, 0.99, 0.01);
};
allpass2_noclip_slider_test = no.noise : fi.allpass2_noclip(M, c0, c1)
with {
  M = hslider("M", 1, 0.1, 1, 0.01);
  c0 = hslider("c0", 0.81, -0.99, 0.99, 0.01);
  c1 = hslider("c1", -1.27, -1.98, 1.98, 0.01);
};
// full-scale noise, coefficients jumping every 24 samples
allpass1_noclip_modulated_test = no.noise : fi.allpass1_noclip(1, c)
with { c = select2(ba.pulsen(24, 48), 0.99, -0.99); };
allpass2_noclip_modulated_test = no.noise : fi.allpass2_noclip(1, c0, c1)
with {
  jump = ba.pulsen(24, 48);
  c0 = select2(jump, 0.98, -0.98);
  c1 = select2(jump, -1.96, 0.01);
};
// coefficients jumping at 10 Hz: c between the ends of its range, and (c0, c1)
// between two stable pairs of pole radius 0.9
allpass1_noclip_jump_test = no.noise : fi.allpass1_noclip(1, c)
with { P = int(ma.SR/10); c = select2(ba.period(2*P) < P, -0.99, 0.99); };
allpass2_noclip_jump_test = no.noise : fi.allpass2_noclip(1, c0, c1)
with {
  P = int(ma.SR/10);
  jump = ba.period(2*P) < P;
  c0 = select2(jump, 0.81, -0.81);
  c1 = select2(jump, -1.27, 0.01);
};
