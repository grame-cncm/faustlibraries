//----------------------------------------------------------------------------
// filters_elliptic_tests.dsp
// Tests for elliptic (Cauer) lowpass/highpass helper filters.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");
no = library("noises.lib");
ba = library("basics.lib");
ma = library("maths.lib");

src = os.tosc(440);

lowpass3e_test = src : fi.lowpass3e(1000);
lowpass3e_slider_test = no.noise : fi.lowpass3e(hslider("fc", 1000, 20, 20000, 1));
lowpass6e_test = src : fi.lowpass6e(1000);
lowpass6e_slider_test = no.noise : fi.lowpass6e(hslider("fc", 1000, 20, 20000, 1));
highpass3e_test = src : fi.highpass3e(1000);
highpass3e_slider_test = no.noise : fi.highpass3e(hslider("fc", 1000, 20, 20000, 1));
highpass3e_modulated_test = no.noise : fi.highpass3e(20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
highpass3e_jump_test = no.noise : fi.highpass3e(20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
highpass6e_test = src : fi.highpass6e(1000);
highpass6e_slider_test = no.noise : fi.highpass6e(hslider("fc", 1000, 20, 20000, 1));
highpass6e_modulated_test = no.noise : fi.highpass6e(20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
highpass6e_jump_test = no.noise : fi.highpass6e(20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
lowpass6e_tpt_df_test = no.noise : fi.lowpass6e_tpt_df(fi.tpt_df_fmin, 4000);
lowpass6e_tpt_df_low_test = no.noise : fi.lowpass6e_tpt_df(fi.tpt_df_fmin, 50);
lowpass6e_tpt_df_slider_test = no.noise : fi.lowpass6e_tpt_df(fi.tpt_df_fmin, hslider("fc", 1000, 20, 20000, 1));
lowpass6e_tpt_df_modulated_test = no.noise : fi.lowpass6e_tpt_df(0, 2500*pow(8, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
lowpass6e_tpt_df_jump_test = no.noise : fi.lowpass6e_tpt_df(ma.MAX, 20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
highpass6e_tpt_df_test = no.noise : fi.highpass6e_tpt_df(fi.tpt_df_fmin, 4000);
highpass6e_tpt_df_low_test = no.noise : fi.highpass6e_tpt_df(fi.tpt_df_fmin, 50);
highpass6e_tpt_df_slider_test = no.noise : fi.highpass6e_tpt_df(fi.tpt_df_fmin, hslider("fc", 1000, 20, 20000, 1));
highpass6e_tpt_df_modulated_test = no.noise : fi.highpass6e_tpt_df(0, 2500*pow(8, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
highpass6e_tpt_df_jump_test = no.noise : fi.highpass6e_tpt_df(ma.MAX, 20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
