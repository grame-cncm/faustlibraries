//----------------------------------------------------------------------------
// misceffects_tests.dsp
// Tests for misc effects helper functions.
//----------------------------------------------------------------------------

ef = library("misceffects.lib");
os = library("oscillators.lib");
fi = library("filters.lib");

cubicnl_test = os.osc(440) : ef.cubicnl(0.5, 0.0);
cubicnl_nodc_test = os.osc(440) : ef.cubicnl_nodc(0.5, 0.0);

gate_mono_test = os.osc(440) : ef.gate_mono(-60, 0.0001, 0.1, 0.02);
gate_stereo_test = os.osc(440), os.osc(441) : ef.gate_stereo(-60, 0.0001, 0.1, 0.02);

fibonacci_test = 0 : ef.fibonacci(2);
fibonacciGeneral_test = 0 : ef.fibonacciGeneral(waveform{2, 3});
fibonacciSeq_test = ef.fibonacciSeq(5);

speakerbp_test = os.osc(440) : ef.speakerbp(100.0, 5000.0);
piano_dispersion_filter_test = os.osc(110) : ef.piano_dispersion_filter(4, 0.0001, 110);
stereo_width_test = os.osc(440), os.osc(550) : ef.stereo_width(0.5);
mesh_square_test = (0,0,0,0) : ef.mesh_square(1);

dryWetMixer_test = os.osc(440) : ef.dryWetMixer(0.5, fi.dcblocker);
dryWetMixerConstantPower_test = os.osc(440) : ef.dryWetMixerConstantPower(0.5, fi.dcblocker);

mixLinearClamp_test = (1,0,0,0) : ef.mixLinearClamp(4, 1, 1.2);
mixLinearLoop_test = (1,0,0,0) : ef.mixLinearLoop(4, 1, -0.3);
mixPowerClamp_test = (1,0,0,0) : ef.mixPowerClamp(4, 1, 1.5);
mixPowerLoop_test = (1,0,0,0) : ef.mixPowerLoop(4, 1, -0.5);

echo_test = os.osc(440) : ef.echo(0.5, 0.25, 0.4);
reverseEchoN_test = os.osc(440) : ef.reverseEchoN(2, 32);
reverseDelayRamped_test = os.osc(440) : ef.reverseDelayRamped(32, 0.6);
uniformPanToStereo_test = os.osc(440), os.osc(550), os.osc(660) : ef.uniformPanToStereo(3);

tapeStop_test = os.osc(440), os.osc(441) : ef.tapeStop(2, 3, 44100, 128, 1.0, 1.0, 22050, button("stop"));

transpose_test = os.osc(440) : ef.transpose(1024, 512, 7);

softclipQuadratic_test = os.osc(440) : ef.softclipQuadratic;
wavefold_test = os.osc(440) : ef.wavefold(0.5);

weightsPowerLoop_test = ef.mixingEnv.weightsPowerLoop(4, 1.2);
