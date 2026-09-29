import("tosc.lib");  // the test source without phase drift (tosc.lib)
import("stdfaust.lib");

wa = library("webaudio.lib");
os = library("oscillators.lib");

lowpass2_test = tosc(440) : wa.lowpass2(1000, 0.707, 0);

highpass2_test = tosc(440) : wa.highpass2(1000, 0.707, 0);

bandpass2_test = tosc(440) : wa.bandpass2(1000, 1, 0);

notch2_test = tosc(440) : wa.notch2(1000, 1, 0);

allpass2_test = tosc(440) : wa.allpass2(1000, 1, 0);

peaking2_test = tosc(440) : wa.peaking2(1000, 3, 1, 0);

lowshelf2_test = tosc(440) : wa.lowshelf2(500, 6, 0);

highshelf2_test = tosc(440) : wa.highshelf2(2000, -6, 0);
BiquadFilter_test = wa.BiquadFilter(1000, 6, 1, 0).lowpass2;
