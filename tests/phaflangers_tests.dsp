import("stdfaust.lib");

pf = library("phaflangers.lib");
os = library("oscillators.lib");

flanger_mono_test = os.osc(440) : pf.flanger_mono(4096, 1024, 0.7, 0.25, 0);

flanger_stereo_test = os.osc(440), os.osc(660) : pf.flanger_stereo(4096, 1024, 1536, 0.7, 0.25, 0);

phaser2_mono_test = os.osc(330) : pf.phaser2_mono(4, 0.0, 50, 200, 1.5, 4000, 0.5, 0.8, 0.2, 0);

phaser2_stereo_test = os.osc(220), os.osc(330) : pf.phaser2_stereo(4, 50, 200, 1.5, 4000, 0.5, 0.8, 0.2, 0);
