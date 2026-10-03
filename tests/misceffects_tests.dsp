//----------------------------------------------------------------------------
// misceffects_tests.dsp
// Tests for misc effects helper functions.
//----------------------------------------------------------------------------

ef = library("misceffects.lib");
os = library("oscillators.lib");
fi = library("filters.lib");
no = library("noises.lib");
ba = library("basics.lib");
ma = library("maths.lib");

cubicnl_test = os.tosc(440) : ef.cubicnl(0.5, 0.0);
cubicnl_nodc_test = os.tosc(440) : ef.cubicnl_nodc(0.5, 0.0);

gate_mono_test = os.tosc(440) : ef.gate_mono(-60, 0.0001, 0.1, 0.02);
gate_stereo_test = os.tosc(440), os.tosc(441) : ef.gate_stereo(-60, 0.0001, 0.1, 0.02);
gate_gain_mono_test = os.tosc(440) : ef.gate_gain_mono(-60, 0.0001, 0.1, 0.02);
gate_gain_mono_slider_test = os.tosc(440) : ef.gate_gain_mono(hslider("gate_gain_mono:thresh", -60, -120, 0, 0.1), hslider("gate_gain_mono:att", 0.0001, 0.0001, 0.1, 0.0001), hslider("gate_gain_mono:hold", 0.1, 0, 1, 0.001), hslider("gate_gain_mono:rel", 0.02, 0.001, 1, 0.001));
gate_gain_mono_modulated_test = no.noise*pow(0.001, float(ba.period(Q))/Q) : ef.gate_gain_mono(-30, 0.0001, 0.02, 0.001*pow(100, tri)) with { Q = int(ma.SR/4); P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
gate_gain_mono_jump_test = no.noise*pow(0.001, float(ba.period(Q))/Q) : ef.gate_gain_mono(-30, 0.0001, 0.02, 0.001*pow(100, sq)) with { Q = int(ma.SR/4); P = int(ma.SR/10); sq = ba.period(2*P) < P; };

fibonacci_test = 1 : ef.fibonacci(2);
fibonacciGeneral_test = 1 : ef.fibonacciGeneral(waveform{2, 3});
fibonacciSeq_test = ef.fibonacciSeq(5);

speakerbp_test = os.tosc(440) : ef.speakerbp(100.0, 5000.0);
piano_dispersion_filter_test = os.tosc(110) : ef.piano_dispersion_filter(4, 0.0001, 110);
piano_dispersion_filter_slider_test = os.tosc(110) : ef.piano_dispersion_filter(4, hslider("piano_dispersion_filter:B", 0.0001, 0.000001, 0.01, 0.000001), hslider("piano_dispersion_filter:f0", 110, 27.5, 4186, 0.1));
piano_dispersion_filter_modulated_test = no.noise : ef.piano_dispersion_filter(4, 0.0001, 27.5*pow(4186/27.5, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
piano_dispersion_filter_jump_test = no.noise : ef.piano_dispersion_filter(4, 0.0001, 27.5*pow(4186/27.5, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
stereo_width_test = os.tosc(440), os.tosc(550) : ef.stereo_width(0.5);
mesh_square_test = (1,0.5,-0.5,0.25) : ef.mesh_square(1);

dryWetMixer_test = os.tosc(440) : ef.dryWetMixer(0.5, fi.dcblocker);
dryWetMixerConstantPower_test = os.tosc(440) : ef.dryWetMixerConstantPower(0.5, fi.dcblocker);

mixLinearClamp_test = (1,0.5,0,0) : ef.mixLinearClamp(4, 1, 1.2);
mixLinearLoop_test = (1,0,0,0) : ef.mixLinearLoop(4, 1, -0.3);
mixPowerClamp_test = (1,0,0,0) : ef.mixPowerClamp(4, 1, 1.5);
mixPowerLoop_test = (1,0,0,0) : ef.mixPowerLoop(4, 1, -0.5);

echo_test = os.tosc(440) : ef.echo(0.5, 0.25, 0.4);
reverseEchoN_test = os.tosc(440) : ef.reverseEchoN(2, 32);
reverseDelayRamped_test = os.tosc(440) : ef.reverseDelayRamped(32, 0.6);
uniformPanToStereo_test = os.tosc(440), os.tosc(550), os.tosc(660) : ef.uniformPanToStereo(3);

tapeStop_test = os.tosc(440), os.tosc(441) : ef.tapeStop(2, 3, 44100, 128, 1.0, 1.0, 22050, button("stop"));
tapeStop_jump_test = os.tosc(440), os.tosc(441) : ef.tapeStop(2, 3, 44100, 128, 1.0, 1.0, 22050, sq) with { P = int(ma.SR/4); sq = ba.period(2*P) < P; };

transpose_test = os.tosc(440) : ef.transpose(1024, 512, 7);
transpose_slider_test = os.tosc(440) : ef.transpose(hslider("transpose:w", 1024, 16, 4096, 1), hslider("transpose:x", 512, 1, 4096, 1), hslider("transpose:s", 7, -12, 12, 0.1));
transpose_modulated_test = os.tosc(440) : ef.transpose(1024, 512, 24*tri - 12) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
transpose_jump_test = os.tosc(440) : ef.transpose(1024, 512, 24*sq - 12) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
doppler_shift_test = os.sawtooth(220) : ef.doppler_shift(220, 1.5);
doppler_shift_slider_test = os.sawtooth(220) : ef.doppler_shift(hslider("doppler_shift:freq", 220, 20, 2000, 1), hslider("doppler_shift:ratio", 1.5, 0.5, 2, 0.01));
doppler_shift_modulated_test = os.tosc(220) : ef.doppler_shift(220, 0.5 + tri) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };

softclipQuadratic_test = os.tosc(440) : ef.softclipQuadratic;
wavefold_test = os.tosc(440) : ef.wavefold(0.5);
wavefold_slider_test = 2*no.noise : ef.wavefold(hslider("width", 0, 0, 1, 0.01));
wavefold_modulated_test = 2*no.noise : ef.wavefold(tri) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };

weightsPowerLoop_test = ef.mixingEnv.weightsPowerLoop(4, 1.2);

// Mid/side and dither
ms_enc_test = os.tosc(440), os.tosc(550) : ef.ms_enc;
ms_dec_test = os.tosc(440), os.tosc(550) : ef.ms_enc : ef.ms_dec;
dither_test = os.tosc(440)*0.001 : ef.dither(16);
dither_shaped_test = os.tosc(440)*0.001 : ef.dither_shaped(2, 16);

// Windowed transposer and granulator
transpose_windowed_test = os.tosc(440) : ef.transpose_windowed(2, 1024, 7);
transpose_windowed_slider_test = os.tosc(440) : ef.transpose_windowed(2, hslider("transpose_windowed:w", 1024, 16, 4096, 1), hslider("transpose_windowed:s", 7, -12, 12, 0.1));
transpose_windowed_modulated_test = os.tosc(440) : ef.transpose_windowed(2, 1024, 24*tri - 12) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
transpose_windowed_jump_test = os.tosc(440) : ef.transpose_windowed(2, 1024, 24*sq - 12) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
granular_test = os.tosc(440) : ef.granular(2, 0.05, 1.5, 0.2, 0.1);
granular_slider_test = os.tosc(440) : ef.granular(2, hslider("granular:dur", 0.05, 0.005, 1, 0.001), hslider("granular:ratio", 1.5, 0.25, 4, 0.01), hslider("granular:pos", 0.2, 0, 1, 0.001), hslider("granular:jit", 0.1, 0, 1, 0.001));
granular_modulated_test = os.tosc(440) : ef.granular(2, 0.05, 0.5 + tri, 0.05 + 0.3*tri, 0.1) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
