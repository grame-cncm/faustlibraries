//----------------------------------------------------------------------------
// hysteresis_tests.dsp
// Tests for hysteresis helper functions.
//----------------------------------------------------------------------------

hy = library("hysteresis.lib");
ba = library("basics.lib");
os = library("oscillators.lib");
ma = library("maths.lib");

mono = os.tosc(100) * 0.5;
stereo = os.tosc(100), os.tosc(150);

ja_hysteresis_test = mono : hy.ja_hysteresis(380, 720, 0.015, 380, 0.25);
ja_hysteresis_slider_test = os.tosc(100)*0.5 : hy.ja_hysteresis(hslider("ja_hysteresis:Ms", 380, 100, 1000, 1), hslider("ja_hysteresis:a", 720, 100, 2000, 1), hslider("ja_hysteresis:alpha", 0.015, 0, 0.1, 0.001), hslider("ja_hysteresis:k", 380, 100, 1000, 1), hslider("ja_hysteresis:c", 0.25, 0, 1, 0.01));
ja_hysteresis_modulated_test = os.tosc(100)*0.5 : hy.ja_hysteresis(380, 720, 0.015, 100*pow(10, tri), 0.25) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
ja_processor_test = mono : hy.ja_processor(380, 720, 0.015, 380, 0.25, ba.db2linear(10), 1.0);
ja_processor_slider_test = os.tosc(100)*0.5 : hy.ja_processor(hslider("ja_processor:Ms", 380, 100, 1000, 1), hslider("ja_processor:a", 720, 100, 2000, 1), hslider("ja_processor:alpha", 0.015, 0, 0.1, 0.001), hslider("ja_processor:k", 380, 100, 1000, 1), hslider("ja_processor:c", 0.25, 0, 1, 0.01), hslider("ja_processor:drive", 3.1623, 0, 10, 0.0001), hslider("ja_processor:trim", 1.0, 0, 2, 0.01));
ja_processor_modulated_test = os.tosc(100)*0.5 : hy.ja_processor(380, 720, 0.015, 380, 0.25, ba.db2linear(20*tri), 1.0) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
ja_processor_stereo_test = stereo : hy.ja_processor_stereo(380, 720, 0.015, 380, 0.25, ba.db2linear(10), 1.0);

ja_processor_ui_test = mono : hy.ja_processor_ui;
ja_processor_stereo_ui_test = stereo : hy.ja_processor_stereo_ui;
