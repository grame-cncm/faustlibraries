//----------------------------------------------------------------------------
// filters_butterworth_tests.dsp
// Tests for basic Butterworth helper filters.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");
no = library("noises.lib");
ba = library("basics.lib");
ma = library("maths.lib");

src = os.tosc(440);

lowpass_test = src : fi.lowpass(4, 2000);
lowpass_lowfc_test = no.noise : fi.lowpass(3, 10.1);
lowpass_zero_freq_test = no.noise : fi.lowpass(3, 1000*max(0, 1 - ba.time/12000) + 1000*(ba.time >= 24000));
lowpass_slider_test = no.noise : fi.lowpass(4, hslider("fc", 2000, 20, 20000, 1));
lowpass_modulated_test = no.noise : fi.lowpass(4, 20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
lowpass_jump_test = no.noise : fi.lowpass(4, 20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
highpass_test = src : fi.highpass(4, 500);
highpass_lowfc_test = no.noise : fi.highpass(3, 10.1);
highpass_zero_freq_test = no.noise : fi.highpass(3, 1000*max(0, 1 - ba.time/12000) + 1000*(ba.time >= 24000));
highpass_slider_test = no.noise : fi.highpass(4, hslider("fc", 500, 20, 20000, 1));
highpass_modulated_test = no.noise : fi.highpass(4, 20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
highpass_jump_test = no.noise : fi.highpass(4, 20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
lowpass0_highpass1_test = src : fi.lowpass0_highpass1(0, 2, 1000);
lowpass0_highpass1_slider_test = no.noise : fi.lowpass0_highpass1(0, 2, hslider("fc", 1000, 20, 20000, 1));
lowpass0_highpass1_modulated_test = no.noise : fi.lowpass0_highpass1(0, 2, 20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
lowpass0_highpass1_jump_test = no.noise : fi.lowpass0_highpass1(0, 2, 20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
lowpass_tpt_df_test = no.noise : fi.lowpass_tpt_df(fi.tpt_df_fmin, 5, 4000);
lowpass_tpt_df_low_test = no.noise : fi.lowpass_tpt_df(fi.tpt_df_fmin, 5, 50);
lowpass_tpt_df_slider_test = no.noise : fi.lowpass_tpt_df(fi.tpt_df_fmin, 3, hslider("fc", 1000, 20, 20000, 1));
lowpass_tpt_df_modulated_test = no.noise : fi.lowpass_tpt_df(0, 3, 2500*pow(8, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
lowpass_tpt_df_jump_test = no.noise : fi.lowpass_tpt_df(ma.MAX, 3, 20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
highpass_tpt_df_test = no.noise : fi.highpass_tpt_df(fi.tpt_df_fmin, 5, 4000);
highpass_tpt_df_low_test = no.noise : fi.highpass_tpt_df(fi.tpt_df_fmin, 5, 50);
highpass_tpt_df_slider_test = no.noise : fi.highpass_tpt_df(fi.tpt_df_fmin, 3, hslider("fc", 1000, 20, 20000, 1));
highpass_tpt_df_modulated_test = no.noise : fi.highpass_tpt_df(0, 3, 2500*pow(8, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
highpass_tpt_df_jump_test = no.noise : fi.highpass_tpt_df(ma.MAX, 3, 20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
