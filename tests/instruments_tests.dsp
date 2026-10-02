//----------------------------------------------------------------------------
// instruments_tests.dsp
// Tests for the Faust-STK instrument building blocks.
//----------------------------------------------------------------------------

inst = library("instruments.lib");
os = library("oscillators.lib");
ma = library("maths.lib");

gate = button("gate");

// Envelope generators
inst_envVibrato_test = os.tosc(440) * inst.envVibrato(0.05, 0.1, 80, 0.2, gate);
inst_asympT60_test = inst.asympT60(1, 0, 0.5, gate);

// Tables
inst_saturationPos_test = 2 * os.tosc(440) : inst.saturationPos;
inst_saturationNeg_test = 2 * os.tosc(440) : inst.saturationNeg;
inst_bow_test = abs(os.tosc(5)) : inst.bow(0.2, 3);
inst_reed_test = os.tosc(440) : inst.reed(0.6, -0.8);

// Filters
inst_onePole_test = os.tosc(440) : inst.onePole(0.1, -0.9);
inst_onePoleSwep_test = os.tosc(440) : inst.onePoleSwep(0.5);
inst_poleZero_test = os.tosc(440) : inst.poleZero(0.5, 0.5, -0.9);
inst_oneZero0_test = os.tosc(440) : inst.oneZero0(0.5, 0.5);
inst_oneZero1_test = os.tosc(440) : inst.oneZero1(0.5, 0.5);
inst_bandPass_test = os.tosc(440) : inst.bandPass(1000, 0.95);
inst_bandPassH_test = os.tosc(440) : inst.bandPassH(1000, 0.95);
inst_jetTable_test = os.tosc(440) : inst.jetTable;
inst_nonLinearModulator_test = os.tosc(440) : inst.nonLinearModulator(0.5, 1, 440, 0, 100, 3);

// Tools
inst_stereoizer_test = os.tosc(440) : inst.stereoizer(ma.SR/440);
inst_instrReverb_test = os.tosc(440), os.tosc(660) : inst.instrReverb;
