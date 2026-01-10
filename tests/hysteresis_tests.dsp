//----------------------------------------------------------------------------
// hysteresis_tests.dsp
// Tests for hysteresis helper functions.
//----------------------------------------------------------------------------

hy = library("hysteresis.lib");
ba = library("basics.lib");
os = library("oscillators.lib");

mono = os.osc(100) * 0.5;
stereo = os.osc(100), os.osc(150);

ja_hysteresis_test = mono : hy.ja_hysteresis(380, 720, 0.015, 380, 0.25);
ja_processor_test = mono : hy.ja_processor(380, 720, 0.015, 380, 0.25, ba.db2linear(10), 1.0);
ja_processor_stereo_test = stereo : hy.ja_processor_stereo(380, 720, 0.015, 380, 0.25, ba.db2linear(10), 1.0);

ja_processor_ui_test = mono : hy.ja_processor_ui;
ja_processor_stereo_ui_test = stereo : hy.ja_processor_stereo_ui;
