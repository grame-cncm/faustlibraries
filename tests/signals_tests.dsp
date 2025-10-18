si = library("signals.lib");
os = library("oscillators.lib");

bus_test = (
    hslider("bus:x0", 0, -1, 1, 0.01),
    hslider("bus:x1", 0, -1, 1, 0.01),
    hslider("bus:x2", 0, -1, 1, 0.01)
) : si.bus(3);

block_test = (
    hslider("block:x0", 0, -1, 1, 0.01),
    hslider("block:x1", 0, -1, 1, 0.01)
) : (si.block(1), _);

interpolate_test = si.interpolate(
    hslider("interpolate:mix", 0.5, 0, 1, 0.01),
    os.osc(220),
    os.osc(440)
);

repeat_test = hslider("repeat:input", 0, -1, 1, 0.01) : si.repeat(3, *(0.5));

smoo_test = hslider("smoo:input", 0, -1, 1, 0.01) : si.smoo;

polySmooth_test = hslider("polySmooth:input", 0, -1, 1, 0.01)
  : si.polySmooth(button("polySmooth:gate"), 0.999, 32);

smoothAndH_test = hslider("smoothAndH:input", 0, -1, 1, 0.01)
  : si.smoothAndH(button("smoothAndH:hold"), 0.999);

bsmooth_test = hslider("bsmooth:input", 0, -1, 1, 0.01) : si.bsmooth;

dot_test = (
    os.osc(100), os.osc(200), os.osc(300),
    os.osc(400), os.osc(500), os.osc(600)
) : si.dot(3);

smooth_test = hslider("smooth:input", 0, -1, 1, 0.01) : si.smooth(0.9);

smoothq_test = hslider("smoothq:input", 0, -1, 1, 0.01) : si.smoothq(0.25, 0.5);

cbus_test = (
    os.osc(100), os.osc(150),
    os.osc(200), os.osc(250)
) : si.cbus(2);

cmul_test = si.cmul(
    os.osc(110), os.osc(220),
    os.osc(330), os.osc(440)
);

cconj_test = (os.osc(210), os.osc(310)) : si.cconj;

onePoleSwitching_test = hslider("onePoleSwitching:input", 0, -1, 1, 0.01)
  : si.onePoleSwitching(0.05, 0.2);

rev_test = os.osc(440) : si.rev(32);

vecOp_test = si.vecOp((v0, v1), +)
with {
    v0 = (hslider("vecOp:v0_0", 0.1, -1, 1, 0.01), hslider("vecOp:v0_1", 0.2, -1, 1, 0.01));
    v1 = (hslider("vecOp:v1_0", 0.3, -1, 1, 0.01), hslider("vecOp:v1_1", 0.4, -1, 1, 0.01));
};

bpar_test = (os.osc(120), os.osc(240), os.osc(360)) : si.bpar(3, *(0.5));

bsum_test = (os.osc(100), os.osc(200), os.osc(300)) : si.bsum(3, *(0.5));

bprod_test = (
    hslider("bprod:x0", 0.5, 0, 2, 0.01),
    hslider("bprod:x1", 0.8, 0, 2, 0.01)
) : si.bprod(2, _);
