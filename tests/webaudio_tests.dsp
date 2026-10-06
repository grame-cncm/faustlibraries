import("stdfaust.lib");

wa = library("webaudio.lib");
os = library("oscillators.lib");
ba = library("basics.lib");
ma = library("maths.lib");
no = library("noises.lib");

lowpass2_test = os.tosc(440) : wa.lowpass2(1000, 0.707, 0);
lowpass2_slider_test = os.tosc(440) : wa.lowpass2(hslider("lowpass2:f0", 1000, 20, 20000, 1), hslider("lowpass2:Q", 0.707, 0.1, 20, 0.001), hslider("lowpass2:dtune", 0, -1200, 1200, 1));
lowpass2_modulated_test = no.noise : wa.lowpass2(20*pow(250, tri), 0.707, 0) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
lowpass2_jump_test = no.noise : wa.lowpass2(20*pow(250, sq), 0.707, 0) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };

highpass2_test = os.tosc(440) : wa.highpass2(1000, 0.707, 0);
highpass2_slider_test = os.tosc(440) : wa.highpass2(hslider("highpass2:f0", 1000, 20, 20000, 1), hslider("highpass2:Q", 0.707, 0.1, 20, 0.001), hslider("highpass2:dtune", 0, -1200, 1200, 1));
highpass2_modulated_test = no.noise : wa.highpass2(20*pow(250, tri), 0.707, 0) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
highpass2_jump_test = no.noise : wa.highpass2(20*pow(250, sq), 0.707, 0) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };

bandpass2_test = os.tosc(440) : wa.bandpass2(1000, 1, 0);
bandpass2_slider_test = os.tosc(440) : wa.bandpass2(hslider("bandpass2:f0", 1000, 20, 20000, 1), hslider("bandpass2:Q", 1, 0.1, 20, 0.001), hslider("bandpass2:dtune", 0, -1200, 1200, 1));
bandpass2_modulated_test = no.noise : wa.bandpass2(20*pow(250, tri), 1, 0) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
bandpass2_jump_test = no.noise : wa.bandpass2(20*pow(250, sq), 1, 0) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };

notch2_test = os.tosc(440) : wa.notch2(1000, 1, 0);
notch2_slider_test = os.tosc(440) : wa.notch2(hslider("notch2:f0", 1000, 20, 20000, 1), hslider("notch2:Q", 1, 0.1, 20, 0.001), hslider("notch2:dtune", 0, -1200, 1200, 1));
notch2_modulated_test = no.noise : wa.notch2(20*pow(250, tri), 1, 0) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
notch2_jump_test = no.noise : wa.notch2(20*pow(250, sq), 1, 0) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };

allpass2_test = os.tosc(440) : wa.allpass2(1000, 1, 0);
allpass2_slider_test = os.tosc(440) : wa.allpass2(hslider("allpass2:f0", 1000, 20, 20000, 1), hslider("allpass2:Q", 1, 0.1, 20, 0.001), hslider("allpass2:dtune", 0, -1200, 1200, 1));
allpass2_modulated_test = no.noise : wa.allpass2(20*pow(250, tri), 1, 0) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
allpass2_jump_test = no.noise : wa.allpass2(20*pow(250, sq), 1, 0) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };

peaking2_test = os.tosc(440) : wa.peaking2(1000, 3, 1, 0);
peaking2_slider_test = os.tosc(440) : wa.peaking2(hslider("peaking2:f0", 1000, 20, 20000, 1), hslider("peaking2:gain", 3, -24, 24, 0.1), hslider("peaking2:Q", 1, 0.1, 20, 0.001), hslider("peaking2:dtune", 0, -1200, 1200, 1));
peaking2_modulated_test = no.noise : wa.peaking2(20*pow(250, tri), 3, 1, 0) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
peaking2_jump_test = no.noise : wa.peaking2(20*pow(250, sq), 3, 1, 0) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };

lowshelf2_test = os.tosc(440) : wa.lowshelf2(500, 6, 0);
lowshelf2_slider_test = os.tosc(440) : wa.lowshelf2(hslider("lowshelf2:f0", 500, 20, 20000, 1), hslider("lowshelf2:gain", 6, -24, 24, 0.1), hslider("lowshelf2:dtune", 0, -1200, 1200, 1));
lowshelf2_modulated_test = no.noise : wa.lowshelf2(20*pow(250, tri), 6, 0) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
lowshelf2_jump_test = no.noise : wa.lowshelf2(20*pow(250, sq), 6, 0) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };

highshelf2_test = os.tosc(440) : wa.highshelf2(2000, -6, 0);
highshelf2_slider_test = os.tosc(440) : wa.highshelf2(hslider("highshelf2:f0", 2000, 20, 20000, 1), hslider("highshelf2:gain", -6, -24, 24, 0.1), hslider("highshelf2:dtune", 0, -1200, 1200, 1));
highshelf2_modulated_test = no.noise : wa.highshelf2(20*pow(250, tri), -6, 0) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
highshelf2_jump_test = no.noise : wa.highshelf2(20*pow(250, sq), -6, 0) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
BiquadFilter_test = wa.BiquadFilter(1000, 6, 1, 0).lowpass2;
