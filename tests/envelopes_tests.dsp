//----------------------------------------------------------------------------
// envelopes_tests.dsp
// Tests for envelope helper functions.
//----------------------------------------------------------------------------

en = library("envelopes.lib");
no = library("noises.lib");
os = library("oscillators.lib");

gate = button("gate");
legato = checkbox("legato");

ar_test = no.noise * en.ar(0.02, 0.3, gate);
asr_test = no.noise * en.asr(0.05, 0.7, 0.4, gate);
adsr_test = no.noise * en.adsr(0.05, 0.1, 0.6, 0.3, gate);
adsrf_bias_test = no.noise * en.adsrf_bias(
  0.05, 0.1, 0.6, 0.4, 0.2,
  0.4, 0.6, 0.5,
  legato, gate
);
adsr_bias_test = no.noise * en.adsr_bias(
  0.05, 0.1, 0.6, 0.4,
  0.4, 0.6, 0.5,
  legato, gate
);
ahdsrf_bias_test = no.noise * en.ahdsrf_bias(
  0.05, 0.05, 0.1, 0.6, 0.4, 0.2,
  0.4, 0.6, 0.5,
  legato, gate
);
ahdsr_bias_test = no.noise * en.ahdsr_bias(
  0.05, 0.05, 0.1, 0.6, 0.4,
  0.4, 0.6, 0.5,
  legato, gate
);
smoothEnvelope_test = no.noise * en.smoothEnvelope(0.2, gate);
arfe_test = no.noise * en.arfe(0.2, 0.4, 0, gate);
are_test = no.noise * en.are(0.2, 0.4, gate);
asre_test = no.noise * en.asre(0.2, 0.6, 0.4, gate);
adsre_test = no.noise * en.adsre(0.2, 0.1, 0.6, 0.4, gate);
ahdsre_test = no.noise * en.ahdsre(0.2, 0.05, 0.1, 0.6, 0.4, gate);
dx7envelope_test = os.osc(440) * en.dx7envelope(
  0.05, 0.1, 0.1, 0.2,
  1, 0.8, 0.6, 0,
  gate
);
