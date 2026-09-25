sy = library("synths.lib");
ba = library("basics.lib");
ma = library("maths.lib");

popFilterDrum_test = sy.popFilterDrum(200, 5, button("popFilterDrum:gate"));
popFilterDrum_slider_test = sy.popFilterDrum(
    hslider("popFilterDrum:freq", 200, 50, 1000, 1),
    hslider("popFilterDrum:q", 5, 1, 20, 0.1),
    button("popFilterDrum:gate")
);

dubDub_test = sy.dubDub(220, 800, 2, button("dubDub:gate"));
dubDub_slider_test = sy.dubDub(
    hslider("dubDub:freq", 220, 50, 1000, 1),
    hslider("dubDub:cutoff", 800, 100, 6000, 1),
    hslider("dubDub:q", 2, 0.2, 10, 0.1),
    button("dubDub:gate")
);
dubDub_modulated_test = sy.dubDub(220, 100*pow(60, tri), 2, button("dubDub:gate")) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };

sawTrombone_test = sy.sawTrombone(196, 0.6, button("sawTrombone:gate"));
sawTrombone_slider_test = sy.sawTrombone(
    hslider("sawTrombone:freq", 196, 50, 600, 1),
    hslider("sawTrombone:gain", 0.6, 0, 1, 0.01),
    button("sawTrombone:gate")
);

combString_test = sy.combString(220, 4, button("combString:gate"));
combString_slider_test = sy.combString(
    hslider("combString:freq", 220, 55, 880, 1),
    hslider("combString:res", 4, 0.1, 10, 0.01),
    button("combString:gate")
);
combString_modulated_test = sy.combString(220*pow(4, tri), 4, button("combString:gate")) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
combString_jump_test = sy.combString(220*pow(4, sq), 4, button("combString:gate")) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };

additiveDrum_test = sy.additiveDrum(180, (1, 1.3, 2.4, 3.2), (1, 0.8, 0.6, 0.4), 0.4, 0.01, 0.4, button("additiveDrum:gate"));
additiveDrum_slider_test = sy.additiveDrum(
    hslider("additiveDrum:freq", 180, 60, 600, 1),
    (1, 1.3, 2.4, 3.2),
    (1, 0.8, 0.6, 0.4),
    hslider("additiveDrum:harmDec", 0.4, 0, 1, 0.01),
    0.01,
    0.4,
    button("additiveDrum:gate")
);

fm_test = sy.fm((220, 440, 660), (1.5, 0.8));
fm_modulated_test = sy.fm((220, 440), (1000*tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };

logicEFM1_test = sy.logicEFM1(1, 2, 0, 0, 0, 0.3, 2.5, 0.5, 0.2, 0.3, 10, 0,
                              -0.3, 2, 0.3, 1, 10, 500, 0.7, 300, 0, 800, 0.2, 200,
                              261.63, ba.time < 36000, 0.8);

logicEFM1_unison_test = sy.logicEFM1(3, 4, 0, 0, 1, 0.35, 8.9, 0.7, 0, 0.2, 35, 1,
                                     0.8, 1, 0.8, 1, 5, 1200, 0.3, 500, 0, 2000, 0.1, 400,
                                     261.63, ba.time < 36000, 0.8);

kick_test = sy.kick(60, 0.2, 0.01, 0.5, 3, button("kick:gate"));
kick_slider_test = sy.kick(
    hslider("kick:pitch", 60, 30, 120, 0.1),
    hslider("kick:click", 0.2, 0.005, 1, 0.001),
    0.01,
    0.5,
    hslider("kick:drive", 3, 1, 10, 0.1),
    button("kick:gate")
);

clap_test = sy.clap(1200, 0.01, 0.6, button("clap:gate"));
clap_slider_test = sy.clap(
    hslider("clap:tone", 1200, 400, 3500, 10),
    0.01,
    0.6,
    button("clap:gate")
);

hat_test = sy.hat(800, 5000, 0.005, 0.3, button("hat:gate"));
hat_slider_test = sy.hat(
    hslider("hat:pitch", 800, 317, 3170, 1),
    hslider("hat:tone", 5000, 800, 18000, 10),
    0.005,
    0.3,
    button("hat:gate")
);
