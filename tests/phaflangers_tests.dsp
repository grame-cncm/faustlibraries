import("stdfaust.lib");

pf = library("phaflangers.lib");
os = library("oscillators.lib");
ba = library("basics.lib");
ma = library("maths.lib");
no = library("noises.lib");

flanger_mono_test = os.tosc(440) : pf.flanger_mono(4096, 1024, 0.7, 0.25, 0);
flanger_mono_impulse_test = (1-1') : pf.flanger_mono(64, 5, 1, 0.5, 0);
flanger_mono_slider_test = os.tosc(440) : pf.flanger_mono(4096, hslider("flanger_mono:curdel", 1024, 1, 4095, 1), hslider("flanger_mono:depth", 0.7, 0, 1, 0.01), hslider("flanger_mono:fb", 0.25, 0, 0.99, 0.01), 0);
flanger_mono_modulated_test = no.noise : pf.flanger_mono(512, 1 + 255*tri, 1, 0.7, 0) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
flanger_mono_jump_test = no.noise : pf.flanger_mono(512, 1 + 255*sq, 1, 0.7, 0) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };

flanger_stereo_test = os.tosc(440), os.tosc(660) : pf.flanger_stereo(4096, 1024, 1536, 0.7, 0.25, 0);
flanger_stereo_slider_test = os.tosc(440), os.tosc(660) : pf.flanger_stereo(4096, hslider("flanger_stereo:curdel1", 1024, 1, 4095, 1), hslider("flanger_stereo:curdel2", 1536, 1, 4095, 1), hslider("flanger_stereo:depth", 0.7, 0, 1, 0.01), hslider("flanger_stereo:fb", 0.25, 0, 0.99, 0.01), 0);
vibrato2_mono_test = os.tosc(440) : pf.vibrato2_mono(4, 0, 0.5, 1000, 100, 1.5, 4800, 0.5);
vibrato2_mono_slider_test = os.tosc(440) : pf.vibrato2_mono(4, hslider("vibrato2_mono:phase01", 0, 0, 1, 0.01), hslider("vibrato2_mono:fb", 0.5, -0.99, 0.99, 0.01), hslider("vibrato2_mono:width", 1000, 10, 5000, 1), hslider("vibrato2_mono:frqmin", 100, 20, 5000, 1), hslider("vibrato2_mono:fratio", 1.5, 1, 4, 0.01), hslider("vibrato2_mono:frqmax", 4800, 20, 10000, 1), hslider("vibrato2_mono:speed", 0.5, 0, 10, 0.01));
vibrato2_mono_jump_test = no.noise : pf.vibrato2_mono(4, 0, 1.8*sq - 0.9, 1000, 100, 1.5, 4800, 0.5) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };

phaser2_mono_test = os.tosc(330) : pf.phaser2_mono(4, 0.0, 50, 200, 1.5, 4000, 0.5, 0.8, 0.2, 0);
phaser2_mono_slider_test = os.tosc(330) : pf.phaser2_mono(4, hslider("phaser2_mono:phase01", 0, 0, 1, 0.01), hslider("phaser2_mono:width", 50, 10, 5000, 1), hslider("phaser2_mono:frqmin", 200, 20, 5000, 1), hslider("phaser2_mono:fratio", 1.5, 1, 4, 0.01), hslider("phaser2_mono:frqmax", 4000, 20, 10000, 1), hslider("phaser2_mono:speed", 0.5, 0, 10, 0.01), hslider("phaser2_mono:depth", 0.8, 0, 2, 0.01), hslider("phaser2_mono:fb", 0.2, -0.99, 0.99, 0.01), 0);

phaser2_stereo_test = os.tosc(220), os.tosc(330) : pf.phaser2_stereo(4, 50, 200, 1.5, 4000, 0.5, 0.8, 0.2, 0);
