//----------------------------------------------------------------------------
// envelopes_tests.dsp
// Tests for envelope helper functions.
//----------------------------------------------------------------------------

en = library("envelopes.lib");
no = library("noises.lib");
os = library("oscillators.lib");
ba = library("basics.lib");
ma = library("maths.lib");

gate = button("gate");
legato = checkbox("legato");

ar_test = no.noise * en.ar(0.02, 0.3, gate);
ar_slider_test = no.noise * en.ar(hslider("ar:at", 0.02, 0, 5, 0.001), hslider("ar:rt", 0.3, 0, 5, 0.001), gate);
asr_test = no.noise * en.asr(0.05, 0.7, 0.4, gate);
adsr_test = no.noise * en.adsr(0.05, 0.1, 0.6, 0.3, gate);
// a gate of 0.5 (a velocity) must give the same timing as a gate of 1
velocity_gate = 0.5 * os.lf_squarewavepos(4);
asr_velocity_test = en.asr(0.05, 0.7, 0.04, velocity_gate);
asr_slider_test = no.noise * en.asr(hslider("asr:at", 0.05, 0, 5, 0.001), hslider("asr:sl", 0.7, 0, 1, 0.01), hslider("asr:rt", 0.4, 0, 5, 0.001), gate);
adsr_velocity_test = en.adsr(0.05, 0.1, 0.6, 0.04, velocity_gate);
adsr_slider_test = no.noise * en.adsr(hslider("adsr:at", 0.05, 0, 5, 0.001), hslider("adsr:dt", 0.1, 0, 5, 0.001), hslider("adsr:sl", 0.6, 0, 1, 0.01), hslider("adsr:rt", 0.3, 0, 5, 0.001), gate);
adsrf_bias_test = no.noise * en.adsrf_bias(
  0.05, 0.1, 0.6, 0.4, 0.2,
  0.4, 0.6, 0.5,
  legato, gate
);
adsrf_bias_slider_test = no.noise * en.adsrf_bias(hslider("adsrf_bias:att", 0.05, 0, 5, 0.001), hslider("adsrf_bias:dec", 0.1, 0, 5, 0.001), hslider("adsrf_bias:sus", 0.6, 0, 1, 0.01), hslider("adsrf_bias:rel", 0.4, 0, 5, 0.001), hslider("adsrf_bias:final", 0.2, 0, 1, 0.01), hslider("adsrf_bias:bias_att", 0.4, 0, 1, 0.01), hslider("adsrf_bias:bias_dec", 0.6, 0, 1, 0.01), hslider("adsrf_bias:bias_rel", 0.5, 0, 1, 0.01), legato, gate);
adsrf_bias_modulated_test = no.noise * en.adsrf_bias(0.05, 0.1, 0.6, 0.4, 0.2, tri, 1 - tri, tri, checkbox("legato"), button("gate")) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
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
ahdsrf_bias_slider_test = no.noise * en.ahdsrf_bias(hslider("ahdsrf_bias:att", 0.05, 0, 5, 0.001), hslider("ahdsrf_bias:hol", 0.05, 0, 5, 0.001), hslider("ahdsrf_bias:dec", 0.1, 0, 5, 0.001), hslider("ahdsrf_bias:sus", 0.6, 0, 1, 0.01), hslider("ahdsrf_bias:rel", 0.4, 0, 5, 0.001), hslider("ahdsrf_bias:final", 0.2, 0, 1, 0.01), hslider("ahdsrf_bias:bias_att", 0.4, 0, 1, 0.01), hslider("ahdsrf_bias:bias_dec", 0.6, 0, 1, 0.01), hslider("ahdsrf_bias:bias_rel", 0.5, 0, 1, 0.01), legato, gate);
ahdsrf_bias_modulated_test = no.noise * en.ahdsrf_bias(0.05, 0.05, 0.1, 0.6, 0.4, 0.2, tri, 1 - tri, tri, checkbox("legato"), button("gate")) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
ahdsr_bias_test = no.noise * en.ahdsr_bias(
  0.05, 0.05, 0.1, 0.6, 0.4,
  0.4, 0.6, 0.5,
  legato, gate
);
smoothEnvelope_test = no.noise * en.smoothEnvelope(0.2, gate);
smoothEnvelope_slider_test = no.noise * en.smoothEnvelope(hslider("smoothEnvelope:ar", 0.2, 0, 5, 0.001), gate);
asrfe_test = no.noise * en.asrfe(0.02, 0.8, 0.4, 0, gate);
asrfe_slider_test = no.noise * en.asrfe(hslider("asrfe:attT60", 0.02, 0, 5, 0.001), hslider("asrfe:susLvl", 0.8, 0, 1, 0.01), hslider("asrfe:relT60", 0.4, 0, 5, 0.001), hslider("asrfe:finLvl", 0, 0, 1, 0.01), gate);
asrfe_modulated_test = no.noise * en.asrfe(0.01*pow(100, tri), 0.8, 0.01*pow(100, 1 - tri), 0, button("gate")) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
arfe_test = no.noise * en.arfe(0.2, 0.4, 0, gate);
are_test = no.noise * en.are(0.2, 0.4, gate);
asre_test = no.noise * en.asre(0.2, 0.6, 0.4, gate);
adsre_test = no.noise * en.adsre(0.2, 0.1, 0.6, 0.4, gate);
adsre_slider_test = no.noise * en.adsre(hslider("adsre:attT60", 0.2, 0, 5, 0.001), hslider("adsre:decT60", 0.1, 0, 5, 0.001), hslider("adsre:susLvl", 0.6, 0, 1, 0.01), hslider("adsre:relT60", 0.4, 0, 5, 0.001), gate);
ahdsre_test = no.noise * en.ahdsre(0.2, 0.05, 0.1, 0.6, 0.4, gate);
ahdsre_slider_test = no.noise * en.ahdsre(hslider("ahdsre:attT60", 0.2, 0, 5, 0.001), hslider("ahdsre:htT60", 0.05, 0, 5, 0.001), hslider("ahdsre:decT60", 0.1, 0, 5, 0.001), hslider("ahdsre:susLvl", 0.6, 0, 1, 0.01), hslider("ahdsre:relT60", 0.4, 0, 5, 0.001), gate);
dx7envelope_test = os.tosc(440) * en.dx7envelope(
  0.05, 0.1, 0.1, 0.2,
  1, 0.8, 0.6, 0,
  gate
);
dx7envelope_slider_test = os.tosc(440) * en.dx7envelope(hslider("dx7envelope:R1", 0.05, 0, 5, 0.001), hslider("dx7envelope:R2", 0.1, 0, 5, 0.001), hslider("dx7envelope:R3", 0.1, 0, 5, 0.001), hslider("dx7envelope:R4", 0.2, 0, 5, 0.001), hslider("dx7envelope:L1", 1, 0, 1, 0.01), hslider("dx7envelope:L2", 0.8, 0, 1, 0.01), hslider("dx7envelope:L3", 0.6, 0, 1, 0.01), hslider("dx7envelope:L4", 0, 0, 1, 0.01), gate);
