sp = library("spats.lib");
os = library("oscillators.lib");
ma = library("maths.lib");

panner_test = os.osc(220) : sp.panner(hslider("panner:pan", 0.3, 0, 1, 0.01));

constantPowerPan_test = (os.osc(110), os.osc(220))
  : sp.constantPowerPan(hslider("constantPowerPan:pan", 0.4, 0, 1, 0.01));

spat_test = os.osc(330)
  : sp.spat(4,
      hslider("spat:rotation", 0.25, 0, 1, 0.01),
      hslider("spat:distance", 0.5, 0, 1, 0.01));

spcap_spk_deg(0) = -135;
spcap_spk_deg(1) = -45;
spcap_spk_deg(2) = 45;
spcap_spk_deg(3) = 135;
spcap_spk_angle(i) = spcap_spk_deg(i) : ma.deg2rad;
spcap_test = os.osc(440) : sp.spcap(4, 2.0, spcap_spk_angle, 0.0);

spcap_ui_test = os.osc(550) : sp.spcap_ui(4);

wfs_proc(i) = *(0.5); // Simple gain processor
wfs_xs(i) = 0.0;
wfs_ys(i) = 1.0;
wfs_zs(i) = 0.0;
wfs_test = os.osc(440)
  : sp.wfs(0, 1, 0, 0.5, 1, 2, wfs_proc, wfs_xs, wfs_ys, wfs_zs);

wfs_ui_test = os.osc(550)
  : sp.wfs_ui(0, 1, 0, 0.5, 1, 2);

stereoize_test = (os.osc(660), os.osc(770))
  : sp.stereoize(+);
