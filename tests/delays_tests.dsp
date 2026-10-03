//----------------------------------------------------------------------------
// delays_tests.dsp
// Tests for delay helper functions.
//----------------------------------------------------------------------------

os = library("oscillators.lib");
de = library("delays.lib");
ba = library("basics.lib");
ma = library("maths.lib");
no = library("noises.lib");

delay_test = os.tosc(440) : de.delay(44100, 22050);
fdelay_test = os.tosc(440) : de.fdelay(44100, 22050.5);
fdelay_slider_test = os.tosc(440) : de.fdelay(44100, hslider("fdelay:d", 22050.5, 0, 44100, 0.1));
fdelay_modulated_test = no.noise : de.fdelay(256, 16 + 112*tri) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
sdelay_test = os.tosc(440) : de.sdelay(44100, 1024, 22050.5);
sdelay_slider_test = os.tosc(440) : de.sdelay(44100, 1024, hslider("sdelay:d", 22050.5, 0, 44100, 0.1));
sdelay_jump_test = no.noise : de.sdelay(4096, 1024, select2(sq, 1000, 3000)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
prime_power_delays_test = de.prime_power_delays(4, 1, 10);
fdelaylti_test = os.tosc(440) : de.fdelaylti(3, 44100, 22050.5);
fdelaylti_slider_test = os.tosc(440) : de.fdelaylti(3, 44100, hslider("fdelaylti:d", 22050.5, 1, 44100, 0.1));
fdelaylti_modulated_test = no.noise : de.fdelaylti(3, 256, 2 + 62*tri) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
fdelayltv_test = os.tosc(440) : de.fdelayltv(3, 44100, 22050.5);
fdelayltv_slider_test = os.tosc(440) : de.fdelayltv(3, 44100, hslider("fdelayltv:d", 22050.5, 1, 44100, 0.1));
fdelayltv_modulated_test = no.noise : de.fdelayltv(3, 256, 2 + 62*tri) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
fdelay2a_test = os.tosc(440) : de.fdelay2a(44100, 22050.5);
fdelay1a_test = os.tosc(440) : de.fdelay1a(44100, 22050.5);
fdelay3a_test = os.tosc(440) : de.fdelay3a(44100, 22050.5);
fdelay4a_test = os.tosc(440) : de.fdelay4a(44100, 22050.5);
fdelay2a_slider_test = os.tosc(440) : de.fdelay2a(44100, hslider("fdelay2a:d", 22050.5, 1.5, 44100, 0.1));
fdelay1a_modulated_test = no.noise : de.fdelay1a(256, 0.6 + 30*tri) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
fdelay1a_jump_test = no.noise : de.fdelay1a(256, select2(sq, 0.6, 40)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
fdelay2a_modulated_test = no.noise : de.fdelay2a(256, 1.6 + 30*tri) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
fdelay2a_jump_test = no.noise : de.fdelay2a(256, select2(sq, 1.6, 40)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
fdelay3a_modulated_test = no.noise : de.fdelay3a(256, 2.6 + 30*tri) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
fdelay3a_jump_test = no.noise : de.fdelay3a(256, select2(sq, 2.6, 40)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
fdelay4a_modulated_test = no.noise : de.fdelay4a(256, 3.6 + 30*tri) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
fdelay4a_jump_test = no.noise : de.fdelay4a(256, select2(sq, 3.6, 40)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
multiTapSincDelay_test = os.tosc(440) : de.multiTapSincDelay(2, 4096, 1024.0, 1536.0, 0.5);
multiTapSincDelay_slider_test = os.tosc(440) : de.multiTapSincDelay(2, 4096, hslider("multiTapSincDelay:tau1", 1024, 0, 4000, 0.1), hslider("multiTapSincDelay:tau2", 1536, 0, 4000, 0.1), hslider("multiTapSincDelay:alpha", 0.5, 0, 1, 0.01));
multiTapSincDelay_modulated_test = no.noise : de.multiTapSincDelay(2, 4096, 1024.0, 1536.0, tri) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
multiTapSincDelay_near_test = os.tosc(440) : de.multiTapSincDelay(2, 4096, 1024.0, 1024.001, 0.5);
fdelay1_test = os.tosc(440) : de.fdelay1(44100, 22050.5);
fdelay2_test = os.tosc(440) : de.fdelay2(44100, 22050.5);
fdelay3_test = os.tosc(440) : de.fdelay3(44100, 22050.5);
fdelay4_test = os.tosc(440) : de.fdelay4(44100, 22050.5);
fdelay5_test = os.tosc(440) : de.fdelay5(44100, 22050.5);
fdelay3_modulated_test = no.noise : de.fdelay3(256, 2 + 62*tri) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
