//----------------------------------------------------------------------------
// delays_tests.dsp
// Tests for delay helper functions.
//----------------------------------------------------------------------------

os = library("oscillators.lib");
de = library("delays.lib");

delay_test = os.osc(440) : de.delay(44100, 22050);
fdelay_test = os.osc(440) : de.fdelay(44100, 22050.5);
sdelay_test = os.osc(440) : de.sdelay(44100, 1024, 22050.5);
prime_power_delays_test = de.prime_power_delays(4, 1, 10);
fdelaylti_test = os.osc(440) : de.fdelaylti(3, 44100, 22050.5);
fdelayltv_test = os.osc(440) : de.fdelayltv(3, 44100, 22050.5);
fdelay2a_test = os.osc(440) : de.fdelay2a(44100, 22050.5);
multiTapSincDelay_test = os.osc(440) : de.multiTapSincDelay(2, 4096, 1024.0, 1536.0, 0.5);
