//----------------------------------------------------------------------------
// dx7_tests.dsp
// Tests for DX7 helper functions.
//----------------------------------------------------------------------------

dx = library("dx7.lib");
env = library("env.lib");
lfo = library("lfo.lib");
op = library("operator.lib");
pi = library("pitchenv.lib");
ba = library("basics.lib");
ma = library("maths.lib");

env_test = env.env((60,61,62,63), (99,90,70,0), env.scaleoutlevel(80) << 5, 0, button("gate")) : env.q24_to_linear;
env_slider_test = env.env((hslider("env:R1", 60, 0, 99, 1), hslider("env:R2", 61, 0, 99, 1), hslider("env:R3", 62, 0, 99, 1), hslider("env:R4", 63, 0, 99, 1)), (hslider("env:L1", 99, 0, 99, 1), hslider("env:L2", 90, 0, 99, 1), hslider("env:L3", 70, 0, 99, 1), hslider("env:L4", 0, 0, 99, 1)), int(env.scaleoutlevel(hslider("env:outlevel", 80, 0, 99, 1))) << 5, hslider("env:rate_scaling", 0, 0, 27, 1), button("gate")) : env.q24_to_linear;
env_scale_level_test = par(c, 4, env.ScaleLevel(note, 39, 50, 70, c, 3 - c)) with { P = int(ma.SR/10); note = int(128*ba.period(P)/P); };
env_scale_velocity_test = par(s, 8, env.ScaleVelocity(vel, s)) with { P = int(ma.SR/10); vel = 150*ba.period(P)/P - 10; };
env_scale_rate_test = par(s, 8, env.ScaleRate(note, s)) with { P = int(ma.SR/10); note = int(128*ba.period(P)/P); };
env_scaleoutlevel_test = env.scaleoutlevel(int(100*ba.period(P)/P)) with { P = int(ma.SR/10); };

lfo_test = lfo.lfo(1, 50, checkbox("Sync"),35, button("gate"));
lfo_wave_test = par(w, 6, lfo.lfo(w, 0, 1, 70, button("gate")) : _, !);
lfo_speed_test = par(s, 5, lfo.lfo(2, 0, 1, 20*s + 10, button("gate")) : _, !);
lfo_delay_test = par(d, 5, lfo.lfo(0, 20*d, 1, 35, button("gate")) : !, _);
lfo_sync_test = par(s, 2, lfo.lfo(0, 20, s, 35, gate)) with { P = int(ma.SR/4); gate = ba.period(P) < int(P/2); };
lfo_slider_test = lfo.lfo(hslider("lfo:wave", 4, 0, 5, 1), hslider("lfo:delay", 20, 0, 99, 1), hslider("lfo:sync", 1, 0, 1, 1), hslider("lfo:speed", 60, 0, 99, 1), button("gate"));

