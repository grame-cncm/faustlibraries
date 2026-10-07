//----------------------------------------------------------------------------
// filters_analog_sections_tests.dsp
// Tests for analog-transfer filter sections.
//----------------------------------------------------------------------------

fi = library("filters.lib");
os = library("oscillators.lib");
ma = library("maths.lib");
no = library("noises.lib");
ba = library("basics.lib");

src = os.tosc(440);

tf2s_test = src : fi.tf2s(0, 0, 1, sqrt(2), 1, ma.PI*ma.SR/2);
tf2s_lp20_test = no.noise : fi.tf2s(0, 0, 1, sqrt(2), 1, 2*ma.PI*20);
tf2s_lp5_test = no.noise : fi.tf2s(0, 0, 1, sqrt(2), 1, 2*ma.PI*5);
tf2s_notch50_test = no.noise : fi.tf2s(1, 0, 1, 0.1, 1, 2*ma.PI*50);
tf2s_slider_test = no.noise : fi.tf2s(0, 0, 1, sqrt(2), 1, 2*ma.PI*hslider("fc", 1000, 20, 20000, 1));
tf2s_modulated_test = no.noise : fi.tf2s(0, 0, 1, sqrt(2), 1, 2*ma.PI*20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
tf2s_jump_test = no.noise : fi.tf2s(0, 0, 1, sqrt(2), 1, 2*ma.PI*20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
tf2snp_test = src : fi.tf2snp(0, 0, 1, sqrt(2), 1, ma.PI*ma.SR/2);
tf2snp_lowfc_test = no.noise : fi.tf2snp(0, 0, 1, sqrt(2), 1, 2*ma.PI*20);
tf2snp_hp_lowfc_test = no.noise : fi.tf2snp(1, 0, 0, sqrt(2), 1, 2*ma.PI*10.1);
tf2s_nyquist_test = no.noise : fi.tf2s(0, 0, 1, sqrt(2), 1, 2*ma.PI*0.6*ma.SR);
tf2s_zero_freq_test = no.noise : fi.tf2s(1, 0, 0, sqrt(2), 1, 2*ma.PI*(1000*max(0, 1 - ba.time/12000) + 1000*(ba.time >= 24000)));
tf2s_audio_modulated_test = 0.1*no.noise : fi.tf2s(1, 1, 1, 0.1, 1, 2*ma.PI*max(20, 1000*(1 + 0.9*os.tosc(500))));
tf1snp_test = src : fi.tf1snp(0, 1, 1, ma.PI*ma.SR/2);
tf1snp_lowfc_test = no.noise : fi.tf1snp(0, 1, 1, 2*ma.PI*10.1);
tf1snp_slider_test = no.noise : fi.tf1snp(0, 1, 1, 2*ma.PI*hslider("fc", 1000, 20, 20000, 1));
tf1snp_modulated_test = no.noise : fi.tf1snp(0, 1, 1, 2*ma.PI*20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
tf1snp_jump_test = no.noise : fi.tf1snp(0, 1, 1, 2*ma.PI*20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
tf3slf_test = src : fi.tf3slf(0, 0, 0, 1, 1, 2, 2, 1);
tf3slf_lp20_test = no.noise : fi.tf3slf(0, 0, 0, w^3, 1, 2*w, 2*w^2, w^3) with { w = 2*ma.PI*20; };
tf3slf_hp20_test = no.noise : fi.tf3slf(1, 0, 0, 0, 1, 2*w, 2*w^2, w^3) with { w = 2*ma.PI*20; };
tf3slf_lp1k_test = no.noise : fi.tf3slf(0, 0, 0, w^3, 1, 2*w, 2*w^2, w^3) with { w = 2*ma.PI*1000; };
tf3slf_slider_test = no.noise : fi.tf3slf(0, 0, 0, w^3, 1, 2*w, 2*w^2, w^3) with { w = 2*ma.PI*hslider("fc", 1000, 20, 20000, 1); };
tf3slf_modulated_test = no.noise : fi.tf3slf(0, 0, 0, w^3, 1, 2*w, 2*w^2, w^3) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); w = 2*ma.PI*20*pow(250, tri); };
tf3slf_jump_test = no.noise : fi.tf3slf(0, 0, 0, w^3, 1, 2*w, 2*w^2, w^3) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; w = 2*ma.PI*20*pow(250, sq); };
tf1s_test = src : fi.tf1s(0, 1, 1, ma.PI*ma.SR/2);
tf1s_zero_freq_test = no.noise : fi.tf1s(1, 0, 1, 2*ma.PI*1000*(ba.time >= 100));
tf1s_nyquist_test = no.noise : fi.tf1s(0, 1, 1, 2*ma.PI*0.6*ma.SR);
tf1s_slider_test = no.noise : fi.tf1s(0, 1, 1, 2*ma.PI*hslider("fc", 1000, 20, 20000, 1));
tf1s_modulated_test = no.noise : fi.tf1s(0, 1, 1, 2*ma.PI*20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
tf1s_jump_test = no.noise : fi.tf1s(0, 1, 1, 2*ma.PI*20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
tf2sb_test = src : fi.tf2sb(0, 0, 1, sqrt(2), 1, 2*ma.PI*200, 2*ma.PI*1000);
tf2sb_zero_freq_test = no.noise : fi.tf2sb(1, 0, 0, sqrt(2), 1, 2*ma.PI*2000, 2*ma.PI*(1000*max(0, 1 - ba.time/12000) + 1000*(ba.time >= 24000)));
tf2sb_real_test = no.noise : fi.tf2sb(0.3, 0.5, 1, 3, 2, 2*ma.PI*500, 2*ma.PI*1000);
tf2sb_slider_test = no.noise : fi.tf2sb(0, 0, 1, sqrt(2), 1, 2*ma.PI*hslider("bw", 800, 10, 10000, 1), 2*ma.PI*hslider("fc", 1000, 20, 20000, 1));
tf2sb_modulated_test = no.noise : fi.tf2sb(0, 0, 1, sqrt(2), 1, 2*ma.PI*fc/5, 2*ma.PI*fc) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); fc = 20*pow(250, tri); };
tf2sb_jump_test = no.noise : fi.tf2sb(0, 0, 1, sqrt(2), 1, 2*ma.PI*fc/5, 2*ma.PI*fc) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; fc = 20*pow(250, sq); };
tf1sb_test = src : fi.tf1sb(0, 1, 1, 2*ma.PI*200, 2*ma.PI*1000);
tf1sb_zero_freq_test = no.noise : fi.tf1sb(0, 1, 1, 2*ma.PI*2000, 2*ma.PI*(1000*max(0, 1 - ba.time/12000) + 1000*(ba.time >= 24000)));
tf1sb_slider_test = no.noise : fi.tf1sb(0, 1, 1, 2*ma.PI*hslider("bw", 800, 10, 10000, 1), 2*ma.PI*hslider("fc", 1000, 20, 20000, 1));
tf1sb_modulated_test = no.noise : fi.tf1sb(0, 1, 1, 2*ma.PI*fc/5, 2*ma.PI*fc) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); fc = 20*pow(250, tri); };
tf1sb_jump_test = no.noise : fi.tf1sb(0, 1, 1, 2*ma.PI*fc/5, 2*ma.PI*fc) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; fc = 20*pow(250, sq); };
tf2s_df_test = src : fi.tf2s_df(0, 0, 1, sqrt(2), 1, ma.PI*ma.SR/2);
tf2s_df_lp1k_test = no.noise : fi.tf2s_df(0, 0, 1, sqrt(2), 1, 2*ma.PI*1000);
tf2s_df_slider_test = no.noise : fi.tf2s_df(0, 0, 1, sqrt(2), 1, 2*ma.PI*hslider("fc", 2000, 2000, 20000, 1));
tf2s_df_modulated_test = no.noise : fi.tf2s_df(0, 0, 1, sqrt(2), 1, 2*ma.PI*2000*pow(8, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
tf2s_df_jump_test = no.noise : fi.tf2s_df(0, 0, 1, sqrt(2), 1, 2*ma.PI*2000*pow(8, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
tf1s_df_test = src : fi.tf1s_df(0, 1, 1, ma.PI*ma.SR/2);
tf1s_df_hp_test = no.noise : fi.tf1s_df(1, 0, 1, 2*ma.PI*100);
tf1s_df_slider_test = no.noise : fi.tf1s_df(0, 1, 1, 2*ma.PI*hslider("fc", 1000, 20, 20000, 1));
tf1s_df_modulated_test = no.noise : fi.tf1s_df(0, 1, 1, 2*ma.PI*20*pow(250, tri)) with { P = int(ma.SR/10); tri = 1 - abs(2*ba.period(P)/P - 1); };
tf1s_df_jump_test = no.noise : fi.tf1s_df(0, 1, 1, 2*ma.PI*20*pow(250, sq)) with { P = int(ma.SR/10); sq = ba.period(2*P) < P; };
tpt_df_fmin_test = os.tosc(440) * (fi.tpt_df_fmin <= 2304);
