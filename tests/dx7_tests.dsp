//----------------------------------------------------------------------------
// dx7_tests.dsp
// Tests for DX7 helper functions.
//----------------------------------------------------------------------------

dx = library("dx7.lib");
env = library("env.lib");
lfo = library("lfo.lib");
op = library("operator.lib");
pi = library("pitchenv.lib");

env_test = env.env((60,61,62,63), (60,61,62,63), 80, 90, button("gate")) : env.q24_to_linear;

lfo_test = lfo.lfo(1, 50, checkbox("Sync"),35, button("gate"));

operator_test = op.operator(0,1,0,0,99,99,99,99,99,0,0,0,0,0,0,0,4,35,0,0,0,1,3,99,99,99,99,0,0,0,0,50,0,0,0,0,0,-12,0,440.0,1.0,button("gate"));

pitchenv_test = pi.pitchenv((60,61,62,63), (60,61,62,63), button("gate"));

fdbkscalef_test = dx.fdbkscalef(0.5);
fdbkscalef2_test = dx.fdbkscalef2(0.5);
//algorithms_test = dx.algorithms;
algorithm1_test = dx.algorithm(1) <: _,_;
algorithm2_test = dx.algorithm(2) <: _,_;
algorithm3_test = dx.algorithm(3) <: _,_;
algorithm4_test = dx.algorithm(4) <: _,_;
algorithm5_test = dx.algorithm(5) <: _,_;
algorithm6_test = dx.algorithm(6) <: _,_;
algorithm7_test = dx.algorithm(7) <: _,_;
algorithm8_test = dx.algorithm(8) <: _,_;
algorithm9_test = dx.algorithm(9) <: _,_;
algorithm10_test = dx.algorithm(10) <: _,_;
algorithm11_test = dx.algorithm(11) <: _,_;
algorithm12_test = dx.algorithm(12) <: _,_;
algorithm13_test = dx.algorithm(13) <: _,_;
algorithm14_test = dx.algorithm(14) <: _,_;
algorithm15_test = dx.algorithm(15) <: _,_;
algorithm16_test = dx.algorithm(16) <: _,_;
algorithm17_test = dx.algorithm(17) <: _,_;
algorithm18_test = dx.algorithm(18) <: _,_;
algorithm19_test = dx.algorithm(19) <: _,_;
algorithm20_test = dx.algorithm(20) <: _,_;
algorithm21_test = dx.algorithm(21) <: _,_;
algorithm22_test = dx.algorithm(22) <: _,_;
algorithm23_test = dx.algorithm(23) <: _,_;
algorithm24_test = dx.algorithm(24) <: _,_;
algorithm25_test = dx.algorithm(25) <: _,_;
algorithm26_test = dx.algorithm(26) <: _,_;
algorithm27_test = dx.algorithm(27) <: _,_;
algorithm28_test = dx.algorithm(28) <: _,_;
algorithm29_test = dx.algorithm(29) <: _,_;
algorithm30_test = dx.algorithm(30) <: _,_;
algorithm31_test = dx.algorithm(31) <: _,_;
algorithm32_test = dx.algorithm(32) <: _,_;

