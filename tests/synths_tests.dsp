sy = library("synths.lib");

popFilterDrum_test = sy.popFilterDrum(
    hslider("popFilterDrum:freq", 200, 50, 1000, 1),
    hslider("popFilterDrum:q", 5, 1, 20, 0.1),
    button("popFilterDrum:gate")
);

dubDub_test = sy.dubDub(
    hslider("dubDub:freq", 220, 50, 1000, 1),
    hslider("dubDub:cutoff", 800, 100, 6000, 1),
    hslider("dubDub:q", 2, 0.2, 10, 0.1),
    button("dubDub:gate")
);

sawTrombone_test = sy.sawTrombone(
    hslider("sawTrombone:freq", 196, 50, 600, 1),
    hslider("sawTrombone:gain", 0.6, 0, 1, 0.01),
    button("sawTrombone:gate")
);

combString_test = sy.combString(
    hslider("combString:freq", 220, 55, 880, 1),
    hslider("combString:res", 4, 0.1, 10, 0.01),
    button("combString:gate")
);

additiveDrum_test = sy.additiveDrum(
    hslider("additiveDrum:freq", 180, 60, 600, 1),
    (1, 1.3, 2.4, 3.2),
    (1, 0.8, 0.6, 0.4),
    hslider("additiveDrum:harmDec", 0.4, 0, 1, 0.01),
    0.01,
    0.4,
    button("additiveDrum:gate")
);

fm_test = sy.fm((220, 440, 660), (1.5, 0.8));

kick_test = sy.kick(
    hslider("kick:pitch", 60, 30, 120, 0.1),
    hslider("kick:click", 0.2, 0.005, 1, 0.001),
    0.01,
    0.5,
    hslider("kick:drive", 3, 1, 10, 0.1),
    button("kick:gate")
);

clap_test = sy.clap(
    hslider("clap:tone", 1200, 400, 3500, 10),
    0.01,
    0.6,
    button("clap:gate")
);

hat_test = sy.hat(
    hslider("hat:pitch", 800, 317, 3170, 1),
    hslider("hat:tone", 5000, 800, 18000, 10),
    0.005,
    0.3,
    button("hat:gate")
);
