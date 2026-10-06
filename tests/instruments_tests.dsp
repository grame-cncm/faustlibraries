//----------------------------------------------------------------------------
// instruments_tests.dsp
// Tests for the Faust-STK instrument building blocks.
//----------------------------------------------------------------------------

inst = library("instruments.lib");
os = library("oscillators.lib");
ma = library("maths.lib");
ba = library("basics.lib");
no = library("noises.lib");

gate = button("gate");

// Envelope generators
inst_envVibrato_test = os.tosc(440) * inst.envVibrato(0.05, 0.1, 80, 0.2, gate);
inst_asympT60_test = inst.asympT60(1, 0, 0.5, gate);
inst_asympT60_slider_test = inst.asympT60(hslider("asympT60:value", 1, 0, 1, 0.01), hslider("asympT60:trgt", 0, 0, 1, 0.01), hslider("asympT60:T60", 0.5, 0.01, 5, 0.01), gate);

// Tables
inst_saturationPos_test = 2 * os.tosc(440) : inst.saturationPos;
inst_saturationNeg_test = 2 * os.tosc(440) : inst.saturationNeg;
inst_bow_test = abs(os.tosc(5)) : inst.bow(0.2, 3);
inst_reed_test = os.tosc(440) : inst.reed(0.6, -0.8);

// Filters
inst_onePole_test = os.tosc(440) : inst.onePole(0.1, -0.9);
inst_onePole_slider_test = os.tosc(440) : inst.onePole(hslider("onePole:b0", 0.1, -1, 1, 0.001), hslider("onePole:a1", -0.9, -0.999, 0.999, 0.001));
inst_onePole_modulated_test = no.noise : inst.onePole(0.1, -0.5 - 0.499*tri) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
inst_onePole_jump_test = no.noise : inst.onePole(0.1, -0.5 - 0.499*sq) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
inst_onePoleSwep_test = os.tosc(440) : inst.onePoleSwep(0.5);
inst_poleZero_test = os.tosc(440) : inst.poleZero(0.5, 0.5, -0.9);
inst_poleZero_slider_test = os.tosc(440) : inst.poleZero(hslider("poleZero:b0", 0.5, -1, 1, 0.001), hslider("poleZero:b1", 0.5, -1, 1, 0.001), hslider("poleZero:a1", -0.9, -0.999, 0.999, 0.001));
inst_poleZero_modulated_test = no.noise : inst.poleZero(0.5, 0.5, -0.5 - 0.499*tri) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
inst_poleZero_jump_test = no.noise : inst.poleZero(0.5, 0.5, -0.5 - 0.499*sq) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
inst_oneZero0_test = os.tosc(440) : inst.oneZero0(0.5, 0.5);
inst_oneZero0_slider_test = os.tosc(440) : inst.oneZero0(hslider("oneZero0:b0", 0.5, -1, 1, 0.001), hslider("oneZero0:b1", 0.5, -0.999, 0.999, 0.001));
inst_oneZero0_modulated_test = no.noise : inst.oneZero0(0.5, -0.5 - 0.499*tri) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
inst_oneZero0_jump_test = no.noise : inst.oneZero0(0.5, -0.5 - 0.499*sq) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
inst_oneZero1_test = os.tosc(440) : inst.oneZero1(0.5, 0.5);
inst_bandPass_test = os.tosc(440) : inst.bandPass(1000, 0.95);
inst_bandPass_slider_test = os.tosc(440) : inst.bandPass(hslider("bandPass:resonance", 1000, 20, 20000, 1), hslider("bandPass:radius", 0.95, 0, 0.999, 0.001));
inst_bandPass_modulated_test = no.noise : inst.bandPass(50*pow(100, tri), 0.99) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
inst_bandPass_jump_test = no.noise : inst.bandPass(50*pow(100, sq), 0.99) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
inst_bandPassH_test = os.tosc(440) : inst.bandPassH(1000, 0.95);
inst_bandPassH_slider_test = os.tosc(440) : inst.bandPassH(hslider("bandPassH:resonance", 1000, 20, 20000, 1), hslider("bandPassH:radius", 0.95, 0, 0.999, 0.001));
inst_bandPassH_modulated_test = no.noise : inst.bandPassH(50*pow(100, tri), 0.99) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
inst_bandPassH_jump_test = no.noise : inst.bandPassH(50*pow(100, sq), 0.99) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
inst_jetTable_test = os.tosc(440) : inst.jetTable;
inst_nonLinearModulator_test = os.tosc(440) : inst.nonLinearModulator(0.5, 1, 440, 0, 100, 3);

// Tools
inst_stereoizer_test = os.tosc(440) : inst.stereoizer(ma.SR/440);
inst_instrReverb_test = os.tosc(440), os.tosc(660) : inst.instrReverb;
