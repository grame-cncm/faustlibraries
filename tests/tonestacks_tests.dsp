//----------------------------------------------------------------------------
// tonestacks_tests.dsp
// Tests of tonestacks.lib.
//----------------------------------------------------------------------------

ba = library("basics.lib");
ma = library("maths.lib");
no = library("noises.lib");
ts = library("tonestacks.lib");

bassman_test = no.noise : ts.bassman(0.5, 0.5, 0.5);
bassman_slider_test = no.noise : ts.bassman(hslider("bassman:t", 0.5, 0, 1, 0.01), hslider("bassman:m", 0.5, 0, 1, 0.01), hslider("bassman:l", 0.5, 0, 1, 0.01));
bassman_modulated_test = no.noise : ts.bassman(0.5, 0.5, tri) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
bassman_jump_test = no.noise : ts.bassman(0.5, 0.5, sq) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
bassman_middle_jump_test = no.noise : ts.bassman(0, sq, 1) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
mesa_test = no.noise : ts.mesa(0.5, 0.5, 0.5);
ac15_test = no.noise : ts.ac15(0.5, 0.5, 0.5);
ac15_slider_test = no.noise : ts.ac15(hslider("ac15:t", 0.5, 0, 1, 0.01), hslider("ac15:m", 0.5, 0, 1, 0.01), hslider("ac15:l", 0.5, 0, 1, 0.01));
ac15_modulated_test = no.noise : ts.ac15(0.5, tri, 0.5) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
ac15_jump_test = no.noise : ts.ac15(0.5, sq, 0.5) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
