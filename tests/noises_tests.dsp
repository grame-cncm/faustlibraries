//----------------------------------------------------------------------------
// noises_tests.dsp
// Tests for noise library functions.
//----------------------------------------------------------------------------

no = library("noises.lib");
ba = library("basics.lib");
ma = library("maths.lib");

noise_test = no.noise;
multirandom_test = no.multirandom(3);
multinoise_test = no.multinoise(3);
noises_test = no.noises(4, 2);

dnoise_test = (trigger, seedRange) : no.dnoise
with {
  trigger = 1 : ba.impulsify;
  seedRange = 10.0;
};

//randomseed_test = no.randomseed;
//rnoise_test = no.rnoise;
//rmultirandom_test = no.rmultirandom(3);
//rmultinoise_test = no.rmultinoise(3);
//rnoises_test = no.rnoises(4, 1);

pink_filter_test = no.noise : no.pink_filter;
pink_noise_test = no.pink_noise;
pink_noise_vm_test = no.pink_noise_vm(4);

// 10.1 Hz rather than 10.0: at 48 kHz a 10 Hz period lands on sample 4800
// exactly, where the driving oscillator crosses zero -- a one-ulp rounding
// difference between backends flips which side of the sample the latch
// trigger falls on, making the test back end-sensitive for no reason
// (Commitium faust-general, thread "emitter", 2026-09-04).
lfnoise0_test = no.lfnoise0(10.1);
lfnoiseN_test = no.lfnoiseN(3, 10.1);
lfnoise_test = no.lfnoise(10.1);

sparse_noise_test = no.sparse_noise(5.0);
velvet_noise_test = no.velvet_noise(0.5, 5.0);

gnoise_test = no.gnoise(8);
colored_noise_test = no.colored_noise(4, 0.0);
gnoisem_test = no.gnoisem(8);
pink_noise_m_test = no.pink_noise_m;