operator_test = op.operator(0,1,0,0,99,99,99,99,99,99,90,70,0,0,0,0,4,35,0,0,0,1,3,99,99,99,99,0,0,0,0,50,0,0,0,0,0,-12,0,440.0,1.0,button("gate"));
operator_modulated_test = op.operator(0,1,0,0,99,99,99,99,99,99,99,99,99,0,0,0,4,35,0,0,0,1,3,99,99,99,99,0,0,0,0,50,0,0,0,0,0,-12,2*tri - 1,440.0,1.0,button("gate")) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
voice = \(mode, coarse, fine, detune, keyvel, ams, ratescale, bp, ld, rd, lc, rc, wave, speed, delay, pmd, amd, sync, pms, keysync, transpose, freq, gain, gate).(op.operator(mode, coarse, fine, detune, 99, 60, 50, 40, 30, 99, 80, 60, 0, keyvel, ams, ratescale, bp, ld, rd, lc, rc, wave, speed, delay, pmd, amd, sync, pms, keysync, 99, 99, 99, 99, 50, 50, 50, 50, transpose, 0, freq, gain, gate));
operator_ratio_test = par(c, 4, voice(0, 2*c, 25, 5 - 3*c, 0, 0, 0, 0, 0, 0, 0, 0, 0, 35, 0, 0, 0, 0, 0, 1, 0, 220, 1, button("gate")));
operator_fixed_test = par(c, 4, voice(1, c, 50, 3*c, 0, 0, 0, 0, 0, 0, 0, 0, 0, 35, 0, 0, 0, 0, 0, 1, 0, 220, 1, button("gate")));
operator_scaling_test = par(c, 4, voice(0, 1, 0, 0, 0, 0, 0, 39, 50, 70, c, 3 - c, 0, 35, 0, 0, 0, 0, 0, 1, 0, 110 + 330*(c > 1), 1, button("gate")));
operator_velocity_test = par(s, 4, voice(0, 1, 0, 0, 2*s + 1, 0, 0, 0, 0, 0, 0, 0, 0, 35, 0, 0, 0, 0, 0, 1, 0, 440, 0.25*(s + 1), button("gate")));
operator_ratescale_test = par(s, 4, voice(0, 1, 0, 0, 0, 0, 2*s + 1, 0, 0, 0, 0, 0, 0, 35, 0, 0, 0, 0, 0, 1, 0, 880, 1, button("gate")));
operator_pmd_test = par(s, 4, voice(0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, s + 2, 60, 10, 60, 0, 1, 2*s + 1, 1, 0, 440, 1, button("gate")));
operator_amd_test = par(s, 4, voice(0, 1, 0, 0, 0, s, 0, 0, 0, 0, 0, 0, s + 2, 60, 10, 0, 60, 1, 0, 1, 0, 440, 1, button("gate")));
operator_keysync_test = par(s, 2, voice(0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 35, 0, 0, 0, 0, 0, s, 7, 220, 1, gate)) with { P = int(ma.SR/4); gate = ba.period(P) < int(P/2); };
operator_pitchenv_test = op.operator(0, 1, 0, 0, 99, 60, 50, 40, 30, 99, 80, 60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 35, 0, 0, 0, 0, 0, 1, 99, 99, 99, 80, 70, 40, 60, 30, 0, 0, 440, 1, button("gate"));
operator_phasemod_test = op.operator(0, 1, 0, 0, 99, 60, 50, 40, 30, 99, 80, 60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 35, 0, 0, 0, 0, 0, 1, 99, 99, 99, 99, 50, 50, 50, 50, 0, 0.25, 440, 1, button("gate"));
operator_slider_test = op.operator(0, hslider("operator:coarse", 2, 0, 31, 1), hslider("operator:fine", 25, 0, 99, 1), hslider("operator:detune", 3, -7, 7, 1), hslider("operator:outLev", 90, 0, 99, 1), 60, 50, 40, 30, 99, 80, 60, 0, hslider("operator:keyVelSens", 3, 0, 7, 1), hslider("operator:ampModSens", 2, 0, 3, 1), hslider("operator:rateScale", 3, 0, 7, 1), hslider("operator:breakpoint", 39, 0, 99, 1), hslider("operator:ldepth", 50, 0, 99, 1), hslider("operator:rdepth", 70, 0, 99, 1), hslider("operator:lcurve", 1, 0, 3, 1), hslider("operator:rcurve", 2, 0, 3, 1), hslider("operator:wave", 4, 0, 5, 1), hslider("operator:speed", 60, 0, 99, 1), hslider("operator:delay", 10, 0, 99, 1), hslider("operator:pmd", 40, 0, 99, 1), hslider("operator:amd", 40, 0, 99, 1), 1, hslider("operator:pms", 3, 0, 7, 1), 1, 99, 99, 99, 99, 50, 50, 50, 50, hslider("operator:transpose", 0, -24, 24, 1), 0, hslider("operator:freq", 440, 50, 2000, 1), hslider("operator:gain", 0.8, 0, 1, 0.01), button("gate"));

pitchenv_test = pi.pitchenv((60,61,62,63), (60,61,62,63), button("gate"));
pitchenv_slider_test = pi.pitchenv((hslider("pitchenv:R1", 60, 0, 99, 1), hslider("pitchenv:R2", 61, 0, 99, 1), hslider("pitchenv:R3", 62, 0, 99, 1), hslider("pitchenv:R4", 63, 0, 99, 1)), (hslider("pitchenv:L1", 60, 0, 99, 1), hslider("pitchenv:L2", 61, 0, 99, 1), hslider("pitchenv:L3", 62, 0, 99, 1), hslider("pitchenv:L4", 63, 0, 99, 1)), button("gate"));
pitchenv_falling_test = pi.pitchenv((99, 99, 99, 80), (70, 40, 60, 30), button("gate"));
pitchenv_rising_test = pi.pitchenv((99, 99, 99, 80), (30, 60, 40, 70), button("gate"));

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

