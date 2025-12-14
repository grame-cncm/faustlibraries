//----------------------------------------------------------------------------
// demos_tests.dsp
// Tests for demos helper functions.
//----------------------------------------------------------------------------

dm = library("demos.lib");
os = library("oscillators.lib");
no = library("noises.lib");

monoOsc(freq) = os.osc(freq);
stereoOsc(f1, f2) = monoOsc(f1), monoOsc(f2);
stereoNoise = no.noise, no.noise;

mth_octave_spectral_level_demo_test = no.noise : dm.mth_octave_spectral_level_demo(1.5);
spectral_level_demo_test = no.noise : dm.spectral_level_demo;
parametric_eq_demo_test = no.noise : dm.parametric_eq_demo;
spectral_tilt_demo_test = no.noise : dm.spectral_tilt_demo(4);
mth_octave_filterbank_demo_test = no.noise : dm.mth_octave_filterbank_demo(1);
filterbank_demo_test = no.noise : dm.filterbank_demo;
cubicnl_demo_test = no.noise : dm.cubicnl_demo;
gate_demo_test = stereoNoise : dm.gate_demo;
compressor_demo_test = stereoNoise : dm.compressor_demo;
moog_vcf_demo_test = monoOsc(440) : dm.moog_vcf_demo;
wah4_demo_test = monoOsc(440) : dm.wah4_demo;
crybaby_demo_test = monoOsc(440) : dm.crybaby_demo;
flanger_demo_test = stereoOsc(440, 442) : dm.flanger_demo;
phaser2_demo_test = stereoOsc(440, 442) : dm.phaser2_demo;
tapeStop_demo_test = stereoOsc(440, 442) : dm.tapeStop_demo;
freeverb_demo_test = stereoOsc(440, 442) : dm.freeverb_demo;
springreverb_demo_test = monoOsc(220) : dm.springreverb_demo;
stereo_reverb_tester_test = stereoNoise : dm.stereo_reverb_tester(!);
fdnrev0_demo_test = stereoNoise : dm.fdnrev0_demo(16, 5, 3);
zita_rev_fdn_demo_test = par(i, 8, monoOsc(440 + i)) : dm.zita_rev_fdn_demo;
zita_light_test = stereoOsc(440, 442) : dm.zita_light;
zita_rev1_test = stereoOsc(440, 442) : dm.zita_rev1;
vital_rev_demo_test = stereoOsc(440, 442) : dm.vital_rev_demo;
reverbTank_demo_test = stereoOsc(440, 442) : dm.reverbTank_demo;
kb_rom_rev1_demo_test = stereoOsc(440, 442) : dm.kb_rom_rev1_demo;
dattorro_rev_demo_test = stereoOsc(440, 442) : dm.dattorro_rev_demo;
jprev_demo_test = stereoOsc(440, 442) : dm.jprev_demo;
greyhole_demo_test = stereoOsc(440, 442) : dm.greyhole_demo;
sawtooth_demo_test = dm.sawtooth_demo;
virtual_analog_oscillator_demo_test = dm.virtual_analog_oscillator_demo;
oscrs_demo_test = dm.oscrs_demo;
velvet_noise_demo_test = dm.velvet_noise_demo;
latch_demo_test = dm.latch_demo;
envelopes_demo_test = dm.envelopes_demo;
fft_spectral_level_demo_test = dm.fft_spectral_level_demo(256);
reverse_echo_demo_test = no.noise : dm.reverse_echo_demo(3);
pospass_demo_test = monoOsc(440) : dm.pospass_demo;
exciter_test = no.noise : dm.exciter;
vocoder_demo_test = no.noise : dm.vocoder_demo;
colored_noise_demo_test = dm.colored_noise_demo;
shock_trigger_demo_test = dm.shock_trigger_demo;
projected_gravity_demo_test = dm.projected_gravity_demo;
total_accel_demo_test = dm.total_accel_demo;
orientation6_demo_test = dm.orientation6_demo;
motion_wrapper_demo_test = dm.motion_wrapper_demo;