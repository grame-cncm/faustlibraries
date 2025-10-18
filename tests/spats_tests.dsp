sp = library("spats.lib");
os = library("oscillators.lib");

panner_test = os.osc(220) : sp.panner(hslider("panner:pan", 0.3, 0, 1, 0.01));

constantPowerPan_test = (os.osc(110), os.osc(220))
  : sp.constantPowerPan(hslider("constantPowerPan:pan", 0.4, 0, 1, 0.01));

spat_test = os.osc(330)
  : sp.spat(4,
      hslider("spat:rotation", 0.25, 0, 1, 0.01),
      hslider("spat:distance", 0.5, 0, 1, 0.01));

wfs_inGain(i) = 0.5;
wfs_xs(i) = 0.0;
wfs_ys(i) = 1.0;
wfs_zs(i) = 0.0;
wfs_test = os.osc(440)
  : sp.wfs(0, 1, 0, 0.5, 1, 2, wfs_inGain, wfs_xs, wfs_ys, wfs_zs);

wfs_ui_test = os.osc(550)
  : sp.wfs_ui(0, 1, 0, 0.5, 1, 2);

stereoize_test = (os.osc(660), os.osc(770))
  : sp.stereoize(+);
