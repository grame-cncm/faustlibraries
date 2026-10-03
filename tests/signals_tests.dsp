si = library("signals.lib");
os = library("oscillators.lib");
ba = library("basics.lib");
ma = library("maths.lib");
no = library("noises.lib");

bus_test = (
    hslider("bus:x0", 0.25, -1, 1, 0.01),
    hslider("bus:x1", -0.5, -1, 1, 0.01),
    hslider("bus:x2", 0.75, -1, 1, 0.01)
) : si.bus(3);

block_test = (
    hslider("block:x0", 0.5, -1, 1, 0.01),
    hslider("block:x1", -0.25, -1, 1, 0.01)
) : (si.block(1), _);

interpolate_test = si.interpolate(
    hslider("interpolate:mix", 0.5, 0, 1, 0.01),
    os.tosc(220),
    os.tosc(440)
);

repeat_test = hslider("repeat:input", 0.5, -1, 1, 0.01) : si.repeat(3, *(0.5));

smoo_test = hslider("smoo:input", 0.5, -1, 1, 0.01) : si.smoo;

polySmooth_test = hslider("polySmooth:input", 0.5, -1, 1, 0.01)
  : si.polySmooth(button("polySmooth:gate"), 0.999, 32);

smoothAndH_test = hslider("smoothAndH:input", 0.5, -1, 1, 0.01)
  : si.smoothAndH(button("smoothAndH:hold"), 0.999);

bsmooth_test = hslider("bsmooth:input", 0.5, -1, 1, 0.01) : si.bsmooth;

dot_test = (
    os.tosc(100), os.tosc(200), os.tosc(300),
    os.tosc(400), os.tosc(500), os.tosc(600)
) : si.dot(3);

smooth_test = hslider("smooth:input", 0.5, -1, 1, 0.01) : si.smooth(0.9);
smooth_slider_test = no.noise : si.smooth(hslider("smooth:s", 0.999, 0, 0.9999, 0.0001));
smooth_modulated_test = no.noise : si.smooth(1 - 0.1*pow(0.001, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
smooth_jump_test = no.noise : si.smooth(1 - 0.1*pow(0.001, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };

smoothq_test = hslider("smoothq:input", 0.5, -1, 1, 0.01) : si.smoothq(0.25, 0.5);
smoothq_linear_test = select2(ba.period(2*P) < P, -1, 1) : si.smoothq(0.25, 1)
with { P = int(ma.SR/4); };
smoothq_slider_test = no.noise : ba.sAndH(ba.period(Q) == 0) : si.smoothq(hslider("smoothq:time", 0.25, 0.001, 1, 0.001), hslider("smoothq:q", 0.5, 0, 1, 0.01)) with { Q = int(ma.SR/30); };
smoothq_modulated_test = no.noise : ba.sAndH(ba.period(Q) == 0) : si.smoothq(0.001*pow(1000, tri), 0.5) with { Q = int(ma.SR/30); P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
smoothq_jump_test = no.noise : ba.sAndH(ba.period(Q) == 0) : si.smoothq(0.001*pow(1000, sq), 0.5) with { Q = int(ma.SR/30); P = int(ma.SR/10); sq = ba.period(2*P) < P; };

cbus_test = (
    os.tosc(100), os.tosc(150),
    os.tosc(200), os.tosc(250)
) : si.cbus(2);

cmul_test = si.cmul(
    os.tosc(110), os.tosc(220),
    os.tosc(330), os.tosc(440)
);

cconj_test = (os.tosc(210), os.tosc(310)) : si.cconj;

onePoleSwitching_test = hslider("onePoleSwitching:input", 0.5, -1, 1, 0.01)
  : si.onePoleSwitching(0.05, 0.2);
onePoleSwitching_slider_test = no.noise : si.onePoleSwitching(hslider("onePoleSwitching:att", 0.05, 0.001, 1, 0.001), hslider("onePoleSwitching:rel", 0.2, 0.001, 1, 0.001));
onePoleSwitching_modulated_test = no.noise : si.onePoleSwitching(0.001*pow(1000, tri), 0.001*pow(1000, 1 - tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
onePoleSwitching_jump_test = no.noise : si.onePoleSwitching(0.001*pow(1000, sq), 0.001*pow(1000, 1 - sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
lag_ud_test = hslider("lag_ud:input", 0.5, -1, 1, 0.01) : si.lag_ud(0.05, 0.2);

rev_test = os.tosc(440) : si.rev(32);

vecOp_test = si.vecOp((v0, v1), +)
with {
    v0 = (hslider("vecOp:v0_0", 0.1, -1, 1, 0.01), hslider("vecOp:v0_1", 0.2, -1, 1, 0.01));
    v1 = (hslider("vecOp:v1_0", 0.3, -1, 1, 0.01), hslider("vecOp:v1_1", 0.4, -1, 1, 0.01));
};

bpar_test = (os.tosc(120), os.tosc(240), os.tosc(360)) : si.bpar(3, *(0.5));

bsum_test = (os.tosc(100), os.tosc(200), os.tosc(300)) : si.bsum(3, *(0.5));

bprod_test = (
    hslider("bprod:x0", 0.5, 0, 2, 0.01),
    hslider("bprod:x1", 0.8, 0, 2, 0.01)
) : si.bprod(2, _);
