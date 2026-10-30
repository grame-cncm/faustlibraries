so = library("soundfiles.lib");
ba = library("basics.lib");
ma = library("maths.lib");
os = library("oscillators.lib");

sf = soundfile("sound[url:{'tests/assets/silence.wav'}]", 1);

loop_test = so.loop(sf, 0) + os.tosc(110) * 0.001;
loop_speed_test = so.loop_speed(sf, 0, hslider("loop_speed:speed", 1, 0, 2, 0.01)) + os.tosc(110) * 0.001;
loop_speed_level_test = so.loop_speed_level(
    sf,
    0,
    hslider("loop_speed_level:speed", 1, 0, 2, 0.01),
    hslider("loop_speed_level:level", 0.5, 0, 1, 0.01)
) + os.tosc(110) * 0.001;
sound_test = so.sound(sf, 0).loop + os.tosc(110) * 0.001;
sound_loop_test = so.sound(sf, 0).loop;
sound_loop_speed_test = so.sound(sf, 0).loop_speed(0.7);
sound_loop_speed_level_test = so.sound(sf, 0).loop_speed_level(1.5, 0.5);
sound_play_test = so.sound(sf, 0).play(0.5, gate) with { P = int(ma.SR/4); gate = ba.period(P) < int(P/2); };
sound_play_rev_test = so.sound(sf, 0).play_rev(0.5, gate) with { P = int(ma.SR/4); gate = ba.period(P) < int(P/2); };
sound_play_interp_test = so.sound(sf, 0).play_interp(440, 550, 0.5, gate, 1) with { P = int(ma.SR/4); gate = ba.period(P) < int(P/2); };
