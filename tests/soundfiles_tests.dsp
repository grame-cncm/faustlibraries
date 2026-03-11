so = library("soundfiles.lib");
os = library("oscillators.lib");

sf = soundfile("sound[url:{'tests/assets/silence.wav'}]", 1);

loop_test = so.loop(sf, 0) + os.osc(110) * 0.001;
loop_speed_test = so.loop_speed(sf, 0, hslider("loop_speed:speed", 1, 0, 2, 0.01)) + os.osc(110) * 0.001;
loop_speed_level_test = so.loop_speed_level(
    sf,
    0,
    hslider("loop_speed_level:speed", 1, 0, 2, 0.01),
    hslider("loop_speed_level:level", 0.5, 0, 1, 0.01)
) + os.osc(110) * 0.001;
