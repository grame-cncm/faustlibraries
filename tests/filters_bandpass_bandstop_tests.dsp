//----------------------------------------------------------------------------
// filters_bandpass_bandstop_tests.dsp
// Tests for Butterworth bandpass/bandstop helper functions.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");
no = library("noises.lib");
ba = library("basics.lib");
ma = library("maths.lib");

src = os.tosc(440);

bandpass_test = src : fi.bandpass(2, 500, 1500);
bandpass_lowband_test = no.noise : fi.bandpass(2, 100, 200);
bandpass_narrowlow_test = no.noise : fi.bandpass(2, 20, 22);
bandpass_zero_freq_test = no.noise : fi.bandpass(2, 1000*max(0, 1 - ba.time/12000) + 1000*(ba.time >= 24000), 2000);
bandpass3_zero_freq_test = no.noise : fi.bandpass(3, 1000*max(0, 1 - ba.time/12000) + 1000*(ba.time >= 24000), 2000);
bandpass_nyquist_test = no.noise : fi.bandpass(2, 1000, 0.6*ma.SR);
bandpass_slider_test = no.noise : fi.bandpass(2, hslider("fl", 500, 20, 20000, 1), hslider("fu", 1500, 20, 20000, 1));
bandpass_modulated_test = no.noise : fi.bandpass(2, fl, 3*fl) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); fl = 20*pow(250, tri); };
bandpass_jump_test = no.noise : fi.bandpass(2, fl, 3*fl) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; fl = 20*pow(250, sq); };
bandstop_test = src : fi.bandstop(2, 500, 1500);
bandstop_wide_test = no.noise : fi.bandstop(2, 5000, 8000);
bandstop_zero_freq_test = no.noise : fi.bandstop(2, 1000*max(0, 1 - ba.time/12000) + 1000*(ba.time >= 24000), 2000);
bandstop_slider_test = no.noise : fi.bandstop(2, hslider("fl", 500, 20, 20000, 1), hslider("fu", 1500, 20, 20000, 1));
bandstop_modulated_test = no.noise : fi.bandstop(2, fl, 3*fl) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); fl = 20*pow(250, tri); };
bandstop_jump_test = no.noise : fi.bandstop(2, fl, 3*fl) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; fl = 20*pow(250, sq); };
bandpass0_bandstop1_test = src : fi.bandpass0_bandstop1(0, 2, 500, 1500);
bandpass0_bandstop1_slider_test = no.noise : fi.bandpass0_bandstop1(0, 2, hslider("fl", 500, 20, 20000, 1), hslider("fu", 1500, 20, 20000, 1));
bandpass0_bandstop1_modulated_test = no.noise : fi.bandpass0_bandstop1(0, 2, fl, 3*fl) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); fl = 20*pow(250, tri); };
bandpass0_bandstop1_jump_test = no.noise : fi.bandpass0_bandstop1(0, 2, fl, 3*fl) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; fl = 20*pow(250, sq); };
