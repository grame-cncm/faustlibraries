//----------------------------------------------------------------------------
// tubes_tests.dsp
// Tests for the Guitarix tube amplifier stage emulations.
//----------------------------------------------------------------------------

tu = library("tubes.lib");
os = library("oscillators.lib");

src = os.osc(440);

// Table-interpolation helpers
tu_rtable_test = tu.rtable(waveform{0.0, 1.0, 2.0, 3.0}, 2);
tu_inverse_test = src : tu.inverse;
tu_ccopysign_test = tu.ccopysign(0.5, src);
tu_sign_test = src : tu.sign;
tu_invsign_test = src : tu.invsign;
tu_interpolation_test = tu.interpolation(waveform{0.0, 1.0, 2.0, 3.0}, 0.5, 1);
tu_boundIndex_test = tu.boundIndex(2000, 2500);
tu_boundFactor_test = tu.boundFactor(2000, 1500.5, 1500);
tu_tubeF_test = src : tu.tubeF(tu.tubetable_12AX7_0, -5, 5, 200, 2000);
tu_getFactor_test = tu.getFactor(-5, 200, 2000, src);

// Gain stages
tubestage_test = src : tu.tubestage(tu.tubetable_12AX7_0, 86.0, 2700.0, 1.581656);
tubestage130_20_test = src : tu.tubestage130_20(tu.tubetable_6DJ8_0, 86.0, 2700.0, 1.863946);
tubestageF_test = src : tu.tubestageF(tu.tubetable_12AX7_0, 250.0, 40.0, 86.0, 2700.0, 1.581656);

// Raw table access, one per tube family
tubetable_12AX7_test = tu.tubetable_12AX7_rtable_0(100), tu.tubetable_12AX7_rtable_1(100);
tubetable_12AT7_test = tu.tubetable_12AT7_rtable_0(100), tu.tubetable_12AT7_rtable_1(100);
tubetable_12AU7_test = tu.tubetable_12AU7_rtable_0(100), tu.tubetable_12AU7_rtable_1(100);
tubetable_6V6_test = tu.tubetable_6V6_rtable_0(100), tu.tubetable_6V6_rtable_1(100);
tubetable_6DJ8_test = tu.tubetable_6DJ8_rtable_0(100), tu.tubetable_6DJ8_rtable_1(100);
tubetable_6C16_test = tu.tubetable_6C16_rtable_0(100), tu.tubetable_6C16_rtable_1(100);

// Preamp stages, all models
T1_12AX7_test = src : tu.T1_12AX7;
T2_12AX7_test = src : tu.T2_12AX7;
T3_12AX7_test = src : tu.T3_12AX7;
T1_12AT7_test = src : tu.T1_12AT7;
T2_12AT7_test = src : tu.T2_12AT7;
T3_12AT7_test = src : tu.T3_12AT7;
T1_12AU7_test = src : tu.T1_12AU7;
T2_12AU7_test = src : tu.T2_12AU7;
T3_12AU7_test = src : tu.T3_12AU7;
T1_6V6_test = src : tu.T1_6V6;
T2_6V6_test = src : tu.T2_6V6;
T3_6V6_test = src : tu.T3_6V6;
T1_6DJ8_test = src : tu.T1_6DJ8;
T2_6DJ8_test = src : tu.T2_6DJ8;
T3_6DJ8_test = src : tu.T3_6DJ8;
T1_6C16_test = src : tu.T1_6C16;
T2_6C16_test = src : tu.T2_6C16;
T3_6C16_test = src : tu.T3_6C16;
